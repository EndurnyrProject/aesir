defmodule Aesir.ZoneServer.Unit.Mob.MobStateTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  defmodule TestAtkBuff do
    @moduledoc false
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_mob_atk_buff,
      no_dispel: false,
      properties: [:buff]

    @impl true
    def modifiers(instance, _context), do: %{atk: instance.val1}
  end

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

  describe "walk delays" do
    test "block movement until their monotonic expiry without shortening an existing delay" do
      state = build_mob_state()
      delayed = MobState.apply_walk_delay(state, 1_600, 10_000)
      extended = MobState.apply_walk_delay(delayed, 500, 10_500)

      assert extended.walk_delay_until == 11_600
      assert MobState.walk_delayed?(extended, 11_599)
      refute MobState.walk_delayed?(extended, 11_600)
    end

    test "the zero sentinel does not block a negative monotonic clock" do
      state = build_mob_state()
      now = System.monotonic_time(:millisecond)

      refute MobState.walk_delayed?(state, now)

      delayed = MobState.apply_walk_delay(state, 1_600, now)
      assert delayed.walk_delay_until == now + 1_600
      assert MobState.walk_delayed?(delayed, now)
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
    test "mob combatant has divine_protection_level, demon_bane_level and dragonology_level of 0" do
      state = build_mob_state()

      combatant = MobState.to_combatant(state)

      assert combatant.divine_protection_level == 0
      assert combatant.demon_bane_level == 0
      assert combatant.dragonology_level == 0
    end
  end

  describe "to_combatant/1 class and equip_modifiers" do
    test "a normal mob (no :boss mode) combatant has class :normal" do
      state = build_mob_state()

      combatant = MobState.to_combatant(state)

      assert combatant.class == :normal
    end

    test "a mob with the :boss mode has combatant class :boss" do
      base = build_mob_state()
      mob_data = %{base.mob_data | modes: [:boss]}
      state = %MobState{base | mob_data: mob_data}

      combatant = MobState.to_combatant(state)

      assert combatant.class == :boss
    end

    test "mob combatant equip_modifiers is always an empty map" do
      state = build_mob_state()

      combatant = MobState.to_combatant(state)

      assert combatant.equip_modifiers == %{}
    end
  end

  describe "to_combatant/1 status modifiers" do
    test "an ATK-raising status on the mob raises combat_stats.atk" do
      state = build_mob_state()
      Registry.register_module(TestAtkBuff)
      UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())

      baseline = MobState.to_combatant(state).combat_stats.atk

      StatusStorage.apply_status(:mob, state.instance_id, :sc_test_mob_atk_buff, val1: 30)

      buffed = MobState.to_combatant(state).combat_stats.atk

      assert buffed == baseline + 30
      assert buffed > baseline
    end

    test "with no active statuses, to_combatant/1 is unchanged from the un-buffed values" do
      state = build_mob_state()
      UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())

      combatant = MobState.to_combatant(state)

      assert combatant.combat_stats.atk == 50
      assert combatant.combat_stats.def == 25
      assert combatant.base_stats.str == 40
    end
  end

  describe "get_stats/1 status modifiers" do
    test "with no active statuses, get_stats/1 is unchanged from the un-buffed values" do
      state = build_mob_state()

      stats = MobState.get_stats(state)

      assert stats.atk == 50
      assert stats.def == 25
      assert stats.str == 40
    end
  end

  describe "sc_elementalchange defense element override" do
    test "to_combatant/1 uses the base element with no override present" do
      state = build_mob_state()
      UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())

      combatant = MobState.to_combatant(state)

      assert combatant.element == {:neutral, 1}
    end

    test "get_element/1 returns the base element with no override present" do
      state = build_mob_state()
      UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())

      assert MobState.get_element(state) == {:neutral, 1}
    end

    test "to_combatant/1 folds an active override into the element field" do
      state = build_mob_state()
      UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())

      StatusStorage.apply_status(:mob, state.instance_id, :sc_elementalchange, val1: 2, val2: 3)

      combatant = MobState.to_combatant(state)

      assert combatant.element == {:fire, 2}
    end

    test "get_element/1 folds an active override" do
      state = build_mob_state()
      UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())

      StatusStorage.apply_status(:mob, state.instance_id, :sc_elementalchange, val1: 2, val2: 3)

      assert MobState.get_element(state) == {:fire, 2}
    end

    test "the override never changes the mob's own attack element" do
      state = build_mob_state()
      UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())

      StatusStorage.apply_status(:mob, state.instance_id, :sc_elementalchange, val1: 2, val2: 3)

      combatant = MobState.to_combatant(state)

      assert combatant.weapon.element == :neutral
      assert combatant.weapon.element == elem(state.mob_data.element, 0)
    end

    test "re-applying the status replaces the override instead of stacking" do
      state = build_mob_state()
      UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())

      StatusStorage.apply_status(:mob, state.instance_id, :sc_elementalchange, val1: 1, val2: 3)
      StatusStorage.apply_status(:mob, state.instance_id, :sc_elementalchange, val1: 1, val2: 6)

      combatant = MobState.to_combatant(state)

      assert combatant.element == {:holy, 1}
    end

    test "a mob with an active status but no override on the mob keeps the base element" do
      state = build_mob_state()
      Registry.register_module(TestAtkBuff)
      UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())

      StatusStorage.apply_status(:mob, state.instance_id, :sc_test_mob_atk_buff, val1: 30)

      assert MobState.get_element(state) == {:neutral, 1}
      assert MobState.to_combatant(state).element == {:neutral, 1}
    end
  end
end
