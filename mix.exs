defmodule Aesir.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  defp deps do
    [
      {:mimic, "~> 1.12", only: [:test, :dev]},
      {:recode, "~> 0.6", only: :dev, runtime: false}
    ]
  end
end
