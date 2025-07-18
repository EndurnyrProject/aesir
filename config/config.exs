import Config

config :logger, :console,
  level: :debug,
  format: "$date $time [$level] $metadata$message\n",
  metadata: [:user_id]

config :commons,
  ecto_repos: [Aesir.Repo]

config :commons, Aesir.Repo,
  database: "aesir_dev",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5432,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Account Server Configuration  
config :account_server,
  port: 6901

# Character Server Configuration
config :char_server,
  port: 6121

# Zone Server Configuration
config :zone_server,
  port: 5121

# Cluster Configuration
config :libcluster,
  topologies: []

import_config "#{config_env()}.exs"
