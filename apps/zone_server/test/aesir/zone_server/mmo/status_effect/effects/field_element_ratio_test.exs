defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.FieldElementRatioTest do
  @moduledoc """
  The element fields' ratio bonus has to survive the whole way from the status
  module to the element table.

  These drive the real status storage, the real modifier aggregation and the
  real damage calculators, so a bonus that is only correct in `modifiers/2` but
  never read by the combat engine fails here. The element table is observed
  rather than the damage number, because base attack and MATK carry random
  variance.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.CriticalHits
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @attacker_id 1001

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})

    Mimic.copy(CriticalHits)
    Mimic.copy(ElementModifiers)
    Mimic.copy(UnitRegistry)

    stub(CriticalHits, :calculate_critical_hit, fn _, damage ->
      %{damage: damage, is_critical: false}
    end)

    # Reports the ratio the element table actually produced, bonus included.
    stub(ElementModifiers, :get_modifier, fn attack_element,
                                             defense_element,
                                             defense_level,
                                             ratio_bonus ->
      ratio =
        call_original(ElementModifiers, :get_modifier, [
          attack_element,
          defense_element,
          defense_level,
          ratio_bonus
        ])

      send(self(), {:element_ratio, attack_element, ratio_bonus, ratio})
      ratio
    end)

    stub(UnitRegistry, :get_unit_info, fn _, _ -> {:ok, %{stats: %{}}} end)

    :ok
  end

  defp fire_attacker do
    CombatTestHelper.create_player_combatant(
      unit_id: @attacker_id,
      str: 50,
      weapon_element: :fire
    )
  end

  defp earth_defender, do: CombatTestHelper.create_mob_combatant(element: {:earth, 1})

  describe "Volcano" do
    test "a physical fire attack inside Volcano lv5 gains 20 ratio points end to end" do
      :ok =
        StatusStorage.apply_status(:player, @attacker_id, :sc_volcano, val1: 5, duration: 30_000)

      assert {:ok, _} = DamageCalculator.calculate_damage(fire_attacker(), earth_defender())

      # fire vs earth is 2.0 on the table; the field adds 20 points => 2.2
      assert_received {:element_ratio, :fire, 20, ratio}
      assert_in_delta ratio, 2.2, 0.0001
    end

    test "a magic fire attack inside Volcano lv5 gains 20 ratio points end to end" do
      :ok =
        StatusStorage.apply_status(:player, @attacker_id, :sc_volcano, val1: 5, duration: 30_000)

      caster = %{unit_type: :player, unit_id: @attacker_id, combat_stats: %{matk: 200}}

      target = %{
        unit_type: :mob,
        unit_id: 2001,
        element: {:earth, 1},
        combat_stats: %{mdef: 0, soft_mdef: 0}
      }

      assert {:ok, _} =
               MagicDamageCalculator.calculate_magic_damage(caster, target, element: :fire)

      assert_received {:element_ratio, :fire, 20, ratio}
      assert_in_delta ratio, 2.2, 0.0001
    end

    test "without Volcano the same fire attack keeps the plain table ratio" do
      assert {:ok, _} = DamageCalculator.calculate_damage(fire_attacker(), earth_defender())

      assert_received {:element_ratio, :fire, 0, ratio}
      assert_in_delta ratio, 2.0, 0.0001
    end

    test "Volcano does not touch a non-fire attack" do
      :ok =
        StatusStorage.apply_status(:player, @attacker_id, :sc_volcano, val1: 5, duration: 30_000)

      attacker = CombatTestHelper.create_player_combatant(unit_id: @attacker_id, str: 50)

      assert {:ok, _} = DamageCalculator.calculate_damage(attacker, earth_defender())

      assert_received {:element_ratio, :neutral, 0, _ratio}
    end
  end

  describe "Deluge and Violent Gale" do
    test "a water attack inside Deluge lv5 gains 20 ratio points end to end" do
      :ok =
        StatusStorage.apply_status(:player, @attacker_id, :sc_deluge, val1: 5, duration: 30_000)

      attacker =
        CombatTestHelper.create_player_combatant(
          unit_id: @attacker_id,
          str: 50,
          weapon_element: :water
        )

      assert {:ok, _} = DamageCalculator.calculate_damage(attacker, earth_defender())

      # water vs earth is 1.0 on the table; the field adds 20 points => 1.2
      assert_received {:element_ratio, :water, 20, ratio}
      assert_in_delta ratio, 1.2, 0.0001
    end

    test "a wind attack inside Violent Gale lv5 gains 20 ratio points end to end" do
      :ok =
        StatusStorage.apply_status(:player, @attacker_id, :sc_violentgale,
          val1: 5,
          duration: 30_000
        )

      attacker =
        CombatTestHelper.create_player_combatant(
          unit_id: @attacker_id,
          str: 50,
          weapon_element: :wind
        )

      assert {:ok, _} = DamageCalculator.calculate_damage(attacker, earth_defender())

      # wind vs earth is 0.9 on the table; the field adds 20 points => 1.1
      assert_received {:element_ratio, :wind, 20, ratio}
      assert_in_delta ratio, 1.1, 0.0001
    end
  end

  describe "overlapping fields" do
    test "two element fields each keep their own element's ratio bonus" do
      :ok =
        StatusStorage.apply_status(:player, @attacker_id, :sc_volcano, val1: 5, duration: 30_000)

      :ok =
        StatusStorage.apply_status(:player, @attacker_id, :sc_deluge, val1: 3, duration: 30_000)

      assert {:ok, _} = DamageCalculator.calculate_damage(fire_attacker(), earth_defender())

      assert_received {:element_ratio, :fire, 20, _}
    end
  end
end
