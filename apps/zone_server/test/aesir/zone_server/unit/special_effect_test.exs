defmodule Aesir.ZoneServer.Unit.SpecialEffectTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import Mimic

  alias Aesir.Net.SpecialEffect, as: SpecialEffectMsg
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.SpecialEffect

  setup :verify_on_exit!

  describe "play/3 with :area target" do
    test "broadcasts a SpecialEffect with the resolved effect_id to in-range players" do
      test_pid = self()

      stub(SpatialIndex, :get_unit_position, fn :player, 2_000 ->
        {:ok, {150, 150, "prontera"}}
      end)

      stub(Broadcast, :to_in_range, fn map_name, x, y, _range, packet, _opts ->
        send(test_pid, {:broadcast, map_name, x, y, packet})
        :ok
      end)

      SpecialEffect.play({:player, 2_000}, :hit1, :area)

      assert_received {:broadcast, "prontera", 150, 150,
                       %SpecialEffectMsg{source_id: 2_000, effect_id: 0}}
    end

    test "defaults to :area when no target is given" do
      test_pid = self()

      stub(SpatialIndex, :get_unit_position, fn :player, 2_000 ->
        {:ok, {10, 20, "geffen"}}
      end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet, _opts ->
        send(test_pid, {:broadcast, packet})
        :ok
      end)

      SpecialEffect.play({:player, 2_000}, :hit1)

      assert_received {:broadcast, %SpecialEffectMsg{effect_id: 0}}
    end
  end

  describe "play/3 with :self target" do
    test "sends only to the source unit via to_player/2" do
      test_pid = self()

      reject(&SpatialIndex.get_unit_position/2)
      reject(&Broadcast.to_in_range/6)

      stub(Broadcast, :to_player, fn char_id, packet ->
        send(test_pid, {:to_player, char_id, packet})
        :ok
      end)

      SpecialEffect.play({:player, 2_000}, :hit1, :self)

      assert_received {:to_player, 2_000, %SpecialEffectMsg{source_id: 2_000, effect_id: 0}}
    end
  end

  describe "play/3 with an unknown effect atom" do
    test "logs a warning and sends nothing" do
      reject(&Broadcast.to_in_range/6)
      reject(&Broadcast.to_player/2)

      log =
        capture_log(fn ->
          assert :ok = SpecialEffect.play({:player, 2_000}, :not_a_real_effect, :area)
        end)

      assert log =~ "not_a_real_effect"
    end
  end
end
