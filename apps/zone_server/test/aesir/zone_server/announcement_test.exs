defmodule Aesir.ZoneServer.AnnouncementTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.Commons.InterServer.PubSub
  alias Aesir.Net.Announcement, as: AnnouncementMsg
  alias Aesir.ZoneServer.Announcement
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.SpatialIndex

  setup :verify_on_exit!

  @opts %{text: "hello", color: 0x0099FF, style: :TOP, source_name: "GM"}

  @expected_packet %AnnouncementMsg{
    text: "hello",
    color: 0x0099FF,
    style: :TOP,
    source_name: "GM"
  }

  describe "to_self/2" do
    test "builds the packet and sends it to the single player" do
      test_pid = self()

      stub(Broadcast, :to_player, fn char_id, packet ->
        send(test_pid, {:to_player, char_id, packet})
        :ok
      end)

      assert :ok = Announcement.to_self(42, @opts)

      assert_received {:to_player, 42, @expected_packet}
    end
  end

  describe "to_map/2" do
    test "resolves map players and sends the packet to them" do
      test_pid = self()

      stub(SpatialIndex, :get_players_on_map, fn "prontera" -> [1, 2, 3] end)

      stub(Broadcast, :to_players, fn char_ids, packet ->
        send(test_pid, {:to_players, char_ids, packet})
        :ok
      end)

      assert :ok = Announcement.to_map("prontera", @opts)

      assert_received {:to_players, [1, 2, 3], @expected_packet}
    end
  end

  describe "to_area/3" do
    test "delivers only to players inside the rectangle" do
      test_pid = self()

      stub(SpatialIndex, :get_players_on_map, fn "prontera" -> [:inside, :outside] end)

      stub(SpatialIndex, :get_position, fn
        :inside -> {:ok, {15, 15, "prontera"}}
        :outside -> {:ok, {99, 99, "prontera"}}
      end)

      stub(Broadcast, :to_players, fn char_ids, packet ->
        send(test_pid, {:to_players, char_ids, packet})
        :ok
      end)

      assert :ok = Announcement.to_area("prontera", {10, 10, 20, 20}, @opts)

      assert_received {:to_players, [:inside], @expected_packet}
    end
  end

  describe "to_all/1" do
    test "publishes the built packet for global fan-out" do
      test_pid = self()

      stub(PubSub, :broadcast_announcement, fn packet ->
        send(test_pid, {:broadcast_announcement, packet})
        :ok
      end)

      assert :ok = Announcement.to_all(@opts)

      assert_received {:broadcast_announcement, @expected_packet}
    end
  end

  describe "deliver_local/2" do
    test "fans an already-built packet to the map's players" do
      test_pid = self()

      stub(SpatialIndex, :get_players_on_map, fn "geffen" -> [7, 8] end)

      stub(Broadcast, :to_players, fn char_ids, packet ->
        send(test_pid, {:to_players, char_ids, packet})
        :ok
      end)

      assert :ok = Announcement.deliver_local(@expected_packet, "geffen")

      assert_received {:to_players, [7, 8], @expected_packet}
    end
  end
end
