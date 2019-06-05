defmodule InkyZeroNerves.MixProject do
  use Mix.Project

  def project do
    [
      app: :inky,
      version: "0.0.1",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:circuits_spi, "~> 0.1"}
    ]
  end
end
