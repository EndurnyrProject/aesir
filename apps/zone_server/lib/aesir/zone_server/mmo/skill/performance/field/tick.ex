defmodule Aesir.ZoneServer.Mmo.Skill.Performance.Field.Tick do
  @moduledoc """
  Applies periodic performance effects to living units on field cells.

  The normal effect and overlapping-cell damage have independent cadences so
  Idun can heal every six seconds while dissonant cells strike every three.
  """

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Resource
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @overlap_interval 3_000

  @doc "Runs due effects, returning the group with updated tick deadlines."
  @spec run(Group.t(), integer()) :: {:ok, Group.t()}
  def run(%Group{state: %{performance: perf}} = group, now) do
    own_due? = perf.tick != nil and due?(perf.next_effect_at, now)

    overlap_due? =
      MapSet.size(perf.dissonant_cells) > 0 and
        due?(Map.get(perf, :next_overlap_at, 0), now)

    if own_due? or overlap_due?,
      do: run_due(group, now, own_due?, overlap_due?),
      else: {:ok, group}
  end

  defp run_due(group, now, own_due?, overlap_due?) do
    with {:ok, caster} <- Combat.resolve_combatant(group.caster_type, group.caster_id),
         {:ok, {_module, caster_state, _pid}} <-
           UnitRegistry.get_unit(group.caster_type, group.caster_id) do
      Enum.each(group.cells, fn cell ->
        apply_cell(group, cell, caster, caster_state, own_due?, overlap_due?)
      end)

      perf = group.state.performance

      perf =
        perf
        |> maybe_advance(:next_effect_at, own_due?, now + perf.tick_interval)
        |> maybe_advance(:next_overlap_at, overlap_due?, now + @overlap_interval)

      {:ok, %{group | state: %{group.state | performance: perf}}}
    else
      _ -> {:ok, group}
    end
  end

  @doc "Strikes each eligible target with neutral Dissonance misc damage."
  @spec dissonance(Group.t(), struct(), [{atom(), integer()}]) :: :ok
  def dissonance(group, caster, targets) do
    level = group.level
    lesson = group.state.performance.lesson_level

    Enum.each(targets, fn target ->
      Combat.execute_misc_attack(caster, target,
        skill_id: 317,
        skill_level: level,
        base_damage: 30 + 10 * level + level * lesson,
        element: :neutral
      )
    end)
  end

  @doc "Drains SP from each eligible Ugly Dance target."
  @spec ugly_dance(Group.t(), struct(), [{atom(), integer()}]) :: :ok
  def ugly_dance(group, _caster, targets) do
    amount = 5 + 5 * group.level + group.level * group.state.performance.lesson_level
    Enum.each(targets, fn {type, id} -> Resource.drain_sp(type, id, amount) end)
  end

  @doc "Heals living Idun occupants other than the performer."
  @spec idun_heal(Group.t(), struct(), [{atom(), integer()}]) :: :ok
  def idun_heal(group, _caster, targets) do
    perf = group.state.performance
    amount = 30 + 5 * group.level + div(perf.caster_vit, 2) + 5 * perf.lesson_level

    Enum.each(targets, fn
      {:player, id} when id != group.caster_id ->
        DamageApplication.apply_heal(:player, id, amount, group.caster_id)

      {:mob, id} ->
        case UnitRegistry.get_unit(:mob, id) do
          {:ok, {_module, _state, pid}} when is_pid(pid) -> MobSession.heal(pid, amount)
          _ -> :ok
        end

      _ ->
        :ok
    end)
  end

  @doc "Attempts a thirty-second sleep using both performers' INT every six seconds."
  @spec lullaby(Group.t(), struct(), [{atom(), integer()}]) :: :ok
  def lullaby(group, caster, targets) do
    intelligence =
      Enum.reduce(group.state.performance.performers, 0, fn id, total ->
        case UnitRegistry.get_unit(:player, id) do
          {:ok, {_module, performer, _pid}} -> total + Caster.stat(performer, :int)
          _ -> total
        end
      end)

    Enum.each(targets, fn {type, id} ->
      StatusInterpreter.apply_status(type, id, :sc_sleep,
        val1: group.level,
        caster_id: caster.character_id,
        success_rate: (intelligence + 99 + :rand.uniform(201)) / 10,
        duration: 30_000,
        owner_refresh: :notify
      )
    end)
  end

  defp apply_cell(group, {x, y} = cell, caster, caster_state, own_due?, overlap_due?) do
    case effect_for_cell(group.state.performance, cell, own_due?, overlap_due?) do
      nil ->
        :ok

      effect ->
        reach = if effect == :idun_heal, do: :everyone, else: :enemy
        targets = targets(group, x, y, caster, reach)
        apply_effect(effect, group, caster_state, targets)
    end
  end

  defp effect_for_cell(perf, cell, own_due?, overlap_due?) do
    if MapSet.member?(perf.dissonant_cells, cell) do
      if overlap_due?, do: %{song: :dissonance, dance: :ugly_dance}[perf.kind]
    else
      if own_due?, do: perf.tick
    end
  end

  defp apply_effect(:dissonance, group, caster, targets), do: dissonance(group, caster, targets)
  defp apply_effect(:ugly_dance, group, caster, targets), do: ugly_dance(group, caster, targets)
  defp apply_effect(:idun_heal, group, caster, targets), do: idun_heal(group, caster, targets)
  defp apply_effect(:lullaby, group, caster, targets), do: lullaby(group, caster, targets)

  defp targets(group, x, y, caster, reach) do
    group.map_name
    |> SpatialIndex.get_all_units_in_range(x, y, 0)
    |> Enum.uniq()
    |> Enum.filter(fn {type, id} ->
      {type, id} != {group.caster_type, group.caster_id} and
        not (type == :player and id in Map.get(group.state.performance, :performers, [])) and
        case UnitRegistry.get_unit(type, id) do
          {:ok, {_module, state, _pid}} ->
            type in [:player, :mob] and Unit.living?(state) and
              (reach == :everyone or Targeting.validate_enemy(caster, state) == :ok)

          _ ->
            false
        end
    end)
  end

  defp due?(0, _now), do: true
  defp due?(deadline, now), do: now >= deadline

  defp maybe_advance(perf, _key, false, _next), do: perf
  defp maybe_advance(perf, key, true, next), do: Map.put(perf, key, next)
end
