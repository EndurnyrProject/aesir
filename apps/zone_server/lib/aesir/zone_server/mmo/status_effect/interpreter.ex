defmodule Aesir.ZoneServer.Mmo.StatusEffect.Interpreter do
  @moduledoc """
  Interprets and executes status effect definitions.

  This is the core engine that processes data-driven status effects,
  managing their lifecycle and executing their actions.
  """
  require Logger

  alias Aesir.ZoneServer.Mmo.StatusEffect.Actions.Conditional
  alias Aesir.ZoneServer.Mmo.StatusEffect.Actions.Damage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Actions.Heal
  alias Aesir.ZoneServer.Mmo.StatusEffect.Actions.IncrementState
  alias Aesir.ZoneServer.Mmo.StatusEffect.Actions.ModifyStat
  alias Aesir.ZoneServer.Mmo.StatusEffect.Actions.NotifyClient
  alias Aesir.ZoneServer.Mmo.StatusEffect.Actions.RemoveStatus
  alias Aesir.ZoneServer.Mmo.StatusEffect.Actions.SetState
  alias Aesir.ZoneServer.Mmo.StatusEffect.FormulaCompiler
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @compiled_effects :status_effect_definitions

  @doc """
  Initialize the interpreter by loading and compiling all status effect definitions.
  """
  def init do
    :ets.new(@compiled_effects, [:set, :public, :named_table])
    load_definitions()
    :ok
  end

  @doc """
  Apply a status effect to a target.
  """
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
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
    case get_compiled_definition(status_id) do
      nil ->
        Logger.warning("Unknown status effect: #{status_id}")
        {:error, :unknown_status}

      definition ->
        # Check immunities
        if check_immunity(target_id, definition) do
          {:error, :immune}
        else
          # Create initial state and phase
          initial_state = definition[:instance_state] || %{}
          initial_phase = if definition[:phases], do: :wait, else: nil

          # Create temporary instance for context building
          instance = %{
            type: status_id,
            val1: val1,
            val2: val2,
            val3: val3,
            val4: val4,
            tick: tick,
            flag: flag,
            caster_id: caster_id,
            state: initial_state,
            phase: initial_phase,
            started_at: System.system_time(:millisecond)
          }

          # Build context
          context = build_context(target_id, caster_id, instance)

          # Execute on_apply hooks
          # credo:disable-for-next-line Credo.Check.Refactor.Nesting
          case execute_hooks(definition[:on_apply], target_id, instance, context) do
            {:ok, new_instance} ->
              # Calculate duration
              duration = calculate_duration(definition, new_instance, context)

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
                new_instance[:state] || %{},
                new_instance[:phase]
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
  def process_tick(target_id, status_id) do
    with definition when definition != nil <- get_compiled_definition(status_id),
         instance when instance != nil <- StatusStorage.get_status(target_id, status_id) do
      context = build_context(target_id, instance.source_id, instance)

      # Check for phase transitions
      instance = check_phase_transition(instance, definition, context)

      # Get current phase or root definition
      current_def = get_current_phase_definition(definition, instance)

      # Execute tick actions
      case execute_hooks(current_def[:tick][:actions], target_id, instance, context) do
        {:ok, new_instance} ->
          # Update the status entry with new state and phase
          StatusStorage.update_status(target_id, status_id, fn e ->
            %{e | state: new_instance[:state] || %{}, phase: new_instance[:phase]}
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
  # credo:disable-for-lines:2 Credo.Check.Refactor.CyclomaticComplexity
  def on_damage(target_id, damage_info) do
    # Get all active statuses for the target
    statuses = StatusStorage.get_player_statuses(target_id)

    Enum.each(statuses, fn status ->
      with definition when definition != nil <- get_compiled_definition(status.type) do
        current_def = get_current_phase_definition(definition, status)

        if current_def[:on_damage] do
          context = build_context(target_id, status.source_id, status)
          context = Map.put(context, :damage_info, damage_info)

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
          if check_condition(condition, context) do
            case action do
              :remove_self ->
                remove_status(target_id, status.type)

              actions when is_list(actions) ->
                # credo:disable-for-next-line Credo.Check.Refactor.Nesting
                case execute_hooks(actions, target_id, status, context) do
                  {:ok, new_instance} ->
                    # Update state if changed
                    # credo:disable-for-next-line Credo.Check.Refactor.Nesting
                    StatusStorage.update_status(target_id, status.type, fn e ->
                      %{e | state: new_instance[:state] || %{}, phase: new_instance[:phase]}
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
  def remove_status(target_id, status_id) do
    with definition when definition != nil <- get_compiled_definition(status_id),
         instance when instance != nil <- StatusStorage.get_status(target_id, status_id) do
      context = build_context(target_id, instance.source_id, instance)

      # Execute on_expire hooks
      execute_hooks(definition[:on_expire], target_id, instance, context)

      # Clean up - only need to remove from StatusStorage now
      StatusStorage.remove_status(target_id, status_id)
    end

    :ok
  end

  @doc """
  Get calculated modifiers for all active statuses.
  """
  def get_all_modifiers(target_id) do
    statuses = StatusStorage.get_player_statuses(target_id)

    Enum.reduce(statuses, %{}, fn status, acc ->
      case get_compiled_definition(status.type) do
        definition when definition != nil ->
          current_def = get_current_phase_definition(definition, status)
          modifiers = current_def[:modifiers] || %{}

          # Compile and evaluate dynamic modifiers
          # credo:disable-for-next-line Credo.Check.Refactor.Nesting
          compiled_modifiers =
            Enum.map(modifiers, fn {key, value} ->
              # credo:disable-for-next-line Credo.Check.Refactor.Nesting
              case value do
                formula when is_binary(formula) ->
                  context = build_context(target_id, status.source_id, status)
                  compiled_fn = FormulaCompiler.compile(formula)
                  {key, compiled_fn.(context)}

                static_value ->
                  {key, static_value}
              end
            end)
            |> Map.new()

          merge_modifiers(acc, compiled_modifiers)

        _ ->
          acc
      end
    end)
  end

  defp load_definitions do
    path = Path.join(:code.priv_dir(:zone_server), "db/re/status_effects.exs")

    case File.read(path) do
      {:ok, content} ->
        {definitions, _} = Code.eval_string(content)

        Enum.each(definitions, fn {id, definition} ->
          compiled = compile_definition(definition)
          :ets.insert(@compiled_effects, {id, compiled})
        end)

        Logger.info("Loaded #{map_size(definitions)} status effect definitions")

      {:error, reason} ->
        Logger.error("Failed to load status definitions: #{inspect(reason)}")
    end
  end

  defp compile_definition(definition) do
    definition
    |> compile_hooks()
    |> compile_phases()
  end

  defp compile_hooks(definition) do
    Enum.reduce([:on_apply, :on_expire, :on_damage, :on_damaged], definition, fn hook, def ->
      case def[hook] do
        nil ->
          def

        # Special handling for on_damage which can have action/condition structure
        %{action: _} = _damage_config when hook == :on_damage ->
          # Don't compile on_damage with action/condition structure
          def

        actions ->
          Map.put(def, hook, compile_actions(actions))
      end
    end)
    |> compile_tick_hooks()
  end

  defp compile_tick_hooks(definition) do
    case definition[:tick] do
      nil ->
        definition

      tick_def ->
        Map.put(definition, :tick, %{
          interval: tick_def[:interval] || 1000,
          actions: compile_actions(tick_def[:actions] || [])
        })
    end
  end

  defp compile_phases(definition) do
    case definition[:phases] do
      nil ->
        definition

      phases ->
        compiled_phases =
          Enum.map(phases, fn {phase_id, phase_def} ->
            compiled_phase =
              phase_def
              |> Map.put(:modifiers, phase_def[:modifiers] || %{})
              |> compile_hooks()

            {phase_id, compiled_phase}
          end)
          |> Map.new()

        Map.put(definition, :phases, compiled_phases)
    end
  end

  defp compile_actions(actions) when is_list(actions) do
    Enum.map(actions, &compile_action/1)
  end

  defp compile_actions(action), do: [compile_action(action)]

  defp compile_action(%{type: :conditional} = action) do
    %{
      type: :conditional,
      condition: FormulaCompiler.compile(action[:if] || action[:condition]),
      then_actions: compile_actions(action[:then] || []),
      else_actions: compile_actions(action[:else] || [])
    }
  end

  defp compile_action(%{formula: formula} = action) when is_binary(formula) do
    Map.put(action, :formula_fn, FormulaCompiler.compile(formula))
  end

  defp compile_action(action), do: action

  defp get_compiled_definition(status_id) do
    case :ets.lookup(@compiled_effects, status_id) do
      [{_, definition}] -> definition
      [] -> nil
    end
  end

  defp build_context(target_id, caster_id, instance) do
    # TODO: Get actual player stats from PlayerSession
    target_stats = %{
      max_hp: 1000,
      max_sp: 100,
      hp: 800,
      sp: 80,
      level: 50,
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10
    }

    caster_stats =
      if caster_id do
        # TODO: Get caster stats
        target_stats
      else
        %{}
      end

    %{
      # Include IDs for custom functions to access
      target_id: target_id,
      caster_id: caster_id,
      # Stats for formula calculations
      target: target_stats,
      caster: caster_stats,
      state: instance[:state] || %{},
      val1: instance[:val1] || 0,
      val2: instance[:val2] || 0,
      val3: instance[:val3] || 0,
      val4: instance[:val4] || 0
    }
  end

  defp check_immunity(_target_id, definition) do
    # TODO: Check target properties against immunity list
    _ = definition[:immunity]
    false
  end

  defp check_condition(nil, _context), do: true

  defp check_condition(%{element: element}, context) do
    context[:damage_info][:element] == element
  end

  defp check_condition(condition_fn, context) when is_function(condition_fn) do
    condition_fn.(context) != 0
  end

  defp check_condition(_, _), do: true

  defp calculate_duration(definition, instance, context) do
    case definition[:duration] do
      nil ->
        instance[:tick] || 0

      formula when is_binary(formula) ->
        compiled_fn = FormulaCompiler.compile(formula)
        trunc(compiled_fn.(context))

      duration ->
        duration
    end
  end

  defp check_phase_transition(instance, definition, _context) do
    case {instance[:phase], definition[:phases]} do
      {nil, _} ->
        instance

      {_, nil} ->
        instance

      {current_phase, phases} ->
        current_def = phases[current_phase]

        # credo:disable-for-next-line Credo.Check.Refactor.Nesting
        if current_def[:duration] do
          elapsed = System.system_time(:millisecond) - instance[:started_at]

          # credo:disable-for-next-line Credo.Check.Refactor.Nesting
          if elapsed >= current_def[:duration] && current_def[:next] do
            Map.put(instance, :phase, current_def[:next])
          else
            instance
          end
        else
          instance
        end
    end
  end

  defp get_current_phase_definition(definition, instance) do
    case {instance[:phase], definition[:phases]} do
      {nil, _} -> definition
      {_, nil} -> definition
      {phase, phases} -> Map.merge(definition, phases[phase] || %{})
    end
  end

  defp execute_hooks(nil, _target_id, instance, _context), do: {:ok, instance}
  defp execute_hooks([], _target_id, instance, _context), do: {:ok, instance}

  defp execute_hooks(actions, target_id, instance, context) when is_list(actions) do
    Enum.reduce_while(actions, {:ok, instance}, fn action, {:ok, inst} ->
      case execute_action(action, target_id, inst, context) do
        {:ok, new_inst} -> {:cont, {:ok, new_inst}}
        :remove -> {:halt, :remove}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @doc """
  Execute a single action and return the new state.
  Public function for use by Conditional and other actions that need to execute nested actions.
  """
  def execute_single_action(action, target_id, state, context) do
    case action_type_to_module(action[:type] || action.type) do
      {:ok, module} ->
        module.execute(target_id, action, state, context)

      {:error, :unknown_action_type} ->
        Logger.warning("Unknown action type: #{action[:type] || action.type}")
        {:ok, state}
    end
  end

  defp execute_action(action, target_id, instance, context) do
    case execute_single_action(action, target_id, instance[:state] || %{}, context) do
      {:ok, new_state} ->
        {:ok, Map.put(instance, :state, new_state)}

      other ->
        other
    end
  end

  defp action_type_to_module(:damage), do: {:ok, Damage}
  defp action_type_to_module(:heal), do: {:ok, Heal}
  defp action_type_to_module(:modify_stat), do: {:ok, ModifyStat}
  defp action_type_to_module(:remove_status), do: {:ok, RemoveStatus}
  defp action_type_to_module(:notify_client), do: {:ok, NotifyClient}
  defp action_type_to_module(:set_state), do: {:ok, SetState}
  defp action_type_to_module(:increment_state), do: {:ok, IncrementState}
  defp action_type_to_module(:conditional), do: {:ok, Conditional}
  defp action_type_to_module(_), do: {:error, :unknown_action_type}

  defp merge_modifiers(base, new) do
    Map.merge(base, new, fn _key, v1, v2 ->
      v1 + v2
    end)
  end

  @doc """
  Check if a status has a specific property.
  """
  def has_property?(status_id, property) do
    case get_compiled_definition(status_id) do
      %{properties: props} when is_list(props) -> property in props
      _ -> false
    end
  end

  @doc """
  Check if a status is a debuff.
  """
  def debuff?(status_id) do
    has_property?(status_id, :debuff)
  end

  @doc """
  Check if a status is a buff.
  """
  def buff?(status_id) do
    not debuff?(status_id)
  end

  @doc """
  Check if a status prevents movement.
  """
  def prevents_movement?(status_id) do
    has_property?(status_id, :prevents_movement)
  end

  @doc """
  Check if a status prevents skills.
  """
  def prevents_skills?(status_id) do
    has_property?(status_id, :prevents_skills)
  end

  @doc """
  Check if a status prevents attacks.
  """
  def prevents_attack?(status_id) do
    has_property?(status_id, :prevents_attack)
  end

  @doc """
  Get all properties of a status.
  """
  def get_properties(status_id) do
    case get_compiled_definition(status_id) do
      %{properties: props} when is_list(props) -> props
      _ -> []
    end
  end
end
