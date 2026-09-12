defmodule Aesir.ZoneServer.Mmo.Woe.CastleMobs do
  @moduledoc """
  Populates and clears the PvE mob pack of an unowned WoE castle.

  Each castle map resolves to one of four region mob sets by its map-name
  prefix (`"aldeg_cas01"` resolves to `"aldeg"`). A set holds roaming mobs,
  summoned to random walkable cells across the map, and room mobs, summoned
  at the Emperium cell. The pack is present exactly while a castle is
  unowned and has no active siege: `seed/1` runs at boot, agit end, and
  castle release; `wipe/1` runs at agit start.
  """

  require Logger

  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb.Castle
  alias Aesir.ZoneServer.Unit.Mob.MobSupervisor

  @type region_set :: %{
          roaming: [{pos_integer(), pos_integer()}],
          room: [{pos_integer(), pos_integer()}]
        }

  @aldeg %{
    roaming: [
      {1117, 10},
      {1132, 4},
      {1219, 2},
      {1205, 1},
      {1216, 10},
      {1193, 18},
      {1269, 9},
      {1276, 7},
      {1208, 3},
      {1275, 1},
      {1268, 1},
      {1272, 1}
    ],
    room: [{1272, 1}, {1270, 4}, {1268, 1}, {1219, 1}, {1276, 5}]
  }

  @gefg %{
    roaming: [
      {1117, 10},
      {1263, 11},
      {1102, 10},
      {1130, 10},
      {1140, 20},
      {1163, 9},
      {1275, 1},
      {1219, 1},
      {1150, 1},
      {1159, 1}
    ],
    room: [{1203, 1}, {1087, 1}, {1213, 10}, {1189, 10}]
  }

  @payg %{
    roaming: [
      {1277, 9},
      {1208, 10},
      {1262, 5},
      {1102, 5},
      {1150, 1},
      {1115, 1},
      {1129, 11},
      {1276, 5},
      {1282, 4},
      {1253, 5}
    ],
    room: [{1150, 1}, {1115, 1}, {1208, 6}, {1276, 5}]
  }

  @prtg %{
    roaming: [
      {1163, 1},
      {1132, 10},
      {1219, 5},
      {1268, 5},
      {1251, 1},
      {1252, 1},
      {1276, 5},
      {1259, 2},
      {1283, 3},
      {1275, 1},
      {1200, 1}
    ],
    room: [{1268, 1}, {1251, 1}, {1252, 1}, {1219, 1}, {1276, 5}]
  }

  @doc """
  Resolves the region mob set for a castle map, by the map name's prefix up
  to the first underscore. Returns `:error` for a map with no matching
  region.
  """
  @spec set_for(String.t()) :: {:ok, region_set()} | :error
  def set_for(map) do
    case String.split(map, "_", parts: 2) do
      ["aldeg", _] -> {:ok, @aldeg}
      ["gefg", _] -> {:ok, @gefg}
      ["payg", _] -> {:ok, @payg}
      ["prtg", _] -> {:ok, @prtg}
      _ -> :error
    end
  end

  @doc """
  Wipes `castle`'s map, then summons its roaming mobs at random walkable
  cells and its room mobs at the Emperium cell. A map with no region set
  does nothing. A failed summon logs a warning and does not stop the rest.
  """
  @spec seed(Castle.t()) :: :ok
  def seed(%Castle{} = castle) do
    case set_for(castle.map) do
      :error ->
        :ok

      {:ok, set} ->
        wipe(castle)

        {x, y} = castle.emperium

        Enum.each(set.roaming, &summon_all(castle, &1, 0, 0))
        Enum.each(set.room, &summon_all(castle, &1, x, y))

        :ok
    end
  end

  @doc """
  Kills every mob on `castle`'s map.
  """
  @spec wipe(Castle.t()) :: :ok
  def wipe(%Castle{map: map}), do: MobSupervisor.kill_all(map)

  @spec summon_all(Castle.t(), {pos_integer(), pos_integer()}, integer(), integer()) :: :ok
  defp summon_all(castle, {mob_id, amount}, x, y) do
    Enum.each(1..amount, fn _ -> summon(castle, mob_id, x, y) end)
  end

  @spec summon(Castle.t(), pos_integer(), integer(), integer()) :: :ok
  defp summon(castle, mob_id, x, y) do
    case Coordinator.summon_mob(castle.map, mob_id, x, y, []) do
      {:ok, _unit_id} ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "Failed to summon mob #{mob_id} for castle #{castle.name} (#{castle.map}): #{inspect(reason)}"
        )

        :ok
    end
  end
end
