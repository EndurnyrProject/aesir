import Config

# Configure the database for testing
config :commons, Aesir.Repo,
  database: "aesir_test",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5432,
  show_sensitive_data_on_connection_error: true,
  pool: Ecto.Adapters.SQL.Sandbox

# Disable clustering for tests
config :libcluster,
  topologies: []

# Reduce log level for cleaner test output
config :logger, level: :warning
