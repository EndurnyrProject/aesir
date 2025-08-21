defmodule Aesir.ZoneServer.Mmo.StatusEffect.Schema do
  @moduledoc """
  Defines and validates schemas for status effect definitions using Peri.

  This module provides comprehensive validation for status effects DSL, ensuring
  consistency and correctness of status effect definitions. Always enforces strict
  validation - raises on any validation errors and does not allow unknown fields.
  """

  import Peri
  require Logger

  # Type alias for action lists
  @type action_list :: {:either, {{:list, :map}, :map, :atom}}

  # Base action schema - strict mode, no unknown fields allowed
  defschema(
    :action,
    %{
      type: {:required, {:enum, action_types()}}
    },
    mode: :strict
  )

  # Define tick configuration schema
  defschema(
    :tick_config,
    %{
      interval: {:required, {:integer, {:gt, 0}}},
      actions: {:required, {:custom, &validate_action_list/1}}
    },
    mode: :strict
  )

  # Define status phase schema
  defschema(
    :status_phase,
    %{
      modifiers: {:map, :atom, :any},
      flags: {:list, :atom},
      duration: {:integer, {:gt, 0}},
      next: :atom,
      on_apply: {:custom, &validate_action_list/1},
      on_remove: {:custom, &validate_action_list/1},
      on_expire: {:custom, &validate_action_list/1},
      tick: {:custom, &validate_tick_config/1}
    },
    mode: :strict
  )

  # Define main status effect schema - strict mode
  defschema(
    :status_effect,
    %{
      # Core metadata fields
      properties: {:list, :atom},
      calc_flags: {:list, :atom},

      # Effect relationships
      prevented_by: {:list, :atom},
      conflicts_with: {:list, :atom},
      end_on_start: {:list, :atom},
      immunity: {:list, :atom},
      cleanse: {:list, :atom},

      # State and behavior
      modifiers: {:map, :atom, :any},
      instance_state: {:map, :atom, :any},
      flags: {:list, :atom},
      states: {:list, :atom},

      # Lifecycle hooks - all optional
      on_apply: {:custom, &validate_action_list/1},
      on_remove: {:custom, &validate_action_list/1},
      on_expire: {:custom, &validate_action_list/1},
      tick: {:custom, &validate_tick_config/1},

      # Event hooks - all optional
      on_damage: {:custom, &validate_action_list/1},
      on_damaged: {:custom, &validate_action_list/1},
      on_attack: {:custom, &validate_action_list/1},
      on_attacked: {:custom, &validate_action_list/1},
      on_move: {:custom, &validate_action_list/1},
      on_skill_cast: {:custom, &validate_action_list/1},
      on_skill_hit: {:custom, &validate_action_list/1},
      on_killed: {:custom, &validate_action_list/1},
      on_die: {:custom, &validate_action_list/1},

      # Multi-phase support
      phases: {:map, :atom, {:custom, &validate_phase/1}}
    },
    mode: :strict
  )

  # Specific action schemas - all strict mode
  defschema(
    :damage_action,
    %{
      type: {:required, {:literal, :damage}},
      formula: {:required, :string},
      element: :atom,
      min: {:integer, {:gte, 0}},
      ignore_def: :boolean
    },
    mode: :strict
  )

  defschema(
    :heal_action,
    %{
      type: {:required, {:literal, :heal}},
      formula: {:required, :string},
      min: {:integer, {:gte, 0}}
    },
    mode: :strict
  )

  defschema(
    :modify_stat_action,
    %{
      type: {:required, {:literal, :modify_stat}},
      stat: {:required, :atom},
      amount: {:required, :any}
    },
    mode: :strict
  )

  defschema(
    :remove_status_action,
    %{
      type: {:required, {:literal, :remove_status}},
      status: {:required, :any}
    },
    mode: :strict
  )

  defschema(
    :apply_status_action,
    %{
      type: {:required, {:literal, :apply_status}},
      status: {:required, :atom},
      duration: {:integer, {:gt, 0}},
      chance: {:integer, {:range, {0, 100}}}
    },
    mode: :strict
  )

  defschema(
    :notify_client_action,
    %{
      type: {:required, {:literal, :notify_client}},
      packet: {:required, :atom},
      data: :map
    },
    mode: :strict
  )

  defschema(
    :set_state_action,
    %{
      type: {:required, {:literal, :set_state}},
      key: {:required, :atom},
      value: :any
    },
    mode: :strict
  )

  defschema(
    :increment_state_action,
    %{
      type: {:required, {:literal, :increment_state}},
      key: {:required, :atom},
      amount: {:integer, {:default, 1}}
    },
    mode: :strict
  )

  defschema(
    :conditional_action,
    %{
      type: {:required, {:literal, :conditional}},
      condition: {:required, :any},
      then_actions: {:required, {:custom, &validate_action_list/1}},
      else_actions: {:custom, &validate_action_list/1}
    },
    mode: :strict
  )

  defschema(
    :force_hit_action,
    %{
      type: {:required, {:literal, :force_hit}}
    },
    mode: :strict
  )

  defschema(
    :set_damage_action,
    %{
      type: {:required, {:literal, :set_damage}},
      amount: {:required, :any}
    },
    mode: :strict
  )

  defschema(
    :modify_damage_action,
    %{
      type: {:required, {:literal, :modify_damage}},
      multiplier: :float,
      add: :integer
    },
    mode: :strict
  )

  defschema(
    :set_visual_effect_action,
    %{
      type: {:required, {:literal, :set_visual_effect}},
      effect: {:required, :atom}
    },
    mode: :strict
  )

  defschema(
    :break_equipment_action,
    %{
      type: {:required, {:literal, :break_equipment}},
      slot: {:required, :atom},
      chance: {:integer, {:range, {0, 100}}}
    },
    mode: :strict
  )

  defschema(
    :maximize_damage_action,
    %{
      type: {:required, {:literal, :maximize_damage}}
    },
    mode: :strict
  )

  defschema(
    :modify_display_damage_action,
    %{
      type: {:required, {:literal, :modify_display_damage}},
      multiplier: :float
    },
    mode: :strict
  )

  defschema(
    :reflect_damage_action,
    %{
      type: {:required, {:literal, :reflect_damage}},
      percentage: {:required, {:integer, {:range, {0, 100}}}},
      to_attacker: {:boolean, {:default, true}}
    },
    mode: :strict
  )

  defschema(
    :transfer_damage_action,
    %{
      type: {:required, {:literal, :transfer_damage}},
      percentage: {:required, {:integer, {:range, {0, 100}}}},
      target: {:required, :atom}
    },
    mode: :strict
  )

  @doc """
  Returns the list of all valid action types.
  """
  @spec action_types() :: [atom()]
  def action_types do
    [
      :damage,
      :heal,
      :modify_stat,
      :remove_status,
      :notify_client,
      :set_state,
      :increment_state,
      :conditional,
      :apply_status,
      :force_hit,
      :set_damage,
      :modify_damage,
      :set_visual_effect,
      :break_equipment,
      :maximize_damage,
      :modify_display_damage,
      :reflect_damage,
      :transfer_damage
    ]
  end

  # Custom validators

  @doc """
  Validates an action list which can be:
  - An atom (reference to another action)
  - A single action map
  - A list of action maps or atoms
  """
  @spec validate_action_list(any()) :: :ok | {:error, String.t(), keyword()}
  def validate_action_list(nil), do: :ok
  def validate_action_list(action) when is_atom(action), do: :ok

  def validate_action_list(action) when is_map(action) do
    case validate_single_action(action) do
      :ok -> :ok
      error -> error
    end
  end

  def validate_action_list(actions) when is_list(actions) do
    errors =
      actions
      |> Enum.with_index()
      |> Enum.reduce([], fn {action, index}, acc ->
        case validate_single_action_item(action) do
          :ok -> acc
          {:error, msg, ctx} -> [{index, msg, ctx} | acc]
        end
      end)

    case errors do
      [] -> :ok
      _ -> {:error, "Invalid actions in list", [errors: errors]}
    end
  end

  def validate_action_list(_) do
    {:error, "Action must be an atom, map, or list", []}
  end

  defp validate_single_action_item(action) when is_atom(action), do: :ok
  defp validate_single_action_item(action) when is_map(action), do: validate_single_action(action)
  defp validate_single_action_item(action) when is_list(action), do: validate_action_list(action)

  defp validate_single_action_item(_) do
    {:error, "Action list item must be an atom, map, or list", []}
  end

  defp validate_single_action(action) when is_map(action) do
    case Map.get(action, :type) do
      nil ->
        {:error, "Action must have a :type field", []}

      type ->
        if type in action_types() do
          # Basic validation - just check the type is valid
          :ok
        else
          {:error, "Invalid action type: #{type}", [type: type]}
        end
    end
  end

  @doc """
  Validates a tick configuration.
  """
  @spec validate_tick_config(any()) :: :ok | {:error, String.t(), keyword()}
  def validate_tick_config(nil), do: :ok

  def validate_tick_config(config) when is_map(config) do
    with :ok <- validate_tick_interval(Map.get(config, :interval)),
         :ok <- validate_action_list(Map.get(config, :actions)) do
      :ok
    end
  end

  def validate_tick_config(_) do
    {:error, "Tick config must be a map", []}
  end

  defp validate_tick_interval(nil) do
    {:error, "Tick interval is required", []}
  end

  defp validate_tick_interval(interval) when is_integer(interval) and interval > 0 do
    :ok
  end

  defp validate_tick_interval(_) do
    {:error, "Tick interval must be a positive integer", []}
  end

  @doc """
  Validates a status phase.
  """
  @spec validate_phase(any()) :: :ok | {:error, String.t(), keyword()}
  def validate_phase(phase) when is_map(phase) do
    # Just ensure it's a map for now - detailed validation can be added later
    :ok
  end

  def validate_phase(_) do
    {:error, "Phase must be a map", []}
  end

  @doc """
  Validates a status effect definition against the schema.
  Always uses strict mode and raises on any validation errors.
  Does not allow unknown fields.

  Raises `RuntimeError` if validation fails.
  """
  @spec validate(map()) :: map()
  def validate(effect) do
    # Check if effect is empty
    if map_size(effect) == 0 do
      raise "Status effect validation failed: Effect definition cannot be empty"
    end

    # First check for unknown fields
    schema = get_schema(:status_effect)
    known_fields = Map.keys(schema)
    effect_fields = Map.keys(effect)
    unknown_fields = effect_fields -- known_fields

    unless Enum.empty?(unknown_fields) do
      raise "Status effect validation failed: Unknown fields: #{inspect(unknown_fields)}"
    end

    # Then validate with Peri
    case Peri.validate(schema, effect, mode: :strict) do
      {:ok, validated} ->
        # Double check that strict mode actually filtered out any extra fields
        if Map.keys(validated) != Map.keys(effect) do
          extra = Map.keys(effect) -- Map.keys(validated)
          raise "Status effect validation failed: Unknown fields: #{inspect(extra)}"
        end

        validated

      {:error, errors} ->
        formatted_errors = format_errors(errors)
        raise "Status effect validation failed: #{formatted_errors}"
    end
  end

  @doc """
  Validates a status effect and raises if invalid.
  Alias for `validate/1` for backward compatibility.
  """
  @spec validate!(map()) :: map()
  def validate!(effect), do: validate(effect)

  @doc """
  Validates all status effects in the registry.
  Always uses strict mode and raises on any validation errors.
  """
  @spec validate_all(map()) :: map()
  def validate_all(status_effects) do
    Enum.reduce(status_effects, %{}, fn {id, effect}, acc ->
      try do
        validated = validate(effect)
        Map.put(acc, id, validated)
      rescue
        error ->
          raise "Validation failed for status effect #{id}: #{Exception.message(error)}"
      end
    end)
  end

  # Private helper functions

  defp format_errors(errors) when is_list(errors) do
    errors
    |> Enum.map_join("\n", fn
      {field, msg} -> "  #{field}: #{msg}"
      error -> "  #{inspect(error)}"
    end)
  end

  defp format_errors(error) do
    inspect(error)
  end

  @doc """
  Validates formula strings by checking for basic syntax.
  This is a custom validator that can be used with Peri.

  ## Parameters
    - `formula` - The formula string to validate
    
  ## Returns
    - `:ok` if valid
    - `{:error, message, context}` if invalid
  """
  @spec validate_formula(String.t()) :: :ok | {:error, String.t(), keyword()}
  def validate_formula(formula) when is_binary(formula) do
    # Basic validation - check for common formula patterns
    # This could be enhanced with actual formula parsing
    cond do
      String.length(formula) == 0 ->
        {:error, "Formula cannot be empty", []}

      String.contains?(formula, ["level", "base_level", "skill_level", "+"]) ->
        :ok

      true ->
        # For now, accept any non-empty string
        :ok
    end
  end

  def validate_formula(_) do
    {:error, "Formula must be a string", []}
  end

  @doc """
  Checks if a status effect conforms to the schema without raising.

  ## Parameters
    - `status_effect` - The status effect definition to check
    
  ## Returns
    - `true` if the effect conforms to the schema
    - `false` otherwise
  """
  @spec conforms?(map()) :: boolean()
  def conforms?(status_effect) do
    try do
      validate(status_effect)
      true
    rescue
      _ -> false
    end
  end
end
