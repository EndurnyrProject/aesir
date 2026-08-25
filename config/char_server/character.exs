import Config

alias Hush.Provider.SystemEnvironment

config :char_server, :new_character,
  start_map: {:hush, SystemEnvironment, "START_MAP", optional: true},
  start_x: {:hush, SystemEnvironment, "START_X", optional: true, cast: :integer},
  start_y: {:hush, SystemEnvironment, "START_Y", optional: true, cast: :integer},
  start_zeny: {:hush, SystemEnvironment, "START_ZENY", default: 0, cast: :integer}
