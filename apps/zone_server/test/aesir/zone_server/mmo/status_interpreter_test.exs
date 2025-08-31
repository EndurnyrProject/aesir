defmodule Aesir.ZoneServer.Mmo.StatusInterpreterTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    # Copy modules for mocking
    Mimic.copy(Aesir.ZoneServer.Mmo.StatusEffect.Resistance)
    Mimic.copy(UnitRegistry)

    # Use a test player ID
    player_id = :rand.uniform(100_000)

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
           max_sp: 500,
           hp: 1000,
           sp: 500,
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
    stub(Resistance, :roll_success, fn _success_rate -> true end)

    %{player_id: player_id}
  end

  describe "apply_status/9" do
    test "applies stone status with initial wait phase", %{player_id: player_id} do
      assert :ok = Interpreter.apply_status(:player, player_id, :sc_stone, 1, 0, 0, 0, 10_000, 0)

      # Check status was stored
      assert StatusStorage.has_status?(:player, player_id, :sc_stone)

      # Check initial phase is wait
      status = StatusStorage.get_status(:player, player_id, :sc_stone)
      assert status.phase == :wait
    end

    test "applies freeze status with defense penalties", %{player_id: player_id} do
      assert :ok = Interpreter.apply_status(:player, player_id, :sc_freeze, 1, 0, 0, 0, 5000, 0)

      # Get modifiers
      modifiers = Interpreter.get_all_modifiers(:player, player_id)

      # Check for expected modifiers
      # Water element level 1
      assert modifiers[:def_ele] == :water1
      # -100% physical defense
      assert modifiers[:def_rate] == -100
      # -50% magic defense
      assert modifiers[:mdef_rate] == -50
    end

    test "applies poison status with DoT configuration", %{player_id: player_id} do
      assert :ok = Interpreter.apply_status(:player, player_id, :sc_poison, 5, 0, 0, 0, 60_000, 0)

      status = StatusStorage.get_status(:player, player_id, :sc_poison)
      assert status != nil

      # Check modifiers
      modifiers = Interpreter.get_all_modifiers(:player, player_id)
      assert modifiers[:def2] == -25
    end

    test "applies curse status with stat penalties", %{player_id: player_id} do
      assert :ok = Interpreter.apply_status(:player, player_id, :sc_curse, 1, 0, 0, 0, 30_000, 0)

      modifiers = Interpreter.get_all_modifiers(:player, player_id)

      # LUK set to 0
      assert modifiers[:luk] == 0
      # ATK reduced by 25% (combined atk_rate)
      assert modifiers[:atk_rate] == -25
      # Movement speed reduced
      assert modifiers[:movement_speed] == -10
    end

    test "applies stun status with action prevention flags", %{player_id: player_id} do
      assert :ok = Interpreter.apply_status(:player, player_id, :sc_stun, 1, 0, 0, 0, 3000, 0)

      # Stun has no modifiers, just flags
      modifiers = Interpreter.get_all_modifiers(:player, player_id)
      assert modifiers == %{}

      # Status should exist
      assert StatusStorage.has_status?(:player, player_id, :sc_stun)
    end

    test "applies blind status with accuracy penalties", %{player_id: player_id} do
      assert :ok = Interpreter.apply_status(:player, player_id, :sc_blind, 1, 0, 0, 0, 30_000, 0)

      modifiers = Interpreter.get_all_modifiers(:player, player_id)
      assert modifiers[:hit] == -25
      assert modifiers[:flee] == -25
    end

    test "applies provoke with dynamic values", %{player_id: player_id} do
      # val2 = ATK%, val3 = DEF%
      assert :ok =
               Interpreter.apply_status(:player, player_id, :sc_provoke, 1, 30, 50, 0, 10_000, 0)

      modifiers = Interpreter.get_all_modifiers(:player, player_id)

      # ATK increased by val2
      assert modifiers[:batk_rate] == 30
      assert modifiers[:watk_rate] == 30
      # DEF reduced by val3
      assert modifiers[:def_rate] == -50
      assert modifiers[:def2_rate] == -50
      # HIT bonus is val3
      assert modifiers[:hit] == 50
    end

    @tag :skip
    test "applies endure with MDEF bonus", %{player_id: player_id} do
      assert :ok = Interpreter.apply_status(:player, player_id, :sc_endure, 5, 0, 0, 0, 30_000, 0)

      modifiers = Interpreter.get_all_modifiers(:player, player_id)
      # MDEF bonus based on val1
      assert modifiers[:mdef] == 5
      assert modifiers[:endure] == true

      # Check initial state
      status = StatusStorage.get_status(:player, player_id, :sc_endure)
      assert status.state[:hits_remaining] == 7
    end

    test "applies bleeding with regeneration block", %{player_id: player_id} do
      assert :ok =
               Interpreter.apply_status(:player, player_id, :sc_bleeding, 5, 0, 0, 0, 120_000, 0)

      modifiers = Interpreter.get_all_modifiers(:player, player_id)
      assert modifiers[:hp_regen] == -100
      assert modifiers[:sp_regen] == -100
    end

    test "multiple statuses stack modifiers correctly", %{player_id: player_id} do
      # Apply multiple statuses
      assert :ok = Interpreter.apply_status(:player, player_id, :sc_curse, 1, 0, 0, 0, 30_000, 0)
      assert :ok = Interpreter.apply_status(:player, player_id, :sc_blind, 1, 0, 0, 0, 30_000, 0)

      # Get combined modifiers
      modifiers = Interpreter.get_all_modifiers(:player, player_id)

      # Both statuses should contribute
      # From curse (rAthena: set to 0, not -999)
      assert modifiers[:luk] == 0
      # From blind
      assert modifiers[:hit] == -25
      # From blind
      assert modifiers[:flee] == -25
    end
  end

  describe "remove_status/2" do
    test "removes status and clears modifiers", %{player_id: player_id} do
      # Apply status
      assert :ok = Interpreter.apply_status(:player, player_id, :sc_curse, 1, 0, 0, 0, 30_000, 0)
      assert StatusStorage.has_status?(:player, player_id, :sc_curse)

      # Remove status
      assert :ok = Interpreter.remove_status(:player, player_id, :sc_curse)
      refute StatusStorage.has_status?(:player, player_id, :sc_curse)

      # Modifiers should be cleared
      modifiers = Interpreter.get_all_modifiers(:player, player_id)
      assert modifiers == %{}
    end
  end

  describe "process_tick/2" do
    test "processes tick for poison status", %{player_id: player_id} do
      assert :ok = Interpreter.apply_status(:player, player_id, :sc_poison, 5, 0, 0, 0, 60_000, 0)

      # Process a tick
      assert :ok = Interpreter.process_tick(:player, player_id, :sc_poison)

      # Status should still exist (not expired)
      assert StatusStorage.has_status?(:player, player_id, :sc_poison)
    end

    test "handles phase transition for stone status", %{player_id: player_id} do
      assert :ok = Interpreter.apply_status(:player, player_id, :sc_stone, 1, 0, 0, 0, 10_000, 0)

      # Initial phase should be wait
      status = StatusStorage.get_status(:player, player_id, :sc_stone)
      assert status.phase == :wait

      # Manually update timestamp to simulate time passing
      StatusStorage.update_status(:player, player_id, :sc_stone, fn s ->
        # 6 seconds ago
        %{s | started_at: s.started_at - 6000}
      end)

      # Process tick should transition to stone phase
      assert :ok = Interpreter.process_tick(:player, player_id, :sc_stone)

      status = StatusStorage.get_status(:player, player_id, :sc_stone)
      assert status.phase == :stone
    end
  end

  describe "on_damage/2" do
    test "removes sleep status on damage", %{player_id: player_id} do
      assert :ok = Interpreter.apply_status(:player, player_id, :sc_sleep, 1, 0, 0, 0, 30_000, 0)
      assert StatusStorage.has_status?(:player, player_id, :sc_sleep)

      # Trigger damage event
      Interpreter.on_damage(:player, player_id, %{damage: 100, element: :neutral})

      # Sleep should be removed
      refute StatusStorage.has_status?(:player, player_id, :sc_sleep)
    end
  end

  describe "status properties" do
    test "correctly identifies debuffs" do
      assert Interpreter.debuff?(:sc_curse) == true
      assert Interpreter.debuff?(:sc_poison) == true
      assert Interpreter.debuff?(:sc_freeze) == true
    end

    test "correctly identifies buffs" do
      assert Interpreter.buff?(:sc_endure) == true
      assert Interpreter.buff?(:sc_hiding) == true
    end

    test "identifies movement prevention" do
      assert Interpreter.prevents_movement?(:sc_stone) == true
      assert Interpreter.prevents_movement?(:sc_freeze) == true
      assert Interpreter.prevents_movement?(:sc_stun) == true
      assert Interpreter.prevents_movement?(:sc_sleep) == true
    end

    test "identifies skill prevention" do
      assert Interpreter.prevents_skills?(:sc_stone) == true
      assert Interpreter.prevents_skills?(:sc_freeze) == true
      assert Interpreter.prevents_skills?(:sc_stun) == true
      assert Interpreter.prevents_skills?(:sc_silence) == true
    end

    test "identifies attack prevention" do
      assert Interpreter.prevents_attack?(:sc_stone) == true
      assert Interpreter.prevents_attack?(:sc_freeze) == true
      assert Interpreter.prevents_attack?(:sc_stun) == true
      assert Interpreter.prevents_attack?(:sc_sleep) == true
    end
  end

  describe "complex status effects" do
    test "arcane charge accumulates state", %{player_id: player_id} do
      assert :ok =
               Interpreter.apply_status(
                 :player,
                 player_id,
                 :sc_arcane_charge,
                 1,
                 0,
                 0,
                 0,
                 60_000,
                 0
               )

      # Check initial state
      status = StatusStorage.get_status(:player, player_id, :sc_arcane_charge)
      assert status.state[:charges] == 0

      # Modifiers should be based on charges
      modifiers = Interpreter.get_all_modifiers(:player, player_id)
      # 0 charges * 10
      assert modifiers[:matk] == 0
    end

    test "poison react tracks counters", %{player_id: player_id} do
      assert :ok =
               Interpreter.apply_status(
                 :player,
                 player_id,
                 :sc_poisonreact,
                 10,
                 0,
                 0,
                 0,
                 120_000,
                 0
               )

      status = StatusStorage.get_status(:player, player_id, :sc_poisonreact)
      assert status.state[:counter_remaining] == "val1 / 2"
      assert status.state[:boost_mode] == false
    end

    test "deadly poison has conditional tick", %{player_id: player_id} do
      assert :ok =
               Interpreter.apply_status(:player, player_id, :sc_dpoison, 1, 0, 0, 0, 60_000, 0)

      modifiers = Interpreter.get_all_modifiers(:player, player_id)
      assert modifiers[:hp_regen] == -100
      assert modifiers[:sp_regen] == -100
      assert modifiers[:def_rate] == -25
    end
  end
end
