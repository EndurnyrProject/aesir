import Config

# Absolute level ceilings enforced on top of each job's own max level tables.
# The effective cap is the smaller of the job table's max and this value, so the defaults
# leave the per-job tables in charge. Lower these to cap progression globally.
config :zone_server,
  max_base_level: 999,
  max_job_level: 999
