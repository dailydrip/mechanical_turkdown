defmodule MechanicalTurkdown.Mixfile do
  use Mix.Project

  def project do
    [
      app: :mechanical_turkdown,
      version: "0.1.0",
      elixir: "~> 1.3",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      applications: [
        :logger,
        :erlcloud,
      ],
      mod: {MechanicalTurkdown, []}]
  end

  defp deps do
    [
      {:erlcloud, "~> 2.2.1"},
    ]
  end
end
