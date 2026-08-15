defmodule Aesir.ZoneServer.Unit.Player.Handlers.WaitingRoomHandler do
  @moduledoc """
  Player-session handlers for NPC waiting rooms: joining, leaving, and chatting
  in the room an NPC opens above its head so players can gather.

  Joins and leaves mutate `PlayerState.waiting_room` (a single-writer field) and
  the shared `Mmo.WaitingRoom` store, which is the cross-player source of truth
  for membership. Roster and member counts are always read from the store, never
  reconstructed from per-player state. The warp and disconnect paths call
  `leave_if_in_room/1` so a player who leaves the world by any route is removed
  from their room and their co-members are notified.
  """

  alias Aesir.Net.WaitingRoomChat
  alias Aesir.Net.WaitingRoomInfo
  alias Aesir.Net.WaitingRoomJoinResult
  alias Aesir.Net.WaitingRoomMember
  alias Aesir.Net.WaitingRoomMemberUpdate
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.WaitingRoom
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Npc.Events, as: NpcEvents
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StateCommit

  @type session_state :: SessionState.t()

  @spec join(session_state(), non_neg_integer()) :: {:noreply, session_state()}
  def join(%{game_state: %PlayerState{waiting_room: room_id}} = state, _room_id)
      when not is_nil(room_id),
      do: {:noreply, state}

  def join(%{game_state: game_state, connection_pid: pid, trade: trade} = state, room_id) do
    if trade != nil or game_state.action_state == :vending do
      {:noreply, state}
    else
      do_join(state, pid, game_state, room_id)
    end
  end

  defp do_join(state, pid, game_state, room_id) do
    member = member(game_state)
    base_level = game_state.stats.progression.base_level

    case WaitingRoom.join(room_id, member, base_level, game_state.zeny) do
      {:ok, room} ->
        MessageRouter.send_to(pid, join_ok(room_id, room))

        broadcast_member_update(room_id, member,
          joined: true,
          kicked: false,
          exclude_id: game_state.character_id
        )

        broadcast_room_info(room_id)
        maybe_fire_event(room)

        {:noreply, StateCommit.commit(state, %{game_state | waiting_room: room_id})}

      {:error, reason} ->
        MessageRouter.send_to(pid, join_fail(room_id, reason))
        {:noreply, state}
    end
  end

  defp maybe_fire_event(%WaitingRoom{} = room) do
    if WaitingRoom.fire_event?(room), do: NpcEvents.trigger(room.event_ref)
  end

  @spec leave(session_state()) :: {:noreply, session_state()}
  def leave(%{game_state: game_state} = state) do
    {:noreply, StateCommit.commit(state, leave_if_in_room(game_state))}
  end

  @spec chat(session_state(), String.t()) :: {:noreply, session_state()}
  def chat(%{game_state: %PlayerState{waiting_room: nil}} = state, _message),
    do: {:noreply, state}

  def chat(
        %{game_state: %PlayerState{waiting_room: room_id} = game_state} = state,
        message
      ) do
    packet = %WaitingRoomChat{
      room_id: room_id,
      char_id: game_state.character_id,
      name: game_state.character_name,
      message: message
    }

    Broadcast.to_players(member_char_ids(room_id), packet)
    {:noreply, state}
  end

  @doc """
  Removes the player from their waiting room, returning the player state with
  `waiting_room` cleared. A no-op when the player is in no room.

  This is the shared cleanup hook the warp and disconnect paths call, so a
  player who leaves the world by any route is removed from their room and their
  co-members are notified.
  """
  @spec leave_if_in_room(PlayerState.t()) :: PlayerState.t()
  def leave_if_in_room(%PlayerState{waiting_room: nil} = game_state), do: game_state

  def leave_if_in_room(%PlayerState{waiting_room: room_id} = game_state) do
    WaitingRoom.leave(room_id, game_state.character_id)
    broadcast_member_update(room_id, member(game_state), joined: false, kicked: false)
    broadcast_room_info(room_id)
    %{game_state | waiting_room: nil}
  end

  defp member(game_state) do
    %WaitingRoom.Member{
      char_id: game_state.character_id,
      account_id: game_state.account_id,
      name: game_state.character_name
    }
  end

  defp join_ok(room_id, room) do
    %WaitingRoomJoinResult{
      room_id: room_id,
      result: 0,
      members: Enum.map(room.members, &%WaitingRoomMember{char_id: &1.char_id, name: &1.name})
    }
  end

  defp join_fail(room_id, reason) do
    %WaitingRoomJoinResult{room_id: room_id, result: failure_code(reason)}
  end

  defp failure_code(:full), do: 1
  defp failure_code(:not_found), do: 1
  defp failure_code(:too_low_level), do: 3
  defp failure_code(:too_high_level), do: 4
  defp failure_code(:no_zeny), do: 5
  defp failure_code(_other), do: 1

  defp broadcast_member_update(room_id, member, opts) do
    packet = %WaitingRoomMemberUpdate{
      room_id: room_id,
      joined: Keyword.fetch!(opts, :joined),
      kicked: Keyword.fetch!(opts, :kicked),
      char_id: member.char_id,
      name: member.name
    }

    Broadcast.to_players(
      member_char_ids(room_id),
      packet,
      exclude_id: Keyword.get(opts, :exclude_id)
    )
  end

  defp broadcast_room_info(room_id) do
    with {:ok, room} <- WaitingRoom.get(room_id),
         {:ok, {_module, placement}} <- NpcRegistry.module_for_unit(room_id) do
      packet = %WaitingRoomInfo{
        room_id: room_id,
        title: room.title,
        member_count: length(room.members),
        limit: room.limit,
        public: true
      }

      Broadcast.to_in_range(placement.map, placement.x, placement.y, Config.view_range(), packet)
    else
      _not_found -> :ok
    end
  end

  defp member_char_ids(room_id) do
    room_id |> WaitingRoom.members() |> Enum.map(& &1.char_id)
  end
end
