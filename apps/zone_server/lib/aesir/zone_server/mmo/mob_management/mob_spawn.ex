defmodule Aesir.ZoneServer.Mmo.MobManagement.MobSpawn do
  @moduledoc """
  TypedStruct for mob spawn configuration.
  Defines where and how mobs spawn on a map.
  """
  use TypedStruct

  typedstruct module: SpawnArea do
    @typedoc """
    Spawn area definition.
    x, y: center coordinates (0,0 means anywhere on map)
    xs, ys: radius from center (0,0 means exact position)
    """
    field :x, integer(), enforce: true
    field :y, integer(), enforce: true
    field :xs, integer(), default: 0
    field :ys, integer(), default: 0
  end

  typedstruct do
    field :mob, integer(), enforce: true
    field :amount, integer(), enforce: true
    field :respawn_time, integer(), enforce: true
    field :spawn_area, SpawnArea.t(), enforce: true
  end
end
