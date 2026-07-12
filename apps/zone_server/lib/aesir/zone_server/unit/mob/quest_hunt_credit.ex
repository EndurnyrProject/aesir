defmodule Aesir.ZoneServer.Unit.Mob.QuestHuntCredit do
  @moduledoc """
  Fans a mob kill out to the sessions that may credit it against a hunting
  quest, mirroring rAthena's `mob.cpp:3576` dispatch into
  `quest_update_objective_sub` (`quest.cpp:729`).

  Recipients are the solo killer, or -- when the killer is in a party --
  every party member currently online on the mob's map within `AREA_SIZE`
  (14) cells (Chebyshev) of the kill cell. rAthena filters party hunt credit
  on party id, map, and range only: there is deliberately **no alive/HP
  filter** (a dead-but-in-range member still gets the tick), and the killer is
  naturally included exactly once via the same range scan, never double-counted.

  This module never touches quest state itself: each recipient gets a
  `{:quest_kill, mob_id}` message on its own `player:<char_id>` topic and its
  `PlayerSession` decides whether any of its quests care.
  """

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Phoenix.PubSub

  @area_size 14

  @doc """
  Broadcasts `{:quest_kill, mob_id}` to every session eligible to credit the
  kill of `mob_id` at `{mob_x, mob_y}` on `mob_map`.

  With no party (or a killer no longer in the registry) only the killer is
  credited; otherwise the killer's live party co-members in range on the map
  are, with the killer among them. `attacker_id` is never `nil` here --
  `MobSession.announce_kill/2` guards that case before calling.
  """
  @spec credit(non_neg_integer(), non_neg_integer(), String.t(), {integer(), integer()}) :: :ok
  def credit(attacker_id, mob_id, mob_map, {mob_x, mob_y}) do
    attacker_id
    |> recipients(mob_map, {mob_x, mob_y})
    |> Enum.each(fn char_id ->
      PubSub.broadcast(Aesir.PubSub, "player:#{char_id}", {:quest_kill, mob_id})
    end)
  end

  @spec recipients(non_neg_integer(), String.t(), {integer(), integer()}) ::
          [non_neg_integer()]
  defp recipients(attacker_id, mob_map, kill_cell) do
    case UnitRegistry.get_unit(:player, attacker_id) do
      {:ok, {_module, %{party_id: party_id}, _pid}} when party_id > 0 ->
        party_recipients(attacker_id, party_id, mob_map, kill_cell)

      _ ->
        [attacker_id]
    end
  end

  @spec party_recipients(
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          {integer(), integer()}
        ) :: [non_neg_integer()]
  defp party_recipients(attacker_id, party_id, mob_map, kill_cell) do
    case PartyManager.get(party_id) do
      {:ok, %PartyState{members: members}} ->
        members
        |> Map.keys()
        |> Enum.filter(&in_range?(&1, mob_map, kill_cell))

      {:error, _reason} ->
        [attacker_id]
    end
  end

  @spec in_range?(non_neg_integer(), String.t(), {integer(), integer()}) :: boolean()
  defp in_range?(char_id, mob_map, {mob_x, mob_y}) do
    case UnitRegistry.get_unit(:player, char_id) do
      {:ok, {_module, %{map_name: ^mob_map, x: x, y: y}, _pid}} ->
        Geometry.chebyshev_distance(mob_x, mob_y, x, y) <= @area_size

      _ ->
        false
    end
  end
end
