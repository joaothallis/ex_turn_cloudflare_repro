defmodule ExTurnCloudflareRepro.Probe do
  @moduledoc """
  Single iteration: start a `PeerConnection` pinned to a narrow port range,
  add a dummy audio track so ICE gathering actually kicks off, wait until
  gathering completes or times out, record whether any `typ relay` candidate
  was emitted, then close the PC without any cooldown.
  """
  require Logger
  alias ExWebRTC.{MediaStreamTrack, PeerConnection}

  @gather_timeout_ms 10_000

  @type outcome :: %{
          iteration: non_neg_integer(),
          relay_candidate?: boolean(),
          gathering_completed?: boolean(),
          elapsed_ms: non_neg_integer()
        }

  @spec run(non_neg_integer(), [map()], Enumerable.t()) :: outcome()
  def run(iteration, ice_servers, port_range) do
    t0 = System.monotonic_time(:millisecond)

    {:ok, pc} =
      PeerConnection.start_link(
        ice_servers: to_atom_keys(ice_servers),
        ice_port_range: port_range
      )

    audio = MediaStreamTrack.new(:audio, ["audio_stream"])
    {:ok, _sender} = PeerConnection.add_track(pc, audio)

    {:ok, offer} = PeerConnection.create_offer(pc)
    :ok = PeerConnection.set_local_description(pc, offer)

    {completed?, relay?} = wait_for_gathering(pc, false)

    :ok = PeerConnection.close(pc)

    %{
      iteration: iteration,
      relay_candidate?: relay?,
      gathering_completed?: completed?,
      elapsed_ms: System.monotonic_time(:millisecond) - t0
    }
  end

  defp wait_for_gathering(pc, relay?) do
    receive do
      {:ex_webrtc, ^pc, {:ice_candidate, %{candidate: cand}}} ->
        wait_for_gathering(pc, relay? or String.contains?(cand || "", "typ relay"))

      {:ex_webrtc, ^pc, {:ice_gathering_state_change, :complete}} ->
        {true, relay?}

      {:ex_webrtc, ^pc, _other} ->
        wait_for_gathering(pc, relay?)
    after
      @gather_timeout_ms -> {false, relay?}
    end
  end

  # Cloudflare returns string keys; ExWebRTC expects atom keys.
  defp to_atom_keys(ice_servers) do
    Enum.map(ice_servers, fn server ->
      %{
        urls: server["urls"],
        username: server["username"],
        credential: server["credential"]
      }
    end)
  end
end
