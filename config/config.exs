import Config

config :commons,
  env: config_env(),
  ecto_repos: [Aesir.Repo]

import_config "database.exs"
import_config "libcluster.exs"
import_config "observability.exs"

import_config "./account_server/main.exs"
import_config "./char_server/main.exs"
import_config "./zone_server/main.exs"
