defmodule Aesir.ZoneServer.Unit.Resource do
  @moduledoc """
  Typed resource reads and asynchronous effects for live units.

  Homunculi require typed references. Aggregate-local callers build a local
  effect and apply it through the owning Homunculus handler instead of sending
  to their own session process.
  """

  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @typedoc "A live unit type that supports resource effects."
  @type resource_unit :: :player | :mob | :homunculus
  @type resource :: :hp | :sp

  @doc "Reads current HP or SP from the typed registry snapshot."
  @spec read(Ref.t(), resource()) :: {:ok, non_neg_integer()} | {:error, :not_found}
  def read({unit_type, unit_id} = ref, resource) when resource in [:hp, :sp] do
    if Ref.valid?(ref) and unit_type in [:player, :mob, :homunculus] do
      case UnitRegistry.get_unit(unit_type, unit_id) do
        {:ok, {_module, state, _pid}} -> read_state(state, resource)
        {:error, :not_found} -> {:error, :not_found}
      end
    else
      {:error, :not_found}
    end
  end

  @doc "Drains a percentage of maximum SP through the owning session."
  @spec drain_sp_percent(resource_unit(), non_neg_integer(), non_neg_integer()) :: :ok
  def drain_sp_percent(unit_type, unit_id, percentage)
      when unit_type in [:player, :mob] and is_integer(unit_id) and unit_id >= 0 and
             is_integer(percentage) and percentage >= 0 do
    drain_sp_percent({unit_type, unit_id}, percentage)
  end

  @doc "Drains a percentage of maximum SP through a typed unit reference."
  @spec drain_sp_percent(Ref.t(), non_neg_integer()) :: :ok
  def drain_sp_percent({unit_type, unit_id} = ref, percentage)
      when is_integer(percentage) and percentage >= 0 do
    if Ref.valid?(ref) and unit_type in [:player, :mob, :homunculus] do
      case UnitRegistry.get_unit(unit_type, unit_id) do
        {:ok, {_module, state, pid}} when is_pid(pid) ->
          drain_sp(ref, state, pid, percentage_amount(unit_type, state, percentage))

        _ ->
          :ok
      end
    else
      :ok
    end
  end

  @doc "Drains fixed SP through the owning session."
  @spec drain_sp(resource_unit(), non_neg_integer(), non_neg_integer()) :: :ok
  def drain_sp(unit_type, unit_id, amount)
      when unit_type in [:player, :mob] and is_integer(unit_id) and unit_id >= 0 and
             is_integer(amount) and amount >= 0 do
    drain_sp({unit_type, unit_id}, amount)
  end

  @doc "Drains fixed SP through a typed unit reference."
  @spec drain_sp(Ref.t(), non_neg_integer()) :: :ok
  def drain_sp({unit_type, unit_id} = ref, amount) when is_integer(amount) and amount >= 0 do
    if Ref.valid?(ref) and unit_type in [:player, :mob, :homunculus] do
      case UnitRegistry.get_unit(unit_type, unit_id) do
        {:ok, {_module, state, pid}} when is_pid(pid) -> drain_sp(ref, state, pid, amount)
        _ -> :ok
      end
    else
      :ok
    end
  end

  @doc "Builds an aggregate-local Homunculus SP drain effect."
  @spec local_sp_drain_effect(Ref.t(), non_neg_integer()) :: tuple()
  def local_sp_drain_effect({:homunculus, world_gid} = ref, amount)
      when is_integer(amount) and amount >= 0 do
    if Ref.valid?(ref) do
      {:homunculus, {:drain_sp, world_gid, amount}}
    else
      raise ArgumentError, "invalid Homunculus resource reference"
    end
  end

  defp read_state(%{stats: %{current_state: current}}, resource),
    do: Map.fetch(current, resource)

  defp read_state(state, resource) do
    case Map.fetch(state, resource) do
      {:ok, value} when is_integer(value) and value >= 0 -> {:ok, value}
      _ -> {:error, :not_found}
    end
  end

  defp percentage_amount(:player, %{stats: %{derived_stats: %{max_sp: max_sp}}}, percentage)
       when is_integer(max_sp) and max_sp >= 0,
       do: div(max_sp * percentage, 100)

  defp percentage_amount(unit_type, %{max_sp: max_sp}, percentage)
       when unit_type in [:mob, :homunculus] and is_integer(max_sp) and max_sp >= 0,
       do: div(max_sp * percentage, 100)

  defp percentage_amount(_unit_type, _state, _percentage), do: 0

  defp drain_sp({:player, _unit_id}, state, pid, amount) do
    if Unit.living?(state), do: PlayerSession.consume_sp(pid, amount)
    :ok
  end

  defp drain_sp({:mob, _unit_id}, state, pid, amount) do
    if Unit.living?(state), do: MobSession.zap_sp(pid, amount)
    :ok
  end

  defp drain_sp({:homunculus, world_gid}, state, pid, amount) do
    if Unit.living?(state) do
      if pid == self() do
        raise ArgumentError, "aggregate-local Homunculus drain must use local_sp_drain_effect/2"
      end

      GenServer.cast(pid, {:homunculus, {:drain_sp, world_gid, amount}})
    end

    :ok
  end
end
