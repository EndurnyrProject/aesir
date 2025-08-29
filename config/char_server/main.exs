import Config

alias Hush.Provider.SystemEnvironment

config :char_server, :server_info,
  name: {:hush, SystemEnvironment, "CHAR_SERVER_NAME", default: "Aesir"},
  cluster_id: {:hush, SystemEnvironment, "CLUSTER_ID", default: "default"}

import_config "network.exs"
