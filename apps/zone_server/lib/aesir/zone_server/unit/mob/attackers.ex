defmodule Aesir.ZoneServer.Unit.Mob.Attackers do
  @moduledoc """
  Rolls one of the units currently attacking or casting at a player.

  The candidates are the first 30 characters within 14 cells of the player,
  taken in map block order. The roll is uniform and reads published registry
  snapshots without calling another session.
  """

  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @area 14
  @max_attackers 30
  @doc """
  Returns one random attacker of `owner` as `{:ok, typed_ref}`, or `:none` when
  nothing targets it or the owner has no position.
  """
  @spec random(%{
          required(:character_id) => integer(),
          required(:map_name) => String.t(),
          required(:x) => integer(),
          required(:y) => integer(),
          optional(atom()) => term()
        }) :: {:ok, Ref.t()} | :none
  def random(%{character_id: owner_id, map_name: map_name, x: x, y: y} = owner)
      when is_binary(map_name) and is_integer(x) and is_integer(y) do
    case scan(owner, {:player, owner_id}) do
      [] -> :none
      attackers -> {:ok, Enum.at(attackers, :rand.uniform(length(attackers)) - 1)}
    end
  end

  def random(%{character_id: _owner_id}), do: :none

  defp scan(owner, owner_ref) do
    owner.map_name
    |> SpatialIndex.units_in_area(
      owner.x - @area,
      owner.y - @area,
      owner.x + @area,
      owner.y + @area
    )
    |> Enum.reduce_while([], fn target_ref, attackers ->
      if attacker?(target_ref, owner, owner_ref),
        do: collected([target_ref | attackers]),
        else: {:cont, attackers}
    end)
    |> Enum.reverse()
  end

  defp collected(attackers) when length(attackers) >= @max_attackers, do: {:halt, attackers}
  defp collected(attackers), do: {:cont, attackers}

  defp attacker?(owner_ref, _owner, owner_ref), do: false

  defp attacker?({type, id}, owner, owner_ref) when type in [:player, :mob, :homunculus] do
    with {:ok, {_module, state, _pid}} <- UnitRegistry.get_unit(type, id),
         %{map_name: map_name, x: x, y: y} when is_integer(x) and is_integer(y) <- state do
      map_name == owner.map_name and max(abs(x - owner.x), abs(y - owner.y)) <= @area and
        UnitRegistry.targeting?(type, state, owner_ref)
    else
      _unavailable -> false
    end
  end

  defp attacker?(_target_ref, _owner, _owner_ref), do: false
end
