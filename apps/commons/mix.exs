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
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Commons.Application, []}
    ]
  end

  defp deps do
    [
      {:bcrypt_elixir, "~> 3.0"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.16", only: [:dev, :test], runtime: false},
      {:ecto, "~> 3.13"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, "~> 0.19"},
      {:ex_doc, "~> 0.28", only: :dev, runtime: false},
      {:gen_state_machine, "~> 3.0"},
      {:hammox, "~> 0.7", only: :test},
      {:mimic, "~> 1.12", only: :test},
      {:nimble_options, "~> 1.1"},
      {:ranch, "~> 2.2"},
      {:recode, "~> 0.6", only: :dev, runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
