import Config

alias Hush.Provider.SystemEnvironment

config :char_server, :network,
  bind_ip: {:hush, SystemEnvironment, "CHAR_BIND_IP", default: "0.0.0.0"},
  broadcast_addr: {:hush, SystemEnvironment, "CHAR_BROADCAST_ADDR", default: "127.0.0.1"},
  port: {:hush, SystemEnvironment, "CHAR_PORT", default: 6121, cast: :integer},
  server_config: %{
    name: {:hush, SystemEnvironment, "CHAR_SERVER_NAME", default: "Aesir"},
    cluster_id: {:hush, SystemEnvironment, "CLUSTER_ID", default: "default"}
  }
