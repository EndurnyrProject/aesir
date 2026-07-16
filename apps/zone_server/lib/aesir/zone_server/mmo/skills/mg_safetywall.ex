defmodule Aesir.ZoneServer.Mmo.Skills.MgSafetywall do
  @moduledoc """
  Safety Wall (MG_SAFETYWALL). Ground-targeted, no-damage defensive skill-unit.

  As a `target_type: :ground` skill, `use Skill` auto-derives the `cast/4` that
  places this single-cell unit at the target cell, consuming a Blue Gemstone. The
  hit/shield budget is shared by the wall and computed once at placement from the
  caster's stats (rAthena `group->val2`/`val3`): `hits_remaining = level + 1` and
  `shield_hp = 300*level + 65*(INT + baseLv) + maxSP`. Each tick the unit grants
  the `sc_safetywall` marker to every unit standing on its cell - allies and the
  caster included, since it is defensive - that does not already carry it. The
  status blocks short-range physical hits and spends the wall's shared budget; once
  exhausted it tears this unit down (rAthena `skill_delunitgroup`).

  rAthena (`skill_db` id 12): `Element: Ghost`, no damage, single cell, status
  `Safetywall`; requires `Blue_Gemstone` (717).
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 12,
    name: :mg_safetywall,
    display_name: "Safety Wall",
    max_level: 10,
    target_type: :ground,
    damage_type: :no_damage,
    range: 9,
    element: :ghost,
    hit_interval: 1_000,
    unit_duration: [5000, 10_000, 15_000, 20_000, 25_000, 30_000, 35_000, 40_000, 45_000, 50_000],
    cast_time: [3200, 2880, 2560, 2240, 1920, 1600, 1280, 960, 640, 320],
    fixed_cast_time: [800, 720, 640, 560, 480, 400, 320, 240, 160, 80],
    sp_cost: [30, 30, 30, 35, 35, 35, 40, 40, 40, 40],
    item_cost: [%{id: 717, amount: 1}]

  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Ground

  @impl Ground
  def on_place(%Group{
        center: center,
        level: level,
        caster_type: caster_type,
        caster_id: caster_id
      }) do
    definition = definition()
    {:ok, %{stats: stats}} = UnitRegistry.get_unit_info(caster_type, caster_id)

    {:ok,
     %{
       cells: [center],
       state: %{hits_remaining: level + 1, shield_hp: shield_hp(level, stats)},
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1)
     }}
  end

  @impl Ground
  def on_interval(%Group{center: {cx, cy}, map_name: map_name, level: level} = group, _now) do
    # Skip occupants who already carry the marker so a stationary defender keeps
    # spending the wall's shared budget instead of re-granting it each tick.
    map_name
    |> SpatialIndex.get_all_units_in_range(cx, cy, 0)
    |> Enum.filter(fn {unit_type, _unit_id} -> unit_type in [:player, :mob] end)
    |> Enum.reject(fn {unit_type, unit_id} ->
      StatusStorage.has_status?(unit_type, unit_id, :sc_safetywall)
    end)
    |> Enum.each(fn {unit_type, unit_id} ->
      StatusInterpreter.apply_status(unit_type, unit_id, :sc_safetywall,
        val1: level,
        val2: group.group_id,
        caster_id: group.caster_id
      )
    end)

    {:ok, group}
  end

  @spec shield_hp(non_neg_integer(), map()) :: non_neg_integer()
  defp shield_hp(level, %{int: int, base_level: base_level, max_sp: max_sp}) do
    300 * level + 65 * (int + base_level) + max_sp
  end
end
