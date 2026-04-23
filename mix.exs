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
      {:ex_webrtc, "~> 0.16.0"},
      {:ex_ice, "~> 0.15.0"},
      {:ex_turn, "~> 0.2.1"},
      {:req, "~> 0.5"}
    ]
  end
end
