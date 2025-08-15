defmodule Commons.MixProject do
  use Mix.Project

  def project do
    [
      app: :commons,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :bunt],
      mod: {Aesir.Commons.Application, []}
    ]
  end

  defp deps do
    [
      {:bcrypt_elixir, "~> 3.0"},
      {:bunt, "~> 1.0"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.16", only: [:dev, :test], runtime: false},
      {:ecto, "~> 3.13"},
      {:ecto_sql, "~> 3.13"},
      {:ex_doc, "~> 0.28", only: :dev, runtime: false},
      {:gen_state_machine, "~> 3.0"},
      {:hammox, "~> 0.7", only: :test},
      {:libcluster, "~> 3.4"},
      {:memento, "~> 0.5"},
      {:mimic, "~> 1.12", only: :test},
      {:nimble_options, "~> 1.1"},
      {:phoenix_pubsub, "~> 2.1"},
      {:postgrex, ">= 0.0.0"},
      {:ranch, "~> 2.2"},
      {:recode, github: "hrzndhrn/recode", branch: "0.8.0-dev", only: [:dev], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases() do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
