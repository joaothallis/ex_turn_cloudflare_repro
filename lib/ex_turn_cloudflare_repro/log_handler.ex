defmodule ExTurnCloudflareRepro.LogHandler do
  @moduledoc """
  `:logger` handler that watches for the `ExTURN.Client` 437 line and
  forwards a `{:repro_437, iteration}` message to the caller process.

  We can't rely on `Logger.metadata` because `ExTURN.Client` is its own
  GenServer and no metadata is attached to its log calls.
  """

  @handler_id :repro_437_detector
  @signature "Failed to create allocation, reason: 437"

  @spec install(pid()) :: :ok | {:error, term()}
  def install(parent) when is_pid(parent) do
    :logger.add_handler(@handler_id, __MODULE__, %{
      config: %{parent: parent},
      level: :info
    })
  end

  @spec uninstall() :: :ok | {:error, term()}
  def uninstall, do: :logger.remove_handler(@handler_id)

  @spec set_iteration(non_neg_integer()) :: :ok
  def set_iteration(i) do
    {:ok, %{config: config} = cfg} = :logger.get_handler_config(@handler_id)
    :logger.update_handler_config(@handler_id, %{cfg | config: Map.put(config, :iteration, i)})
    :ok
  end

  @doc false
  def log(%{msg: msg} = _event, %{config: %{parent: parent} = config}) do
    text = format(msg)

    if String.contains?(text, @signature) do
      send(parent, {:repro_437, Map.get(config, :iteration, :unknown)})
    end

    :ok
  end

  defp format({:string, s}), do: IO.iodata_to_binary(s)
  defp format({:report, report}), do: inspect(report)

  defp format({format, args}) do
    format |> :io_lib.format(args) |> IO.iodata_to_binary()
  rescue
    _ -> inspect({format, args})
  end
end
