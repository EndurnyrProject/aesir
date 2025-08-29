import Config

alias Hush.Provider.SystemEnvironment

config :account_server, :network,
  bind_ip: {:hush, SystemEnvironment, "ACCOUNT_BIND_IP", default: "0.0.0.0"},
  port: {:hush, SystemEnvironment, "ACCOUNT_PORT", default: 6901, cast: :integer}
