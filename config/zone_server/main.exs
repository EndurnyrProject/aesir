import Config

alias Hush.Provider.SystemEnvironment

config :zone_server, :server_info,
  cluster_id: {:hush, SystemEnvironment, "CLUSTER_ID", default: "default"}

# Player view range (rAthena AREA_SIZE): the cell radius a client is told about.
# Drives entity visibility, combat/skill/effect broadcasts, and the radius within
# which a client may acquire an attack/skill target.
config :zone_server, view_range: 20

# Require a valid single-use zone-entry token (issued by the char server on
# character selection) in SessionAuth before admitting a client to the zone.
# Set to false only during a client rollout that does not yet echo the token;
# while disabled, missing/invalid tokens are logged but still admitted.
config :zone_server, enforce_zone_auth_token: true

import_config "network.exs"
