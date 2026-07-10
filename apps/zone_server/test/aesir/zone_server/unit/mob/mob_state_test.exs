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

  describe "initiated_by_self?" do
    test "a freshly built mob state did not initiate combat itself" do
      state = build_mob_state()

      assert state.initiated_by_self? == false
    end

    test "set_initiated/2 toggles the initiated_by_self? flag" do
      state = build_mob_state()

      assert MobState.set_initiated(state, true).initiated_by_self? == true
      assert MobState.set_initiated(state, false).initiated_by_self? == false
    end
  end

  describe "rude attacks" do
    test "a freshly built mob state has no rude attacks recorded" do
      state = build_mob_state()

      assert state.rude_attack_count == 0
      assert state.rude_attacked? == false
    end

    test "note_rude_attack/1 increments the count and raises the flag" do
      state = build_mob_state()

      updated = MobState.note_rude_attack(state)

      assert updated.rude_attack_count == 1
      assert updated.rude_attacked? == true

      again = MobState.note_rude_attack(updated)

      assert again.rude_attack_count == 2
      assert again.rude_attacked? == true
    end

    test "clear_rude_attacked/1 clears the flag but preserves the count" do
      state = build_mob_state() |> MobState.note_rude_attack()

      cleared = MobState.clear_rude_attacked(state)

      assert cleared.rude_attacked? == false
      assert cleared.rude_attack_count == 1
    end
  end

  describe "skill cooldowns" do
    test "a freshly built mob state has no skill cooldowns" do
      state = build_mob_state()

      assert state.skill_cooldowns == %{}
    end

    test "a skill with no cooldown entry is ready" do
      state = build_mob_state()

      assert MobState.skill_ready?(state, "NPC_FIREATTACK", 0)
    end

    test "put_skill_cooldown/3 gates the skill until now reaches expires_at" do
      state =
        build_mob_state()
        |> MobState.put_skill_cooldown("NPC_FIREATTACK", 5_000)

      assert state.skill_cooldowns == %{"NPC_FIREATTACK" => 5_000}
      refute MobState.skill_ready?(state, "NPC_FIREATTACK", 4_999)
      assert MobState.skill_ready?(state, "NPC_FIREATTACK", 5_000)
      assert MobState.skill_ready?(state, "NPC_FIREATTACK", 5_001)
    end
  end

  describe "casting" do
    test "a freshly built mob state is not casting" do
      state = build_mob_state()

      assert state.casting == nil
    end

    test "set_casting/2 and clear_casting/1 round-trip" do
      cast = %{skill: "NPC_FIREATTACK", target: 42, complete_at: 5_000}
      state = build_mob_state()

      set = MobState.set_casting(state, cast)
      assert set.casting == cast

      assert MobState.clear_casting(set).casting == nil
    end
  end

  describe "master link" do
    test "a freshly built mob state has no master" do
      state = build_mob_state()

      assert state.master_id == nil
    end

    test "set_master/2 sets the master instance id" do
      state = build_mob_state()

      assert MobState.set_master(state, 99).master_id == 99
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

    test "mob MATK band is deterministic: matk_min == matk_max == matk" do
      state = build_mob_state()

      combatant = MobState.to_combatant(state)

      assert combatant.combat_stats.matk_min == 60
      assert combatant.combat_stats.matk_max == 60
      assert combatant.combat_stats.matk_min == combatant.combat_stats.matk
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
