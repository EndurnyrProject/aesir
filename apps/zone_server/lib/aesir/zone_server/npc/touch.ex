defmodule Aesir.ZoneServer.Npc.Touch do
  @moduledoc """
  The one-toucher rule of `OnTouch_` trigger areas.

  An NPC declaring `OnTouch_` is attached to at most one player at a time:
  the first eligible player to enter its area claims it and keeps it until
  leaving the area (or the map), at which point the claim passes to another
  player still inside. This module owns that claim in the public
  `:npc_touching` ETS table (`gid -> char_id`), created by
  `Aesir.ZoneServer.Npc.SessionSupervisor` next to the session flags table.

  `claim/2` is atomic (`:ets.insert_new/2`), so two sessions entering the
  same area at once cannot both win. A row whose owner is no longer a
  registered player is treated as free, so a session that died without
  releasing its claims cannot wedge the NPC for everyone else.
  """

  alias Aesir.ZoneServer.Unit.UnitRegistry

  @table :npc_touching

  @doc "The ETS table name; created by `Npc.SessionSupervisor`."
  @spec table() :: atom()
  def table, do: @table

  @doc """
  Claims `gid` for `char_id`. Returns `:ok` when the claim is now held by
  `char_id` (fresh, already held by it, or taken over from a vanished player)
  and `:taken` when another live player holds it.
  """
  @spec claim(non_neg_integer(), integer()) :: :ok | :taken
  def claim(gid, char_id) do
    if :ets.insert_new(@table, {gid, char_id}) do
      :ok
    else
      case toucher(gid) do
        ^char_id -> :ok
        nil -> claim(gid, char_id)
        other -> take_over_if_gone(gid, char_id, other)
      end
    end
  end

  @doc """
  Releases `gid` when `char_id` holds it. Returns `:released` when the row was
  dropped and `:not_owner` otherwise.
  """
  @spec release(non_neg_integer(), integer()) :: :released | :not_owner
  def release(gid, char_id) do
    case :ets.select_delete(@table, [{{gid, char_id}, [], [true]}]) do
      1 -> :released
      0 -> :not_owner
    end
  end

  @doc "The char_id attached to `gid`, or `nil` when the NPC is free."
  @spec toucher(non_neg_integer()) :: integer() | nil
  def toucher(gid) do
    case :ets.lookup(@table, gid) do
      [{^gid, char_id}] -> char_id
      [] -> nil
    end
  end

  defp take_over_if_gone(gid, char_id, owner) do
    case UnitRegistry.get_unit(:player, owner) do
      {:ok, _unit} ->
        :taken

      {:error, :not_found} ->
        release(gid, owner)
        claim(gid, char_id)
    end
  end
end
