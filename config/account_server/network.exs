import Config

alias Hush.Provider.SystemEnvironment

config :account_server, :network,
  bind_ip: {:hush, SystemEnvironment, "ACCOUNT_BIND_IP", default: "127.0.0.1"},
  port: {:hush, SystemEnvironment, "ACCOUNT_PORT", default: 6900, cast: :integer}
