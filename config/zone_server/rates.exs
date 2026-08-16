import Config

# Server EXP rate multipliers, as a percentage (100 = 1x, 200 = 2x, 0 = no EXP).
# Applied to the raw reward at its source, before per-character status/equipment
# EXP bonuses (rAthena conf/battle/exp.conf).
#
#   * base/job_exp_rate -> mob-kill reward, scaled before it is split across attackers
#   * mvp_exp_rate      -> the MVP-tier boss bonus experience granted to the top damager
#   * quest_exp_rate    -> experience handed out by NPC/quest scripts (`getexp`)
config :zone_server,
  base_exp_rate: 100,
  job_exp_rate: 100,
  mvp_exp_rate: 100,
  quest_exp_rate: 100

# Guild progression.
#
#   * guild_exp_rate           -> multiplier on taxed member EXP contributions (100 = 1x)
#   * guild_exp_limit          -> max per-position EXP tax percentage
#   * guild_skills_gvg_only    -> restrict guild actives to GvG ground (false until WoE lands)
#   * guild_aura_affects_master -> whether the master receives his own guild auras
config :zone_server,
  guild_exp_rate: 100,
  guild_exp_limit: 50,
  guild_skills_gvg_only: false,
  guild_aura_affects_master: false
