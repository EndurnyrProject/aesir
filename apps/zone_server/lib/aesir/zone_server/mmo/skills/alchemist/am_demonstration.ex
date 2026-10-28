defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmDemonstration do
  @moduledoc """
  Demonstration (AM_DEMONSTRATION), a Fire weapon-damage field.

  The field is one cell that lasts 35 plus 5 seconds per skill level and
  reaches the 3x3 area around it. Each enemy there receives a normal physical
  weapon attack every tick, timed from when the field first reached it; the
  attack may miss, and Guard never blocks it. A confirmed hit attempts to break
  a player target's weapon. It is a no-damage skill: its hits never set off the
  target's when-hit equipment procs.

  A player's cast fails before anything is spent when another Demonstration
  stands within one cell of the target, or any character other than the
  Emperium stands within one cell of it.

  Both modes cost 10 SP and a Fire Bottle and deal 100 plus 20 per level percent
  fire weapon damage. Renewal: ticks every 0.5 s, a 0.8 s cast plus 0.2 s fixed,
  a 0.5 s delay, and a 3 per level percent weapon break. Pre-renewal: ticks every
  second, a 1 s cast, and a 1 per level percent weapon break.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 229,
    name: :am_demonstration,
    no_reiteration: true,
    no_footset: true,
    unit_range: 1,
    ignore_atk_card: true,
    ignore_auto_guard: true,
    requires: [],
    display_name: "Demonstration",
    max_level: 5,
    target_type: :ground,
    damage_type: :no_damage,
    damage_kind: :weapon,
    element: :fire,
    range: 9,
    hit_interval: [renewal: 500, pre_renewal: 1_000],
    unit_duration: [40_000, 45_000, 50_000, 55_000, 60_000],
    sp_cost: List.duplicate(10, 5),
    item_cost: [%{id: 7135, amount: 1}],
    cast_time: [renewal: List.duplicate(800, 5), pre_renewal: List.duplicate(1_000, 5)],
    fixed_cast_time: [renewal: List.duplicate(200, 5), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(500, 5), pre_renewal: []]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat.EquipBreak
  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @radius 1
  @behaviour Ground

  @doc false
  @spec cast(PlayerState.t(), {:ground, integer(), integer()}, pos_integer(), struct()) ::
          {:ok, PlayerState.t()} | {:error, term()}
  def cast(caster, {:ground, x, y}, level, _definition) do
    case Unit.place(caster, :am_demonstration, level, {x, y}) do
      {:ok, _group} ->
        {:ok, caster}

      {:error, reason} ->
        if Unit.paid_refusal?(reason), do: {:ok, caster}, else: {:error, reason}
    end
  end

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center, level: level}) do
    definition = definition()

    {:ok,
     %{
       cells: [center],
       state: %{},
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1),
       unit_range: @radius
     }}
  end

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()} | {:expire, Group.t()}
  def on_interval(%Group{caster_id: caster_id} = group, _now) do
    case UnitRegistry.get_unit(:player, caster_id) do
      {:ok, {PlayerState, _caster, _pid}} -> {:ok, group}
      {:error, :not_found} -> {:expire, group}
    end
  end

  @impl Ground
  @spec unit_targets(Group.t(), Ground.cell(), [{atom(), integer()}]) :: [{atom(), integer()}]
  def unit_targets(%Group{caster_id: caster_id} = group, _cell, refs) do
    case UnitRegistry.get_unit(:player, caster_id) do
      {:ok, {PlayerState, caster, _pid}} ->
        SplashTargets.eligible(refs, PlayerState.to_combatant(caster), field: group)

      {:error, :not_found} ->
        []
    end
  end

  @impl Ground
  @spec on_unit_hit(Group.t(), Ground.cell(), {atom(), integer()}, integer()) :: {:ok, Group.t()}
  def on_unit_hit(%Group{caster_id: caster_id} = group, _cell, target, _now) do
    with {:ok, {PlayerState, caster, _pid}} <- UnitRegistry.get_unit(:player, caster_id) do
      hit(caster, group, target)
    end

    {:ok, group}
  end

  @spec hit(PlayerState.t(), Group.t(), {atom(), integer()}) :: :ok
  defp hit(caster, group, {unit_type, target_id} = target_ref) do
    case SkillAttack.execute_field_skill_attack(caster, target_ref, group,
           skill_id: group.skill_id,
           skill_level: group.level,
           skill_ratio: skill_ratio(group.level),
           element: :fire,
           skip_crit: true,
           skip_range: true,
           report_hit: true
         ) do
      {:ok, %{hit?: true}} -> roll_weapon_break(unit_type, target_id, group.level)
      _ -> :ok
    end
  end

  @spec roll_weapon_break(atom(), integer(), pos_integer()) :: :ok
  defp roll_weapon_break(:player, target_id, level) do
    case UnitRegistry.get_unit(:player, target_id) do
      {:ok, {PlayerState, target, target_pid}} ->
        level
        |> weapon_break_rate()
        |> EquipBreak.resolve_slot({:player, target_id, target.stats}, :weapon)
        |> Enum.each(&dispatch_break(&1, target_pid))

      {:error, :not_found} ->
        :ok
    end
  end

  defp roll_weapon_break(_unit_type, _target_id, _level), do: :ok

  @spec dispatch_break({:target, :weapon}, pid()) :: :ok
  defp dispatch_break({:target, :weapon}, target_pid),
    do: PlayerSession.break_equip(target_pid, :right_hand)

  @spec skill_ratio(pos_integer()) :: pos_integer()
  defp skill_ratio(level), do: 100 + 20 * level

  defp weapon_break_rate(level) do
    case GameMode.mode() do
      :renewal -> 300 * level
      :pre_renewal -> 100 * level
    end
  end
end
