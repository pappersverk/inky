defmodule Inky.MixProject do
  use Mix.Project

  def project do
    [
      app: :inky,
      version: "1.0.2",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      source_url: "https://github.com/pappersverk/inky/",
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:circuits_gpio, "~> 0.4"},
      {:circuits_spi, "~> 0.1"},
      {:credo, "~> 1.0.0", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp docs do
    [
      main: Inky,
      extras: [
        "README.md": [
          title: "Readme"
        ]
      ]
    ]
  end

  defp package do
    [
      name: "inky",
      description:
        "A library to drive the Inky series of eInk displays from Pimoroni. Ported from the original Python project, all Elixir.",
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/pappersverk/inky"}
    ]
  end
end
