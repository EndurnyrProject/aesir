import Config

config :logger, :console,
  level: :debug,
  format: "$date $time [$level] $metadata$message\n",
  metadata: [:user_id]

# Silence the noisy QUIC transport debug/info logs (congestion control, pmtu
# probes, packet headers, etc). Set to :debug to re-enable them when debugging
# the transport layer.
config :commons, :quic_log_level, :warning

if config_env() == :test do
  config :logger, level: :warning
end
