defmodule Aesir.ZoneServer.Mmo.Combat.MiscDamageCalculatorTest do
  @moduledoc """
  Tests for the renewal BF_MISC damage calculator.

  Misc damage applies the element modifier and the renewal hard-DEF (eDEF)
  reduction `dmg * (4000 + eDEF) / (4000 + 10*eDEF)`, ignores soft-DEF and MDEF,
  and floors at 1. Misc never crits.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.Combat.MiscDamageCalculator
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator

  setup :set_mimic_from_context

  setup do
    # The flat BF_MISC path now resolves the attacker's status modifiers for the
    # element-ratio seam; default to none so existing damage assertions hold.
    Mimic.copy(ModifierCalculator)
    stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)
    :ok
  end

  defp attacker do
    %{unit_type: :player, unit_id: 1001, combat_stats: %{}}
  end

  defp defender(hard_def, opts \\ []) do
    %{
      unit_type: :mob,
      unit_id: 2001,
      combat_stats: %{
        def: hard_def,
        soft_mdef: Keyword.get(opts, :soft_mdef, 0),
        mdef: Keyword.get(opts, :mdef, 0)
      },
      element: Keyword.get(opts, :element, {:neutral, 1})
    }
  end

  describe "calculate_misc_damage/3" do
    test "applies NO defense reduction: base damage passes through neutral-on-neutral" do
      # rAthena battle_calc_misc_attack never reduces by DEF; hard def 10 is ignored.
      assert {:ok, %{damage: 100, is_critical: false}} =
               MiscDamageCalculator.calculate_misc_damage(attacker(), defender(10),
                 base_damage: 100
               )
    end

    test "ignores hard-DEF, soft-DEF and MDEF entirely" do
      with_defenses = defender(999, soft_mdef: 999, mdef: 999)
      without_defenses = defender(0, soft_mdef: 0, mdef: 0)

      assert MiscDamageCalculator.calculate_misc_damage(attacker(), with_defenses,
               base_damage: 100
             ) ==
               MiscDamageCalculator.calculate_misc_damage(attacker(), without_defenses,
                 base_damage: 100
               )
    end

    test "applies the element modifier (no defense)" do
      # fire vs earth (level 1) = 2.0: 100 -> 200; no DEF reduction
      assert {:ok, %{damage: 200, is_critical: false}} =
               MiscDamageCalculator.calculate_misc_damage(
                 attacker(),
                 defender(10, element: {:earth, 1}),
                 base_damage: 100,
                 element: :fire
               )
    end

    test "ignore_element bypasses the element table without changing misc damage otherwise" do
      assert {:ok, %{damage: 100, is_critical: false}} =
               MiscDamageCalculator.calculate_misc_damage(
                 attacker(),
                 defender(10, element: {:earth, 1}),
                 base_damage: 100,
                 element: :fire,
                 ignore_element: true
               )
    end

    test "floors damage at 1 when base is 0" do
      assert {:ok, %{damage: 1, is_critical: false}} =
               MiscDamageCalculator.calculate_misc_damage(attacker(), defender(0), base_damage: 0)
    end

    test "fixed_damage short-circuits the whole pipeline" do
      assert {:ok, %{damage: 50, is_critical: false}} =
               MiscDamageCalculator.calculate_misc_damage(attacker(), defender(999),
                 fixed_damage: 50,
                 base_damage: 9999,
                 element: :fire
               )
    end

    test "a matching {:element_ratio, _} attacker modifier raises the element ratio" do
      # Attacker standing on a fire field: fire vs earth L1 = 2.0, plus 20 ratio
      # points -> 2.2. 100 -> 220. (Volcano/Deluge/Violent Gale reaching BF_MISC.)
      stub(ModifierCalculator, :get_all_modifiers, fn :player, 1001 ->
        %{{:element_ratio, :fire} => 20}
      end)

      assert {:ok, %{damage: 220, is_critical: false}} =
               MiscDamageCalculator.calculate_misc_damage(
                 attacker(),
                 defender(10, element: {:earth, 1}),
                 base_damage: 100,
                 element: :fire
               )
    end

    test "a non-matching {:element_ratio, _} modifier is ignored" do
      # Wind-field ratio does not touch a fire attack.
      stub(ModifierCalculator, :get_all_modifiers, fn :player, 1001 ->
        %{{:element_ratio, :wind} => 20}
      end)

      assert {:ok, %{damage: 200, is_critical: false}} =
               MiscDamageCalculator.calculate_misc_damage(
                 attacker(),
                 defender(10, element: {:earth, 1}),
                 base_damage: 100,
                 element: :fire
               )
    end

    test "the ratio bonus is added unclamped over an immunity (0.0 + 20 pts -> 0.20)" do
      # Faithful to rAthena: the element-ratio points are added to the raw
      # attribute ratio with no floor, so poison-on-poison (0.0) + 20 -> 0.20.
      stub(ModifierCalculator, :get_all_modifiers, fn :player, 1001 ->
        %{{:element_ratio, :poison} => 20}
      end)

      assert {:ok, %{damage: 20, is_critical: false}} =
               MiscDamageCalculator.calculate_misc_damage(
                 attacker(),
                 defender(10, element: {:poison, 1}),
                 base_damage: 100,
                 element: :poison
               )
    end
  end
end
