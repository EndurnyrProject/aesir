defmodule Aesir.ZoneServer.Mmo.StatusEffect.Action do
  @moduledoc """
  Behaviour for status effect actions.

  Actions are the building blocks of status effects. Each action type
  (damage, heal, modify_stat, etc.) implements this behaviour.
  """

  @doc """
  Execute the action on a target.

  ## Parameters
    - `target_id` - The ID of the target entity
    - `params` - Action-specific parameters from the status definition
    - `instance_state` - Current state of this status instance
    - `context` - Runtime context (caster info, etc.)

  ## Returns
    - `{:ok, new_state}` - Action succeeded, possibly with updated state
    - `{:error, reason}` - Action failed
    - `:remove` - This status should be removed
  """
  @callback execute(
              target_id :: integer(),
              params :: map(),
              instance_state :: map(),
              context :: map()
            ) ::
              {:ok, map()} | {:error, term()} | :remove
end
