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
    field :mob_id, integer(), enforce: true
    field :amount, integer(), enforce: true
    field :respawn_time, integer(), enforce: true
    field :spawn_area, SpawnArea.t(), enforce: true
  end

  @doc """
  Converts a raw map from the configuration file to a MobSpawn struct.
  """
  @spec from_map(map()) :: t()
  def from_map(spawn_map) when is_map(spawn_map) do
    %__MODULE__{
      mob_id: Map.fetch!(spawn_map, :mob_id),
      amount: Map.fetch!(spawn_map, :amount),
      respawn_time: Map.fetch!(spawn_map, :respawn_time),
      spawn_area: spawn_area_from_map(Map.fetch!(spawn_map, :spawn_area))
    }
  end

  defp spawn_area_from_map(area_map) when is_map(area_map) do
    %SpawnArea{
      x: Map.get(area_map, :x, 0),
      y: Map.get(area_map, :y, 0),
      xs: Map.get(area_map, :xs, 0),
      ys: Map.get(area_map, :ys, 0)
    }
  end
end
