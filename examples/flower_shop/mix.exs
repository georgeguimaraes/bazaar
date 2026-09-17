defmodule FlowerShop.MixProject do
  use Mix.Project

  def project do
    [
      app: :flower_shop,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {FlowerShop.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:bazaar, path: "../.."},
      {:phoenix, "~> 1.8"},
      {:bandit, "~> 1.6"},
      {:jason, "~> 1.4"},
      {:req, "~> 0.5"}
    ]
  end
end
