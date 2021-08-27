defmodule CPSIM.MixProject do
  use Mix.Project

  def project do
    [
      app: :cpsim_cp,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {CPSIM.CP.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:websockex, "~> 0.4.3"},
      {:elixir_uuid, "~> 1.2"},
      {:jason, "~> 1.2"},
      {:accessible, "~> 0.3.0"}
    ]
  end
end
