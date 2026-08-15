defmodule Aesir.ZoneServer.Unit.Player.Handlers.WaitingRoomHandlerTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Net.WaitingRoomChat
  alias Aesir.Net.WaitingRoomJoinResult
  alias Aesir.ZoneServer.Mmo.WaitingRoom
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Player.Handlers.WaitingRoomHandler
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

  describe "join/2" do
    test "joins, sends the roster, and records the room" do
      assert :ok = create_room()
      state = session()

      {:noreply, new_state} = WaitingRoomHandler.join(state, @room_gid)

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
      assert {:ok, _} = WaitingRoom.join(@room_gid, member(2), 50, 0)
      state = session()

      {:noreply, ^state} = WaitingRoomHandler.join(state, @room_gid)

      assert_receive {:send, :world,
                      {:waiting_room_join_result, %WaitingRoomJoinResult{result: 1}}}
    end

    test "rejects with the too-low-level code" do
      assert :ok = WaitingRoom.create(@room_gid, "W", 8, 7, "", 0, 50, 60)
      state = session(40)

      {:noreply, ^state} = WaitingRoomHandler.join(state, @room_gid)

      assert_receive {:send, :world,
                      {:waiting_room_join_result, %WaitingRoomJoinResult{result: 3}}}
    end

    test "rejects with the no-zeny code" do
      assert :ok = WaitingRoom.create(@room_gid, "W", 8, 7, "", 1000, 1, 99)
      state = session(50, 500)

      {:noreply, ^state} = WaitingRoomHandler.join(state, @room_gid)

      assert_receive {:send, :world,
                      {:waiting_room_join_result, %WaitingRoomJoinResult{result: 5}}}
    end

    test "ignores a join while already in a room" do
      assert :ok = create_room()
      state = session()

      {:noreply, joined} = WaitingRoomHandler.join(state, @room_gid)

      assert_receive {:send, :world,
                      {:waiting_room_join_result, %WaitingRoomJoinResult{result: 0}}}

      {:noreply, ^joined} = WaitingRoomHandler.join(joined, @room_gid)
      refute_receive {:send, :world, {:waiting_room_join_result, _}}
    end
  end

  describe "leave/1 and leave_if_in_room/1" do
    test "leave clears the room and removes membership" do
      assert :ok = create_room()
      state = session()

      {:noreply, joined} = WaitingRoomHandler.join(state, @room_gid)

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

      {:noreply, joined} = WaitingRoomHandler.join(state, @room_gid)

      assert_receive {:send, :world,
                      {:waiting_room_join_result, %WaitingRoomJoinResult{result: 0}}}

      {:ok, mock_pid} = MockSession.start_link(self())
      expect(UnitRegistry, :get_player_pid, 1, fn 1 -> {:ok, mock_pid} end)

      {:noreply, ^joined} = WaitingRoomHandler.chat(joined, "hello")

      assert_receive {:mock_cast_received,
                      {:send_packet, %WaitingRoomChat{room_id: @room_gid, message: "hello"}}}
    end
  end
end
