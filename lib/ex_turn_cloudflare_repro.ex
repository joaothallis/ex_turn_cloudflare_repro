defmodule ExTurnCloudflareRepro do
  @moduledoc """
  Minimal reproduction for STUN 437 "Allocation Mismatch" emitted by
  ExTURN.Client 0.2.1 against Cloudflare TURN when peer connections are
  opened/closed rapidly on a narrow UDP source-port range.

  Entry point: `mix run -e "ExTurnCloudflareRepro.run()"`

  Exit code reflects the signal:
    * `0` — all N iterations completed without a 437 (GREEN)
    * `2` — at least one 437 was observed (RED — the bug reproduces)
  """
  require Logger

  alias ExTurnCloudflareRepro.{CloudflareClient, IceFilter, Loop}

  @default_iterations 20
  @default_port_range_start 50_000
  @default_port_range_size 5

  @spec run() :: no_return()
  def run do
    opts = read_opts()

    Logger.info(
      "[repro] starting server=#{opts[:server]} iterations=#{opts[:iterations]} " <>
        "ports=#{inspect(opts[:port_range])}"
    )

    ice_servers =
      case opts[:server] do
        :cloudflare -> fetch_cloudflare!()
        :coturn -> fetch_coturn!()
      end

    filtered = IceFilter.filter_turn_udp_3478(ice_servers)
    Logger.info("[repro] filtered servers: #{inspect(filtered)}")

    result = Loop.run(filtered, iterations: opts[:iterations], port_range: opts[:port_range])

    report(result)

    System.halt(if result.seen_437?, do: 2, else: 0)
  end

  defp read_opts do
    port_start = int_env("REPRO_PORT_RANGE_START", @default_port_range_start)
    port_size = int_env("REPRO_PORT_RANGE_SIZE", @default_port_range_size)

    server =
      case System.get_env("TURN_SERVER", "cloudflare") do
        "cloudflare" -> :cloudflare
        "coturn" -> :coturn
        other -> raise "Unknown TURN_SERVER=#{other}, expected cloudflare|coturn"
      end

    [
      server: server,
      iterations: int_env("REPRO_ITERATIONS", @default_iterations),
      port_range: port_start..(port_start + port_size - 1)
    ]
  end

  defp int_env(name, default) do
    case System.get_env(name) do
      nil -> default
      val -> String.to_integer(val)
    end
  end

  defp fetch_cloudflare! do
    id = System.fetch_env!("CF_TURN_APP_ID")
    token = System.fetch_env!("CF_TURN_APP_TOKEN")

    case CloudflareClient.fetch_ice_servers(id, token) do
      {:ok, servers} -> servers
      {:error, reason} -> raise "Cloudflare fetch failed: #{inspect(reason)}"
    end
  end

  defp fetch_coturn! do
    [
      %{
        "urls" => [System.get_env("COTURN_URL", "turn:127.0.0.1:3478?transport=udp")],
        "username" => System.get_env("COTURN_USERNAME", "repro"),
        "credential" => System.get_env("COTURN_CREDENTIAL", "repro")
      }
    ]
  end

  defp report(result) do
    total = length(result.iterations)
    relay = Enum.count(result.iterations, & &1.relay_candidate?)
    gathered = Enum.count(result.iterations, & &1.gathering_completed?)

    # IO.puts rather than Logger.info so the summary reliably flushes before
    # the immediately-following System.halt/1 tears down the runtime.
    IO.puts(
      "[repro] result: iterations=#{total} relay=#{relay} gathered=#{gathered} " <>
        "seen_437?=#{result.seen_437?} first_437_iteration=#{inspect(result.first_437_iteration)}"
    )
  end
end
