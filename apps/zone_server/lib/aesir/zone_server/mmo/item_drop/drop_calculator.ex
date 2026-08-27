defmodule Aesir.ZoneServer.Mmo.ItemDrop.DropCalculator do
  @moduledoc """
  Pure drop-roll calculation for mob-death loot.

  Each drop slot rolls independently against its renewal rate: the server
  per-category rate multiplier (`Config.item_drop_rate/1`), the LUK hook
  (no-op today), the caller-supplied `drop_bonus` (e.g. Bubble Gum's SC_ITEMBOOST),
  the 90% drop-rate cap (only for items not already above it), the renewal
  level-penalty modifier, and the configured per-category floor/ceiling
  (`Config.item_drop_bounds/1`, default 1..10000). Items that pass are scattered
  onto walkable cells around the death position (death cell first, then the
  rAthena SE -> W -> N cycle). Placement is guaranteed: a scatter cell whose
  spiral search finds no traversable cell falls back to the death cell, and
  the death cell itself falls back to its own requested coordinates when its
  spiral search comes up empty. No item is ever silently dropped from the
  result.

  Pure: only persistent_term/ETS-backed reads (`ItemManagement`, `MapCache`,
  `LevelPenalty`); no process state, no side effects. The drop bonus arrives as a
  plain integer percent, resolved by the caller from the killer's merged status
  modifiers, so no status lookups happen here.
  """

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Mmo.ItemDrop.LevelPenalty
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop

  @drop_rate_cap 9000
  @max_rate 10_000

  @scatter_offsets [{1, -1}, {-1, 0}, {0, 1}]

  @type drop ::
          {nameid :: integer(), amount :: integer(), x :: integer(), y :: integer(),
           identified :: boolean()}

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
  Rolls the killer's equipment bonus item drops (`bAddMonsterDropItem`) and
  returns the items that dropped, scattered around `{x, y}` like the mob's own
  drops.

  Reads the killer's merged equipment modifiers for `{:add_monster_drop, item_id}`
  (unconditional) and `{:add_monster_drop, item_id, gate}` entries. A gate is
  either a race - dropped only when `mob_race` matches it, or when it is `:all` -
  or a monster id, dropped only by that one monster. Each entry's value is a
  chance out of 10_000 (`n/100 %`) rolled independently. Entries whose item id no
  longer resolves are skipped.
  """
  @spec roll_equipment_drops(
          map(),
          atom() | nil,
          integer() | nil,
          String.t(),
          integer(),
          integer()
        ) :: [drop()]
  def roll_equipment_drops(equip_modifiers, mob_race, mob_id, map_name, x, y)
      when is_map(equip_modifiers) do
    equip_modifiers
    |> Enum.flat_map(&roll_bonus_slot(&1, mob_race, mob_id))
    |> scatter(map_name, x, y)
  end

  @spec roll_bonus_slot({term(), term()}, atom() | nil, integer() | nil) ::
          [{integer(), integer(), boolean()}]
  defp roll_bonus_slot({{:add_monster_drop, nameid}, chance}, _mob_race, _mob_id)
       when is_integer(nameid) and is_integer(chance),
       do: maybe_bonus_drop(nameid, chance)

  defp roll_bonus_slot({{:add_monster_drop, nameid, race}, chance}, mob_race, _mob_id)
       when is_integer(nameid) and is_integer(chance) and is_atom(race) and
              (race == :all or race == mob_race),
       do: maybe_bonus_drop(nameid, chance)

  defp roll_bonus_slot({{:add_monster_drop, nameid, gate_id}, chance}, _mob_race, mob_id)
       when is_integer(nameid) and is_integer(chance) and is_integer(gate_id) and
              gate_id == mob_id,
       do: maybe_bonus_drop(nameid, chance)

  defp roll_bonus_slot(_entry, _mob_race, _mob_id), do: []

  @spec maybe_bonus_drop(integer(), integer()) :: [{integer(), integer(), boolean()}]
  defp maybe_bonus_drop(nameid, chance) do
    case ItemManagement.get_item_by_id(nameid) do
      {:ok, %{type: type}} ->
        if :rand.uniform(@max_rate) <= chance,
          do: [{nameid, 1, type not in [:weapon, :armor]}],
          else: []

      {:error, _reason} ->
        []
    end
  end

  @doc """
  Computes the final drop rate (out of 10_000) for a `:common`-category slot.
  Delegates to `drop_rate/6`; the defaults reproduce the pre-config math.
  """
  @spec drop_rate(integer(), integer(), integer(), integer(), integer()) :: integer()
  def drop_rate(base, killer_luk, killer_base_level, mob_level, drop_bonus),
    do: drop_rate(base, killer_luk, killer_base_level, mob_level, drop_bonus, :common)

  @doc """
  Computes the final drop rate (out of 10_000) for a slot of drop `category`,
  after the server per-category rate multiplier, the LUK hook, the caller-supplied
  drop bonus, the 90% cap, the renewal level penalty, and the per-category
  floor/ceiling clamp.
  """
  @spec drop_rate(
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          :common | :heal | :use | :equip | :card
        ) :: integer()
  def drop_rate(base, killer_luk, killer_base_level, mob_level, drop_bonus, category) do
    base
    |> apply_rate(Config.item_drop_rate(category))
    |> apply_luk_bonus(killer_luk)
    |> apply_rate(100 + drop_bonus)
    |> cap_rate(base)
    |> apply_rate(LevelPenalty.drop(mob_level, killer_base_level))
    |> clamp_rate(category)
  end

  @spec roll_slot(MobDrop.t(), integer(), integer(), integer(), integer()) ::
          [{integer(), integer(), boolean()}]
  defp roll_slot(
         %MobDrop{item: aegis, rate: base},
         killer_luk,
         killer_base_level,
         mob_level,
         drop_bonus
       ) do
    case ItemManagement.get_item_by_aegis(aegis) do
      {:ok, %{id: nameid, type: type}} ->
        rate =
          drop_rate(
            base,
            killer_luk,
            killer_base_level,
            mob_level,
            drop_bonus,
            Config.drop_category(type)
          )

        identified = type not in [:weapon, :armor]
        if :rand.uniform(@max_rate) <= rate, do: [{nameid, 1, identified}], else: []

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

  @spec clamp_rate(integer(), atom()) :: integer()
  defp clamp_rate(rate, category) do
    {min_rate, max_rate} = Config.item_drop_bounds(category)
    rate |> max(min_rate) |> min(max_rate)
  end

  @spec scatter([{integer(), integer(), boolean()}], String.t(), integer(), integer()) :: [drop()]
  defp scatter(items, map_name, x, y) do
    items
    |> Enum.with_index()
    |> Enum.map(fn {{nameid, amount, identified}, index} ->
      {cx, cy} = resolve_cell(index, map_name, x, y)
      {nameid, amount, cx, cy, identified}
    end)
  end

  # Guarantees a cell for every drop slot: the death cell slot (index 0)
  # falls back to its own requested coordinates when its spiral search finds
  # nothing walkable; every other scatter slot falls back to the death cell.
  @spec resolve_cell(non_neg_integer(), String.t(), integer(), integer()) ::
          {integer(), integer()}
  defp resolve_cell(0, map_name, x, y) do
    case nearest_walkable({x, y}, map_name) do
      {:ok, cell} -> cell
      :error -> {x, y}
    end
  end

  defp resolve_cell(index, map_name, x, y) do
    {dx, dy} = Enum.at(@scatter_offsets, rem(index - 1, length(@scatter_offsets)))

    case nearest_walkable({x + dx, y + dy}, map_name) do
      {:ok, cell} -> cell
      :error -> resolve_cell(0, map_name, x, y)
    end
  end

  @spec nearest_walkable({integer(), integer()}, String.t()) ::
          {:ok, {integer(), integer()}} | :error
  defp nearest_walkable({cx, cy}, map_name) do
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
