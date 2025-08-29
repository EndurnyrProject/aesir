import Config

config :logger, :console,
  level: :debug,
  format: "$date $time [$level] $metadata$message\n",
  metadata: [:user_id]

if config_env() == :test do
  config :logger, level: :warning
end
