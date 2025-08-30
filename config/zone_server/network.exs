import Config

alias Hush.Provider.SystemEnvironment

config :zone_server, :network,
  bind_ip: {:hush, SystemEnvironment, "ZONE_BIND_IP", default: "0.0.0.0"},
  port: {:hush, SystemEnvironment, "ZONE_PORT", default: 5121, cast: :integer}
