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
  end

  describe "join/4" do
    test "appends members in join order" do
      assert :ok = create_room()

      assert {:ok, %WaitingRoom{members: [%Member{char_id: 1}]}} =
               WaitingRoom.join(100, member(1), 50, 0)

      assert {:ok, %WaitingRoom{members: [%Member{char_id: 1}, %Member{char_id: 2}]}} =
               WaitingRoom.join(100, member(2), 50, 0)
    end

    test "rejects when full (the owner NPC occupies one slot)" do
      assert :ok = WaitingRoom.create(100, "W", 2, 2, "", 0, 1, 99)

      assert {:ok, _} = WaitingRoom.join(100, member(1), 50, 0)
      assert {:error, :full} = WaitingRoom.join(100, member(2), 50, 0)
    end

    test "rejects out-of-range level and short zeny in precedence order" do
      assert :ok = WaitingRoom.create(100, "W", 8, 7, "", 1000, 50, 60)

      assert {:error, :too_low_level} = WaitingRoom.join(100, member(1), 49, 9999)
      assert {:error, :too_high_level} = WaitingRoom.join(100, member(2), 61, 9999)
      assert {:error, :no_zeny} = WaitingRoom.join(100, member(3), 55, 999)
      assert {:ok, _} = WaitingRoom.join(100, member(4), 55, 1000)
    end

    test "returns :not_found for a missing room" do
      assert {:error, :not_found} = WaitingRoom.join(999, member(1), 50, 0)
    end
  end

  describe "leave/2 and kick/2" do
    test "leave removes the member" do
      assert :ok = create_room()
      assert {:ok, _} = WaitingRoom.join(100, member(1), 50, 0)
      assert {:ok, _} = WaitingRoom.join(100, member(2), 50, 0)

      assert :ok = WaitingRoom.leave(100, 1)
      assert [%Member{char_id: 2}] = WaitingRoom.members(100)
    end

    test "kick removes by name" do
      assert :ok = create_room()
      assert {:ok, _} = WaitingRoom.join(100, member(1), 50, 0)

      assert :ok = WaitingRoom.kick(100, "char1")
      assert [] = WaitingRoom.members(100)
      assert {:error, :not_found} = WaitingRoom.kick(100, "nobody")
    end
  end

  describe "enable_event/1 and disable_event/1" do
    test "toggle the enabled flag without touching members" do
      assert :ok = create_room()
      assert {:ok, _} = WaitingRoom.join(100, member(1), 50, 0)

      assert {:ok, %WaitingRoom{enabled?: true}} = WaitingRoom.enable_event(100)
      assert :ok = WaitingRoom.disable_event(100)

      assert {:ok, %WaitingRoom{enabled?: false, members: [%Member{char_id: 1}]}} =
               WaitingRoom.get(100)
    end
  end

  describe "fire_event?/1" do
    test "true only when enabled, an event is set, and membership reaches the trigger" do
      assert :ok = WaitingRoom.create(100, "W", 8, 1, "B::OnStart", 0, 1, 99)

      assert {:ok, room} = WaitingRoom.join(100, member(1), 50, 0)
      assert WaitingRoom.fire_event?(room)

      assert :ok = WaitingRoom.disable_event(100)
      assert {:ok, disabled} = WaitingRoom.get(100)
      refute WaitingRoom.fire_event?(disabled)
    end

    test "false when no event label is set" do
      assert :ok = WaitingRoom.create(100, "W", 8, 1, "", 0, 1, 99)

      assert {:ok, room} = WaitingRoom.join(100, member(1), 50, 0)
      refute WaitingRoom.fire_event?(room)
    end
  end

  describe "state/2" do
    test "answers all nine info types and -1 when absent" do
      assert -1 = WaitingRoom.state(999, 0)

      assert :ok = WaitingRoom.create(100, "My Room", 8, 7, "B::OnStart", 0, 1, 99)
      assert {:ok, _} = WaitingRoom.join(100, member(1), 50, 0)
      assert {:ok, _} = WaitingRoom.join(100, member(2), 50, 0)

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
      assert {:ok, _} = WaitingRoom.join(100, member(1), 50, 0)

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
          Task.async(fn -> WaitingRoom.join(100, member(i), 50, 0) end)
        end

      results = Task.await_many(tasks, 5_000)

      assert 2 = Enum.count(results, &match?({:ok, _}, &1))
      assert 8 = Enum.count(results, &(&1 == {:error, :full}))
      assert 2 = WaitingRoom.members(100) |> length()
    end
  end
end
