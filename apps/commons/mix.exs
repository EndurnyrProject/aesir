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
      dialyzer: dialyzer(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :bunt],
      mod: {Aesir.Commons.Application, []}
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:mix],
      ignore_warnings: "../../.dialyzer_ignore.exs"
    ]
  end

  defp deps do
    [
      {:bandit, "~> 1.0", only: :dev},
      {:bcrypt_elixir, "~> 3.0"},
      {:benchee, "~> 1.4", only: [:dev, :test]},
      {:bunt, "~> 1.0"},
      {:credo, "~> 1.7", only: [:dev], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.16", only: [:dev, :test], runtime: false},
      {:ecto, "~> 3.13"},
      {:ecto_sql, "~> 3.13"},
      {:ex_doc, "~> 0.28", only: :dev, runtime: false},
      {:hammox, "~> 0.7", only: :test},
      {:horde, "~> 0.10"},
      {:hush, "~> 1.2"},
      {:libcluster, "~> 3.4"},
      {:local_cluster, "~> 2.0", only: [:test], runtime: false},
      {:mimic, "~> 1.12", only: :test},
      {:nimble_options, "~> 1.1"},
      {:nimble_parsec, "~> 1.4"},
      {:phoenix_pubsub, "~> 2.1"},
      {:plug_crypto, "~> 2.1"},
      {:postgrex, ">= 0.0.0"},
      {:process_tree, "~> 0.2.1"},
      {:protox, "~> 2.0"},
      {:quic, "~> 1.6"},
      {:ranch, "~> 2.2"},
      {:recode, "~> 0.8.0", only: [:dev], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:tidewave, "~> 0.4", only: :dev},
      {:typedstruct, github: "ygorcastor/typedstruct", branch: "main"}
    ]
  end

  defp aliases() do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run apps/commons/priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
