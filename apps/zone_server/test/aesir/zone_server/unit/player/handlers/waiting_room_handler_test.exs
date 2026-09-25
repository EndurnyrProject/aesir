defmodule Aesir.ZoneServer.Unit.Player.Handlers.WaitingRoomHandlerTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Commons.Auth
  alias Aesir.Net.MoveStop
  alias Aesir.Net.WaitingRoomChat
  alias Aesir.Net.WaitingRoomCreateResult
  alias Aesir.Net.WaitingRoomInfo
  alias Aesir.Net.WaitingRoomJoinResult
  alias Aesir.Net.WaitingRoomMemberUpdate
  alias Aesir.Net.WaitingRoomRemoved
  alias Aesir.Net.WaitingRoomRoleChanged
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.WaitingRoom
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.WaitingRoomHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule MockSession do
    use GenServer

    def start_link(test_pid), do: GenServer.start_link(__MODULE__, test_pid)

    @impl true
    def init(test_pid), do: {:ok, %{test_pid: test_pid}}

    @impl true
    def handle_cast(msg, %{test_pid: test_pid} = state) do
      send(test_pid, {:mock_cast_received, msg})
      {:noreply, state}
    end
  end

  setup :verify_on_exit!

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok
  end

  @room_gid 100

  defp session(base_level \\ 50, zeny \\ 1000) do
    game_state =
      PlayerStateFixture.build(%{
        character_id: 1,
        character_name: "TestChar",
        account_id: 10,
        map_name: "test_map",
        x: 100,
        y: 100,
        zeny: zeny,
        stats: %{progression: %{base_level: base_level, job_id: 0}}
      })

    %{game_state: game_state, connection_pid: self(), trade: nil, connection_monitor_ref: nil}
  end

  defp member(char_id) do
    %WaitingRoom.Member{char_id: char_id, account_id: char_id * 10, name: "char#{char_id}"}
  end

  defp create_room(opts \\ []) do
    WaitingRoom.create(
      Keyword.get(opts, :gid, @room_gid),
      Keyword.get(opts, :title, "W"),
      Keyword.get(opts, :limit, 8),
      Keyword.get(opts, :trigger, 7),
      Keyword.get(opts, :event_ref, ""),
      Keyword.get(opts, :zeny, 0),
      Keyword.get(opts, :min_lvl, 1),
      Keyword.get(opts, :max_lvl, 99)
    )
  end

  describe "join/3 on an NPC room" do
    test "joins, sends the roster, and records the room" do
      assert :ok = create_room()
      state = session()

      {:noreply, new_state} = WaitingRoomHandler.join(state, @room_gid, "")

      assert new_state.game_state.waiting_room == @room_gid
      assert [%{char_id: 1}] = WaitingRoom.members(@room_gid)

      assert_receive {:send, :world,
                      {:waiting_room_join_result,
                       %WaitingRoomJoinResult{
                         room_id: @room_gid,
                         result: 0,
                         members: [%{char_id: 1}]
                       }}}
    end

    test "rejects with the full code when the room is at capacity" do
      assert :ok = WaitingRoom.create(@room_gid, "W", 2, 2, "", 0, 1, 99)
      assert {:ok, _} = WaitingRoom.join(@room_gid, member(2), 50, 0, "", [])
      state = session()

      {:noreply, ^state} = WaitingRoomHandler.join(state, @room_gid, "")

      assert_receive {:send, :world,
                      {:waiting_room_join_result, %WaitingRoomJoinResult{result: 1}}}
    end

    test "rejects with the too-low-level code" do
      assert :ok = WaitingRoom.create(@room_gid, "W", 8, 7, "", 0, 50, 60)
      state = session(40)

      {:noreply, ^state} = WaitingRoomHandler.join(state, @room_gid, "")

      assert_receive {:send, :world,
                      {:waiting_room_join_result, %WaitingRoomJoinResult{result: 3}}}
    end

    test "rejects with the no-zeny code" do
      assert :ok = WaitingRoom.create(@room_gid, "W", 8, 7, "", 1000, 1, 99)
      state = session(50, 500)

      {:noreply, ^state} = WaitingRoomHandler.join(state, @room_gid, "")

      assert_receive {:send, :world,
                      {:waiting_room_join_result, %WaitingRoomJoinResult{result: 5}}}
    end

    test "ignores a join while already in a room" do
      assert :ok = create_room()
      state = session()

      {:noreply, joined} = WaitingRoomHandler.join(state, @room_gid, "")

      assert_receive {:send, :world,
                      {:waiting_room_join_result, %WaitingRoomJoinResult{result: 0}}}

      {:noreply, ^joined} = WaitingRoomHandler.join(joined, @room_gid, "")
      refute_receive {:send, :world, {:waiting_room_join_result, _}}
    end
  end

  describe "leave/1 and leave_if_in_room/1" do
    test "leave clears the room and removes membership" do
      assert :ok = create_room()
      state = session()

      {:noreply, joined} = WaitingRoomHandler.join(state, @room_gid, "")

      assert_receive {:send, :world,
                      {:waiting_room_join_result, %WaitingRoomJoinResult{result: 0}}}

      {:noreply, left} = WaitingRoomHandler.leave(joined)
      assert left.game_state.waiting_room == nil
      assert [] = WaitingRoom.members(@room_gid)
    end

    test "leave_if_in_room is a no-op when not in a room" do
      game_state = session().game_state
      assert game_state == WaitingRoomHandler.leave_if_in_room(game_state)
    end
  end

  describe "chat/2" do
    test "broadcasts to room members" do
      assert :ok = create_room()
      state = session()

      {:noreply, joined} = WaitingRoomHandler.join(state, @room_gid, "")

      assert_receive {:send, :world,
                      {:waiting_room_join_result, %WaitingRoomJoinResult{result: 0}}}

      {:ok, mock_pid} = MockSession.start_link(self())
      expect(UnitRegistry, :get_player_pid, 1, fn 1 -> {:ok, mock_pid} end)

      {:noreply, ^joined} = WaitingRoomHandler.chat(joined, "hello")

      assert_receive {:mock_cast_received,
                      {:send_packet, %WaitingRoomChat{room_id: @room_gid, message: "hello"}}}
    end
  end

  defp player(opts \\ []) do
    game_state =
      PlayerStateFixture.build(%{
        character_id: Keyword.get(opts, :char_id, 1),
        character_name: Keyword.get(opts, :name, "TestChar"),
        account_id: Keyword.get(opts, :account_id, 10),
        map_name: "test_map",
        x: 100,
        y: 100,
        zeny: 1000,
        action_state: Keyword.get(opts, :action_state, :idle),
        movement_state: Keyword.get(opts, :movement_state, :standing),
        waiting_room: Keyword.get(opts, :waiting_room),
        stats: %{
          progression: %{
            base_level: 50,
            job_id: 0,
            learned_skills: Keyword.get(opts, :learned, %{1 => 9})
          }
        }
      })

    %{
      game_state: game_state,
      connection_pid: self(),
      trade: Keyword.get(opts, :trade),
      connection_monitor_ref: nil
    }
  end

  defp register_player(char_id, map, x, y) do
    game_state = %PlayerState{character_id: char_id, map_name: map, x: x, y: y}
    UnitRegistry.register_unit(:player, char_id, PlayerState, game_state, self())
  end

  defp capture_broadcasts do
    test_pid = self()

    stub(Broadcast, :to_in_range, fn map, x, y, _range, packet ->
      send(test_pid, {:in_range, {map, x, y}, packet})
      :ok
    end)

    stub(Broadcast, :to_in_range, fn map, x, y, _range, packet, _opts ->
      send(test_pid, {:in_range, {map, x, y}, packet})
      :ok
    end)

    stub(Broadcast, :to_players, fn ids, packet ->
      send(test_pid, {:to_players, Enum.to_list(ids), packet})
      :ok
    end)

    stub(Broadcast, :to_players, fn ids, packet, _opts ->
      send(test_pid, {:to_players, Enum.to_list(ids), packet})
      :ok
    end)
  end

  describe "create/5" do
    setup do
      capture_broadcasts()
      :ok
    end

    test "refuses when in a room, trading, vending, or below NV_BASIC 4" do
      for state <- [
            player(waiting_room: 5),
            player(trade: %{partner_char_id: 2}),
            player(action_state: :vending),
            player(learned: %{1 => 3})
          ] do
        assert {:noreply, ^state} = WaitingRoomHandler.create(state, "T", "", 5, true)

        assert_receive {:send, :world,
                        {:waiting_room_create_result, %WaitingRoomCreateResult{result: 1}}}
      end
    end

    test "refuses on a nochat map" do
      stub(MapFlags, :get, fn "test_map", :nochat -> true end)
      state = player()

      assert {:noreply, ^state} = WaitingRoomHandler.create(state, "T", "", 5, true)

      assert_receive {:send, :world,
                      {:waiting_room_create_result, %WaitingRoomCreateResult{result: 1}}}
    end

    test "opens a room owned by the creator and shows it nearby" do
      {:noreply, new_state} = WaitingRoomHandler.create(player(), "Hello", "", 5, true)

      room_id = new_state.game_state.waiting_room

      assert {:ok, %WaitingRoom{owner: {:player, 1}, members: [%{char_id: 1}]}} =
               WaitingRoom.get(room_id)

      assert_receive {:send, :world,
                      {:waiting_room_create_result, %WaitingRoomCreateResult{result: 0}}}

      assert_receive {:in_range, {"test_map", 100, 100},
                      %WaitingRoomInfo{
                        room_id: ^room_id,
                        owner_gid: 1,
                        owner_is_npc: false,
                        member_count: 1
                      }}
    end

    test "stops a walking creator" do
      state = player(action_state: :moving, movement_state: :moving)

      {:noreply, new_state} = WaitingRoomHandler.create(state, "T", "", 5, true)

      assert_receive {:send, :gameplay, {:move_stop, %MoveStop{gid: 1, x: 100, y: 100}}}
      assert new_state.game_state.movement_state == :standing
      assert new_state.game_state.action_state == :idle
    end

    test "cancels a pending auto-attack even between swings" do
      timer = Process.send_after(self(), {:combat, {:auto_attack, 99}}, 60_000)
      state = player()

      state =
        put_in(state.game_state, %{
          state.game_state
          | combat_target_id: 99,
            combat_action_type: 7,
            continuous_attack_timer: timer
        })

      {:noreply, new_state} = WaitingRoomHandler.create(state, "T", "", 5, true)

      assert new_state.game_state.combat_target_id == nil
      assert new_state.game_state.continuous_attack_timer == nil
      refute Process.read_timer(timer)
    end

    test "drops an attack but keeps a cast in flight" do
      {:noreply, attacker} =
        WaitingRoomHandler.create(player(action_state: :attacking), "T", "", 5, true)

      assert attacker.game_state.action_state == :idle

      {:noreply, caster} =
        WaitingRoomHandler.create(
          player(char_id: 2, name: "Caster", action_state: :casting),
          "T",
          "",
          5,
          true
        )

      assert caster.game_state.action_state == :casting
    end
  end

  describe "join/3 on a player room" do
    setup do
      capture_broadcasts()
      owner = %WaitingRoom.Member{char_id: 2, account_id: 20, name: "Owner"}
      {:ok, room} = WaitingRoom.create_player_room(owner, "P", "secret", 5, false)
      %{room_id: room.room_id}
    end

    test "a wrong password is refused with code 2", %{room_id: room_id} do
      stub(Auth, :get_account!, fn 10 -> %{gm_level: 0} end)
      state = player()

      assert {:noreply, ^state} = WaitingRoomHandler.join(state, room_id, "nope")

      assert_receive {:send, :world,
                      {:waiting_room_join_result, %WaitingRoomJoinResult{result: 2}}}
    end

    test "the right password joins without a GM lookup", %{room_id: room_id} do
      reject(Auth, :get_account!, 1)

      {:noreply, new_state} = WaitingRoomHandler.join(player(), room_id, "secret")

      assert new_state.game_state.waiting_room == room_id

      assert_receive {:send, :world,
                      {:waiting_room_join_result,
                       %WaitingRoomJoinResult{
                         result: 0,
                         owner_gid: 2,
                         members: [%{char_id: 2}, %{char_id: 1}]
                       }}}
    end

    test "a GM at the configured level joins without the password", %{room_id: room_id} do
      stub(Auth, :get_account!, fn 10 -> %{gm_level: 60} end)

      {:noreply, new_state} = WaitingRoomHandler.join(player(), room_id, "nope")

      assert new_state.game_state.waiting_room == room_id

      assert_receive {:send, :world,
                      {:waiting_room_join_result, %WaitingRoomJoinResult{result: 0}}}
    end

    test "a joiner on another map than the owner is refused with code 1", %{room_id: room_id} do
      register_player(2, "other_map", 50, 50)
      state = player()

      assert {:noreply, ^state} = WaitingRoomHandler.join(state, room_id, "secret")

      assert_receive {:send, :world,
                      {:waiting_room_join_result, %WaitingRoomJoinResult{result: 1}}}
    end

    test "a kicked player is refused with code 6", %{room_id: room_id} do
      state = player()
      {:noreply, _joined} = WaitingRoomHandler.join(state, room_id, "secret")
      assert {:ok, _} = WaitingRoom.kick(room_id, "TestChar")

      assert {:noreply, ^state} = WaitingRoomHandler.join(state, room_id, "secret")

      assert_receive {:send, :world,
                      {:waiting_room_join_result, %WaitingRoomJoinResult{result: 6}}}
    end

    test "stops a walking joiner", %{room_id: room_id} do
      state = player(action_state: :moving, movement_state: :moving)

      {:noreply, new_state} = WaitingRoomHandler.join(state, room_id, "secret")

      assert_receive {:send, :gameplay, {:move_stop, %MoveStop{gid: 1}}}
      assert new_state.game_state.movement_state == :standing
      assert new_state.game_state.action_state == :idle
    end
  end

  describe "leave_if_in_room/1 on a player room" do
    setup do
      capture_broadcasts()
      owner = %WaitingRoom.Member{char_id: 1, account_id: 10, name: "TestChar"}
      {:ok, room} = WaitingRoom.create_player_room(owner, "P", "", 5, true)
      {:ok, _} = WaitingRoom.join(room.room_id, member(2), 50, 0, "", [])
      {:ok, _} = WaitingRoom.join(room.room_id, member(3), 50, 0, "", [])
      register_player(1, "test_map", 100, 100)
      register_player(2, "test_map", 110, 110)
      %{room_id: room.room_id}
    end

    test "a member leaving updates the others and the nearby count", %{room_id: room_id} do
      game_state = player(char_id: 3, name: "char3", waiting_room: room_id).game_state

      assert %{waiting_room: nil} = WaitingRoomHandler.leave_if_in_room(game_state)

      assert_receive {:to_players, [1, 2],
                      %WaitingRoomMemberUpdate{joined: false, kicked: false, char_id: 3}}

      assert_receive {:in_range, {"test_map", 100, 100},
                      %WaitingRoomInfo{member_count: 2, owner_gid: 1}}

      refute_received {:to_players, _, %WaitingRoomRoleChanged{}}
    end

    test "the owner leaving hands the room to the next member", %{room_id: room_id} do
      game_state = player(waiting_room: room_id).game_state

      assert %{waiting_room: nil} = WaitingRoomHandler.leave_if_in_room(game_state)

      assert_receive {:to_players, [2, 3], %WaitingRoomMemberUpdate{joined: false, char_id: 1}}

      assert_receive {:to_players, [2, 3],
                      %WaitingRoomRoleChanged{room_id: ^room_id, char_id: 2, owner: true}}

      assert_receive {:in_range, {"test_map", 100, 100}, %WaitingRoomRemoved{room_id: ^room_id}}

      assert_receive {:in_range, {"test_map", 110, 110},
                      %WaitingRoomInfo{room_id: ^room_id, owner_gid: 2, member_count: 2}}
    end

    test "the last member leaving removes the room", %{room_id: room_id} do
      assert {:ok, :left} = WaitingRoom.leave(room_id, 2)
      assert {:ok, :left} = WaitingRoom.leave(room_id, 3)
      game_state = player(waiting_room: room_id).game_state

      assert %{waiting_room: nil} = WaitingRoomHandler.leave_if_in_room(game_state)

      assert_receive {:in_range, {"test_map", 100, 100}, %WaitingRoomRemoved{room_id: ^room_id}}
      refute_received {:to_players, _, _}
      refute_received {:in_range, _, %WaitingRoomInfo{}}
      assert :error = WaitingRoom.get(room_id)
    end
  end

  describe "owner commands" do
    setup do
      capture_broadcasts()
      owner = %WaitingRoom.Member{char_id: 1, account_id: 10, name: "TestChar"}
      {:ok, room} = WaitingRoom.create_player_room(owner, "P", "", 5, true)
      {:ok, _} = WaitingRoom.join(room.room_id, member(2), 50, 0, "", [])
      {:ok, _} = WaitingRoom.join(room.room_id, member(3), 50, 0, "", [])
      register_player(1, "test_map", 100, 100)
      register_player(2, "test_map", 110, 110)

      %{
        room_id: room.room_id,
        owner: player(waiting_room: room.room_id),
        member: player(char_id: 3, name: "char3", account_id: 30, waiting_room: room.room_id)
      }
    end

    test "kick removes the member, bars them, and tells their session", ctx do
      {:ok, victim_pid} = MockSession.start_link(self())

      UnitRegistry.register_unit(
        :player,
        2,
        PlayerState,
        %PlayerState{character_id: 2},
        victim_pid
      )

      stub(Auth, :get_account!, fn 20 -> %{gm_level: 0} end)

      assert {:noreply, _} = WaitingRoomHandler.kick(ctx.owner, "char2")

      assert {:ok, room} = WaitingRoom.get(ctx.room_id)
      assert Enum.map(room.members, & &1.char_id) == [1, 3]
      assert MapSet.member?(room.kick_list, 2)

      room_id = ctx.room_id
      assert_receive {:mock_cast_received, {:waiting_room, {:kick, ^room_id}}}

      assert_receive {:to_players, [1, 3],
                      %WaitingRoomMemberUpdate{joined: false, kicked: true, char_id: 2}}

      assert_receive {:in_range, _, %WaitingRoomInfo{member_count: 2}}
    end

    test "kick changes nothing for a non-owner, an unknown name, the owner, or a GM", ctx do
      stub(Auth, :get_account!, fn 20 -> %{gm_level: 60} end)

      for {state, name} <- [
            {ctx.member, "char2"},
            {ctx.owner, "nobody"},
            {ctx.owner, "TestChar"},
            {ctx.owner, "char2"}
          ] do
        assert {:noreply, ^state} = WaitingRoomHandler.kick(state, name)
      end

      assert [1, 2, 3] = ctx.room_id |> WaitingRoom.members() |> Enum.map(& &1.char_id)
      refute_received {:to_players, _, _}
      refute_received {:in_range, _, _}
    end

    test "change_owner hands the room over and moves the bubble", ctx do
      room_id = ctx.room_id

      assert {:noreply, _} = WaitingRoomHandler.change_owner(ctx.owner, "char2")

      assert {:ok, %{owner: {:player, 2}}} = WaitingRoom.get(room_id)

      assert_receive {:to_players, _,
                      %WaitingRoomRoleChanged{room_id: ^room_id, char_id: 2, owner: true}}

      assert_receive {:to_players, _,
                      %WaitingRoomRoleChanged{room_id: ^room_id, char_id: 1, owner: false}}

      assert_receive {:in_range, {"test_map", 100, 100}, %WaitingRoomRemoved{room_id: ^room_id}}

      assert_receive {:in_range, {"test_map", 110, 110},
                      %WaitingRoomInfo{room_id: ^room_id, owner_gid: 2}}
    end

    test "change_owner does nothing for a non-owner or an unknown name", ctx do
      assert {:noreply, _} = WaitingRoomHandler.change_owner(ctx.member, "char2")
      assert {:noreply, _} = WaitingRoomHandler.change_owner(ctx.owner, "nobody")

      assert {:ok, %{owner: {:player, 1}}} = WaitingRoom.get(ctx.room_id)
      refute_received {:to_players, _, _}
      refute_received {:in_range, _, _}
    end

    test "change_status edits the room and tells members and nearby players", ctx do
      room_id = ctx.room_id

      assert {:noreply, _} =
               WaitingRoomHandler.change_status(ctx.owner, "New", "pw", 30, false)

      assert {:ok, %{title: "New", pass: "pw", limit: 20, public?: false}} =
               WaitingRoom.get(room_id)

      assert_receive {:to_players, [1, 2, 3],
                      %WaitingRoomInfo{room_id: ^room_id, title: "New", limit: 20, public: false}}

      assert_receive {:in_range, {"test_map", 100, 100},
                      %WaitingRoomInfo{room_id: ^room_id, title: "New", limit: 20, public: false}}
    end

    test "change_status does nothing for a non-owner", ctx do
      assert {:noreply, _} = WaitingRoomHandler.change_status(ctx.member, "New", "", 5, true)

      assert {:ok, %{title: "P"}} = WaitingRoom.get(ctx.room_id)
      refute_received {:to_players, _, _}
      refute_received {:in_range, _, _}
    end
  end
end
