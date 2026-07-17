defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ElementalChangeTest do
  @moduledoc """
  SC_ELEMENTALCHANGE overrides a mob's *defense* element only.

  Exercises the real `MobState.to_combatant/1` fold-in and the damage
  pipeline's element-resistance lookup end to end, so a defense/attack element
  mix-up or a broken fold-in fails loudly. `weapon_endow_test.exs` covers the
  attack-element family this status must not be confused with.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.CriticalHits
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @mob_instance_id 3001

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})

    Mimic.copy(CriticalHits)
    Mimic.copy(ElementModifiers)

    stub(CriticalHits, :calculate_critical_hit, fn _, damage ->
      %{damage: damage, is_critical: false}
    end)

    stub(ElementModifiers, :get_modifier, fn attack_element,
                                             defense_element,
                                             defense_level,
                                             ratio_bonus ->
      send(self(), {:defense_element, defense_element, defense_level})

      call_original(ElementModifiers, :get_modifier, [
        attack_element,
        defense_element,
        defense_level,
        ratio_bonus
      ])
    end)

    :ok
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
      element: {:fire, 1},
      race: :formless,
      size: :medium
    }

    spawn_ref = %MobSpawn{
      mob: 1001,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    state = MobState.new(@mob_instance_id, mob_data, spawn_ref, "prontera", 100, 100)
    UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())
    state
  end

  defp attack_mob(mob_state) do
    attacker = CombatTestHelper.create_player_combatant(str: 50)
    defender = MobState.to_combatant(mob_state)

    assert {:ok, _} = DamageCalculator.calculate_damage(attacker, defender)
  end

  describe "without an override" do
    test "damage resolves the modifier table against the mob's native element" do
      state = build_mob_state()

      attack_mob(state)

      assert_received {:defense_element, :fire, 1}
    end
  end

  describe "with an active sc_elementalchange" do
    test "damage resolves the modifier table against the overridden element" do
      state = build_mob_state()

      StatusStorage.apply_status(:mob, state.instance_id, :sc_elementalchange,
        val1: 2,
        val2: 1,
        duration: 30_000
      )

      attack_mob(state)

      assert_received {:defense_element, :water, 2}
    end

    test "the mob's own attack element is untouched" do
      state = build_mob_state()

      StatusStorage.apply_status(:mob, state.instance_id, :sc_elementalchange,
        val1: 2,
        val2: 1,
        duration: 30_000
      )

      combatant = MobState.to_combatant(state)

      assert combatant.weapon.element == :fire
    end
  end

  describe "re-applying the status" do
    test "replaces the element instead of stacking (no merge_modifiers collision)" do
      state = build_mob_state()

      StatusStorage.apply_status(:mob, state.instance_id, :sc_elementalchange,
        val1: 1,
        val2: 1,
        duration: 30_000
      )

      StatusStorage.apply_status(:mob, state.instance_id, :sc_elementalchange,
        val1: 1,
        val2: 6,
        duration: 30_000
      )

      attack_mob(state)

      assert_received {:defense_element, :holy, 1}
    end
  end
end
