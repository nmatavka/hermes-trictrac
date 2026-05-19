defmodule HermesTrictrac.MixProject do
  use Mix.Project

  def project do
    [
      app: :hermes_trictrac,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      listeners: [Phoenix.CodeReloader],
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {HermesTrictrac.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.8"},
      {:phoenix_html, "~> 4.2"},
      {:phoenix_live_reload, "~> 1.6", only: :dev},
      {:phoenix_live_view, "~> 1.1"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.4"},
      {:plug_cowboy, "~> 2.8"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:hermes_bluesky, path: "hermes-bluesky"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "cmd --cd assets npm install"],
      "assets.build": ["esbuild hermes_trictrac"],
      "assets.deploy": [
        "cmd --cd assets npm install",
        "esbuild hermes_trictrac --minify",
        "phx.digest"
      ]
    ]
  end
end
