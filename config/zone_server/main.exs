import Config

alias Hush.Provider.SystemEnvironment

config :zone_server, :server_info,
  cluster_id: {:hush, SystemEnvironment, "CLUSTER_ID", default: "default"}

# Player view range (rAthena AREA_SIZE): the cell radius a client is told about.
# Drives entity visibility, combat/skill/effect broadcasts, and the radius within
# which a client may acquire an attack/skill target.
config :zone_server, view_range: 20

# Party tunables (rAthena MAX_PARTY / inter_athena.conf / party.conf).
config :zone_server, max_party: 12
config :zone_server, party_share_level: 15
config :zone_server, party_even_share_bonus: 0

# Renewal death EXP penalty as a percentage of the exp needed to reach the next
# base/job level (rAthena exp.conf death_penalty_base/job, renewal default 1%).
# Never de-levels; skipped for characters carrying SC_LIFEINSURANCE. Set to 0 to
# disable.
config :zone_server, death_penalty_base: 1
config :zone_server, death_penalty_job: 1

# Require a valid single-use zone-entry token (issued by the char server on
# character selection) in SessionAuth before admitting a client to the zone.
# Set to false only during a client rollout that does not yet echo the token;
# while disabled, missing/invalid tokens are logged but still admitted.
config :zone_server, enforce_zone_auth_token: true

import_config "network.exs"
