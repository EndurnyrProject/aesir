defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.AutoCounterTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  describe "before_weapon_hit interception" do
    test "a melee swing from the front arc within range is countered with a forced crit" do
      test_pid = self()
      defender_id = 8001
      defender = build_defender(defender_id, 150, 150, 6)
      arm(defender_id, 3)

      stub_defender(defender_id, defender)
      stub_entity_info()

      stub(Combat, :execute_skill_attack, fn state, target_id, opts ->
        send(test_pid, {:counter, state, target_id, opts})
        :ok
      end)

      info = attack_info({:mob, 9001}, defender_id, attacker_position: {151, 150}, distance: 1)

      assert {:intercept, :auto_counter} =
               Interpreter.before_weapon_hit(:mob, defender_id, info)

      refute StatusStorage.has_status?(:mob, defender_id, :sc_auto_counter)

      assert_received {:counter, ^defender, 9001, opts}
      assert Keyword.fetch!(opts, :force_crit) == true
      assert Keyword.fetch!(opts, :skill_ratio) == 100 + 10 * 3
      assert Keyword.fetch!(opts, :skill_level) == 3
    end

    test "a swing from behind the defender resolves normally and the stance survives" do
      defender_id = 8002
      defender = build_defender(defender_id, 150, 150, 6)
      arm(defender_id, 5)

      stub_defender(defender_id, defender)
      stub_entity_info()
      reject(&Combat.execute_skill_attack/3)

      info = attack_info({:mob, 9002}, defender_id, attacker_position: {149, 150}, distance: 1)

      assert :continue = Interpreter.before_weapon_hit(:mob, defender_id, info)
      assert StatusStorage.has_status?(:mob, defender_id, :sc_auto_counter)
    end

    test "a ranged basic attack never triggers the counter" do
      defender_id = 8003
      defender = build_defender(defender_id, 150, 150, 6)
      arm(defender_id, 5)

      stub_defender(defender_id, defender)
      stub_entity_info()
      reject(&Combat.execute_skill_attack/3)

      info =
        attack_info({:mob, 9003}, defender_id,
          attacker_position: {151, 150},
          attacker_short?: false,
          distance: 1
        )

      assert :continue = Interpreter.before_weapon_hit(:mob, defender_id, info)
      assert StatusStorage.has_status?(:mob, defender_id, :sc_auto_counter)
    end

    test "a front-arc melee swing beyond weapon range plus one does not trigger" do
      defender_id = 8004
      defender = build_defender(defender_id, 150, 150, 6)
      arm(defender_id, 5)

      stub_defender(defender_id, defender)
      stub_entity_info()
      reject(&Combat.execute_skill_attack/3)

      info = attack_info({:mob, 9004}, defender_id, attacker_position: {153, 150}, distance: 3)

      assert :continue = Interpreter.before_weapon_hit(:mob, defender_id, info)
      assert StatusStorage.has_status?(:mob, defender_id, :sc_auto_counter)
    end

    test "an expired stance (absent status) yields a normal hit" do
      defender_id = 8005
      defender = build_defender(defender_id, 150, 150, 6)

      stub_defender(defender_id, defender)
      stub_entity_info()
      reject(&Combat.execute_skill_attack/3)

      info = attack_info({:mob, 9005}, defender_id, attacker_position: {151, 150}, distance: 1)

      assert :continue = Interpreter.before_weapon_hit(:mob, defender_id, info)
    end

    test "a same-cell melee swing is countered regardless of facing" do
      test_pid = self()
      defender_id = 8006
      defender = build_defender(defender_id, 150, 150, 0)
      arm(defender_id, 1)

      stub_defender(defender_id, defender)
      stub_entity_info()

      stub(Combat, :execute_skill_attack, fn _state, target_id, opts ->
        send(test_pid, {:counter, target_id, opts})
        :ok
      end)

      info = attack_info({:mob, 9006}, defender_id, attacker_position: {150, 150}, distance: 0)

      assert {:intercept, :auto_counter} =
               Interpreter.before_weapon_hit(:mob, defender_id, info)

      assert_received {:counter, 9006, opts}
      assert Keyword.fetch!(opts, :skill_ratio) == 110
    end
  end

  defp arm(defender_id, level) do
    :ok = StatusStorage.apply_status(:mob, defender_id, :sc_auto_counter, val1: level)
  end

  defp attack_info(attacker, defender_id, opts) do
    %{
      attacker: attacker,
      target: {:mob, defender_id},
      attacker_boss?: false,
      attacker_root_level: 0,
      attacker_position: Keyword.fetch!(opts, :attacker_position),
      attacker_short?: Keyword.get(opts, :attacker_short?, true),
      distance: Keyword.fetch!(opts, :distance)
    }
  end

  defp stub_defender(defender_id, defender) do
    stub(TargetResolver, :resolve, fn ^defender_id -> {:ok, self(), defender, :mob} end)
  end

  defp stub_entity_info do
    stub(UnitRegistry, :get_unit_info, fn _type, id ->
      {:ok,
       %{
         unit_id: id,
         race: :human,
         element: :neutral,
         boss_flag: false,
         size: :medium,
         stats: %{max_hp: 1_000, max_sp: 100}
       }}
    end)
  end

  defp build_defender(id, x, y, dir) do
    mob_data = %MobDefinition{
      id: 1002,
      aegis_name: "test_mob",
      name: "Test Mob",
      level: 10,
      hp: 100,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      attack_range: 1,
      size: :medium,
      race: :formless,
      element: {:neutral, 1},
      walk_speed: 200,
      attack_delay: 1_000,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      modes: []
    }

    spawn_ref = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: x, y: y}
    }

    id
    |> MobState.new(mob_data, spawn_ref, "prontera", x, y)
    |> Map.put(:dir, dir)
  end
end
