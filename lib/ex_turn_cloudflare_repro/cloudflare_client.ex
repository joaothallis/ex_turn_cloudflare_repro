defmodule ExTurnCloudflareRepro.CloudflareClient do
  @moduledoc """
  Posts to `rtc.live.cloudflare.com/v1/turn/keys/<id>/credentials/generate-ice-servers`
  with a 24h TTL and returns the `iceServers` list as-is (string keys,
  same shape Cloudflare documents).
  """
  require Logger

  @base_url "https://rtc.live.cloudflare.com"

  @spec fetch_ice_servers(String.t(), String.t(), pos_integer()) ::
          {:ok, [map()]} | {:error, term()}
  def fetch_ice_servers(app_id, app_token, ttl \\ 86_400) do
    url = "#{@base_url}/v1/turn/keys/#{app_id}/credentials/generate-ice-servers"

    Req.post(
      url,
      headers: %{
        "content-type" => ["application/json"],
        "authorization" => "Bearer #{app_token}"
      },
      json: %{"ttl" => ttl}
    )
    |> parse()
  end

  @doc false
  @spec parse(term()) :: {:ok, [map()]} | {:error, term()}
  def parse({:ok, %{status: 201, body: %{"iceServers" => ice_servers}}}) do
    {:ok, List.wrap(ice_servers)}
  end

  def parse({:ok, %{status: status, body: body}}) do
    {:error, "HTTP #{status}: #{inspect(body)}"}
  end

  def parse({:error, reason}), do: {:error, reason}
end
