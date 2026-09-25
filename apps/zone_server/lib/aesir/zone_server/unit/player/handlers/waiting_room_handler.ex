defmodule Aesir.ZoneServer.Unit.Player.Handlers.WaitingRoomHandler do
  @moduledoc """
  Player-session handlers for chat rooms, the bubbles an NPC or a player opens
  above their head so players can gather: creating a player room, joining any
  room (with a password for private player rooms), leaving, and chatting.

  Joins, creates, and leaves mutate `PlayerState.waiting_room` (a single-writer
  field) and the shared `Mmo.WaitingRoom` store, which is the cross-player source
  of truth for membership and ownership. Roster and member counts are always read
  from the store, never reconstructed from per-player state.

  The room bubble is drawn at the owner's position: the NPC placement for NPC
  rooms, the owning player's live position for player rooms. When a player owner
  leaves, the leaver's session announces the succession (or the room's removal)
  from the store's single compare-and-swap result, so no other session is called.
  The warp and disconnect paths call `leave_if_in_room/1`, so every exit route
  runs the same succession and cleanup.
  """

  alias Aesir.Commons.Auth
  alias Aesir.Net.WaitingRoomChat
  alias Aesir.Net.WaitingRoomCreateResult
  alias Aesir.Net.WaitingRoomInfo
  alias Aesir.Net.WaitingRoomJoinResult
  alias Aesir.Net.WaitingRoomMember
  alias Aesir.Net.WaitingRoomMemberUpdate
  alias Aesir.Net.WaitingRoomRemoved
  alias Aesir.Net.WaitingRoomRoleChanged
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Skills.Novice.NvBasic
  alias Aesir.ZoneServer.Mmo.WaitingRoom
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Npc.Events, as: NpcEvents
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @type session_state :: SessionState.t()

  # Action states a create or join interrupts: walking and attacking stop, a
  # cast in flight is left alone.
  @settle_states [:attacking, :combat_moving, :moving, :skill_moving, :moving_to_item]

  @doc """
  Opens a player chat room owned by the caller. Refused (create result 1) when
  the player is already in a room, trading, vending, below NV_BASIC 4, or on a
  `nochat` map. On success the player stops walking and attacking, becomes the
  owner and sole member, and nearby players see the bubble.
  """
  @spec create(session_state(), String.t(), String.t(), non_neg_integer(), boolean()) ::
          {:noreply, session_state()}
  def create(%{connection_pid: pid} = state, title, pass, limit, public?) do
    if can_create?(state) do
      %{game_state: game_state} = state = settle(state)

      {:ok, room} =
        WaitingRoom.create_player_room(member(game_state), title, pass, limit, public?)

      MessageRouter.send_to(pid, %WaitingRoomCreateResult{result: 0})

      Broadcast.to_in_range(
        game_state.map_name,
        game_state.x,
        game_state.y,
        Config.view_range(),
        info_packet(room)
      )

      {:noreply, StateCommit.commit(state, %{game_state | waiting_room: room.room_id})}
    else
      MessageRouter.send_to(pid, %WaitingRoomCreateResult{result: 1})
      {:noreply, state}
    end
  end

  defp can_create?(%{game_state: game_state, trade: trade}) do
    game_state.waiting_room == nil and trade == nil and game_state.action_state != :vending and
      NvBasic.allows_action?(game_state.stats.progression.learned_skills, :chat_room) == :ok and
      not MapFlags.get(game_state.map_name, :nochat)
  end

  @doc """
  Joins the room `room_id` with `pass` (only checked for private rooms). A GM at
  or above `Config.chat_room_gm_level/0` joins a private room without the right
  password. Refused when the owner is on another map. On success the player
  stops walking and attacking and receives the roster.
  """
  @spec join(session_state(), non_neg_integer(), String.t()) :: {:noreply, session_state()}
  def join(%{game_state: %PlayerState{waiting_room: room_id}} = state, _room_id, _pass)
      when not is_nil(room_id),
      do: {:noreply, state}

  def join(%{game_state: game_state, trade: trade} = state, room_id, pass) do
    if trade != nil or game_state.action_state == :vending do
      {:noreply, state}
    else
      do_join(state, room_id, pass)
    end
  end

  defp do_join(%{game_state: game_state, connection_pid: pid} = state, room_id, pass) do
    member = member(game_state)

    with :ok <- ensure_same_map(room_id, game_state.map_name),
         {:ok, room} <- join_store(room_id, member, game_state, pass) do
      %{game_state: game_state} = state = settle(state)
      MessageRouter.send_to(pid, join_ok(room))

      broadcast_member_update(room_id, member,
        joined: true,
        kicked: false,
        exclude_id: game_state.character_id
      )

      broadcast_room_info(room_id)
      maybe_fire_event(room)

      {:noreply, StateCommit.commit(state, %{game_state | waiting_room: room_id})}
    else
      {:error, reason} ->
        MessageRouter.send_to(pid, join_fail(room_id, reason))
        {:noreply, state}
    end
  end

  defp ensure_same_map(room_id, map_name) do
    with {:ok, room} <- WaitingRoom.get(room_id),
         {:ok, {owner_map, _x, _y}} when owner_map != map_name <- owner_position(room) do
      {:error, :full}
    else
      _ -> :ok
    end
  end

  defp join_store(room_id, member, game_state, pass) do
    base_level = game_state.stats.progression.base_level

    case WaitingRoom.join(room_id, member, base_level, game_state.zeny, pass, []) do
      {:error, :wrong_password} = error ->
        if gm_privileged?(game_state.account_id),
          do:
            WaitingRoom.join(room_id, member, base_level, game_state.zeny, pass,
              bypass_password: true
            ),
          else: error

      result ->
        result
    end
  end

  defp gm_privileged?(account_id),
    do: Auth.get_account!(account_id).gm_level >= Config.chat_room_gm_level()

  defp maybe_fire_event(%WaitingRoom{} = room) do
    if WaitingRoom.fire_event?(room), do: NpcEvents.trigger(room.event_ref)
  end

  # Stops a walk (MoveStop to self and nearby) and drops an attack, including a
  # repeat attack waiting on its next swing, as creating or joining a room does;
  # a cast in flight keeps running.
  defp settle(state) do
    {:noreply, %{game_state: game_state} = state} =
      MovementHandler.handle_force_stop_movement(state)

    game_state = PlayerState.clear_combat_intent(game_state)
    state = %{state | game_state: game_state}

    if game_state.action_state in @settle_states do
      {:ok, idle} = PlayerState.transition_to(game_state, :idle)
      %{state | game_state: idle}
    else
      state
    end
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
  Removes the player from their chat room, returning the player state with
  `waiting_room` cleared. A no-op when the player is in no room.

  Announces from the store's result: a plain leave updates the members and the
  nearby count; a player owner leaving hands the room to the next member (role
  update to members, bubble moved from the leaver to the new owner); the last
  member leaving a player room removes its bubble.

  This is the shared cleanup hook the warp and disconnect paths call, so a
  player who leaves the world by any route is removed from their room.
  """
  @spec leave_if_in_room(PlayerState.t()) :: PlayerState.t()
  def leave_if_in_room(%PlayerState{waiting_room: nil} = game_state), do: game_state

  def leave_if_in_room(%PlayerState{waiting_room: room_id} = game_state) do
    case WaitingRoom.leave(room_id, game_state.character_id) do
      {:ok, :left} ->
        broadcast_member_update(room_id, member(game_state), joined: false, kicked: false)
        broadcast_room_info(room_id)

      {:ok, {:owner_changed, next}} ->
        broadcast_member_update(room_id, member(game_state), joined: false, kicked: false)

        Broadcast.to_players(member_char_ids(room_id), %WaitingRoomRoleChanged{
          room_id: room_id,
          char_id: next.char_id,
          owner: true
        })

        broadcast_room_removed_at(game_state.map_name, game_state.x, game_state.y, room_id)
        broadcast_room_info(room_id)

      {:ok, :destroyed} ->
        broadcast_room_removed_at(game_state.map_name, game_state.x, game_state.y, room_id)

      :error ->
        :ok
    end

    %{game_state | waiting_room: nil}
  end

  @doc """
  Kicks the member named `name` from the caller's player room, barring them from
  rejoining. Ignored unless the caller owns the room; the owner cannot kick
  themselves, and GMs at or above `Config.chat_room_gm_level/0` are immune. The
  store is updated here, then the victim's session is told to clear its binding.
  """
  @spec kick(session_state(), String.t()) :: {:noreply, session_state()}
  def kick(%{game_state: %PlayerState{waiting_room: room_id} = game_state} = state, name)
      when not is_nil(room_id) and name != game_state.character_name do
    with {:ok, room} <- WaitingRoom.get(room_id),
         true <- WaitingRoom.owner?(room, game_state.character_id),
         %WaitingRoom.Member{} = target <- Enum.find(room.members, &(&1.name == name)),
         false <- gm_privileged?(target.account_id),
         {:ok, kicked} <- WaitingRoom.kick(room_id, name) do
      with {:ok, pid} <- UnitRegistry.get_player_pid(kicked.char_id),
           do: PlayerSession.kick_from_waiting_room(pid, room_id)

      broadcast_member_update(room_id, kicked, joined: false, kicked: true)
      broadcast_room_info(room_id)
    end

    {:noreply, state}
  end

  def kick(state, _name), do: {:noreply, state}

  @doc """
  Hands the caller's player room to the member named `name`. Ignored unless the
  caller owns the room and `name` is another member. Members are told both role
  changes, and the bubble moves from the caller to the new owner.
  """
  @spec change_owner(session_state(), String.t()) :: {:noreply, session_state()}
  def change_owner(%{game_state: %PlayerState{waiting_room: room_id} = game_state} = state, name)
      when not is_nil(room_id) do
    with {:ok, room} <- WaitingRoom.change_owner(room_id, game_state.character_id, name) do
      ids = Enum.map(room.members, & &1.char_id)
      {:player, new_owner} = room.owner

      Broadcast.to_players(ids, %WaitingRoomRoleChanged{
        room_id: room_id,
        char_id: new_owner,
        owner: true
      })

      Broadcast.to_players(ids, %WaitingRoomRoleChanged{
        room_id: room_id,
        char_id: game_state.character_id,
        owner: false
      })

      broadcast_room_removed_at(game_state.map_name, game_state.x, game_state.y, room_id)
      broadcast_room_info(room_id)
    end

    {:noreply, state}
  end

  def change_owner(state, _name), do: {:noreply, state}

  @doc """
  Edits the caller's player room (title, password, limit, public flag), with the
  same truncation and clamping as creation. Ignored unless the caller owns the
  room. Members and nearby players receive the updated room info.
  """
  @spec change_status(session_state(), String.t(), String.t(), non_neg_integer(), boolean()) ::
          {:noreply, session_state()}
  def change_status(
        %{game_state: %PlayerState{waiting_room: room_id} = game_state} = state,
        title,
        pass,
        limit,
        public?
      )
      when not is_nil(room_id) do
    with {:ok, room} <-
           WaitingRoom.change_status(
             room_id,
             game_state.character_id,
             title,
             pass,
             limit,
             public?
           ) do
      packet = info_packet(room)
      Broadcast.to_players(Enum.map(room.members, & &1.char_id), packet)

      Broadcast.to_in_range(
        game_state.map_name,
        game_state.x,
        game_state.y,
        Config.view_range(),
        packet
      )
    end

    {:noreply, state}
  end

  def change_status(state, _title, _pass, _limit, _public?), do: {:noreply, state}

  @doc """
  Clears the player's room binding when they are kicked or the room is deleted,
  notifying the player. The room itself was already updated in the shared store
  by the caller, so this only fixes this player's single-writer field. A
  binding that no longer matches `room_id` (the player already left) is left
  untouched.
  """
  @spec handle_kick(session_state(), non_neg_integer()) :: {:noreply, session_state()}
  def handle_kick(
        %{game_state: %PlayerState{waiting_room: room_id} = game_state} = state,
        room_id
      ) do
    MessageRouter.send_to(state.connection_pid, kick_packet(room_id, game_state))
    {:noreply, StateCommit.commit(state, %{game_state | waiting_room: nil})}
  end

  def handle_kick(%{game_state: %PlayerState{}} = state, _room_id), do: {:noreply, state}

  @doc "Builds the `WaitingRoomInfo` bubble packet for `room`, naming its owner."
  @spec info_packet(WaitingRoom.t()) :: WaitingRoomInfo.t()
  def info_packet(%WaitingRoom{} = room) do
    %WaitingRoomInfo{
      room_id: room.room_id,
      title: room.title,
      member_count: length(room.members),
      limit: room.limit,
      public: room.public?,
      owner_gid: owner_gid(room),
      owner_is_npc: match?({:npc, _}, room.owner)
    }
  end

  @doc """
  Resolves where `room`'s bubble is anchored: the NPC placement for NPC rooms,
  the owning player's current position for player rooms. `:error` when the
  owner is not in the world.
  """
  @spec owner_position(WaitingRoom.t()) :: {:ok, {String.t(), integer(), integer()}} | :error
  def owner_position(%WaitingRoom{owner: {:npc, gid}}) do
    case NpcRegistry.module_for_unit(gid) do
      {:ok, {_module, placement}} -> {:ok, {placement.map, placement.x, placement.y}}
      :error -> :error
    end
  end

  def owner_position(%WaitingRoom{owner: {:player, char_id}}) do
    case UnitRegistry.get_unit(:player, char_id) do
      {:ok, {_module, owner_state, _pid}} ->
        {:ok, {owner_state.map_name, owner_state.x, owner_state.y}}

      {:error, :not_found} ->
        :error
    end
  end

  defp owner_gid(%WaitingRoom{owner: {_kind, id}}), do: id

  defp kick_packet(room_id, game_state) do
    %WaitingRoomMemberUpdate{
      room_id: room_id,
      joined: false,
      kicked: true,
      char_id: game_state.character_id,
      name: game_state.character_name
    }
  end

  defp member(game_state) do
    %WaitingRoom.Member{
      char_id: game_state.character_id,
      account_id: game_state.account_id,
      name: game_state.character_name
    }
  end

  defp join_ok(room) do
    %WaitingRoomJoinResult{
      room_id: room.room_id,
      result: 0,
      members: Enum.map(room.members, &%WaitingRoomMember{char_id: &1.char_id, name: &1.name}),
      owner_gid: owner_gid(room)
    }
  end

  defp join_fail(room_id, reason) do
    %WaitingRoomJoinResult{room_id: room_id, result: failure_code(reason)}
  end

  defp failure_code(:full), do: 1
  defp failure_code(:not_found), do: 1
  defp failure_code(:wrong_password), do: 2
  defp failure_code(:too_low_level), do: 3
  defp failure_code(:too_high_level), do: 4
  defp failure_code(:no_zeny), do: 5
  defp failure_code(:kicked), do: 6

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
         {:ok, {map, x, y}} <- owner_position(room) do
      Broadcast.to_in_range(map, x, y, Config.view_range(), info_packet(room))
    else
      _not_found -> :ok
    end
  end

  defp broadcast_room_removed_at(map, x, y, room_id) do
    Broadcast.to_in_range(map, x, y, Config.view_range(), %WaitingRoomRemoved{room_id: room_id})
  end

  defp member_char_ids(room_id) do
    room_id |> WaitingRoom.members() |> Enum.map(& &1.char_id)
  end
end
