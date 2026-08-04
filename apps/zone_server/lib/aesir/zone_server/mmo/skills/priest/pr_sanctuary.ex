defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrSanctuary do
  @moduledoc """
  Sanctuary (PR_SANCTUARY), a periodic 21-cell Holy field.

  Every second it heals living non-undead/non-demon occupants below maximum HP.
  Enemy undead and demons instead take the same amount as fixed Holy magic
  damage. Successful offensive hits spend the group's shared `level + 3` quota;
  healing and failed hits do not.

  Renewal references:

  * `db/re/skill_db.yml:2460-2533` -- metadata, costs, timing, and unit flags
  * `src/map/skill.cpp:5752-6343,6923-6973,12417-12421` -- tick and quota behavior
  * `src/map/skills/acolyte/sanctuary.cpp:9-13` -- placement layout
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 70,
    name: :pr_sanctuary,
    display_name: "Sanctuary",
    max_level: 10,
    target_type: :ground,
    damage_type: :no_damage,
    damage_kind: :magic,
    range: 9,
    element: :holy,
    splash_radius: 2,
    knockback: 2,
    hit_interval: 1_000,
    cast_time: List.duplicate(4_000, 10),
    fixed_cast_time: List.duplicate(1_000, 10),
    unit_duration: [
      3_900,
      6_900,
      9_900,
      12_900,
      15_900,
      18_900,
      21_900,
      24_900,
      27_900,
      30_900
    ],
    sp_cost: [15, 18, 21, 24, 27, 30, 33, 36, 39, 42],
    item_cost: [%{id: 717, amount: 1}]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.CombatTarget
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Ground

  @layout [
    {-1, -2},
    {0, -2},
    {1, -2},
    {-2, -1},
    {-1, -1},
    {0, -1},
    {1, -1},
    {2, -1},
    {-2, 0},
    {-1, 0},
    {0, 0},
    {1, 0},
    {2, 0},
    {-2, 1},
    {-1, 1},
    {0, 1},
    {1, 1},
    {2, 1},
    {-1, 2},
    {0, 2},
    {1, 2}
  ]

  @impl Ground
  def on_place(%Group{center: {cx, cy}, level: level}) do
    definition = definition()

    {:ok,
     %{
       cells: Enum.map(@layout, fn {dx, dy} -> {cx + dx, cy + dy} end),
       state: %{hits_remaining: level + 3},
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1),
       path_check: true
     }}
  end

  @impl Ground
  def on_interval(%Group{state: %{hits_remaining: hits}} = group, _now) when hits <= 0,
    do: {:expire, group}

  def on_interval(%Group{} = group, _now) do
    case Combat.resolve_combatant(group.caster_type, group.caster_id) do
      {:ok, caster} ->
        enemies =
          group.map_name
          |> Combat.splash_targets(group.center, definition().splash_radius, caster)
          |> MapSet.new()

        group
        |> targets_in_field()
        |> Enum.reduce_while(group, &affect_target(&1, &2, caster, enemies))
        |> finish_interval()

      {:error, _reason} ->
        {:ok, group}
    end
  end

  defp targets_in_field(%Group{} = group) do
    group.cells
    |> Enum.flat_map(fn {x, y} ->
      SpatialIndex.get_all_units_in_range(group.map_name, x, y, 0)
    end)
    |> Enum.filter(&CombatTarget.combat_unit?/1)
    |> Enum.uniq()
  end

  defp affect_target({unit_type, unit_id} = target, group, caster, enemies) do
    with {:ok, {module, state, pid}} <- UnitRegistry.get_unit(unit_type, unit_id),
         true <- Unit.living?(state) do
      affect_living_target(target, {module, state, pid}, group, caster, enemies)
    else
      _ -> {:cont, group}
    end
  end

  defp affect_living_target(
         {unit_type, unit_id} = target,
         {module, state, pid},
         group,
         caster,
         enemies
       ) do
    case target_effect(module, state, target, enemies) do
      :damage ->
        damage_target(group, caster, unit_type, unit_id)

      :skip ->
        {:cont, group}

      :heal ->
        heal_target(unit_type, unit_id, pid, group)
    end
  end

  defp target_effect(module, state, target, enemies) do
    cond do
      undead_or_demon?(module, state) and MapSet.member?(enemies, target) -> :damage
      undead_or_demon?(module, state) -> :skip
      full_hp?(state) or emperium?(state) -> :skip
      true -> :heal
    end
  end

  defp heal_target(:player, unit_id, _pid, group) do
    DamageApplication.apply_heal(:player, unit_id, heal_amount(group.level), group.caster_id)
    {:cont, group}
  end

  defp heal_target(:homunculus, unit_id, _pid, group) do
    DamageApplication.apply_heal(
      :homunculus,
      unit_id,
      heal_amount(group.level),
      group.caster_id
    )

    {:cont, group}
  end

  defp heal_target(:mob, _unit_id, pid, group) when is_pid(pid) do
    MobSession.heal(pid, heal_amount(group.level))
    {:cont, group}
  end

  defp heal_target(_unit_type, _unit_id, _pid, group) do
    {:cont, group}
  end

  defp damage_target(group, caster, unit_type, unit_id) do
    result =
      Combat.apply_skill_unit_damage(
        caster,
        unit_type,
        unit_id,
        group.skill_id,
        group.level,
        :holy,
        0,
        fixed_damage: heal_amount(group.level)
      )

    if result == :ok do
      Combat.knockback(unit_type, unit_id, elem(group.center, 0), elem(group.center, 1), 2)
      hits_remaining = group.state.hits_remaining - 1
      updated = %{group | state: %{group.state | hits_remaining: hits_remaining}}
      if hits_remaining <= 0, do: {:halt, updated}, else: {:cont, updated}
    else
      {:cont, group}
    end
  end

  defp finish_interval(%Group{state: %{hits_remaining: hits}} = group) when hits <= 0,
    do: {:expire, group}

  defp finish_interval(group), do: {:ok, group}

  defp undead_or_demon?(module, state) do
    module.get_race(state) in [:undead, :demon] or elem(module.get_element(state), 0) == :undead
  end

  defp full_hp?(%PlayerState{
         stats: %{current_state: %{hp: hp}, derived_stats: %{max_hp: max_hp}}
       }),
       do: hp >= max_hp

  defp full_hp?(%MobState{hp: hp, max_hp: max_hp}), do: hp >= max_hp
  defp full_hp?(%HomunculusState{hp: hp, max_hp: max_hp}), do: hp >= max_hp
  defp full_hp?(_state), do: true

  defp emperium?(%MobState{mob_id: 1_288}), do: true

  # NOTE: Exclude rAthena's CLASS_BATTLEFIELD mobs once Aesir models that mob classification.
  defp emperium?(_state), do: false

  defp heal_amount(level) when level <= 6, do: 100 * level
  defp heal_amount(_level), do: 777
end
