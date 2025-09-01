defmodule Aesir.ZoneServer.Mmo.StatusEffect.InterpreterTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  describe "apply_status/9" do
    test "applies a status to a target" do
      target_id = 1
      status_id = :sc_provoke
      val1 = 10
      val2 = 20

      setup_player_mock(target_id)

      assert :ok = Interpreter.apply_status(:player, target_id, status_id, [val1: val1, val2: val2])
      assert StatusStorage.has_status?(:player, target_id, status_id)
    end

    test "raises error when player not found" do
      target_id = 9999
      status_id = :sc_provoke

      assert_raise RuntimeError, ~r/Cannot apply status effect to non-existent/, fn ->
        Interpreter.apply_status(:player, target_id, status_id, [val1: 0])
      end
    end
  end

  describe "remove_status/2" do
    test "removes a status from a target" do
      target_id = 1
      status_id = :sc_provoke
      val1 = 10

      # Mock player session
      setup_player_mock(target_id)

      # First apply the status
      :ok = Interpreter.apply_status(:player, target_id, status_id, [val1: val1])
      assert StatusStorage.has_status?(:player, target_id, status_id)

      # Then remove it
      :ok = Interpreter.remove_status(:player, target_id, status_id)
      refute StatusStorage.has_status?(:player, target_id, status_id)
    end
  end

  describe "on_damage/2" do
    test "processes damage events for all statuses" do
      target_id = 1

      # Mock player session
      setup_player_mock(target_id)

      # First apply some status
      :ok = Interpreter.apply_status(:player, target_id, :sc_provoke, [val1: 10])

      # Trigger damage event
      damage_info = %{damage: 100, element: :neutral, dmg_type: :physical}
      Interpreter.on_damage(:player, target_id, damage_info)

      # We can't easily assert effects here without mocking,
      # but we can at least verify it doesn't crash
    end
  end

  describe "get_all_modifiers/1" do
    test "returns modifiers for all active statuses" do
      target_id = 1

      # Mock player session
      setup_player_mock(target_id)

      # Status with modifiers
      :ok = Interpreter.apply_status(:player, target_id, :sc_provoke, [val1: 10, val2: 20])

      modifiers = Interpreter.get_all_modifiers(:player, target_id)

      # The provoke status adds HIT=val3 (which is 0 in this case)
      assert is_map(modifiers)
      assert Map.has_key?(modifiers, :hit)
    end
  end

  # Helper to set up player mock with stats
  defp setup_player_mock(player_id) do
    # Copy and stub necessary modules
    Mimic.copy(Aesir.ZoneServer.Mmo.StatusEffect.Resistance)
    Mimic.copy(UnitRegistry)

    # Mock UnitRegistry to return entity info
    stub(UnitRegistry, :get_unit_info, fn _unit_type, _unit_id ->
      {:ok,
       %{
         unit_id: player_id,
         unit_type: :player,
         race: :human,
         element: :neutral,
         element_level: 1,
         boss_flag: false,
         size: :medium,
         stats: %{
           max_hp: 1000,
           max_sp: 100,
           hp: 800,
           sp: 80,
           level: 50,
           base_level: 50,
           str: 10,
           agi: 10,
           vit: 10,
           int: 10,
           dex: 10,
           luk: 10,
           mdef: 5
         }
       }}
    end)

    # Stub resistance roll to always succeed for predictable tests
    stub(Aesir.ZoneServer.Mmo.StatusEffect.Resistance, :roll_success, fn _ -> true end)
  end
end
