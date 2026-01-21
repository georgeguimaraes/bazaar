defmodule Bazaar.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/georgeguimaraes/bazaar"

  def project do
    [
      app: :bazaar,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),

      # Hex
      description: "Open your store to AI agents. Elixir SDK for UCP.",
      package: package(),

      # Docs
      name: "Bazaar",
      docs: docs(),
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:smelter, path: "../smelter"},
      {:ecto, "~> 3.12"},
      {:jason, "~> 1.4"},
      {:jsv, "~> 0.15", optional: true},
      {:plug, "~> 1.16", optional: true},
      {:phoenix, "~> 1.7", optional: true},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["George Guimarães"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib priv .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "guides/getting-started.md",
        "guides/handlers.md",
        "guides/schemas.md",
        "guides/plugs.md",
        "guides/testing.md"
      ],
      groups_for_extras: [
        Guides: ~r/guides\/.*/
      ],
      source_ref: "v#{@version}"
    ]
  end
end
