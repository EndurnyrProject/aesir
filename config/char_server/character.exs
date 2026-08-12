import Config

alias Hush.Provider.SystemEnvironment

# New-character starting state (rAthena conf/char_athena.conf start_point /
# start_zeny). Applied when a character record is first created; the map/coords
# seed both the last-position and the save-point. Defaults match the previous
# hard-coded character defaults.
config :char_server, :new_character,
  start_map: {:hush, SystemEnvironment, "START_MAP", default: "new_zone01"},
  start_x: {:hush, SystemEnvironment, "START_X", default: 53, cast: :integer},
  start_y: {:hush, SystemEnvironment, "START_Y", default: 111, cast: :integer},
  start_zeny: {:hush, SystemEnvironment, "START_ZENY", default: 0, cast: :integer}
