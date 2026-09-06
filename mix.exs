defmodule Aesir.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.14.0",
      start_permanent: Mix.env() == :prod,
      dialyzer: dialyzer(),
      deps: deps(),
      aliases: aliases()
    ]
  end

  def cli do
    [preferred_envs: ["test.integration": :test]]
  end

  defp aliases do
    [
      "test.integration": &test_integration/1
    ]
  end

  defp test_integration(args) do
    Mix.Task.run("app.config")

    selector =
      case Application.get_env(:commons, :game_mode, :renewal) do
        :renewal -> "integration_re:true"
        :pre_renewal -> "integration_pre_re:true"
      end

    Mix.Task.run("test", ["--only", selector | args])
  end

  defp dialyzer do
    [
      plt_add_apps: [:mix],
      ignore_warnings: ".dialyzer_ignore.exs"
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev], runtime: false},
      {:hush, "~> 1.2"},
      {:oeditus_credo, "~> 0.8", only: [:dev], runtime: false}
    ]
  end
end
