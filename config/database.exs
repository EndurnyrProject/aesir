import Config

alias Hush.Provider.SystemEnvironment

config :commons, Aesir.Repo,
  database: "aesir_dev",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5432,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

if config_env() == :test do
  # Only the primary checkout has a `.git` directory; git worktrees have a `.git` file and
  # jj workspaces have none. Give every other checkout its own test database so concurrent
  # `mix test` runs don't share sandbox state. The path hash keeps same-named checkouts apart.
  repo_root = Path.expand("../..", __DIR__)

  test_database =
    System.get_env("TEST_DATABASE") ||
      if File.dir?(Path.join(repo_root, ".git")) do
        "aesir_test"
      else
        suffix =
          repo_root
          |> Path.basename()
          |> String.downcase()
          |> String.replace(~r/[^a-z0-9]+/, "_")
          |> String.slice(0, 32)

        "grain_next_test_#{suffix}_#{repo_root |> :erlang.phash2() |> Integer.to_string(36)}"
      end

  config :commons, Aesir.Repo,
    database: test_database,
    username: "postgres",
    password: "postgres",
    hostname: "localhost",
    port: 5432,
    show_sensitive_data_on_connection_error: true,
    pool: Ecto.Adapters.SQL.Sandbox
end

if config_env() == :prod do
  config :commons, Aesir.Repo,
    database: {:hush, SystemEnvironment, "POSTGRES_DB", default: "aesir"},
    username: {:hush, SystemEnvironment, "POSTGRES_USER"},
    password: {:hush, SystemEnvironment, "POSTGRES_PASSWORD"},
    hostname: {:hush, SystemEnvironment, "POSTGRES_HOST"},
    port: {:hush, SystemEnvironment, "POSTGRES_PORT", default: 5432, cast: :integer},
    pool_size: {:hush, SystemEnvironment, "POSTGRES_POOL_SIZE", default: 10, cast: :integer},
    show_sensitive_data_on_connection_error: false
end
