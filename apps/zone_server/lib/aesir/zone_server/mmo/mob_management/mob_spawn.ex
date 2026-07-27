defmodule Aesir.ZoneServer.Mmo.MobManagement.MobSpawn do
  @moduledoc """
  Mob spawn configuration: where and how mobs spawn on a map.
  """

  defmodule SpawnArea do
    @moduledoc false

    @enforce_keys [:x, :y]
    defstruct x: nil, y: nil, xs: 0, ys: 0

    @typedoc """
    Spawn area definition.
    x, y: center coordinates (0,0 means anywhere on map)
    xs, ys: radius from center (0,0 means exact position)
    """
    @type t() :: %__MODULE__{
            x: integer(),
            y: integer(),
            xs: integer(),
            ys: integer()
          }
  end

  @enforce_keys [:mob, :amount, :respawn_time, :spawn_area]
  defstruct mob: nil, amount: nil, respawn_time: nil, respawn_variance: 0, spawn_area: nil

  @type t() :: %__MODULE__{
          mob: integer(),
          amount: integer(),
          respawn_time: integer(),
          respawn_variance: integer(),
          spawn_area: SpawnArea.t()
        }
end
