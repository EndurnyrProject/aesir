defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.RuwachTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Ruwach
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
  @caster_pos {:ok, {150, 150, "prontera"}}

  defp entry, do: %StatusEntry{type: :sc_ruwach, val1: 1, state: %{}}

  describe "metadata" do
    test "is a 10s buff that ticks every 500ms with the ruwach sprite option" do
      assert :sc_ruwach = Ruwach.id()

      assert %{properties: [:buff], duration: 10_000, tick_interval: 500, option: :ruwach} =
               Ruwach.metadata()
    end
  end

  describe "on_apply/3 - first pulse" do
    test "reveals concealed units and deals a holy splash, excluding the caster" do
      stub(SpatialIndex, :get_unit_position, fn :player, 1000 -> @caster_pos end)

      stub(SpatialIndex, :get_all_units_in_range, fn "prontera", 150, 150, 2 ->
        [{:player, 1000}, {:player, 2000}]
      end)

      expect(Helpers, :remove_statuses, fn {:player, 2000}, [:sc_hiding, :sc_cloaking] -> :ok end)

      stub(Combat, :resolve_combatant, fn 1000 -> {:ok, %{unit_id: 1000}} end)
      stub(Combat, :splash_targets, fn "prontera", {150, 150}, 2, 1000 -> [{:mob, 5000}] end)

      expect(Combat, :apply_skill_unit_damage, fn %{unit_id: 1000},
                                                  :mob,
                                                  5000,
                                                  24,
                                                  1,
                                                  :holy,
                                                  145 ->
        :ok
      end)

      assert {:ok, %StatusEntry{}} = Ruwach.on_apply(@caster, entry(), %{target_id: 1000})
    end
  end

  describe "on_tick/3 - recurring pulse" do
    test "reveals concealed units and deals a holy splash on each tick" do
      stub(SpatialIndex, :get_unit_position, fn :player, 1000 -> @caster_pos end)

      stub(SpatialIndex, :get_all_units_in_range, fn "prontera", 150, 150, 2 ->
        [{:player, 2000}]
      end)

      expect(Helpers, :remove_statuses, fn {:player, 2000}, [:sc_hiding, :sc_cloaking] -> :ok end)

      stub(Combat, :resolve_combatant, fn 1000 -> {:ok, %{unit_id: 1000}} end)
      stub(Combat, :splash_targets, fn "prontera", {150, 150}, 2, 1000 -> [{:mob, 5000}] end)

      expect(Combat, :apply_skill_unit_damage, fn %{unit_id: 1000},
                                                  :mob,
                                                  5000,
                                                  24,
                                                  1,
                                                  :holy,
                                                  145 ->
        :ok
      end)

      assert {:ok, %StatusEntry{}} = Ruwach.on_tick(@caster, entry(), %{target_id: 1000})
    end
  end

  describe "missing caster" do
    test "is a safe no-op when the caster position cannot be resolved" do
      stub(SpatialIndex, :get_unit_position, fn :player, 1000 -> {:error, :not_found} end)
      reject(&Helpers.remove_statuses/2)
      reject(&Combat.resolve_combatant/1)
      reject(&Combat.splash_targets/4)
      reject(&Combat.apply_skill_unit_damage/7)

      assert {:ok, %StatusEntry{}} = Ruwach.on_apply(@caster, entry(), %{target_id: 1000})
      assert {:ok, %StatusEntry{}} = Ruwach.on_tick(@caster, entry(), %{target_id: 1000})
    end

    test "still reveals but skips the splash when the caster combatant is gone" do
      stub(SpatialIndex, :get_unit_position, fn :player, 1000 -> @caster_pos end)

      stub(SpatialIndex, :get_all_units_in_range, fn "prontera", 150, 150, 2 ->
        [{:player, 2000}]
      end)

      expect(Helpers, :remove_statuses, fn {:player, 2000}, [:sc_hiding, :sc_cloaking] -> :ok end)

      stub(Combat, :resolve_combatant, fn 1000 -> {:error, :not_found} end)
      reject(&Combat.splash_targets/4)
      reject(&Combat.apply_skill_unit_damage/7)

      assert {:ok, %StatusEntry{}} = Ruwach.on_apply(@caster, entry(), %{target_id: 1000})
    end
  end

  test "does not reveal a corpse" do
    corpse = %PlayerState{
      character_id: 2000,
      action_state: :dead,
      stats: %{current_state: %{hp: 0}}
    }

    stub(SpatialIndex, :get_unit_position, fn :player, 1000 -> @caster_pos end)

    stub(SpatialIndex, :get_all_units_in_range, fn "prontera", 150, 150, 2 ->
      [{:player, 2000}]
    end)

    stub(UnitRegistry, :get_unit, fn :player, 2000 -> {:ok, {PlayerState, corpse, self()}} end)
    reject(&Helpers.remove_statuses/2)
    stub(Combat, :resolve_combatant, fn 1000 -> {:error, :not_found} end)

    assert {:ok, %StatusEntry{}} = Ruwach.on_apply(@caster, entry(), %{target_id: 1000})
  end
end
