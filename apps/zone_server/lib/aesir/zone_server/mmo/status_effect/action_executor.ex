defmodule Aesir.ZoneServer.Mmo.StatusEffect.ActionExecutor do
  @moduledoc """
  Executes status effect actions within a given context.

  This module handles the execution of actions defined in status effects,
  such as dealing damage, healing, modifying stats, etc.

  It routes action execution to the appropriate handler modules based on
  the action type, and manages the state changes that result from actions.
  """

  alias Aesir.ZoneServer.Mmo.StatusEffect.Actions.Conditional
  alias Aesir.ZoneServer.Mmo.StatusEffect.Actions.Damage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Actions.Heal
  alias Aesir.ZoneServer.Mmo.StatusEffect.Actions.IncrementState
  alias Aesir.ZoneServer.Mmo.StatusEffect.Actions.ModifyStat
  alias Aesir.ZoneServer.Mmo.StatusEffect.Actions.NotifyClient
  alias Aesir.ZoneServer.Mmo.StatusEffect.Actions.RemoveStatus
  alias Aesir.ZoneServer.Mmo.StatusEffect.Actions.SetState

  require Logger

  @doc """
  Execute a sequence of actions for a status effect.

  ## Parameters
    - actions: List of actions to execute (or nil)
    - target_id: The ID of the target entity
    - instance: The status effect instance
    - context: The execution context
    
  ## Returns
    - {:ok, updated_instance} if successful
    - :remove if the status effect should be removed
    - {:error, reason} if an error occurs
  """
  @spec execute_hooks(list() | nil, integer(), map(), map()) ::
          {:ok, map()} | :remove | {:error, term()}
  def execute_hooks(nil, _target_id, instance, _context), do: {:ok, instance}
  def execute_hooks([], _target_id, instance, _context), do: {:ok, instance}

  def execute_hooks(actions, target_id, instance, context) when is_list(actions) do
    Enum.reduce_while(actions, {:ok, instance}, fn action, {:ok, inst} ->
      case execute_action(action, target_id, inst, context) do
        {:ok, new_inst} -> {:cont, {:ok, new_inst}}
        :remove -> {:halt, :remove}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @doc """
  Execute a single action with the given state and context.

  ## Parameters
    - action: The action to execute
    - target_id: The ID of the target entity
    - state: The current state map
    - context: The execution context
    
  ## Returns
    - {:ok, new_state} if successful
    - :remove if the status effect should be removed
    - {:error, reason} if an error occurs
  """
  @spec execute_single_action(map(), integer(), map(), map()) ::
          {:ok, map()} | :remove | {:error, term()}
  def execute_single_action(action, target_id, state, context) do
    case action_type_to_module(action[:type] || action.type) do
      {:ok, module} ->
        module.execute(target_id, action, state, context)

      {:error, :unknown_action_type} ->
        Logger.warning("Unknown action type: #{action[:type] || action.type}")
        {:ok, state}
    end
  end

  @doc """
  Execute an action and update the instance with the new state.

  ## Parameters
    - action: The action to execute
    - target_id: The ID of the target entity
    - instance: The status effect instance
    - context: The execution context
    
  ## Returns
    - {:ok, new_instance} if successful
    - :remove or {:error, reason} from execute_single_action
  """
  @spec execute_action(map(), integer(), map(), map()) ::
          {:ok, map()} | :remove | {:error, term()}
  def execute_action(action, target_id, instance, context) do
    case execute_single_action(action, target_id, instance.state || %{}, context) do
      {:ok, new_state} ->
        {:ok, Map.put(instance, :state, new_state)}

      other ->
        other
    end
  end

  @doc """
  Map an action type to its handler module.

  ## Parameters
    - action_type: The type of action (atom)
    
  ## Returns
    - {:ok, module} if the handler is found
    - {:error, :unknown_action_type} otherwise
  """
  @spec action_type_to_module(atom()) :: {:ok, module()} | {:error, :unknown_action_type}
  def action_type_to_module(:damage), do: {:ok, Damage}
  def action_type_to_module(:heal), do: {:ok, Heal}
  def action_type_to_module(:modify_stat), do: {:ok, ModifyStat}
  def action_type_to_module(:remove_status), do: {:ok, RemoveStatus}
  def action_type_to_module(:notify_client), do: {:ok, NotifyClient}
  def action_type_to_module(:set_state), do: {:ok, SetState}
  def action_type_to_module(:increment_state), do: {:ok, IncrementState}
  def action_type_to_module(:conditional), do: {:ok, Conditional}
  def action_type_to_module(_), do: {:error, :unknown_action_type}
end
