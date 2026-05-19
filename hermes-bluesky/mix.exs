defmodule HermesBluesky.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://example.invalid/hermes-bluesky"

  def project do
    [
      app: :hermes_bluesky,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Hermes.Bluesky.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:atex, path: "atex-main"},
      {:gen_stage, "~> 1.3"},
      {:jason, "~> 1.4"},
      {:jose, "~> 1.11"},
      {:mime, "~> 2.0"},
      {:plug, "~> 1.18"},
      {:req, "~> 0.5"},
      {:telemetry, "~> 1.0"},
      {:wesex, git: "https://github.com/OdielDomanie/wesex", tag: "0.4.3"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.39", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Unified Elixir Bluesky SDK that stitches together the local ATProto projects."
  end

  defp package do
    [
      licenses: ["GPL-3.0-or-later"],
      links: %{"Source" => @source_url}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "UPSTREAMS.md", "LICENSE"],
      source_url: @source_url,
      source_ref: "v#{@version}"
    ]
  end
end
