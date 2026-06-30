defmodule AccountServer.MixProject do
  use Mix.Project

  def project do
    [
      app: :account_server,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      dialyzer: dialyzer(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Aesir.AccountServer.Application, []}
    ]
  end

  defp deps do
    [
      {:commons, in_umbrella: true}
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:mix],
      ignore_warnings: "../../.dialyzer_ignore.exs"
    ]
  end
end
