defmodule Aesir.ZoneServer.Mmo.Woe.CastleVerifier do
  @moduledoc """
  Boot-time sanity check for FE castle Emperium and WoE-respawn cells.

  A non-walkable cell would surface only as a failed Emperium summon when
  `Woe.Server.start/0` arms the castle (`Coordinator.summon_mob` rejects
  unwalkable coordinates), leaving the castle silently non-gvg for the whole
  siege. `verify!/0` runs at boot and raises loudly on any bad cell instead,
  so a bad seed coordinate aborts boot rather than hiding until AgitStart.
  """

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb

  @type cell_kind :: :emperium | :respawn

  @doc """
  Verifies every FE castle's Emperium and respawn cells against `MapCache`
  walkability, returning `:ok` or raising with the list of bad cells.
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
        {kind, {x, y}} <- [emperium: castle.emperium, respawn: castle.respawn],
        not MapCache.walkable?(castle.map, x, y),
        do: {castle.map, castle.name, kind, x, y}
  end
end
