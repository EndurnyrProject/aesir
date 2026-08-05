defmodule Aesir.ZoneServer.Mmo.CombatAbsorbTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.HandedAttack
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :setup_ets_tables

  @moduletag :capture_log

  @mob_id 2001
  @player_id 3001
  @caster_id 1000
  @map_name "prontera"
  @skill_id 28
  @skill_level 5

  defmodule FakeUnit do
    @moduledoc false
    defstruct [:combatant, :stats, :x, :y]

    def to_combatant(%__MODULE__{combatant: combatant}), do: combatant
  end

  defp combatant(unit_id, type) do
    Combatant.new!(%{
      unit_id: unit_id,
      unit_type: type,
      base_stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      combat_stats: %{atk: 0, def: 0, hit: 200, flee: 0, perfect_dodge: 0},
      progression: %{base_level: 1, job_level: 1},
      element: {:neutral, 1},
      race: :formless,
      size: :medium,
      weapon: %{type: :fist, element: :neutral, size: :medium},
      attack_range: 5,
      attack_delay_ms: 500,
      position: {150, 150},
      map_name: @map_name
    })
  end

  defp stub_mob_target(target_id) do
    target = combatant(target_id, :mob)

    target_state =
      struct(MobState, %{
        instance_id: target_id,
        hp: 100,
        max_hp: 100,
        is_dead: false,
        x: 150,
        y: 150,
        map_name: @map_name
      })

    Mimic.copy(MobState)
    stub(MobState, :to_combatant, fn ^target_state -> target end)

    stub(UnitRegistry, :get_unit, fn
      :mob, ^target_id -> {:ok, {MobState, target_state, self()}}
    end)

    stub(SpatialIndex, :get_unit_position, fn :mob, ^target_id -> {:ok, {150, 150, @map_name}} end)
  end

  defp stub_player_target(target_id) do
    target_pid = spawn(fn -> Process.sleep(:infinity) end)
    target = combatant(target_id, :player)

    target_state = %PlayerState{
      character_id: target_id,
      action_state: :idle,
      x: 150,
      y: 150,
      map_name: @map_name,
      stats: %{current_state: %{hp: 100}}
    }

    Mimic.copy(PlayerState)
    stub(PlayerState, :to_combatant, fn %PlayerState{} -> target end)

    stub(UnitRegistry, :get_unit, fn
      :mob, ^target_id -> {:error, :not_found}
      :player, ^target_id -> {:ok, {PlayerState, target_state, target_pid}}
    end)

    stub(UnitRegistry, :get_player_pid, fn ^target_id -> {:ok, target_pid} end)
    stub(PlayerSession, :get_current_stats, fn ^target_pid -> target_state.stats end)
    stub(PlayerSession, :get_state, fn ^target_pid -> %{game_state: target_state} end)

    target_pid
  end

  defp stub_entity_info(unit_type, unit_id) do
    stub(UnitRegistry, :get_unit_info, fn ^unit_type, ^unit_id ->
      {:ok,
       %{
         unit_id: unit_id,
         unit_type: unit_type,
         race: :formless,
         element: :neutral,
         element_level: 1,
         boss_flag: false,
         size: :medium,
         stats: %{
           max_hp: 1000,
           max_sp: 0,
           hp: 1000,
           sp: 0,
           level: 50,
           base_level: 50,
           str: 1,
           agi: 1,
           vit: 1,
           int: 1,
           dex: 1,
           luk: 1,
           mdef: 0
         }
       }}
    end)
  end

  setup do
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)

    stub(DamageCalculator, :calculate_damage, fn _attacker, _target, _opts ->
      {:ok, %{damage: 100, is_critical: false}}
    end)

    :ok
  end

  describe "aggregate weapon-swing absorption" do
    test "one dual-component swing spends one mob absorber budget" do
      test_pid = self()
      stub_mob_target(@mob_id)
      stub_entity_info(:mob, @mob_id)

      :ok = StatusInterpreter.apply_status(:mob, @mob_id, :sc_kyrie, val2: 10_000, val3: 2)

      expect(MobSession, :apply_damage, fn _pid, 0, @caster_id ->
        send(test_pid, :damage_applied)
        :ok
      end)

      swing = %HandedAttack{
        primary: %{damage: 100, is_critical: false},
        secondary: %{damage: 50, is_critical: false},
        raw_total: 150,
        display_divisions: 1,
        outcome: :hit,
        primary_element: :neutral
      }

      {settled, :ok} =
        DamageApplication.apply_weapon_swing(
          :mob,
          self(),
          @mob_id,
          swing,
          %{dmg_type: :physical, is_short: true, element: :neutral},
          @caster_id
        )

      assert settled.primary.damage + settled.secondary.damage == 0
      assert_received :damage_applied

      assert %{state: %{shield_hp: 9_850, hits_remaining: 1}} =
               StatusStorage.get_status(:mob, @mob_id, :sc_kyrie)
    end
  end

  describe "pre-damage absorb hook on skill damage" do
    test "an absorbing status on a mob defender reduces incoming damage" do
      attacker = %FakeUnit{combatant: combatant(@caster_id, :player), x: 150, y: 150}
      test_pid = self()

      stub_mob_target(@mob_id)
      stub_entity_info(:mob, @mob_id)

      :ok = StatusInterpreter.apply_status(:mob, @mob_id, :sc_kyrie, val2: 10_000, val3: 2)

      stub(MobSession, :apply_damage, fn _pid, damage, _attacker_id ->
        send(test_pid, {:damage_applied, damage})
        :ok
      end)

      assert :ok =
               Combat.execute_skill_attack(attacker, @mob_id,
                 skill_id: @skill_id,
                 skill_level: @skill_level
               )

      assert_received {:damage_applied, 0}
    end

    test "a player defender with the same status is absorbed identically to today" do
      mob_attacker = %FakeUnit{combatant: combatant(@caster_id, :mob), x: 150, y: 150}
      test_pid = self()

      target_pid = stub_player_target(@player_id)
      stub_entity_info(:player, @player_id)

      :ok = StatusInterpreter.apply_status(:player, @player_id, :sc_kyrie, val2: 10_000, val3: 2)

      stub(PlayerSession, :apply_damage, fn ^target_pid, damage, _attacker_id ->
        send(test_pid, {:damage_applied, damage})
        :ok
      end)

      assert :ok =
               Combat.execute_skill_attack(mob_attacker, @player_id,
                 skill_id: @skill_id,
                 skill_level: @skill_level
               )

      assert_received {:damage_applied, 0}
    end

    test "a mob defender with no active statuses takes full damage" do
      attacker = %FakeUnit{combatant: combatant(@caster_id, :player), x: 150, y: 150}
      test_pid = self()

      stub_mob_target(@mob_id)

      stub(MobSession, :apply_damage, fn _pid, damage, _attacker_id ->
        send(test_pid, {:damage_applied, damage})
        :ok
      end)

      assert :ok =
               Combat.execute_skill_attack(attacker, @mob_id,
                 skill_id: @skill_id,
                 skill_level: @skill_level
               )

      assert_received {:damage_applied, 100}
    end
  end
end
