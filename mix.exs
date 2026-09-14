defmodule Aesir.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.16.0",
      start_permanent: Mix.env() == :prod,
      dialyzer: dialyzer(),
      deps: deps(),
      aliases: aliases()
    ]
  end

  def cli do
    [
      preferred_envs: [
        "test.integration": :test,
        "test.re": :test,
        "test.pre_re": :test,
        "test.integration.re": :test,
        "test.integration.pre_re": :test
      ]
    ]
  end

  defp aliases do
    [
      "test.integration": &test_integration/1,
      "test.re": &test_mode("renewal", "test", &1),
      "test.pre_re": &test_mode("pre_renewal", "test", &1),
      "test.integration.re": &test_mode("renewal", "test.integration", &1),
      "test.integration.pre_re": &test_mode("pre_renewal", "test.integration", &1)
    ]
  end

  defp test_mode(mode, task, args) do
    System.put_env("AESIR_DB_MODE", mode)
    Mix.Task.run(task, args)
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
