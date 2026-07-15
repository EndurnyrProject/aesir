defmodule Aesir.ZoneServer.Mmo.ItemDrop.DropCalculator do
  @moduledoc """
  Pure drop-roll calculation for mob-death loot.

  Each drop slot rolls independently against its renewal rate: the LUK hook
  (no-op today), the caller-supplied `drop_bonus` (e.g. Bubble Gum's SC_ITEMBOOST),
  the 90% drop-rate cap (only for items not already above it), the renewal
  level-penalty modifier, and a floor at 1 (0.01%). Items that pass are scattered
  onto walkable cells around the death position (death cell first, then the
  rAthena SE -> W -> N cycle).

  Pure: only persistent_term/ETS-backed reads (`ItemManagement`, `MapCache`,
  `LevelPenalty`); no process state, no side effects. The drop bonus arrives as a
  plain integer percent, resolved by the caller from the killer's merged status
  modifiers, so no status lookups happen here.
  """

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Mmo.ItemDrop.LevelPenalty
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop

  @drop_rate_cap 9000
  @max_rate 10_000

  @scatter_offsets [{1, -1}, {-1, 0}, {0, 1}]

  @type drop :: {nameid :: integer(), amount :: integer(), x :: integer(), y :: integer()}

  @doc """
  Rolls a mob's drop table and returns the items that dropped, each scattered to
  a walkable cell around `{x, y}`.
  """
  @spec roll(
          [MobDrop.t()],
          integer(),
          integer(),
          integer(),
          integer(),
          String.t(),
          integer(),
          integer()
        ) :: [drop()]
  def roll(drops, killer_luk, killer_base_level, mob_level, drop_bonus, map_name, x, y) do
    drops
    |> Enum.flat_map(&roll_slot(&1, killer_luk, killer_base_level, mob_level, drop_bonus))
    |> scatter(map_name, x, y)
  end

  @doc """
  Computes the final drop rate (out of 10_000) for a slot after the LUK hook,
  the caller-supplied drop bonus (applied before the cap, mirroring rAthena
  `mob.cpp:2837-2862`), the 90% cap, the renewal level penalty, and the
  floor-at-1 clamp.
  """
  @spec drop_rate(integer(), integer(), integer(), integer(), integer()) :: integer()
  def drop_rate(base, killer_luk, killer_base_level, mob_level, drop_bonus) do
    base
    |> apply_luk_bonus(killer_luk)
    |> apply_rate(100 + drop_bonus)
    |> cap_rate(base)
    |> apply_rate(LevelPenalty.drop(mob_level, killer_base_level))
    |> clamp_rate()
  end

  @spec roll_slot(MobDrop.t(), integer(), integer(), integer(), integer()) ::
          [{integer(), integer()}]
  defp roll_slot(
         %MobDrop{item: aegis, rate: base},
         killer_luk,
         killer_base_level,
         mob_level,
         drop_bonus
       ) do
    case ItemManagement.get_item_by_aegis(aegis) do
      {:ok, %{id: nameid}} ->
        rate = drop_rate(base, killer_luk, killer_base_level, mob_level, drop_bonus)
        if :rand.uniform(@max_rate) <= rate, do: [{nameid, 1}], else: []

      {:error, _reason} ->
        []
    end
  end

  # LUK drop bonus stub: rAthena's drops_by_luk / drops_by_luk2 both default to 0,
  # so the modifier is a no-op today. Kept as a hook for future equip-bonus plumbing.
  @spec apply_luk_bonus(integer(), integer()) :: integer()
  defp apply_luk_bonus(rate, _killer_luk), do: rate

  # 90% cap, skipped for items whose base is already rarer than the cap
  # (rAthena's `base_rate < cap` guard).
  @spec cap_rate(integer(), integer()) :: integer()
  defp cap_rate(rate, base) when base < @drop_rate_cap, do: min(rate, @drop_rate_cap)
  defp cap_rate(rate, _base), do: rate

  # Mirrors rAthena's apply_rate macro.
  @spec apply_rate(integer(), integer()) :: integer()
  defp apply_rate(val, 100), do: val
  defp apply_rate(val, pct), do: div(val * pct, 100)

  @spec clamp_rate(integer()) :: integer()
  defp clamp_rate(rate), do: rate |> max(1) |> min(@max_rate)

  @spec scatter([{integer(), integer()}], String.t(), integer(), integer()) :: [drop()]
  defp scatter(items, map_name, x, y) do
    items
    |> Enum.with_index()
    |> Enum.flat_map(fn {{nameid, amount}, index} ->
      case resolve_cell(index, map_name, x, y) do
        {:ok, {cx, cy}} -> [{nameid, amount, cx, cy}]
        :error -> []
      end
    end)
  end

  @spec resolve_cell(non_neg_integer(), String.t(), integer(), integer()) ::
          {:ok, {integer(), integer()}} | :error
  defp resolve_cell(0, map_name, x, y), do: nearest_walkable({x, y}, map_name, x, y)

  defp resolve_cell(index, map_name, x, y) do
    {dx, dy} = Enum.at(@scatter_offsets, rem(index - 1, length(@scatter_offsets)))
    nearest_walkable({x + dx, y + dy}, map_name, x, y)
  end

  @spec nearest_walkable({integer(), integer()}, String.t(), integer(), integer()) ::
          {:ok, {integer(), integer()}} | :error
  defp nearest_walkable({cx, cy}, map_name, _x, _y) do
    [{cx, cy} | nearby_cells(cx, cy)]
    |> Enum.find(&Cell.traversable?(map_name, elem(&1, 0), elem(&1, 1)))
    |> case do
      nil -> :error
      cell -> {:ok, cell}
    end
  end

  defp nearby_cells(x, y) do
    for radius <- 1..5,
        dy <- -radius..radius,
        dx <- -radius..radius,
        max(abs(dx), abs(dy)) == radius do
      {x + dx, y + dy}
    end
  end
end
