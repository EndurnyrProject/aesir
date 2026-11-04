defmodule Aesir.ZoneServer.Mmo.StatusEffect.StartChecks do
  @moduledoc """
  The gates a status application passes before it is stored, in the order
  `Aesir.ZoneServer.Mmo.StatusEffect.Applier` runs them: target
  eligibility and liveness, the map rule and the Madogear refusal, boss
  immunity, the other immunities, the Fail list, magic immunity, and the
  status defense roll that yields the final duration.
  """

  import Bitwise, only: [band: 2]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat.MagicDefense
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition, as: SkillDefinition
  alias Aesir.ZoneServer.Mmo.Skill.Origin
  alias Aesir.ZoneServer.Mmo.StatusEffect.CalcFlags
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusEffect.PropertyChecker
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.Woe.Rules
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @type unit_type :: Unit.unit_type()

  @defense_stats [:str, :agi, :vit, :int, :dex, :luk]

  @doc "The registry info of a status target; a target not in the world raises."
  @spec entity_info(unit_type(), integer()) :: map()
  def entity_info(unit_type, unit_id) do
    case UnitRegistry.get_unit_info(unit_type, unit_id) do
      {:ok, entity_info} ->
        entity_info

      {:error, :not_found} ->
        raise "Cannot apply status effect to non-existent #{unit_type} with ID: #{unit_id}"
    end
  end

  @doc """
  Whether the definition admits `unit_type` as a target. A monster also needs
  the status to be monster-eligible by its calc flags, and a homunculus never
  takes a weapon-bound status.
  """
  @spec ensure_eligible_target(unit_type(), map()) :: :ok | {:error, :ineligible_target}
  def ensure_eligible_target(:mob, %{id: status_id, target_types: target_types}) do
    if :mob in target_types and CalcFlags.monster_eligible?(status_id),
      do: :ok,
      else: {:error, :ineligible_target}
  end

  def ensure_eligible_target(:homunculus, %{require_weapon: [_ | _]}),
    do: {:error, :ineligible_target}

  def ensure_eligible_target(unit_type, %{target_types: target_types}) do
    if unit_type in target_types, do: :ok, else: {:error, :ineligible_target}
  end

  @doc "Refuses a dead target; a target not in the registry passes."
  @spec ensure_living_target(unit_type(), integer()) :: :ok | {:error, :target_dead}
  def ensure_living_target(unit_type, unit_id)
      when unit_type in [:player, :mob, :homunculus] do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {_module, target_state, _pid}} ->
        if Unit.living?(target_state), do: :ok, else: {:error, :target_dead}

      {:error, :not_found} ->
        :ok
    end
  end

  def ensure_living_target(_unit_type, _unit_id), do: :ok

  @doc "Refuses Endure on a map whose siege rules forbid it."
  @spec ensure_status_allowed(unit_type(), integer(), atom()) ::
          :ok | {:error, :status_not_allowed}
  def ensure_status_allowed(unit_type, unit_id, :sc_endure) do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {_module, %{map_name: map_name}, _pid}} ->
        if Rules.status_allowed?(:sc_endure, map_name),
          do: :ok,
          else: {:error, :status_not_allowed}

      {:error, :not_found} ->
        :ok
    end
  end

  def ensure_status_allowed(_unit_type, _unit_id, _status_id), do: :ok

  @doc """
  Refuses an unavoidable start of a `:failed_mado` status while the target
  carries the Madogear option.
  """
  @spec check_failed_mado(unit_type(), integer(), map(), StatusEntry.status_params()) ::
          :ok | {:error, :madogear}
  def check_failed_mado(unit_type, unit_id, definition, params) do
    with true <- :failed_mado in definition.flags and Keyword.get(params, :no_avoid, false),
         {:ok, {_module, %{option: option}, _pid}} when is_integer(option) <-
           UnitRegistry.get_unit(unit_type, unit_id),
         true <- band(option, Option.id(:madogear)) != 0 do
      {:error, :madogear}
    else
      _no_mount_gate -> :ok
    end
  end

  @doc "The boss immunity gate (BossResist), skipped by `no_avoid`."
  @spec check_resisted(map(), StatusEntry.status_params(), map()) :: :ok | {:error, :immune}
  def check_resisted(entity_info, status_params, definition) do
    if Keyword.get(status_params, :no_avoid, false) do
      :ok
    else
      check_immunity(entity_info, immunities(definition, &(&1 == :boss)))
    end
  end

  @doc "Every immunity gate but the boss one (race, element, custom), skipped by `no_avoid`."
  @spec check_avoidable(map(), StatusEntry.status_params(), map()) :: :ok | {:error, :immune}
  def check_avoidable(entity_info, status_params, definition) do
    if Keyword.get(status_params, :no_avoid, false),
      do: :ok,
      else: check_immunity(entity_info, immunities(definition, &(&1 != :boss)))
  end

  defp immunities(definition, keep?),
    do: %{definition | immunity: Enum.filter(definition.immunity, keep?)}

  defp check_immunity(entity_info, definition) do
    if PropertyChecker.check_immunity(entity_info, definition) do
      {:error, :immune}
    else
      :ok
    end
  end

  defp check_magic_immunity(unit_type, unit_id) do
    target = {unit_type, unit_id}

    with %{skill: skill, caster: caster} <- Origin.current(),
         {:ok, %SkillDefinition{damage_kind: :magic, target_type: target_type}} <-
           Catalog.by_name(skill),
         true <- MagicDefense.immune?(target),
         false <- target_type == :self and caster == target do
      {:error, :magic_immune}
    else
      _ -> :ok
    end
  end

  @doc "The `prevented_by` half of the Fail list."
  @spec check_prevented(unit_type(), integer(), map()) :: :ok | {:error, :prevented}
  def check_prevented(unit_type, unit_id, definition) do
    if fails_on?(unit_type, unit_id, definition.prevented_by) do
      {:error, :prevented}
    else
      :ok
    end
  end

  @doc "The `conflicts_with` half of the Fail list."
  @spec check_conflicts(unit_type(), integer(), map()) :: :ok | {:error, :conflict}
  def check_conflicts(unit_type, unit_id, definition) do
    if fails_on?(unit_type, unit_id, definition.conflicts_with) do
      {:error, :conflict}
    else
      :ok
    end
  end

  defp any_status_active?(unit_type, unit_id, status_ids) do
    Enum.any?(status_ids, &StatusStorage.has_status?(unit_type, unit_id, &1))
  end

  # The Fail list (`prevented_by` and `conflicts_with`) also fails on the status
  # damage last broke on the unit, while that record lasts.
  defp fails_on?(_unit_type, _unit_id, []), do: false

  defp fails_on?(unit_type, unit_id, status_ids) do
    any_status_active?(unit_type, unit_id, status_ids) or
      StatusStorage.last_effect(unit_type, unit_id, System.monotonic_time(:millisecond)) in status_ids
  end

  @doc """
  Magic immunity, the first step of the status defense: an unavoidable
  application and a caster no longer in the world skip it.
  """
  @spec check_defended_magic(unit_type(), integer(), StatusEntry.status_params()) ::
          :ok | {:error, :magic_immune}
  def check_defended_magic(unit_type, unit_id, status_params) do
    cond do
      Keyword.get(status_params, :no_avoid, false) -> :ok
      defense_source(unit_type, unit_id, status_params) == :gone -> :ok
      true -> check_magic_immunity(unit_type, unit_id)
    end
  end

  @doc """
  Rolls the status defense and returns the duration the status starts with:
  `nil` for a permanent or infinite status, the base tick when resistance is
  bypassed, otherwise the defended duration. An infinite start of a defended
  status is refused.
  """
  @spec roll_resistance(
          unit_type(),
          integer(),
          atom(),
          map(),
          map(),
          integer() | :infinite | nil,
          StatusEntry.status_params()
        ) :: {:ok, integer() | nil} | {:error, :resisted | :infinite_defended_status}
  def roll_resistance(
        _unit_type,
        _unit_id,
        _status_id,
        %{permanent: true},
        _entity_info,
        _duration_override,
        _params
      ),
      do: {:ok, nil}

  def roll_resistance(
        unit_type,
        unit_id,
        status_id,
        definition,
        entity_info,
        duration_override,
        status_params
      ) do
    tick = base_tick(duration_override, definition)

    cond do
      Keyword.get(status_params, :bypass_resistance, false) or
          Keyword.get(status_params, :no_avoid, false) ->
        {:ok, tick}

      is_nil(tick) and not definition.bypass_resistance and Resistance.defended?(status_id) ->
        {:error, :infinite_defended_status}

      true ->
        defend(unit_type, unit_id, status_id, definition, entity_info, tick, status_params)
    end
  end

  # An infinite start (an equipment script's endless status) keeps no expiry.
  defp base_tick(:infinite, _definition), do: nil
  defp base_tick(duration, definition), do: duration || definition.duration || 10_000

  defp defend(unit_type, unit_id, status_id, definition, entity_info, tick, status_params) do
    status = if definition.bypass_resistance, do: nil, else: status_id
    rate = status_params |> Keyword.get(:success_rate, 100) |> Kernel.*(100) |> round()
    roll = Keyword.get(status_params, :resistance_roll, &Resistance.roll_rate/1)

    result =
      case defense_source(unit_type, unit_id, status_params) do
        :gone ->
          Resistance.roll_chance(10_000, tick, roll)

        {:ok, {source_type, source_id, source_info}} ->
          if Resistance.defended?(status) do
            %{
              status: status,
              rate: rate,
              tick: tick,
              target: defense_view(unit_type, unit_id, entity_info),
              source: defense_view(source_type, source_id, source_info),
              scresist: held_val(unit_type, unit_id, :sc_scresist, :val1),
              siegfried: held_val(unit_type, unit_id, :sc_siegfried, :val2),
              res_eff: status_effect_resistance(unit_type, unit_id, entity_info, status),
              roll: roll,
              no_rate_def: Keyword.get(status_params, :no_rate_def, false),
              no_tick_def: Keyword.get(status_params, :no_tick_def, false)
            }
            |> Resistance.defend(GameMode.mode())
          else
            Resistance.roll_chance(rate, tick, roll)
          end
      end

    case result do
      {:ok, duration} -> {:ok, duration}
      :resisted -> {:error, :resisted}
    end
  end

  defp status_effect_resistance(unit_type, unit_id, entity_info, status) do
    equipment = entity_info |> Map.get(:equip_modifiers, %{}) |> Map.get({:res_eff, status}, 0)

    bonus =
      unit_type
      |> ModifierCalculator.get_all_modifiers(unit_id)
      |> Map.get({:res_eff, status}, 0)

    min(equipment + bonus, 10_000)
  end

  # The source of a status defense: the caster, or the target without one. A
  # caster that has left the world is `:gone` and defends nothing.
  defp defense_source(unit_type, unit_id, status_params) do
    case Keyword.get(status_params, :caster_id) do
      nil ->
        {:ok, {unit_type, unit_id, entity_info(unit_type, unit_id)}}

      caster_id ->
        with {:ok, source_type} <- source_type(caster_id, status_params),
             {:ok, info} <- UnitRegistry.get_unit_info(source_type, caster_id) do
          {:ok, {source_type, caster_id, info}}
        else
          _missing -> :gone
        end
    end
  end

  defp source_type(caster_id, status_params) do
    case Keyword.get(status_params, :source_type) do
      nil -> UnitRegistry.unit_type_for(caster_id)
      source_type -> {:ok, source_type}
    end
  end

  defp held_val(unit_type, unit_id, status_id, field) do
    case StatusStorage.get_status(unit_type, unit_id, status_id) do
      %StatusEntry{} = entry -> Map.get(entry, field)
      nil -> nil
    end
  end

  # The stats a defense recipe reads: effective primary stats, hard MDEF and
  # base level. A monster's stats are read from its combatant so its statuses
  # count; a player's entity info already carries its effective stats.
  defp defense_view(unit_type, unit_id, entity_info) when unit_type in [:mob, :homunculus] do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {module, state, _pid}} -> combatant_view(module.to_combatant(state))
      {:error, :not_found} -> info_view(entity_info)
    end
  end

  defp defense_view(_unit_type, _unit_id, entity_info), do: info_view(entity_info)

  defp combatant_view(combatant) do
    %{
      player?: false,
      level: combatant.progression.base_level,
      mdef: Map.get(combatant.combat_stats, :mdef) || 0
    }
    |> Map.merge(Map.new(@defense_stats, &{&1, Map.get(combatant.base_stats, &1) || 0}))
  end

  defp info_view(entity_info) do
    stats = Map.get(entity_info, :stats) || %{}
    primary = Map.get(stats, :total_stats) || stats

    %{
      player?: Map.get(entity_info, :entity_type) == :player,
      level: Map.get(stats, :base_level) || Map.get(stats, :level) || 0,
      mdef: Map.get(stats, :mdef) || 0
    }
    |> Map.merge(Map.new(@defense_stats, &{&1, Map.get(primary, &1) || 0}))
  end
end
