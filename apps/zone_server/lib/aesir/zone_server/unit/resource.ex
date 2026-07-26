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
      {:ok, {_module, state, pid}} when is_pid(pid) -> drain(unit_type, state, pid, percentage)
      _ -> :ok
    end
  end

  defp drain(:player, %{stats: %{derived_stats: %{max_sp: max_sp}}} = state, pid, percentage)
       when is_integer(max_sp) and max_sp >= 0 do
    if Unit.living?(state), do: PlayerSession.consume_sp(pid, div(max_sp * percentage, 100))
    :ok
  end

  defp drain(:mob, %{max_sp: max_sp} = state, pid, percentage)
       when is_integer(max_sp) and max_sp >= 0 do
    if Unit.living?(state), do: MobSession.zap_sp(pid, div(max_sp * percentage, 100))
    :ok
  end

  defp drain(_unit_type, _state, _pid, _percentage), do: :ok
end
