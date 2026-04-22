defmodule ExTurnCloudflareRepro.IceFilterTest do
  use ExUnit.Case, async: true
  alias ExTurnCloudflareRepro.IceFilter

  test "keeps stun:* and turn:*:3478?transport=udp only" do
    input = [
      %{
        "urls" => [
          "stun:stun.cloudflare.com:3478",
          "turn:turn.cloudflare.com:3478?transport=udp",
          "turn:turn.cloudflare.com:3478?transport=tcp",
          "turn:turn.cloudflare.com:53?transport=udp",
          "turns:turn.cloudflare.com:5349?transport=tcp"
        ],
        "username" => "u",
        "credential" => "c"
      }
    ]

    assert [
             %{
               "urls" => [
                 "stun:stun.cloudflare.com:3478",
                 "turn:turn.cloudflare.com:3478?transport=udp"
               ],
               "username" => "u",
               "credential" => "c"
             }
           ] = IceFilter.filter_turn_udp_3478(input)
  end

  test "drops entries whose urls become empty" do
    input = [%{"urls" => ["turn:x:5349?transport=tcp"], "username" => "u", "credential" => "c"}]
    assert [] = IceFilter.filter_turn_udp_3478(input)
  end

  test "passes through entries without urls key unchanged" do
    input = [%{"username" => "u"}]
    assert [%{"username" => "u"}] = IceFilter.filter_turn_udp_3478(input)
  end
end
