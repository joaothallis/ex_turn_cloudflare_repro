defmodule ExTurnCloudflareRepro.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_turn_cloudflare_repro,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:ex_webrtc, "~> 0.14.0"},
      # ex_webrtc 0.14.0 declares `ex_ice ~> 0.12.0`, but 0.12.x has a race
      # condition fixed in 0.14.0. Override to pick up the fix.
      {:ex_ice, "== 0.14.0", override: true},
      {:ex_turn, "~> 0.2.1"},
      {:req, "~> 0.5"}
    ]
  end
end
