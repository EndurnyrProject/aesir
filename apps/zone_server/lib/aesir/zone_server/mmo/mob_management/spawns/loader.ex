defmodule Aesir.ZoneServer.Mmo.MobManagement.Spawns.Loader do
  @moduledoc """
  Builds the spawn index from our-schema YAML files in the spawns domain.

  Each YAML document is a list of `{map, spawns}` entries; spawns reference mobs
  by numeric id. Cache mechanics live in `Aesir.ZoneServer.Mmo.DataLoader`. Plain
  functions only - no process.
  """

  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn

  @type index :: %{by_map: %{String.t() => [MobSpawn.t()]}}

  @cache_file "spawns_v2.etf"

  @spec load() :: index()
  def load, do: "spawns" |> DataLoader.load(@cache_file, &build/1) |> index()

  @spec build([Path.t()]) :: [%{map: String.t(), spawns: [MobSpawn.t()]}]
  defp build(sources) do
    sources |> Enum.flat_map(&DataLoader.parse_file/1) |> Enum.map(&to_map_spawns!/1)
  end

  @spec index([%{map: String.t(), spawns: [MobSpawn.t()]}]) :: index()
  defp index(maps), do: %{by_map: Map.new(maps, &{&1.map, &1.spawns})}

  @spec to_map_spawns!(map()) :: %{map: String.t(), spawns: [MobSpawn.t()]}
  defp to_map_spawns!(%{"map" => map, "spawns" => spawns}) do
    %{map: map, spawns: Enum.map(spawns, &to_spawn!/1)}
  end

  @spec to_spawn!(map()) :: MobSpawn.t()
  defp to_spawn!(spawn) do
    area = Map.fetch!(spawn, "area")

    %MobSpawn{
      mob: Map.fetch!(spawn, "mob"),
      amount: Map.fetch!(spawn, "amount"),
      respawn_time: Map.fetch!(spawn, "respawn_time"),
      respawn_variance: Map.get(spawn, "respawn_variance", 0),
      spawn_area: %MobSpawn.SpawnArea{
        x: Map.fetch!(area, "x"),
        y: Map.fetch!(area, "y"),
        xs: Map.get(area, "xs", 0),
        ys: Map.get(area, "ys", 0)
      }
    }
  end
end
