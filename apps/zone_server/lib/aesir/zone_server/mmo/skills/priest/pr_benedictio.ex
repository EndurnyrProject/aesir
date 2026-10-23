defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrBenedictio do
  @moduledoc """
  B.S. Sacramenti (PR_BENEDICTIO). An immediate 3x3 blessing cast by three Acolyte-
  family players standing in a row: the two side companions each pay 10 SP. Any
  Acolyte-line class qualifies as a companion (Acolyte, Priest, Monk, and their
  transcendent, baby, and later classes).

  Living players in the area that are neither undead nor demon receive the holy
  armor blessing for 40 s per level; living demon enemies and enemies of undead
  defence element instead take a neutral magic attack whose base is the Heal
  formula's offensive amount at the cast level, ignoring MDEF but taking
  cardfix, skill rates and the element step. Renewal and pre-renewal agree apart
  from the Heal formula itself: 9-cell range, 20 SP, no cast.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 69,
    name: :pr_benedictio,
    display_name: "B.S. Sacramenti",
    status: :sc_benedictio,
    max_level: 5,
    target_type: :ground,
    damage_type: :no_damage,
    damage_kind: :magic,
    range: 9,
    element: :neutral,
    splash_radius: 1,
    sp_cost: List.duplicate(20, 5),
    duration: [40_000, 80_000, 120_000, 160_000, 200_000],
    damage_splash: true

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Combat.SkillHeal
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.JobManagement.JobLineage
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.Invincibility
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @participant_sp_cost 10

  @doc "The cast begins only with two eligible companions beside the caster."
  @impl Active
  @spec begin_attempt(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, :insufficient_companions}
  def begin_attempt(caster, {:ground, _x, _y}, _level, _definition) do
    if length(companions(caster)) == 2,
      do: {:ok, caster},
      else: {:error, :insufficient_companions}
  end

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, :insufficient_companions}
  def cast(caster, {:ground, x, y}, level, definition) do
    case partners(caster) do
      [first, second] ->
        charge_companions([first, second])
        bless_players(caster, x, y, level, definition)
        damage_enemies(caster, x, y, level, definition)
        {:ok, caster}

      _companions ->
        {:error, :insufficient_companions}
    end
  end

  # The partner check runs before the cast is paid and reads the caster's own
  # SP against the companions' share; the effect takes the partners again
  # without it, from the paid caster.
  defp companions(%{stats: %{current_state: %{sp: sp}}}) when sp < @participant_sp_cost, do: []
  defp companions(caster), do: partners(caster)

  # The first two eligible companions in the map's block order take part.
  defp partners(%PlayerState{} = caster) do
    caster.map_name
    |> SpatialIndex.units_in_area(caster.x - 1, caster.y - 1, caster.x + 1, caster.y + 1)
    |> Enum.filter(&match?({:player, id} when id != caster.character_id, &1))
    |> Enum.flat_map(&eligible_companion(&1, caster))
    |> Enum.take(2)
  end

  defp eligible_companion({:player, companion_id}, caster) do
    case UnitRegistry.get_unit(:player, companion_id) do
      {:ok, {PlayerState, companion, pid}} when is_pid(pid) ->
        if eligible_companion?(companion, companion_id, caster),
          do: [%{id: companion_id, pid: pid}],
          else: []

      _other ->
        []
    end
  end

  defp eligible_companion?(companion, companion_id, caster) do
    Unit.living?(companion) and
      acolyte?(companion.stats.progression.job_id) and
      StatusInterpreter.can_use_skill?(:player, companion_id) and
      side_cell?(caster, companion)
  end

  defp acolyte?(job_id) do
    case AvailableJobs.job_id_to_name(job_id) do
      {:ok, job_name} -> JobLineage.base_class(job_name) == :acolyte
      {:error, _reason} -> false
    end
  end

  defp side_cell?(caster, companion) do
    direction = Geometry.calculate_direction(caster.x, caster.y, companion.x, companion.y)
    rem(caster.dir + direction, 8) in [2, 6]
  end

  defp charge_companions(companions) do
    Enum.each(companions, fn %{pid: pid} ->
      PlayerSession.try_consume_sp(pid, @participant_sp_cost)
    end)
  end

  defp bless_players(caster, x, y, level, definition) do
    params = [
      val1: level,
      caster_id: caster.character_id,
      duration: Enum.at(definition.duration, level - 1)
    ]

    caster.map_name
    |> units_in_square(x, y, definition.splash_radius)
    |> Enum.filter(&match?({:player, _id}, &1))
    |> Enum.each(fn {:player, target_id} ->
      with {:ok, {module, state, _pid}} <- UnitRegistry.get_unit(:player, target_id),
           true <- Unit.living?(state),
           false <- Invincibility.active?(state),
           false <- undead_or_demon?(module, state) do
        StatusInterpreter.apply_status(:player, target_id, :sc_benedictio, params)
      else
        _other -> :ok
      end
    end)
  end

  defp damage_enemies(caster, x, y, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      element: definition.element,
      ignore_mdef: true,
      skip_range: true
    ]

    caster.map_name
    |> Combat.splash_targets({x, y}, definition.splash_radius, caster.character_id)
    |> Enum.each(fn {unit_type, target_id} ->
      with {:ok, {module, state, _pid}} <- UnitRegistry.get_unit(unit_type, target_id),
           true <- undead_or_demon?(module, state) do
        Combat.execute_magic_attack(
          caster,
          target_id,
          [base_damage: strike_damage(caster, level, {unit_type, target_id})] ++ opts
        )
      else
        _other -> :ok
      end
    end)
  end

  defp strike_damage(caster, level, target),
    do: SkillHeal.amount(SkillHeal.caster(caster), target, definition().id, level, false)

  defp undead_or_demon?(module, state) do
    combatant = module.to_combatant(state)
    combatant.race == :demon or RaceModifiers.undead_target?(combatant)
  end

  defp units_in_square(map_name, x, y, radius),
    do: SpatialIndex.get_all_units_in_range(map_name, x, y, radius)
end
