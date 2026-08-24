import Config

alias Hush.Provider.SystemEnvironment

config :zone_server, :server_info,
  cluster_id: {:hush, SystemEnvironment, "CLUSTER_ID", default: "default"}

# Player view range: the cell radius a client is told about.
# Drives entity visibility, combat/skill/effect broadcasts, and the radius within
# which a client may acquire an attack/skill target.
config :zone_server, view_range: 20

# Party tunables
config :zone_server, max_party: 12
config :zone_server, party_share_level: 15
config :zone_server, party_even_share_bonus: 0

# Renewal death EXP penalty as a percentage of the exp needed to reach the next
# base/job level (renewal default 1%).
# Never de-levels; skipped for characters carrying SC_LIFEINSURANCE. Set to 0 to
# disable.
config :zone_server, death_penalty_base: 1
config :zone_server, death_penalty_job: 1

# Natural equipment-break rate rolled on a confirmed hit, in 1/10000 units. 
# Default 0 disables natural breaking
config :zone_server, natural_break_rate: 0

# Percentage applied to a boss's randomized respawn delay (base + rand(variance))
# before the 1000 ms floor. 100 leaves the imported delay unchanged.
config :zone_server, boss_respawn_delay_percentage: 100

# Require a valid single-use zone-entry token (issued by the char server on
# character selection) in SessionAuth before admitting a client to the zone.
# Set to false only during a client rollout that does not yet echo the token;
# while disabled, missing/invalid tokens are logged but still admitted.
config :zone_server, enforce_zone_auth_token: true

# Reconcile persisted boss respawn deadlines during MechanicsSupervisor boot.
# Disabled under test: the OTP app starts before ExUnit installs the Ecto
# sandbox, so a boot-time query runs unsandboxed against the real test database
# and its orphan cleanup would permanently delete rows. Tests call
# BossRespawn.reconcile/0 explicitly inside their own sandboxed connection.
config :zone_server, boss_respawn_reconcile_on_boot: config_env() != :test

# Server rate multipliers and progression caps live in dedicated files to keep
# this one focused
import_config "rates.exs"
import_config "drops.exs"
import_config "leveling.exs"
import_config "network.exs"
