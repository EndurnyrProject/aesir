defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SightTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Sight
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  setup do
    stub(UnitRegistry, :get_unit, fn :player, player_id ->
      state = %PlayerState{
        character_id: player_id,
        action_state: :idle,
        stats: %{current_state: %{hp: 1}}
      }

      {:ok, {PlayerState, state, self()}}
    end)

    :ok
  end

  @caster {:player, 1000}

  defp entry, do: %StatusEntry{type: :sc_sight, state: %{}}

  describe "metadata" do
    test "is a 10-second buff mapped to client status id 88" do
      assert :sc_sight = Sight.id()
      assert %{properties: [:buff], duration: 10_000} = Sight.metadata()
    end
  end

  describe "on_apply/3 - reveal pulse" do
    test "ends sc_hiding and sc_cloaking on an in-range unit" do
      stub(SpatialIndex, :get_unit_position, fn :player, 1000 -> {:ok, {150, 150, "prontera"}} end)

      stub(SpatialIndex, :get_all_units_in_range, fn "prontera", 150, 150, 3 ->
        [{:player, 2000}]
      end)

      expect(Helpers, :remove_statuses, fn {:player, 2000}, [:sc_hiding, :sc_cloaking] -> :ok end)

      assert {:ok, %StatusEntry{}} = Sight.on_apply(@caster, entry(), %{target_id: 1000})
    end

    test "is a no-op when no units are in range" do
      stub(SpatialIndex, :get_unit_position, fn :player, 1000 -> {:ok, {150, 150, "prontera"}} end)

      stub(SpatialIndex, :get_all_units_in_range, fn "prontera", 150, 150, 3 -> [] end)
      reject(&Helpers.remove_statuses/2)

      assert {:ok, %StatusEntry{}} = Sight.on_apply(@caster, entry(), %{target_id: 1000})
    end

    test "does not crash when the caster position cannot be resolved" do
      stub(SpatialIndex, :get_unit_position, fn :player, 1000 -> {:error, :not_found} end)
      reject(&Helpers.remove_statuses/2)

      assert {:ok, %StatusEntry{}} = Sight.on_apply(@caster, entry(), %{target_id: 1000})
    end

    test "does not reveal a corpse" do
      corpse = %PlayerState{
        character_id: 2000,
        action_state: :dead,
        stats: %{current_state: %{hp: 0}}
      }

      stub(SpatialIndex, :get_unit_position, fn :player, 1000 -> {:ok, {150, 150, "prontera"}} end)

      stub(SpatialIndex, :get_all_units_in_range, fn "prontera", 150, 150, 3 ->
        [{:player, 2000}]
      end)

      stub(UnitRegistry, :get_unit, fn :player, 2000 -> {:ok, {PlayerState, corpse, self()}} end)
      reject(&Helpers.remove_statuses/2)

      assert {:ok, %StatusEntry{}} = Sight.on_apply(@caster, entry(), %{target_id: 1000})
    end
  end
end
