defmodule Aesir.ZoneServer.Script.WaitingRoomDslTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.WaitingRoom
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Script.Vars
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule TestNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 100, y: 100, dir: 0, sprite: 58, name: "Waiting Room Test"}]

    @impl true
    def on_talk(ctx), do: ctx
  end

  setup :verify_on_exit!

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok
  end

  @npc_gid 100

  defp ctx, do: Ctx.detached(TestNpc, @npc_gid)

  defp member(char_id) do
    %WaitingRoom.Member{char_id: char_id, account_id: char_id * 10, name: "char#{char_id}"}
  end

  describe "waitingroom/3" do
    test "creates a room for the calling NPC" do
      assert %Ctx{} = Dsl.waitingroom(ctx(), "Waiting", 8, event_ref: "B::OnStart", trigger: 7)

      assert {:ok, %WaitingRoom{title: "Waiting", limit: 8, trigger: 7, event_ref: "B::OnStart"}} =
               WaitingRoom.get(@npc_gid)
    end
  end

  describe "delwaitingroom/1" do
    test "deletes the calling NPC's room" do
      assert %Ctx{} = Dsl.waitingroom(ctx(), "W", 8, [])
      assert {:ok, _} = WaitingRoom.get(@npc_gid)

      assert %Ctx{} = Dsl.delwaitingroom(ctx())
      assert :error = WaitingRoom.get(@npc_gid)
    end
  end

  describe "enablewaitingroomevent/1 and disablewaitingroomevent/1" do
    test "toggle the event flag" do
      assert %Ctx{} = Dsl.waitingroom(ctx(), "W", 8, event_ref: "B::OnStart", trigger: 7)

      assert %Ctx{} = Dsl.disablewaitingroomevent(ctx())
      assert {:ok, %WaitingRoom{enabled?: false}} = WaitingRoom.get(@npc_gid)

      assert %Ctx{} = Dsl.enablewaitingroomevent(ctx())
      assert {:ok, %WaitingRoom{enabled?: true}} = WaitingRoom.get(@npc_gid)
    end
  end

  describe "warpwaitingpc/4" do
    test "warps the longest-waiting members and writes the $@ vars" do
      assert %Ctx{} = Dsl.waitingroom(ctx(), "W", 8, event_ref: "", trigger: 2)

      assert {:ok, _} = WaitingRoom.join(@npc_gid, member(1), 50, 0)
      assert {:ok, _} = WaitingRoom.join(@npc_gid, member(2), 50, 0)
      assert {:ok, _} = WaitingRoom.join(@npc_gid, member(3), 50, 0)

      for char_id <- [1, 2] do
        expect(UnitRegistry, :get_player_pid, 1, fn ^char_id -> {:ok, self()} end)
      end

      expect(PlayerSession, :warp_with_fee, 2, fn _pid, map, x, y, zeny ->
        send(self(), {:warped, map, x, y, zeny})
        :ok
      end)

      assert %Ctx{} = Dsl.warpwaitingpc(ctx(), "pvp", 10, 10, nil)

      assert_receive {:warped, "pvp", 10, 10, 0}
      assert_receive {:warped, "pvp", 10, 10, 0}
      refute_receive {:warped, _, _, _, _}

      assert [10, 20] = Vars.get_server_temp("warpwaitingpc", nil)
      assert 2 = Vars.get_server_temp("warpwaitingpcnum", nil)
    end
  end

  describe "kickwaitingroomall/1" do
    test "empties the calling NPC's room" do
      assert %Ctx{} = Dsl.waitingroom(ctx(), "W", 8, [])
      assert {:ok, _} = WaitingRoom.join(@npc_gid, member(1), 50, 0)
      assert {:ok, _} = WaitingRoom.join(@npc_gid, member(2), 50, 0)

      assert %Ctx{} = Dsl.kickwaitingroomall(ctx())
      assert [] = WaitingRoom.members(@npc_gid)
    end
  end

  describe "getwaitingroomusers/1" do
    test "populates the local account-id vars" do
      assert %Ctx{} = Dsl.waitingroom(ctx(), "W", 8, [])
      assert {:ok, _} = WaitingRoom.join(@npc_gid, member(1), 50, 0)
      assert {:ok, _} = WaitingRoom.join(@npc_gid, member(2), 50, 0)

      result = Dsl.getwaitingroomusers(ctx())

      assert Dsl.get_local(result, :waitingroom_users) == [10, 20]
      assert Dsl.get_local(result, :waitingroom_usercount) == 2
    end
  end

  describe "binding cleanup on NPC-initiated removal" do
    test "delwaitingroom casts to clear an online member's binding" do
      assert %Ctx{} = Dsl.waitingroom(ctx(), "W", 8, [])
      assert {:ok, _} = WaitingRoom.join(@npc_gid, member(1), 50, 0)

      expect(UnitRegistry, :get_player_pid, 1, fn 1 -> {:ok, self()} end)

      expect(PlayerSession, :kick_from_waiting_room, 1, fn _pid, room_gid ->
        send(self(), {:kicked, room_gid})
        :ok
      end)

      assert %Ctx{} = Dsl.delwaitingroom(ctx())
      assert_receive {:kicked, @npc_gid}
    end

    test "kickwaitingroomall casts to clear every online member's binding" do
      assert %Ctx{} = Dsl.waitingroom(ctx(), "W", 8, [])
      assert {:ok, _} = WaitingRoom.join(@npc_gid, member(1), 50, 0)
      assert {:ok, _} = WaitingRoom.join(@npc_gid, member(2), 50, 0)

      expect(UnitRegistry, :get_player_pid, 2, fn _char_id -> {:ok, self()} end)

      expect(PlayerSession, :kick_from_waiting_room, 2, fn _pid, room_gid ->
        send(self(), {:kicked, room_gid})
        :ok
      end)

      assert %Ctx{} = Dsl.kickwaitingroomall(ctx())
      assert_receive {:kicked, @npc_gid}
      assert_receive {:kicked, @npc_gid}
    end
  end
end
