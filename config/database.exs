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

config :mnesia,
  dir: ~c".mnesia/#{Mix.env()}/#{node()}"

if config_env() == :dev do
  config :commons, :memento_cluster,
    nodes: [:"account@127.0.0.1", :"char@127.0.0.1", :"zone@127.0.0.1"],
    auto_cluster: true,
    table_load_timeout: 60_000
end

if config_env() == :test do
  config :commons, Aesir.Repo,
    database: "aesir_test",
    username: "postgres",
    password: "postgres",
    hostname: "localhost",
    port: 5432,
    show_sensitive_data_on_connection_error: true,
    pool: Ecto.Adapters.SQL.Sandbox

  config :commons, :memento_cluster,
    nodes: [],
    auto_cluster: false,
    table_load_timeout: 60_000
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

  config :commons, :memento_cluster,
    nodes: :libcluster,
    auto_cluster: true,
    table_load_timeout: 60_000
end
