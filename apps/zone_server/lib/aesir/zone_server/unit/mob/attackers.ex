defmodule Aesir.ZoneServer.Unit.Mob.Attackers do
  @moduledoc """
  Rolls one of the monsters currently targeting a player.

  The candidates are the first 30 living monsters within 14 cells of the
  player whose target is that player, taken in the map's block order; the
  roll is uniform over them. Each candidate's live state is read from its
  session within a shared time budget, so a stalled mob ends the scan early.
  """

  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @area 14
  @max_attackers 30
  @scan_budget_ms 100
  @mob_state_timeout_ms 25

  @doc """
  Returns one random attacker of `owner` as `{:ok, mob_id}`, or `:none` when
  nothing targets it or the owner has no position.
  """
  @spec random(%{
          required(:character_id) => integer(),
          required(:map_name) => String.t(),
          required(:x) => integer(),
          required(:y) => integer(),
          optional(atom()) => term()
        }) :: {:ok, integer()} | :none
  def random(%{character_id: owner_id, map_name: map_name, x: x, y: y} = owner)
      when is_binary(map_name) and is_integer(x) and is_integer(y) do
    case scan(owner, {:player, owner_id}) do
      [] -> :none
      attackers -> {:ok, Enum.at(attackers, :rand.uniform(length(attackers)) - 1)}
    end
  end

  def random(%{character_id: _owner_id}), do: :none

  defp scan(owner, owner_ref) do
    deadline = System.monotonic_time(:millisecond) + @scan_budget_ms

    owner.map_name
    |> SpatialIndex.units_in_area(
      owner.x - @area,
      owner.y - @area,
      owner.x + @area,
      owner.y + @area
    )
    |> Enum.reduce_while([], fn target_ref, attackers ->
      case attacker(target_ref, owner, owner_ref, deadline) do
        {:attacker, id} -> collected([id | attackers])
        :not_attacker -> {:cont, attackers}
        :expired -> {:halt, attackers}
      end
    end)
    |> Enum.reverse()
  end

  defp collected(attackers) when length(attackers) >= @max_attackers, do: {:halt, attackers}
  defp collected(attackers), do: {:cont, attackers}

  defp attacker({:mob, id}, owner, owner_ref, deadline) do
    with {:ok, {MobState, _snapshot, pid}} when is_pid(pid) <- UnitRegistry.get_unit(:mob, id),
         {:ok, %MobState{} = mob} <- live_state(pid, deadline),
         true <- mob.instance_id == id,
         true <- Unit.living?(mob),
         true <- mob.map_name == owner.map_name,
         true <- mob.target_ref == owner_ref,
         true <- max(abs(mob.x - owner.x), abs(mob.y - owner.y)) <= @area do
      {:attacker, id}
    else
      :expired -> :expired
      _other -> :not_attacker
    end
  end

  defp attacker(_target_ref, _owner, _owner_ref, _deadline), do: :not_attacker

  defp live_state(pid, deadline) do
    remaining_ms = deadline - System.monotonic_time(:millisecond)

    if remaining_ms > 0 do
      {:ok, GenServer.call(pid, :get_state, min(remaining_ms, @mob_state_timeout_ms))}
    else
      :expired
    end
  catch
    :exit, _reason ->
      if System.monotonic_time(:millisecond) >= deadline,
        do: :expired,
        else: {:error, :mob_unavailable}
  end
end
