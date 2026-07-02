defmodule Aesir.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.5.0",
      start_permanent: Mix.env() == :prod,
      dialyzer: dialyzer(),
      deps: deps()
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:mix],
      ignore_warnings: ".dialyzer_ignore.exs"
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev], runtime: false},
      {:hush, "~> 1.2"},
      {:oeditus_credo, "~> 0.8", only: [:dev], runtime: false}
    ]
  end
end
