defmodule ExTurnCloudflareRepro.IceFilter do
  @moduledoc """
  Keeps only `turn:*:3478?transport=udp` and `stun:*` URLs. ex_turn 0.2.x
  speaks UDP only, and multiple TURN entries on the same host but different
  ports trigger an ex_ice routing bug — so we drop the rest before handing
  the list to `PeerConnection.start_link/1`.
  """

  @spec filter_turn_udp_3478([map()]) :: [map()]
  def filter_turn_udp_3478(ice_servers) do
    ice_servers
    |> Enum.map(fn
      %{"urls" => urls} = server when is_list(urls) ->
        kept =
          Enum.filter(urls, fn url ->
            String.starts_with?(url, "stun:") or
              String.match?(url, ~r/^turn:.+:3478\?transport=udp$/)
          end)

        %{server | "urls" => kept}

      other ->
        other
    end)
    |> Enum.reject(fn
      %{"urls" => []} -> true
      _ -> false
    end)
  end
end
