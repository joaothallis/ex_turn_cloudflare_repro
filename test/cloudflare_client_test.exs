defmodule ExTurnCloudflareRepro.CloudflareClientTest do
  use ExUnit.Case, async: true
  alias ExTurnCloudflareRepro.CloudflareClient

  test "parse extracts iceServers on 201 (single server)" do
    body = %{
      "iceServers" => %{
        "urls" => ["turn:turn.cloudflare.com:3478?transport=udp"],
        "username" => "u",
        "credential" => "c"
      }
    }

    assert {:ok,
            [
              %{
                "urls" => ["turn:turn.cloudflare.com:3478?transport=udp"],
                "username" => "u",
                "credential" => "c"
              }
            ]} = CloudflareClient.parse({:ok, %{status: 201, body: body}})
  end

  test "parse extracts iceServers on 201 (list form)" do
    body = %{
      "iceServers" => [
        %{"urls" => ["stun:stun.cloudflare.com:3478"]}
      ]
    }

    assert {:ok, [%{"urls" => ["stun:stun.cloudflare.com:3478"]}]} =
             CloudflareClient.parse({:ok, %{status: 201, body: body}})
  end

  test "parse returns error on non-201" do
    assert {:error, "HTTP 401:" <> _} =
             CloudflareClient.parse({:ok, %{status: 401, body: %{"error" => "nope"}}})
  end

  test "parse returns error on transport error" do
    assert {:error, :timeout} = CloudflareClient.parse({:error, :timeout})
  end
end
