# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

config :logger, :console,
  level: :debug,
  format: "$date $time [$level] $metadata$message\n",
  metadata: [:user_id]

# Database Configuration
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
