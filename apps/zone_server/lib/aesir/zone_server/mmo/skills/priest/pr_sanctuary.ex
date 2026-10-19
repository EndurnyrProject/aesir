defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrSanctuary do
  @moduledoc """
  Sanctuary (PR_SANCTUARY). A 21-cell holy field whose cells each act on the
  living units within one cell of them, each unit at most once a second for all
  Sanctuaries together: it heals non-undead, non-demon units below full HP (100
  per level, 777 from level 7, with the caster's and the target's heal bonuses
  of `Combat.SkillHeal`) and instead strikes enemy undead and demons with a holy
  magic attack whose base is half that amount (MDEF ignored), pushing them 2
  cells away from the striking cell. Successful strikes spend a shared quota of
  level plus 3; heals and failed strikes do not. Once it is spent the field ends
  after the striking cell's remaining units. Magic-immune players receive no
  healing and battlefield-class monsters are never healed.

  Renewal: a 4 s cast plus 1 s fixed, and the Emperium is never healed. Pre-renewal:
  a 5 s variable cast, and the Emperium heals like any other mob. Both modes cost
  15 to 42 SP and one Blue Gemstone.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 70,
    name: :pr_sanctuary,
    # Player-coupled at runtime (Blue Gemstone catalyst), but not on the pre-migration mob
    # previous refusal set. Kept mob-selectable with [] to preserve exact pre-migration behaviour; a
    # mob simply fails the cast gracefully as it does today.
    requires: [],
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
    cast_time: [renewal: List.duplicate(4_000, 10), pre_renewal: List.duplicate(5_000, 10)],
    fixed_cast_time: [renewal: List.duplicate(1_000, 10), pre_renewal: []],
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

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.MagicDefense
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Combat.SkillHeal
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
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
       unit_range: 1,
       no_overlap: true,
       path_check: true
     }}
  end

  @impl Ground
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  def unit_targets(%Group{} = group, _cell, refs) do
    case Combat.resolve_combatant(group.caster_type, group.caster_id) do
      {:ok, _caster} -> Enum.filter(refs, &living?/1)
      {:error, _reason} -> []
    end
  end

  @impl Ground
  def on_unit_hit(%Group{} = group, cell, {unit_type, unit_id} = target, _now) do
    with {:ok, caster} <- Combat.resolve_combatant(group.caster_type, group.caster_id),
         {:ok, {module, state, pid}} <- UnitRegistry.get_unit(unit_type, unit_id) do
      case target_effect(module, state, target, caster) do
        :damage -> damage_target(group, caster, cell, unit_type, unit_id)
        :skip -> {:ok, group}
        :heal -> heal_target(unit_type, unit_id, pid, group, heal_amount(group, target, true))
      end
    else
      _unavailable -> {:ok, group}
    end
  end

  defp living?({unit_type, unit_id}) do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {_module, state, _pid}} -> Unit.living?(state)
      _missing -> false
    end
  end

  defp target_effect(module, state, target, caster) do
    cond do
      undead_or_demon?(module, state) and SplashTargets.eligible([target], caster) != [] ->
        :damage

      undead_or_demon?(module, state) ->
        :skip

      protected_emperium?(state) or battlefield?(state) or full_hp?(state) ->
        :skip

      true ->
        :heal
    end
  end

  defp heal_target(:player, unit_id, _pid, group, amount) do
    unless MagicDefense.immune?({:player, unit_id}) do
      DamageApplication.apply_heal(:player, unit_id, amount, group.caster_id)
    end

    {:ok, group}
  end

  defp heal_target(:homunculus, unit_id, _pid, group, amount) do
    DamageApplication.apply_heal(:homunculus, unit_id, amount, group.caster_id)
    {:ok, group}
  end

  defp heal_target(:mob, _unit_id, pid, group, amount) when is_pid(pid) do
    MobSession.heal(pid, amount)
    {:ok, group}
  end

  defp heal_target(_unit_type, _unit_id, _pid, group, _amount) do
    {:ok, group}
  end

  defp damage_target(group, caster, cell, unit_type, unit_id) do
    result =
      Combat.apply_skill_unit_damage(
        caster,
        unit_type,
        unit_id,
        group.skill_id,
        group.level,
        :holy,
        0,
        base_damage: heal_amount(group, {unit_type, unit_id}, false),
        ignore_mdef: true,
        base_distance: definition().knockback,
        origin: cell,
        native_target_types: [:player, :mob, :homunculus]
      )

    if result == :ok do
      hits_remaining = group.state.hits_remaining - 1
      updated = %{group | state: %{group.state | hits_remaining: hits_remaining}}
      if hits_remaining <= 0, do: {:expire, updated}, else: {:ok, updated}
    else
      {:ok, group}
    end
  end

  defp undead_or_demon?(module, state) do
    module.get_race(state) == :demon or
      RaceModifiers.undead_target?(%{element: module.get_element(state)})
  end

  defp full_hp?(%PlayerState{
         stats: %{current_state: %{hp: hp}, derived_stats: %{max_hp: max_hp}}
       }),
       do: hp >= max_hp

  defp full_hp?(%MobState{hp: hp, calculated: calculated}), do: hp >= calculated.max_hp
  defp full_hp?(%HomunculusState{hp: hp, max_hp: max_hp}), do: hp >= max_hp
  defp full_hp?(_state), do: true

  defp protected_emperium?(%MobState{mob_id: 1_288}), do: GameMode.mode() == :renewal
  defp protected_emperium?(_state), do: false

  defp battlefield?(%MobState{} = mob), do: MobState.monster_class(mob) == :battlefield
  defp battlefield?(_state), do: false

  # The recipe for the field's caster as it is now; a caster gone since the
  # strike was decided heals and deals nothing.
  defp heal_amount(%Group{} = group, target, heal?) do
    case UnitRegistry.get_unit(group.caster_type, group.caster_id) do
      {:ok, {_module, caster, _pid}} ->
        SkillHeal.amount(SkillHeal.caster(caster), target, group.skill_id, group.level, heal?)

      _gone ->
        0
    end
  end
end
