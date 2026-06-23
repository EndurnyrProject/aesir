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
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

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
  Drains SP from a player target, fire-and-forget.

  Resolves the player's session and casts the SP deduction, mirroring
  `deal_damage/3` for HP. Non-player targets are a no-op (mobs do not track SP
  for status purposes).
  """
  @spec consume_sp(Definition.target(), non_neg_integer()) :: :ok
  def consume_sp({:player, unit_id}, amount) when amount > 0 do
    case UnitRegistry.get_unit(:player, unit_id) do
      {:ok, {_module, _state, pid}} -> PlayerSession.consume_sp(pid, amount)
      {:error, :not_found} -> :ok
    end
  end

  def consume_sp(_target, _amount), do: :ok

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
