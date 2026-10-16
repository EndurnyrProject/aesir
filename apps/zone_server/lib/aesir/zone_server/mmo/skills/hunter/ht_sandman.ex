defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtSandman do
  @moduledoc """
  Sandman (HT_SANDMAN). A sleep trap.

  The first enemy within one cell sets it off: every enemy within two cells of
  that enemy is put to sleep at 40% plus 10% per level. Renewal sleeps for 18 s,
  pre-renewal for 30 s. Both last 150 s down to 30 s by level, for 12 SP and
  one trap.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 119,
    name: :ht_sandman,
    no_reiteration: true,
    no_footset: true,
    unit_range: 1,
    is_trap: true,
    requires: [],
    display_name: "Sandman",
    max_level: 5,
    target_type: :ground,
    damage_type: :no_damage,
    range: 3,
    splash_radius: 2,
    hit_interval: 1_000,
    unit_duration: [150_000, 120_000, 90_000, 60_000, 30_000],
    sp_cost: List.duplicate(12, 5),
    item_cost: [%{id: 1065, amount: 1}],
    damage_splash: true

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.OnHitEffects
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.Trap
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Ground

  @impl Ground
  def on_place(%Group{center: center, level: level, caster_type: type, caster_id: id} = group) do
    definition = definition()
    {:ok, %{stats: stats}} = UnitRegistry.get_unit_info(type, id)

    {:ok,
     %{
       cells: [center],
       state: Trap.place_state(level, stats, group),
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1),
       unit_range: 1,
       visibility: Trap.visibility(:ht_sandman)
     }}
  end

  @impl Ground
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  def unit_targets(%Group{} = group, _cell, refs), do: Trap.unit_targets(group, refs)

  @impl Ground
  def on_unit_hit(%Group{} = group, _cell, {type, id}, now) do
    with true <- Trap.armed?(group),
         {:ok, caster} <- Combat.resolve_combatant(group.caster_type, group.caster_id),
         {:ok, {x, y, _map}} <- SpatialIndex.get_unit_position(type, id) do
      group
      |> splash_targets({x, y}, definition().splash_radius, caster)
      |> Enum.each(fn target ->
        OnHitEffects.direct(caster, target, BattleFlags.type_bit(:misc), group.skill_id)
        apply_sleep(target, group)
      end)

      {:ok, Trap.spring(group, now)}
    else
      _inert -> {:ok, group}
    end
  end

  defp splash_targets(%Group{caster_type: :player} = group, center, radius, caster),
    do: SplashTargets.select_field(group, center, radius, caster)

  defp splash_targets(%Group{caster_type: :mob} = group, center, radius, caster) do
    group.map_name
    |> Combat.splash_targets(center, radius, caster)
    |> Enum.filter(&Trap.enemy?(group, &1))
  end

  defp apply_sleep({unit_type, unit_id}, group) do
    StatusInterpreter.apply_status(unit_type, unit_id, :sc_sleep,
      duration: sleep_duration(),
      success_rate: 40 + group.level * 10,
      caster_id: group.caster_id,
      source_type: group.caster_type
    )
  end

  defp sleep_duration do
    case GameMode.mode() do
      :renewal -> 18_000
      :pre_renewal -> 30_000
    end
  end
end
