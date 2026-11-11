import Config

alias Hush.Provider.SystemEnvironment

config :char_server, :server_info,
  name: {:hush, SystemEnvironment, "CHAR_SERVER_NAME", default: "Aesir"},
  region: {:hush, SystemEnvironment, "CHAR_SERVER_REGION", default: ""},
  description: {:hush, SystemEnvironment, "CHAR_SERVER_DESCRIPTION", default: ""},
  cluster_id: {:hush, SystemEnvironment, "CLUSTER_ID", default: "default"}

import_config "character.exs"
import_config "network.exs"
