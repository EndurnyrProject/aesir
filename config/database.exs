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
  config :commons, Aesir.Repo,
    database: "aesir_test",
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
