defmodule ZoneServer.MixProject do
  use Mix.Project

  def project do
    [
      app: :zone_server,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Aesir.ZoneServer.Application, []}
    ]
  end

  defp deps do
    [
      {:commons, in_umbrella: true}
    ]
  end
end
