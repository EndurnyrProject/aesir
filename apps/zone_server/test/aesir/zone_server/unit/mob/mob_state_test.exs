defmodule Aesir.ZoneServer.Unit.Mob.MobStateTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Unit.Mob.MobState

  defp build_mob_state do
    mob_data = %MobDefinition{
      id: 1001,
      aegis_name: "test_mob",
      name: "Test Mob",
      level: 25,
      hp: 1000,
      sp: 0,
      stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15},
      atk: 50,
      matk: 60,
      def: 25,
      mdef: 10,
      attack_range: 1,
      walk_speed: 200,
      attack_delay: 1200,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      element: {:neutral, 1},
      race: :formless,
      size: :medium
    }

    spawn_ref = %MobSpawn{
      mob: 1001,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    MobState.new(1, mob_data, spawn_ref, "prontera", 100, 100)
  end

  describe "stolen_from" do
    test "a freshly built mob state is not stolen from" do
      state = build_mob_state()

      assert state.stolen_from == false
    end

    test "mark_stolen/1 sets the stolen_from flag to true" do
      state = build_mob_state()

      updated = MobState.mark_stolen(state)

      assert updated.stolen_from == true
    end
  end

  describe "to_combatant/1 magic stats" do
    test "carries matk, mdef and soft_mdef in combat_stats" do
      state = build_mob_state()

      combatant = MobState.to_combatant(state)

      assert combatant.combat_stats.matk == 60
      assert combatant.combat_stats.mdef == 10
      assert combatant.combat_stats.soft_mdef == div(20 + 25, 4)
    end

    test "soft_mdef uses renewal non-PC formula div(int + level, 4)" do
      base = build_mob_state()
      %MobDefinition{} = base_mob_data = base.mob_data

      mob_data = %MobDefinition{
        base_mob_data
        | level: 50,
          stats: %{base_mob_data.stats | int: 30}
      }

      state = %MobState{base | mob_data: mob_data}

      combatant = MobState.to_combatant(state)

      assert combatant.combat_stats.soft_mdef == 20
    end
  end

  describe "to_combatant/1 attack delay" do
    test "carries the mob's attack_delay as attack_delay_ms" do
      state = build_mob_state()

      combatant = MobState.to_combatant(state)

      assert combatant.attack_delay_ms == state.mob_data.attack_delay
    end
  end

  describe "to_combatant/1 passive skill levels" do
    test "mob combatant has divine_protection_level and demon_bane_level of 0" do
      state = build_mob_state()

      combatant = MobState.to_combatant(state)

      assert combatant.divine_protection_level == 0
      assert combatant.demon_bane_level == 0
    end
  end
end
