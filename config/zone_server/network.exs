import Config

alias Hush.Provider.SystemEnvironment

config :zone_server, :network,
  bind_ip: {:hush, SystemEnvironment, "ZONE_BIND_IP", default: "127.0.0.1"},
  port: {:hush, SystemEnvironment, "ZONE_PORT", default: 5121, cast: :integer}
