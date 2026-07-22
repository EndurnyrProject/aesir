defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrBenedictio do
  @moduledoc """
  B.S. Sacramenti (PR_BENEDICTIO), an immediate 3x3 Holy blessing and attack.

  Casting requires two living, skill-capable Acolyte-family players in the
  caster-relative side cells. The participants do not need to share a party and
  their own SP is not part of candidate selection. At completion each selected
  participant independently attempts to spend 10 SP; either failure is ignored.

  The ground cell then receives two immediate passes. Living players that are
  neither undead nor demon receive SC_BENEDICTIO. Living enemy characters that
  are undead by race or element, or demon by race, receive one 100% Holy magic
  hit that ignores MDEF. No skill-unit group or persistent field is created.

  Renewal references:

  * `db/re/skill_db.yml:2426-2459` -- metadata, cost, area, and duration
  * `src/map/skill.cpp:7907-8001,8012-8078` -- candidate selection and charging
  * `src/map/skill.cpp:8552-8557,9388-9390` -- exact-two gate and cast completion
  * `src/map/skills/acolyte/bssacramenti.cpp:12-38` -- the two immediate area passes
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
    element: :holy,
    splash_radius: 1,
    sp_cost: List.duplicate(20, 5),
    duration: [40_000, 80_000, 120_000, 160_000, 200_000]

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @acolyte_jobs [:acolyte, :acolyte_high, :baby_acolyte]
  @participant_sp_cost 10

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :insufficient_companions}
  def validate(caster, {:ground, _x, _y}, _level, _definition) do
    if length(companions(caster)) == 2,
      do: :ok,
      else: {:error, :insufficient_companions}
  end

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, :insufficient_companions}
  def cast(caster, {:ground, x, y}, level, definition) do
    case companions(caster) do
      [first, second] ->
        charge_companions([first, second])
        bless_players(caster, x, y, level, definition)
        damage_enemies(caster, x, y, level, definition)
        {:ok, caster}

      _companions ->
        {:error, :insufficient_companions}
    end
  end

  defp companions(%{stats: %{current_state: %{sp: sp}}}) when sp < @participant_sp_cost, do: []

  defp companions(%PlayerState{} = caster) do
    caster.map_name
    |> units_in_square(caster.x, caster.y, 1)
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
      {:ok, job_name} -> job_name in @acolyte_jobs
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
      skill_ratio: 100,
      element: definition.element,
      ignore_mdef: true,
      skip_range: true
    ]

    caster.map_name
    |> Combat.splash_targets({x, y}, definition.splash_radius, caster.character_id)
    |> Enum.each(fn {unit_type, target_id} ->
      with {:ok, {module, state, _pid}} <- UnitRegistry.get_unit(unit_type, target_id),
           true <- undead_or_demon?(module, state) do
        Combat.execute_magic_attack(caster, target_id, opts)
      else
        _other -> :ok
      end
    end)
  end

  defp undead_or_demon?(module, state) do
    combatant = module.to_combatant(state)
    combatant.race in [:undead, :demon] or elem(combatant.element, 0) == :undead
  end

  defp units_in_square(map_name, x, y, radius) do
    map_name
    |> SpatialIndex.get_all_units_in_range(x, y, radius * 2)
    |> Enum.filter(fn {unit_type, unit_id} ->
      case SpatialIndex.get_unit_position(unit_type, unit_id) do
        {:ok, {unit_x, unit_y, ^map_name}} ->
          Geometry.in_tile_range?(x, y, unit_x, unit_y, radius)

        _other ->
          false
      end
    end)
  end
end
