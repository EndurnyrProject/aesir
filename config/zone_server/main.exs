import Config

alias Hush.Provider.SystemEnvironment

config :zone_server, :server_info,
  cluster_id: {:hush, SystemEnvironment, "CLUSTER_ID", default: "default"}

# Player view range: the cell radius a client is told about.
# Drives entity visibility, combat/skill/effect broadcasts, and the radius within
# which a client may acquire an attack/skill target.
config :zone_server, view_range: 20

config :zone_server, :vending_rules, %{
  max_price: 1_000_000_000,
  allow_over_max: true,
  tax: 500,
  tax_min: 100_000_000,
  show_buyer_name: true
}

# rAthena conf/battle/pet.conf: Whether to use the legacy pet catch formula.
config :zone_server, pet_legacy_formula: false
# rAthena conf/battle/pet.conf: Pet catch rate as a percentage.
config :zone_server, pet_catch_rate: 100
# rAthena conf/battle/pet.conf: Maximum catch distance in cells; zero disables the check.
config :zone_server, pet_distance_check: 5
# rAthena conf/battle/pet.conf: Whether hiding prevents catching pets.
config :zone_server, pet_hide_check: true
# rAthena conf/battle/pet.conf: Whether pets can be renamed more than once.
config :zone_server, pet_rename: false
# rAthena conf/battle/pet.conf: Pet intimacy gain from feeding as a percentage.
config :zone_server, pet_friendly_rate: 100
# rAthena conf/battle/pet.conf: Pet hunger delay rate as a percentage.
config :zone_server, pet_hungry_delay_rate: 100
# rAthena conf/battle/pet.conf: Whether pet equipment is required for pet skills.
config :zone_server, pet_equip_required: true
# rAthena conf/battle/pet.conf: Whether to destroy pet equipment when inventory has no space.
config :zone_server, pet_unequip_destroy: true
# rAthena conf/battle/pet.conf: Whether pets attack when their master attacks.
config :zone_server, pet_attack_support: false
# rAthena conf/battle/pet.conf: Whether pets attack when their master takes damage.
config :zone_server, pet_damage_support: false
# rAthena conf/battle/pet.conf: Minimum pet intimacy required for support.
config :zone_server, pet_support_min_friendly: 900
# rAthena conf/battle/pet.conf: Whether pets use skills.
config :zone_server, pet_status_support: false
# rAthena conf/battle/pet.conf: Pet battle support rate as a percentage.
config :zone_server, pet_support_rate: 100
# rAthena conf/battle/pet.conf: Whether the master receives experience from pet damage.
config :zone_server, pet_attack_exp_to_master: false
# rAthena conf/battle/pet.conf: Experience rate from pet attacks as a percentage.
config :zone_server, pet_attack_exp_rate: 100
# rAthena conf/battle/pet.conf: Pet level as a percentage of master level; zero disables leveling.
config :zone_server, pet_lv_rate: 0
# rAthena conf/battle/pet.conf: Maximum pet stats when pet leveling is enabled.
config :zone_server, pet_max_stats: 99
# rAthena conf/battle/pet.conf: Maximum minimum pet attack when pet leveling is enabled.
config :zone_server, pet_max_atk1: 500
# rAthena conf/battle/pet.conf: Maximum maximum pet attack when pet leveling is enabled.
config :zone_server, pet_max_atk2: 1000
# rAthena conf/battle/pet.conf: Whether pets are disabled during guild wars.
config :zone_server, pet_disable_in_gvg: false
# rAthena conf/battle/pet.conf: Whether fixed pet skill damage ignores infinite defense.
config :zone_server, pet_ignore_infinite_def: true
# rAthena conf/battle/pet.conf: Whether pets continue attacking when their master is dead.
config :zone_server, pet_master_dead: false
# rAthena conf/battle/pet.conf: Whether autofeed notices ignore the client setting.
config :zone_server, pet_autofeed_always: true
# rAthena conf/battle/pet.conf: Pet walk speed mode: master, default, or mob database.
config :zone_server, pet_walk_speed: 1
# rAthena conf/battle/feature.conf: Whether pet evolution is enabled.
config :zone_server, feature_pet_evolution: true
# rAthena conf/battle/feature.conf: Whether pet autofeeding is enabled.
config :zone_server, feature_pet_autofeed: true
# rAthena conf/battle/feature.conf: Hunger threshold for pet autofeeding.
config :zone_server, feature_pet_autofeed_rate: 89

# Party tunables
config :zone_server, max_party: 12
config :zone_server, party_share_level: 15
config :zone_server, party_even_share_bonus: 0

# How a death costs EXP: 0 no penalty, 1 a percentage of the exp needed for the
# next level, 2 a percentage of the exp into the current level.
config :zone_server, death_penalty_type: 1

# Death EXP penalty rates in 1/10000 (100 = 1%). Never de-levels; skipped for
# characters carrying SC_LIFEINSURANCE.
config :zone_server, death_penalty_base: 100
config :zone_server, death_penalty_job: 100

# Whether max-level characters still lose EXP on death: 0 never, 1 base, 2 job, 3 both.
config :zone_server, death_penalty_maxlv: 0

# Zeny lost on death in 1/10000 of the zeny held; skipped on nozenypenalty maps.
config :zone_server, zeny_penalty: 0

# Natural equipment-break rate rolled on a confirmed hit, in 1/10000 units. 
# Default 0 disables natural breaking
config :zone_server, natural_break_rate: 0

# Percentage applied to a boss's randomized respawn delay (base + rand(variance))
# before the 1000 ms floor. 100 leaves the imported delay unchanged.
config :zone_server, boss_respawn_delay_percentage: 100

# Whether a monster class change fully recovers its HP. Disabled, the new form
# keeps the pre-change HP percentage, never below 1 HP.
config :zone_server, monster_class_change_full_recover: true

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

# Seed unowned castles' PvE mob spawns during the boot map sweep.
# Disabled under test: WoE integration tests boot their own per-test castle
# servers, and seeding the boot-global maps here would spawn duplicate,
# unowned mobs those tests do not expect.
config :zone_server, woe_castle_mobs_on_boot: config_env() != :test

# Server rate multipliers and progression caps live in dedicated files to keep
# this one focused
import_config "rates.exs"
import_config "drops.exs"
import_config "leveling.exs"
import_config "network.exs"
