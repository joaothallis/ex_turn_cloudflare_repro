defmodule ExTurnCloudflareRepro.Loop do
  @moduledoc """
  Runs N open/close iterations back-to-back (no cooldown between them)
  on the pinned `ice_port_range`. Returns an aggregate result and whether
  any iteration hit the ExTURN 437 signature.
  """
  require Logger

  alias ExTurnCloudflareRepro.{LogHandler, Probe}

  @type result :: %{
          iterations: [Probe.outcome()],
          seen_437?: boolean(),
          first_437_iteration: non_neg_integer() | nil
        }

  @spec run([map()], keyword()) :: result()
  def run(ice_servers, opts) do
    n = Keyword.fetch!(opts, :iterations)
    port_range = Keyword.fetch!(opts, :port_range)
    delay_ms = Keyword.get(opts, :delay_ms, 0)

    :ok = LogHandler.install(self())

    outcomes =
      try do
        Enum.map(1..n, fn i ->
          :ok = LogHandler.set_iteration(i)
          if i > 1 and delay_ms > 0, do: Process.sleep(delay_ms)
          outcome = Probe.run(i, ice_servers, port_range)

          Logger.info(
            "[repro] iter=#{i} relay=#{outcome.relay_candidate?} " <>
              "gathered=#{outcome.gathering_completed?} ms=#{outcome.elapsed_ms}"
          )

          outcome
        end)
      after
        LogHandler.uninstall()
      end

    first_437 = drain_first_437()

    %{
      iterations: outcomes,
      seen_437?: first_437 != nil,
      first_437_iteration: first_437
    }
  end

  defp drain_first_437(acc \\ nil) do
    receive do
      {:repro_437, i} when acc == nil -> drain_first_437(i)
      {:repro_437, _} -> drain_first_437(acc)
    after
      0 -> acc
    end
  end
end
