defmodule Tail.Mixfile do
  use Mix.Project

  def project do
    [
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore.exs",
        list_unused_filters: true,
        plt_file: {:no_warn, "priv/plts/tail.plt"}
      ],
      app: :tail,
      version: "1.1.1",
      elixir: "~> 1.6",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: [
        readme: "README.md",
        main: "Tail",
        source_url: "https://github.com/TheFirstAvenger/elixir-tail.git"
      ]
    ]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:excoveralls, "~> 0.12.1", only: :test},
      {:credo, "~> 1.2.0-rc1", only: [:dev, :test], runtime: false},
      {:mix_test_watch, "~> 1.0.2", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev, :test], runtime: false},
      {:earmark, "~> 1.4.3", only: :dev},
      {:ex_doc, "~> 0.21.2", only: :dev}
    ]
  end

  defp description do
    "A simple file tail functionality. Calls a callback function whenever new lines are detected on a file."
  end

  defp package do
    [
      contributors: ["Mike Binns", "Jordan Day"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/TheFirstAvenger/elixir-tail.git"}
    ]
  end
end
