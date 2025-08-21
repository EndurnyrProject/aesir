defmodule Aesir.ZoneServer.Mmo.StatusEffect.InterpreterTest do
  # Set async to false to avoid issues with Mimic
  use ExUnit.Case, async: false
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  import Mimic

  # Copy the PlayerSession module for mocking
  setup do
    Mimic.copy(PlayerSession)
    :ok
  end

  # Use set_mimic_global to make mocks available to all processes
  setup :set_mimic_global
  setup :verify_on_exit!

  setup do
    # Set up test tables, handling the case where they might already exist
    # Safely initialize StatusStorage
    try do
      StatusStorage.init()
    catch
      :error, %ArgumentError{} -> :ok
    end

    # Safely initialize Interpreter
    try do
      Interpreter.init()
    catch
      :error, %ArgumentError{} -> :ok
    end

    # Setup ETS table for zone_players if it doesn't exist
    if :ets.whereis(:zone_players) == :undefined do
      :ets.new(:zone_players, [:set, :public, :named_table])
    end

    # Clear any existing test data
    :ets.delete_all_objects(:player_statuses)

    :ok
  end

  describe "apply_status/9" do
    test "applies a status to a target" do
      target_id = 1
      status_id = :sc_provoke
      val1 = 10
      val2 = 20

      # Mock player session
      setup_player_mock(target_id)

      assert :ok = Interpreter.apply_status(target_id, status_id, val1, val2)
      assert StatusStorage.has_status?(target_id, status_id)
    end

    test "raises error when player not found" do
      # Non-existent player
      target_id = 9999
      status_id = :sc_provoke

      # Make sure the player doesn't exist in ETS
      :ets.delete(:zone_players, target_id)

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
    # Use stub with global mode enabled by set_mimic_global
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

    # Set up mock player in ETS
    mock_pid = Process.whereis(PlayerSession) || self()

    :ets.insert(:zone_players, {player_id, mock_pid, player_id + 1000})
  end
end
