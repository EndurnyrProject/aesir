defmodule Aesir.ZoneServer.Unit.EmoteTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import Mimic

  alias Aesir.Net.Emotion, as: EmotionMsg
  alias Aesir.ZoneServer.Npc.Placement
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Emote
  alias Aesir.ZoneServer.Unit.SpatialIndex

  setup :verify_on_exit!

  describe "show/2 with an atom emote" do
    test "broadcasts an Emotion with the resolved type to in-range players" do
      test_pid = self()

      stub(SpatialIndex, :get_unit_position, fn :player, 2_000 ->
        {:ok, {150, 150, "prontera"}}
      end)

      stub(Broadcast, :to_in_range, fn map_name, x, y, _range, packet, _opts ->
        send(test_pid, {:broadcast, map_name, x, y, packet})
        :ok
      end)

      Emote.show({:player, 2_000}, :surprise)

      assert_received {:broadcast, "prontera", 150, 150, %EmotionMsg{gid: 2_000, type: 0}}
    end
  end

  describe "show/2 with an integer emote" do
    test "broadcasts an Emotion with the given type to in-range players" do
      test_pid = self()

      stub(SpatialIndex, :get_unit_position, fn :mob, 9 ->
        {:ok, {50, 60, "geffen"}}
      end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet, _opts ->
        send(test_pid, {:broadcast, packet})
        :ok
      end)

      Emote.show({:mob, 9}, 3)

      assert_received {:broadcast, %EmotionMsg{gid: 9, type: 3}}
    end
  end

  describe "show/2 with an unknown emote atom" do
    test "logs a warning and sends nothing" do
      reject(&Broadcast.to_in_range/6)

      log =
        capture_log(fn ->
          assert :ok = Emote.show({:player, 2_000}, :not_a_real_emote)
        end)

      assert log =~ "not_a_real_emote"
    end
  end

  describe "show/2 with a unit that has no position" do
    test "sends nothing and returns :ok" do
      reject(&Broadcast.to_in_range/6)

      stub(SpatialIndex, :get_unit_position, fn :player, 2_000 ->
        {:error, :not_found}
      end)

      assert :ok = Emote.show({:player, 2_000}, :surprise)
    end
  end

  describe "show/2 with an NPC source" do
    test "falls back to the placement position for a non-unit NPC gid" do
      test_pid = self()

      stub(SpatialIndex, :get_unit_position, fn :npc, 4_000 -> {:error, :not_found} end)

      stub(NpcRegistry, :module_for_unit, fn 4_000 ->
        {:ok, {__MODULE__, %Placement{map: "prt_castle", x: 44, y: 30, sprite: 88}}}
      end)

      stub(Broadcast, :to_in_range, fn map_name, x, y, _range, packet, _opts ->
        send(test_pid, {:broadcast, map_name, x, y, packet})
        :ok
      end)

      Emote.show({:npc, 4_000}, 3)

      assert_received {:broadcast, "prt_castle", 44, 30, %EmotionMsg{gid: 4_000, type: 3}}
    end

    test "sends nothing when the gid is neither a unit nor a placement" do
      reject(&Broadcast.to_in_range/6)

      stub(SpatialIndex, :get_unit_position, fn :npc, 4_000 -> {:error, :not_found} end)
      stub(NpcRegistry, :module_for_unit, fn 4_000 -> :error end)

      assert :ok = Emote.show({:npc, 4_000}, 3)
    end
  end
end
