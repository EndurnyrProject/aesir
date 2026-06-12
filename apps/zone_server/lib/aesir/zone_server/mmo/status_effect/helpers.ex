defmodule Aesir.ZoneServer.Mmo.StatusEffect.Helpers do
  @moduledoc """
  Helper functions for status effect implementations.

  Meant to be imported by modules using `Aesir.ZoneServer.Mmo.StatusEffect.Definition`,
  providing the common operations status effects perform in their callbacks:
  removing other statuses, dealing damage, and manipulating instance state.
  """

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @doc """
  Removes a status effect from the target, running its on_expire callback.
  """
  @spec remove_status(Definition.target(), atom()) :: :ok
  def remove_status({unit_type, unit_id}, status_id) do
    Interpreter.remove_status(unit_type, unit_id, status_id)
  end

  @doc """
  Removes several status effects from the target.
  """
  @spec remove_statuses(Definition.target(), [atom()]) :: :ok
  def remove_statuses(target, status_ids) do
    Enum.each(status_ids, &remove_status(target, &1))
  end

  @doc """
  Checks whether the target currently has the given status.
  """
  @spec has_status?(Definition.target(), atom()) :: boolean()
  def has_status?({unit_type, unit_id}, status_id) do
    StatusStorage.has_status?(unit_type, unit_id, status_id)
  end

  @doc """
  Deals damage to the target through the combat system.
  """
  @spec deal_damage(Definition.target(), number(), atom()) :: :ok | {:error, term()}
  def deal_damage({_unit_type, unit_id}, amount, element \\ :neutral) do
    Combat.deal_damage(unit_id, trunc(amount), element, :status_effect)
  end

  @doc """
  Returns true when the target is a player.
  """
  @spec player?(Definition.target()) :: boolean()
  def player?({:player, _unit_id}), do: true
  def player?({_unit_type, _unit_id}), do: false

  @doc """
  Puts a value in the instance state.
  """
  @spec put_state(StatusEntry.t(), atom(), term()) :: StatusEntry.t()
  def put_state(%StatusEntry{} = instance, key, value) do
    %{instance | state: Map.put(instance.state || %{}, key, value)}
  end

  @doc """
  Puts several values in the instance state.
  """
  @spec put_state(StatusEntry.t(), Enumerable.t()) :: StatusEntry.t()
  def put_state(%StatusEntry{} = instance, entries) do
    %{instance | state: Enum.into(entries, instance.state || %{})}
  end

  @doc """
  Milliseconds elapsed since the status was applied.
  """
  @spec elapsed_ms(StatusEntry.t()) :: integer()
  def elapsed_ms(%StatusEntry{started_at: started_at}) do
    System.system_time(:millisecond) - started_at
  end
end
