defmodule Aesir.ZoneServer.Mmo.Woe.CastleVerifier do
  @moduledoc """
  Boot-time sanity check for FE castle Emperium, WoE-respawn, treasure, and
  guardian spawn cells.

  A non-walkable Emperium/respawn/treasure cell would surface only as a
  failed Emperium summon when `Woe.Server.start/0` arms the castle
  (`Coordinator.summon_mob` rejects unwalkable coordinates), leaving the
  castle silently non-gvg for the whole siege. `verify!/0` runs at boot and
  raises loudly on any bad cell instead, so a bad seed coordinate aborts boot
  rather than hiding until AgitStart. Guardian cells are fixed-position mob
  spawns (reference data intentionally places some in wall recesses), so
  they are only checked for map bounds, not walkability.
  """

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb

  @type cell_kind :: :emperium | :respawn | :treasure | :guardian

  @doc """
  Verifies every FE castle's Emperium, respawn, and treasure cells against
  `MapCache` walkability and every guardian cell against the map's bounds,
  returning `:ok` or raising with the list of bad cells.
  """
  @spec verify!() :: :ok
  def verify! do
    case bad_cells() do
      [] ->
        :ok

      bad ->
        raise "Non-walkable WoE castle cell(s): " <>
                Enum.map_join(bad, "; ", fn {map, name, kind, x, y} ->
                  "#{name} (#{map}) #{kind} cell (#{x}, #{y})"
                end)
    end
  end

  @spec bad_cells() :: [
          {String.t(), String.t(), cell_kind(), non_neg_integer(), non_neg_integer()}
        ]
  defp bad_cells do
    for castle <- CastleDb.all(),
        {kind, {x, y}} <- cells(castle),
        not valid_cell?(castle.map, kind, x, y),
        do: {castle.map, castle.name, kind, x, y}
  end

  @spec valid_cell?(String.t(), cell_kind(), non_neg_integer(), non_neg_integer()) :: boolean()
  defp valid_cell?(map, :guardian, x, y) do
    map_data = MapCache.get!(map)
    x in 0..(map_data.xs - 1) and y in 0..(map_data.ys - 1)
  end

  defp valid_cell?(map, _kind, x, y), do: MapCache.walkable?(map, x, y)

  @spec cells(CastleDb.Castle.t()) :: [{cell_kind(), {non_neg_integer(), non_neg_integer()}}]
  defp cells(castle) do
    [emperium: castle.emperium, respawn: castle.respawn] ++
      Enum.map(castle.treasure.cells, &{:treasure, &1}) ++
      Enum.map(castle.guardians, &{:guardian, &1.cell})
  end
end
