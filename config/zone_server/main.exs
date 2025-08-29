import Config

alias Hush.Provider.SystemEnvironment

config :zone_server, :server_info,
  cluster_id: {:hush, SystemEnvironment, "CLUSTER_ID", default: "default"}

import_config "network.exs"
