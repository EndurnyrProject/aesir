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
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage

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
  """
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  @spec apply_status(
          integer(),
          atom(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer() | nil
        ) :: :ok | {:error, atom()}
  def apply_status(
        target_id,
        status_id,
        val1 \\ 0,
        val2 \\ 0,
        val3 \\ 0,
        val4 \\ 0,
        tick \\ 0,
        flag \\ 0,
        caster_id \\ nil
      ) do
    case Registry.get_definition(status_id) do
      nil ->
        Logger.warning("Unknown status effect: #{status_id}")
        {:error, :unknown_status}

      definition ->
        # Check immunities
        if PropertyChecker.check_immunity(target_id, definition) do
          {:error, :immune}
        else
          # Create initial state and phase
          initial_state = definition[:instance_state] || %{}
          initial_phase = if definition[:phases], do: :wait, else: nil

          # Create temporary instance for context building
          now_ms = System.monotonic_time(:millisecond)

          instance = %StatusEntry{
            type: status_id,
            val1: val1,
            val2: val2,
            val3: val3,
            val4: val4,
            tick: tick,
            flag: flag,
            source_id: caster_id,
            state: initial_state,
            phase: initial_phase,
            started_at: System.system_time(:millisecond),
            next_tick_at: now_ms + if(tick > 0, do: tick, else: 1000),
            tick_count: 0,
            expires_at: nil
          }

          # Build context
          context = ContextBuilder.build_context(target_id, caster_id, instance)

          # Execute on_apply hooks
          case ActionExecutor.execute_hooks(definition[:on_apply], target_id, instance, context) do
            {:ok, new_instance} ->
              # Calculate duration
              duration = PhaseManager.calculate_duration(definition, new_instance, context)

              # Store in StatusStorage with state and phase
              StatusStorage.apply_status(
                target_id,
                status_id,
                val1,
                val2,
                val3,
                val4,
                tick,
                flag,
                duration,
                caster_id,
                new_instance.state || %{},
                new_instance.phase
              )

              :ok

            {:error, reason} ->
              {:error, reason}
          end
        end
    end
  end

  @doc """
  Process a tick for a status effect.
  """
  @spec process_tick(integer(), atom()) :: :ok
  def process_tick(target_id, status_id) do
    with definition when definition != nil <- Registry.get_definition(status_id),
         instance when instance != nil <- StatusStorage.get_status(target_id, status_id) do
      context = ContextBuilder.build_context(target_id, instance.source_id, instance)

      # Check for phase transitions
      instance = PhaseManager.check_phase_transition(instance, definition, context)

      # Get current phase or root definition
      current_def = PhaseManager.get_current_phase_definition(definition, instance)

      # Execute tick actions
      case ActionExecutor.execute_hooks(
             current_def[:tick][:actions],
             target_id,
             instance,
             context
           ) do
        {:ok, new_instance} ->
          # Update the status entry with new state and phase
          StatusStorage.update_status(target_id, status_id, fn e ->
            %{e | state: new_instance.state || %{}, phase: new_instance.phase}
          end)

          :ok

        :remove ->
          remove_status(target_id, status_id)

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
  @spec on_damage(integer(), map()) :: :ok
  def on_damage(target_id, damage_info) do
    # Get all active statuses for the target
    statuses = StatusStorage.get_player_statuses(target_id)

    Enum.each(statuses, fn status ->
      with definition when definition != nil <- Registry.get_definition(status.type) do
        current_def = PhaseManager.get_current_phase_definition(definition, status)

        if current_def[:on_damage] do
          context = ContextBuilder.build_context(target_id, status.source_id, status)
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
                remove_status(target_id, status.type)

              actions when is_list(actions) ->
                case ActionExecutor.execute_hooks(actions, target_id, status, context) do
                  {:ok, new_instance} ->
                    # Update state if changed
                    StatusStorage.update_status(target_id, status.type, fn e ->
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
  @spec remove_status(integer(), atom()) :: :ok
  def remove_status(target_id, status_id) do
    with definition when definition != nil <- Registry.get_definition(status_id),
         instance when instance != nil <- StatusStorage.get_status(target_id, status_id) do
      context = ContextBuilder.build_context(target_id, instance.source_id, instance)

      # Execute on_expire hooks
      ActionExecutor.execute_hooks(definition[:on_expire], target_id, instance, context)

      # Clean up - only need to remove from StatusStorage now
      StatusStorage.remove_status(target_id, status_id)
    end

    :ok
  end

  @doc """
  Get calculated modifiers for all active statuses.
  """
  @spec get_all_modifiers(integer()) :: map()
  def get_all_modifiers(target_id) do
    ModifierCalculator.get_all_modifiers(target_id)
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
end
