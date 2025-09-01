defmodule Aesir.ZoneServer.Mmo.StatusEffect.Interpreter do
  @moduledoc """
  Interprets and executes status effect definitions.

  This is the core engine that processes data-driven status effects,
  managing their lifecycle and executing their actions.

  This module has been refactored to delegate most of its functionality
  to specialized modules while maintaining backward compatibility.
  """
  require Logger

  alias Aesir.ZoneServer.Mmo.StatusEffect.ActionExecutor
  alias Aesir.ZoneServer.Mmo.StatusEffect.ContextBuilder
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusEffect.PhaseManager
  alias Aesir.ZoneServer.Mmo.StatusEffect.PropertyChecker
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Entity
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Initialize the interpreter by loading and compiling all status effect definitions.
  Handles the case where the table already exists.
  """
  @spec init() :: :ok
  def init do
    Registry.load_definitions()
  end

  @doc """
  Apply a status effect to a target.

  ## Parameters
  - unit_type: Type of unit (:player, :mob, :npc, etc.)
  - unit_id: The ID of the unit receiving the status
  - status_id: The type of status effect to apply (atom)
  - status_params: Keyword list containing status parameters

  ## Returns
  :ok | {:error, atom()}
  """
  @type unit_type :: Entity.unit_type()

  @spec apply_status(unit_type(), integer(), atom(), StatusEntry.status_params()) ::
          :ok | {:error, atom()}
  def apply_status(unit_type, unit_id, status_id, status_params \\ []) do
    case Registry.get_definition(status_id) do
      nil ->
        Logger.warning("Unknown status effect: #{status_id}")
        {:error, :unknown_status}

      definition ->
        do_apply_status(unit_type, unit_id, status_id, status_params, definition)
    end
  end

  defp do_apply_status(unit_type, unit_id, status_id, status_params, definition) do
    entity_info = get_entity_info(unit_type, unit_id)

    if PropertyChecker.check_immunity(entity_info, definition) do
      {:error, :immune}
    else
      apply_with_resistance(unit_type, unit_id, status_id, status_params, definition, entity_info)
    end
  end

  defp apply_with_resistance(
         unit_type,
         unit_id,
         status_id,
         status_params,
         definition,
         entity_info
       ) do
    base_duration = PhaseManager.calculate_base_duration(definition)

    {success_rate, adjusted_duration} =
      if Resistance.should_apply_resistance?(definition) do
        Resistance.apply_resistance(
          definition,
          entity_info[:stats] || %{},
          100,
          base_duration
        )
      else
        {100, base_duration}
      end

    if Resistance.roll_success(success_rate) do
      create_and_apply_instance(
        unit_type,
        unit_id,
        status_id,
        status_params,
        definition,
        adjusted_duration
      )
    else
      {:error, :resisted}
    end
  end

  defp create_and_apply_instance(
         unit_type,
         unit_id,
         status_id,
         status_params,
         definition,
         adjusted_duration
       ) do
    {val1, val2, val3, val4, tick, flag, caster_id, _duration, state, phase} =
      StatusEntry.extract_params(status_params)

    initial_state = Map.merge(definition[:instance_state] || %{}, state)
    initial_phase = phase || if definition[:phases], do: :wait, else: nil

    instance_data = %{
      status_id: status_id,
      val1: val1,
      val2: val2,
      val3: val3,
      val4: val4,
      tick: tick,
      flag: flag,
      caster_id: caster_id,
      initial_state: initial_state,
      initial_phase: initial_phase
    }

    instance = build_status_instance(instance_data)

    context = ContextBuilder.build_context(unit_type, unit_id, caster_id, instance)

    case ActionExecutor.execute_hooks(definition[:on_apply], unit_id, instance, context) do
      {:ok, new_instance} ->
        storage_data = %{
          unit_type: unit_type,
          unit_id: unit_id,
          status_id: status_id,
          val1: val1,
          val2: val2,
          val3: val3,
          val4: val4,
          tick: tick,
          flag: flag,
          adjusted_duration: adjusted_duration,
          caster_id: caster_id,
          new_instance: new_instance
        }

        store_status_instance(storage_data)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_status_instance(instance_data) do
    now_ms = System.monotonic_time(:millisecond)

    %StatusEntry{
      type: instance_data.status_id,
      val1: instance_data.val1,
      val2: instance_data.val2,
      val3: instance_data.val3,
      val4: instance_data.val4,
      tick: instance_data.tick,
      flag: instance_data.flag,
      source_id: instance_data.caster_id,
      state: instance_data.initial_state,
      phase: instance_data.initial_phase,
      started_at: System.system_time(:millisecond),
      next_tick_at: now_ms + if(instance_data.tick > 0, do: instance_data.tick, else: 1000),
      tick_count: 0,
      expires_at: nil
    }
  end

  defp store_status_instance(storage_data) do
    updated_params = [
      val1: storage_data.val1,
      val2: storage_data.val2,
      val3: storage_data.val3,
      val4: storage_data.val4,
      tick: storage_data.tick,
      flag: storage_data.flag,
      duration: storage_data.adjusted_duration,
      caster_id: storage_data.caster_id,
      state: storage_data.new_instance.state || %{},
      phase: storage_data.new_instance.phase
    ]

    StatusStorage.apply_status(
      storage_data.unit_type,
      storage_data.unit_id,
      storage_data.status_id,
      updated_params
    )
  end

  @doc """
  Process a tick for a status effect.
  """
  @spec process_tick(unit_type(), integer(), atom()) :: :ok
  def process_tick(unit_type, unit_id, status_id) do
    with definition when definition != nil <- Registry.get_definition(status_id),
         instance when instance != nil <- StatusStorage.get_status(unit_type, unit_id, status_id) do
      context = ContextBuilder.build_context(unit_type, unit_id, instance.source_id, instance)

      # Check for phase transitions
      instance = PhaseManager.check_phase_transition(instance, definition, context)

      # Get current phase or root definition
      current_def = PhaseManager.get_current_phase_definition(definition, instance)

      # Execute tick actions
      case ActionExecutor.execute_hooks(
             current_def[:tick][:actions],
             unit_id,
             instance,
             context
           ) do
        {:ok, new_instance} ->
          # Update the status entry with new state and phase
          StatusStorage.update_status(unit_type, unit_id, status_id, fn e ->
            %{e | state: new_instance.state || %{}, phase: new_instance.phase}
          end)

          :ok

        :remove ->
          remove_status(unit_type, unit_id, status_id)

        _ ->
          :ok
      end
    else
      _ -> :ok
    end
  end

  @doc """
  Handle damage event for status effects.
  """
  @spec on_damage(unit_type(), integer(), map()) :: :ok
  # credo:disable-for-next-line /CyclomaticComplexity|Nesting/
  def on_damage(unit_type, unit_id, damage_info) do
    # Get all active statuses for the target
    statuses = StatusStorage.get_unit_statuses(unit_type, unit_id)

    Enum.each(statuses, fn status ->
      with definition when definition != nil <- Registry.get_definition(status.type) do
        current_def = PhaseManager.get_current_phase_definition(definition, status)

        if current_def[:on_damage] do
          context = ContextBuilder.build_context(unit_type, unit_id, status.source_id, status)
          context = ContextBuilder.add_damage_info(context, damage_info)

          # on_damage can be a map with action and condition, or just actions
          on_damage_config = current_def[:on_damage]

          # Extract action and condition depending on structure
          {action, condition} =
            case on_damage_config do
              %{action: act, condition: cond} -> {act, cond}
              %{action: act} -> {act, nil}
              actions when is_list(actions) -> {actions, nil}
              _ -> {nil, nil}
            end

          # Check condition if present
          if PropertyChecker.check_condition(condition, context) do
            case action do
              :remove_self ->
                remove_status(unit_type, unit_id, status.type)

              actions when is_list(actions) ->
                # credo:disable-for-next-line Credo.Check.Refactor.Nesting
                case ActionExecutor.execute_hooks(actions, unit_id, status, context) do
                  {:ok, new_instance} ->
                    # Update state if changed
                    # credo:disable-for-next-line Credo.Check.Refactor.Nesting
                    StatusStorage.update_status(unit_type, unit_id, status.type, fn e ->
                      %{e | state: new_instance.state || %{}, phase: new_instance.phase}
                    end)

                  _ ->
                    :ok
                end

              _ ->
                :ok
            end
          end
        end
      end
    end)
  end

  @doc """
  Remove a status effect.
  """
  @spec remove_status(unit_type(), integer(), atom()) :: :ok
  def remove_status(unit_type, unit_id, status_id) do
    with definition when definition != nil <- Registry.get_definition(status_id),
         instance when instance != nil <- StatusStorage.get_status(unit_type, unit_id, status_id) do
      context = ContextBuilder.build_context(unit_type, unit_id, instance.source_id, instance)

      # Execute on_expire hooks
      ActionExecutor.execute_hooks(definition[:on_expire], unit_id, instance, context)

      # Clean up - only need to remove from StatusStorage now
      StatusStorage.remove_status(unit_type, unit_id, status_id)
    end

    :ok
  end

  @doc """
  Get calculated modifiers for all active statuses.
  """
  @spec get_all_modifiers(atom(), integer()) :: map()
  def get_all_modifiers(unit_type, unit_id) do
    ModifierCalculator.get_all_modifiers(unit_type, unit_id)
  end

  @doc """
  Execute a single action and return the new state.
  Public function for use by Conditional and other actions that need to execute nested actions.
  """
  @spec execute_single_action(map(), integer(), map(), map()) ::
          {:ok, map()} | :remove | {:error, term()}
  def execute_single_action(action, target_id, state, context) do
    ActionExecutor.execute_single_action(action, target_id, state, context)
  end

  @doc """
  Check if a status has a specific property.
  """
  @spec has_property?(atom(), atom()) :: boolean()
  def has_property?(status_id, property) do
    PropertyChecker.has_property?(status_id, property)
  end

  @doc """
  Check if a status is a debuff.
  """
  @spec debuff?(atom()) :: boolean()
  def debuff?(status_id) do
    PropertyChecker.debuff?(status_id)
  end

  @doc """
  Check if a status is a buff.
  """
  @spec buff?(atom()) :: boolean()
  def buff?(status_id) do
    PropertyChecker.buff?(status_id)
  end

  @doc """
  Check if a status prevents movement.
  """
  @spec prevents_movement?(atom()) :: boolean()
  def prevents_movement?(status_id) do
    PropertyChecker.prevents_movement?(status_id)
  end

  @doc """
  Check if a status prevents skills.
  """
  @spec prevents_skills?(atom()) :: boolean()
  def prevents_skills?(status_id) do
    PropertyChecker.prevents_skills?(status_id)
  end

  @doc """
  Check if a status prevents attacks.
  """
  @spec prevents_attack?(atom()) :: boolean()
  def prevents_attack?(status_id) do
    PropertyChecker.prevents_attack?(status_id)
  end

  @doc """
  Get all properties of a status.
  """
  @spec get_properties(atom()) :: list(atom())
  def get_properties(status_id) do
    PropertyChecker.get_properties(status_id)
  end

  # Private helper functions

  defp get_entity_info(unit_type, unit_id) do
    case UnitRegistry.get_unit_info(unit_type, unit_id) do
      {:ok, entity_info} ->
        entity_info

      {:error, :not_found} ->
        raise "Cannot apply status effect to non-existent #{unit_type} with ID: #{unit_id}"
    end
  end
end
