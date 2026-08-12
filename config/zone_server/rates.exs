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
