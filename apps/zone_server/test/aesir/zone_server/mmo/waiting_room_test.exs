defmodule Aesir.ZoneServer.Mmo.WaitingRoomTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.WaitingRoom
  alias Aesir.ZoneServer.Mmo.WaitingRoom.Member

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok
  end

  defp create_room(opts \\ []) do
    WaitingRoom.create(
      Keyword.get(opts, :npc_gid, 100),
      Keyword.get(opts, :title, "Waiting"),
      Keyword.get(opts, :limit, 8),
      Keyword.get(opts, :trigger, 7),
      Keyword.get(opts, :event_ref, "Bouncer::OnStart"),
      Keyword.get(opts, :zeny, 0),
      Keyword.get(opts, :min_lvl, 1),
      Keyword.get(opts, :max_lvl, 99)
    )
  end

  defp member(char_id) do
    %Member{char_id: char_id, account_id: char_id * 10, name: "char#{char_id}"}
  end

  describe "create/8" do
    test "creates a room and rejects a duplicate" do
      assert :ok = create_room()
      assert {:error, :already_exists} = create_room()
    end

    test "stores an NPC-owned, public, passwordless room keyed by the NPC gid" do
      assert :ok = create_room()

      assert {:ok,
              %WaitingRoom{
                room_id: 100,
                owner: {:npc, 100},
                public?: true,
                pass: "",
                kick_list: kick_list
              }} = WaitingRoom.get(100)

      assert MapSet.size(kick_list) == 0
    end
  end

  describe "create_player_room/5" do
    test "allocates a player room id with the creator as owner and sole member" do
      assert {:ok, room} = WaitingRoom.create_player_room(member(1), "Hi", "pw", 5, false)

      assert room.room_id >= 0x5800_0000
      assert room.owner == {:player, 1}
      assert room.members == [member(1)]
      assert room.pass == "pw"
      refute room.public?
      assert {:ok, ^room} = WaitingRoom.get(room.room_id)
    end

    test "two creates get distinct ids" do
      assert {:ok, %{room_id: a}} = WaitingRoom.create_player_room(member(1), "A", "", 5, true)
      assert {:ok, %{room_id: b}} = WaitingRoom.create_player_room(member(2), "B", "", 5, true)
      assert a != b
    end

    test "clamps the limit to 1..20 and truncates title and password" do
      title = String.duplicate("t", 70)
      pass = String.duplicate("p", 12)

      assert {:ok, big} = WaitingRoom.create_player_room(member(1), title, pass, 25, false)
      assert big.limit == 20
      assert big.title == String.duplicate("t", 60)
      assert big.pass == String.duplicate("p", 8)

      assert {:ok, small} = WaitingRoom.create_player_room(member(2), "S", "", 0, true)
      assert small.limit == 1
    end

    test "never splits a multi-byte character when truncating" do
      title = String.duplicate("é", 31)

      assert {:ok, room} = WaitingRoom.create_player_room(member(1), title, "", 5, true)
      assert room.title == String.duplicate("é", 30)
      assert String.valid?(room.title)
    end
  end

  describe "occupancy/1" do
    test "counts the NPC for NPC rooms and only members for player rooms" do
      assert :ok = WaitingRoom.create(100, "W", 3, 3, "", 0, 1, 99)
      assert {:ok, npc_room} = WaitingRoom.get(100)
      assert WaitingRoom.occupancy(npc_room) == 1

      assert {:ok, _} = WaitingRoom.join(100, member(1), 50, 0, "", [])
      assert {:ok, _} = WaitingRoom.join(100, member(2), 50, 0, "", [])
      assert {:error, :full} = WaitingRoom.join(100, member(3), 50, 0, "", [])

      assert {:ok, room} = WaitingRoom.create_player_room(member(10), "P", "", 3, true)
      assert WaitingRoom.occupancy(room) == 1
      assert {:ok, _} = WaitingRoom.join(room.room_id, member(11), 50, 0, "", [])
      assert {:ok, full} = WaitingRoom.join(room.room_id, member(12), 50, 0, "", [])
      assert WaitingRoom.occupancy(full) == 3
      assert {:error, :full} = WaitingRoom.join(room.room_id, member(13), 50, 0, "", [])
    end
  end

  describe "join/6 password and kick list" do
    setup do
      {:ok, room} = WaitingRoom.create_player_room(member(1), "P", "secret", 3, false)
      %{room_id: room.room_id}
    end

    test "full wins over wrong password", %{room_id: room_id} do
      assert {:ok, _} = WaitingRoom.join(room_id, member(2), 50, 0, "secret", [])
      assert {:ok, _} = WaitingRoom.join(room_id, member(3), 50, 0, "secret", [])
      assert {:error, :full} = WaitingRoom.join(room_id, member(4), 50, 0, "nope", [])
    end

    test "wrong password is rejected unless bypassed", %{room_id: room_id} do
      assert {:error, :wrong_password} = WaitingRoom.join(room_id, member(2), 50, 0, "nope", [])

      assert {:ok, _} =
               WaitingRoom.join(room_id, member(2), 50, 0, "nope", bypass_password: true)
    end

    test "a public room ignores the password" do
      {:ok, room} = WaitingRoom.create_player_room(member(5), "Pub", "secret", 3, true)
      assert {:ok, _} = WaitingRoom.join(room.room_id, member(6), 50, 0, "nope", [])
    end

    test "kicked is reported only after every other check passes", %{room_id: room_id} do
      assert {:ok, _} = WaitingRoom.join(room_id, member(2), 50, 0, "secret", [])
      assert {:ok, _} = WaitingRoom.kick(room_id, "char2")

      assert {:error, :wrong_password} = WaitingRoom.join(room_id, member(2), 50, 0, "nope", [])
      assert {:error, :kicked} = WaitingRoom.join(room_id, member(2), 50, 0, "secret", [])
    end
  end

  describe "join/6 precedence on an NPC room" do
    test "full wins over level gates" do
      assert :ok = WaitingRoom.create(100, "W", 2, 2, "", 0, 50, 60)
      assert {:ok, _} = WaitingRoom.join(100, member(1), 55, 0, "", [])
      assert {:error, :full} = WaitingRoom.join(100, member(2), 10, 0, "", [])
    end
  end

  describe "leave/2 on a player room" do
    setup do
      {:ok, room} = WaitingRoom.create_player_room(member(1), "P", "", 5, true)
      {:ok, _} = WaitingRoom.join(room.room_id, member(2), 50, 0, "", [])
      {:ok, _} = WaitingRoom.join(room.room_id, member(3), 50, 0, "", [])
      %{room_id: room.room_id}
    end

    test "a non-owner leaving reports :left", %{room_id: room_id} do
      assert {:ok, :left} = WaitingRoom.leave(room_id, 3)

      assert {:ok, %{owner: {:player, 1}, members: [%{char_id: 1}, %{char_id: 2}]}} =
               WaitingRoom.get(room_id)
    end

    test "the owner leaving passes ownership to the next member", %{room_id: room_id} do
      assert {:ok, {:owner_changed, %Member{char_id: 2}}} = WaitingRoom.leave(room_id, 1)

      assert {:ok, %{owner: {:player, 2}, members: [%{char_id: 2} | _]}} =
               WaitingRoom.get(room_id)
    end

    test "the last member leaving destroys the room", %{room_id: room_id} do
      assert {:ok, :left} = WaitingRoom.leave(room_id, 3)
      assert {:ok, :left} = WaitingRoom.leave(room_id, 2)
      assert {:ok, :destroyed} = WaitingRoom.leave(room_id, 1)
      assert :error = WaitingRoom.get(room_id)
    end

    test "an unknown room reports :error" do
      assert :error = WaitingRoom.leave(123_456, 1)
    end
  end

  describe "leave/2 on an NPC room" do
    test "the last member leaving keeps the room" do
      assert :ok = create_room()
      assert {:ok, _} = WaitingRoom.join(100, member(1), 50, 0, "", [])
      assert {:ok, :left} = WaitingRoom.leave(100, 1)
      assert {:ok, %WaitingRoom{members: []}} = WaitingRoom.get(100)
    end
  end

  describe "kick/2 kick list" do
    test "a player room remembers the kicked char id" do
      {:ok, room} = WaitingRoom.create_player_room(member(1), "P", "", 5, true)
      {:ok, _} = WaitingRoom.join(room.room_id, member(2), 50, 0, "", [])

      assert {:ok, %Member{char_id: 2}} = WaitingRoom.kick(room.room_id, "char2")

      assert {:ok, %{members: [%{char_id: 1}], kick_list: kick_list}} =
               WaitingRoom.get(room.room_id)

      assert MapSet.member?(kick_list, 2)
    end

    test "an NPC room has no kick list" do
      assert :ok = create_room()
      assert {:ok, _} = WaitingRoom.join(100, member(1), 50, 0, "", [])

      assert {:ok, %Member{char_id: 1}} = WaitingRoom.kick(100, "char1")
      assert {:ok, %{members: [], kick_list: kick_list}} = WaitingRoom.get(100)
      assert MapSet.size(kick_list) == 0
    end
  end

  describe "change_owner/3" do
    setup do
      {:ok, room} = WaitingRoom.create_player_room(member(1), "P", "", 5, true)
      {:ok, _} = WaitingRoom.join(room.room_id, member(2), 50, 0, "", [])
      {:ok, _} = WaitingRoom.join(room.room_id, member(3), 50, 0, "", [])
      %{room_id: room.room_id}
    end

    test "the owner swaps slots with the named member", %{room_id: room_id} do
      assert {:ok, room} = WaitingRoom.change_owner(room_id, 1, "char3")
      assert room.owner == {:player, 3}
      assert Enum.map(room.members, & &1.char_id) == [3, 2, 1]
      assert {:ok, ^room} = WaitingRoom.get(room_id)
    end

    test "a non-owner is refused", %{room_id: room_id} do
      assert {:error, :not_owner} = WaitingRoom.change_owner(room_id, 2, "char3")
    end

    test "an unknown name is not found", %{room_id: room_id} do
      assert {:error, :not_found} = WaitingRoom.change_owner(room_id, 1, "nobody")
    end
  end

  describe "change_status/6" do
    setup do
      {:ok, room} = WaitingRoom.create_player_room(member(1), "P", "", 5, true)
      {:ok, _} = WaitingRoom.join(room.room_id, member(2), 50, 0, "", [])
      %{room_id: room.room_id}
    end

    test "the owner updates title, password, limit, and public flag", %{room_id: room_id} do
      title = String.duplicate("x", 70)

      assert {:ok, room} = WaitingRoom.change_status(room_id, 1, title, "123456789", 30, false)
      assert room.title == String.duplicate("x", 60)
      assert room.pass == "12345678"
      assert room.limit == 20
      refute room.public?
      assert {:ok, ^room} = WaitingRoom.get(room_id)
    end

    test "a non-owner is refused", %{room_id: room_id} do
      assert {:error, :not_owner} = WaitingRoom.change_status(room_id, 2, "T", "", 5, true)
    end
  end

  describe "owner?/2" do
    test "matches only the owning player" do
      {:ok, room} = WaitingRoom.create_player_room(member(1), "P", "", 5, true)
      assert WaitingRoom.owner?(room, 1)
      refute WaitingRoom.owner?(room, 2)

      assert :ok = create_room()
      {:ok, npc_room} = WaitingRoom.get(100)
      refute WaitingRoom.owner?(npc_room, 100)
    end
  end

  describe "join/6" do
    test "appends members in join order" do
      assert :ok = create_room()

      assert {:ok, %WaitingRoom{members: [%Member{char_id: 1}]}} =
               WaitingRoom.join(100, member(1), 50, 0, "", [])

      assert {:ok, %WaitingRoom{members: [%Member{char_id: 1}, %Member{char_id: 2}]}} =
               WaitingRoom.join(100, member(2), 50, 0, "", [])
    end

    test "rejects when full (the owner NPC occupies one slot)" do
      assert :ok = WaitingRoom.create(100, "W", 2, 2, "", 0, 1, 99)

      assert {:ok, _} = WaitingRoom.join(100, member(1), 50, 0, "", [])
      assert {:error, :full} = WaitingRoom.join(100, member(2), 50, 0, "", [])
    end

    test "rejects out-of-range level and short zeny in precedence order" do
      assert :ok = WaitingRoom.create(100, "W", 8, 7, "", 1000, 50, 60)

      assert {:error, :too_low_level} = WaitingRoom.join(100, member(1), 49, 9999, "", [])
      assert {:error, :too_high_level} = WaitingRoom.join(100, member(2), 61, 9999, "", [])
      assert {:error, :no_zeny} = WaitingRoom.join(100, member(3), 55, 999, "", [])
      assert {:ok, _} = WaitingRoom.join(100, member(4), 55, 1000, "", [])
    end

    test "returns :not_found for a missing room" do
      assert {:error, :not_found} = WaitingRoom.join(999, member(1), 50, 0, "", [])
    end
  end

  describe "leave/2 and kick/2" do
    test "leave removes the member" do
      assert :ok = create_room()
      assert {:ok, _} = WaitingRoom.join(100, member(1), 50, 0, "", [])
      assert {:ok, _} = WaitingRoom.join(100, member(2), 50, 0, "", [])

      assert {:ok, :left} = WaitingRoom.leave(100, 1)
      assert [%Member{char_id: 2}] = WaitingRoom.members(100)
    end

    test "kick removes by name" do
      assert :ok = create_room()
      assert {:ok, _} = WaitingRoom.join(100, member(1), 50, 0, "", [])

      assert {:ok, %Member{char_id: 1}} = WaitingRoom.kick(100, "char1")
      assert [] = WaitingRoom.members(100)
      assert {:error, :not_found} = WaitingRoom.kick(100, "nobody")
    end
  end

  describe "enable_event/1 and disable_event/1" do
    test "toggle the enabled flag without touching members" do
      assert :ok = create_room()
      assert {:ok, _} = WaitingRoom.join(100, member(1), 50, 0, "", [])

      assert {:ok, %WaitingRoom{enabled?: true}} = WaitingRoom.enable_event(100)
      assert :ok = WaitingRoom.disable_event(100)

      assert {:ok, %WaitingRoom{enabled?: false, members: [%Member{char_id: 1}]}} =
               WaitingRoom.get(100)
    end
  end

  describe "fire_event?/1" do
    test "true only when enabled, an event is set, and membership reaches the trigger" do
      assert :ok = WaitingRoom.create(100, "W", 8, 1, "B::OnStart", 0, 1, 99)

      assert {:ok, room} = WaitingRoom.join(100, member(1), 50, 0, "", [])
      assert WaitingRoom.fire_event?(room)

      assert :ok = WaitingRoom.disable_event(100)
      assert {:ok, disabled} = WaitingRoom.get(100)
      refute WaitingRoom.fire_event?(disabled)
    end

    test "false when no event label is set" do
      assert :ok = WaitingRoom.create(100, "W", 8, 1, "", 0, 1, 99)

      assert {:ok, room} = WaitingRoom.join(100, member(1), 50, 0, "", [])
      refute WaitingRoom.fire_event?(room)
    end
  end

  describe "state/2" do
    test "answers all nine info types and -1 when absent" do
      assert -1 = WaitingRoom.state(999, 0)

      assert :ok = WaitingRoom.create(100, "My Room", 8, 7, "B::OnStart", 0, 1, 99)
      assert {:ok, _} = WaitingRoom.join(100, member(1), 50, 0, "", [])
      assert {:ok, _} = WaitingRoom.join(100, member(2), 50, 0, "", [])

      assert 2 = WaitingRoom.state(100, 0)
      assert 8 = WaitingRoom.state(100, 1)
      assert 7 = WaitingRoom.state(100, 2)
      assert 0 = WaitingRoom.state(100, 3)
      assert "My Room" = WaitingRoom.state(100, 4)
      assert "" = WaitingRoom.state(100, 5)
      assert "B::OnStart" = WaitingRoom.state(100, 16)
      assert 0 = WaitingRoom.state(100, 32)
      assert 0 = WaitingRoom.state(100, 33)
      assert -1 = WaitingRoom.state(100, 99)

      assert :ok = WaitingRoom.disable_event(100)
      assert 1 = WaitingRoom.state(100, 3)
    end

    test "reports 0 for over-trigger when the event is disabled" do
      assert :ok = WaitingRoom.create(100, "W", 8, 1, "B::OnStart", 0, 1, 99)
      assert {:ok, _} = WaitingRoom.join(100, member(1), 50, 0, "", [])

      assert 1 = WaitingRoom.state(100, 33)
      assert :ok = WaitingRoom.disable_event(100)
      assert 0 = WaitingRoom.state(100, 33)
    end
  end

  describe "concurrent join" do
    test "the compare-and-swap loop never lets membership exceed the limit" do
      assert :ok = WaitingRoom.create(100, "W", 3, 3, "", 0, 1, 99)

      tasks =
        for i <- 1..10 do
          Task.async(fn -> WaitingRoom.join(100, member(i), 50, 0, "", []) end)
        end

      results = Task.await_many(tasks, 5_000)

      assert 2 = Enum.count(results, &match?({:ok, _}, &1))
      assert 8 = Enum.count(results, &(&1 == {:error, :full}))
      assert 2 = WaitingRoom.members(100) |> length()
    end
  end
end
