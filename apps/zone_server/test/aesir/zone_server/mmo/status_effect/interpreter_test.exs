defmodule Aesir.ZoneServer.Mmo.StatusEffect.InterpreterTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup
  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

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

      assert :ok = Interpreter.apply_status(target_id, status_id, val1, val2)
      assert StatusStorage.has_status?(target_id, status_id)
    end

    test "raises error when player not found" do
      target_id = 9999
      status_id = :sc_provoke

      assert_raise RuntimeError, ~r/Player .* not found/, fn ->
        Interpreter.apply_status(target_id, status_id, 0)
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
      :ok = Interpreter.apply_status(target_id, status_id, val1)
      assert StatusStorage.has_status?(target_id, status_id)

      # Then remove it
      :ok = Interpreter.remove_status(target_id, status_id)
      refute StatusStorage.has_status?(target_id, status_id)
    end
  end

  describe "on_damage/2" do
    test "processes damage events for all statuses" do
      target_id = 1

      # Mock player session
      setup_player_mock(target_id)

      # First apply some status
      :ok = Interpreter.apply_status(target_id, :sc_provoke, 10)

      # Trigger damage event
      damage_info = %{damage: 100, element: :neutral, dmg_type: :physical}
      Interpreter.on_damage(target_id, damage_info)

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
      :ok = Interpreter.apply_status(target_id, :sc_provoke, 10, 20)

      modifiers = Interpreter.get_all_modifiers(target_id)

      # The provoke status adds HIT=val3 (which is 0 in this case)
      assert is_map(modifiers)
      assert Map.has_key?(modifiers, :hit)
    end
  end

  # Helper to set up player mock with stats
  defp setup_player_mock(player_id) do
    stub(PlayerSession, :get_current_stats, fn _ ->
      %Aesir.ZoneServer.Unit.Player.Stats{
        base_stats: %{str: 10, agi: 10, vit: 10, int: 10, dex: 10, luk: 10},
        derived_stats: %{max_hp: 1000, max_sp: 100, aspd: 150},
        current_state: %{hp: 800, sp: 80},
        progression: %{base_level: 50},
        combat_stats: %{hit: 0, flee: 0, critical: 0, atk: 0, def: 0},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }
    end)

    mock_pid = Process.whereis(PlayerSession) || self()

    :ets.insert(table_for(:zone_players), {player_id, mock_pid, player_id + 1000})
  end
end
