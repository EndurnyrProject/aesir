defmodule Aesir.ZoneServer.Unit.Resource do
  @moduledoc """
  Asynchronous resource effects for live units.
  """

  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @typedoc "A live unit type that supports resource effects."
  @type resource_unit :: :player | :mob

  @doc """
  Drains a percentage of a live unit's maximum SP through its owning session.

  Fractional SP is truncated toward zero.
  """
  @spec drain_sp_percent(resource_unit(), non_neg_integer(), non_neg_integer()) :: :ok
  def drain_sp_percent(unit_type, unit_id, percentage)
      when unit_type in [:player, :mob] and is_integer(unit_id) and unit_id >= 0 and
             is_integer(percentage) and percentage >= 0 do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {_module, state, pid}} when is_pid(pid) ->
        drain_sp(unit_type, state, pid, percentage_amount(unit_type, state, percentage))

      _ ->
        :ok
    end
  end

  @doc "Drains a fixed amount of SP from a live unit through its owning session."
  @spec drain_sp(resource_unit(), non_neg_integer(), non_neg_integer()) :: :ok
  def drain_sp(unit_type, unit_id, amount)
      when unit_type in [:player, :mob] and is_integer(unit_id) and unit_id >= 0 and
             is_integer(amount) and amount >= 0 do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {_module, state, pid}} when is_pid(pid) -> drain_sp(unit_type, state, pid, amount)
      _ -> :ok
    end
  end

  defp percentage_amount(:player, %{stats: %{derived_stats: %{max_sp: max_sp}}}, percentage)
       when is_integer(max_sp) and max_sp >= 0,
       do: div(max_sp * percentage, 100)

  defp percentage_amount(:mob, %{max_sp: max_sp}, percentage)
       when is_integer(max_sp) and max_sp >= 0,
       do: div(max_sp * percentage, 100)

  defp percentage_amount(_unit_type, _state, _percentage), do: 0

  defp drain_sp(:player, state, pid, amount) do
    if Unit.living?(state), do: PlayerSession.consume_sp(pid, amount)
    :ok
  end

  defp drain_sp(:mob, state, pid, amount) do
    if Unit.living?(state), do: MobSession.zap_sp(pid, amount)
    :ok
  end
end
