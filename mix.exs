defmodule AssetImport.MixProject do
  use Mix.Project

  @version "0.2.0"

  def project do
    [
      app: :asset_import,
      version: @version,
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps(),
      docs: docs(),
      description: """
      Webpack asset imports in Elixir code. For example in Phoenix controllers/views/templates or LiveView's.
      """
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.1"},
      {:phoenix, "~> 1.4", only: :test},
      {:phoenix_html, "~> 2.13"},
      {:phoenix_live_view, "~> 0.3", only: :test},
      {:mix_test_watch, "~> 0.5", only: :dev, runtime: false},
      {:ex_unit_notifier, "~> 0.1", only: :test},
      {:floki, "~> 0.23.0", only: :test},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}",
      source_url: "https://github.com/coingaming/asset_import"
    ]
  end

  defp package do
    [
      maintainers: ["Reio Piller"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/coingaming/asset_import"},
      files: ~w(lib index.js package.json LICENSE.md mix.exs README.md)
    ]
  end
end
