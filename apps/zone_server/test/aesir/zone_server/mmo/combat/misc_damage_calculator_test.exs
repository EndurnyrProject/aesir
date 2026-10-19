defmodule Aesir.ZoneServer.Mmo.Combat.MiscDamageCalculatorTest do
  @moduledoc """
  Tests for the mode-aware BF_MISC damage calculator.

  Misc damage takes a player target's card reductions, the skill damage rates
  and the active element modifier, ignores DEF and MDEF, has no minimum, and
  never crits. The skill's IgnoreDefCard and IgnoreElement flags come from its
  definition.
  """

  use ExUnit.Case, async: true
  use Mimic

  import Bitwise

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.MiscDamageCalculator
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator

  setup :set_mimic_from_context

  setup do
    # The flat BF_MISC path now resolves the attacker's status modifiers for the
    # element-ratio seam; default to none so existing damage assertions hold.
    Mimic.copy(ModifierCalculator)
    stub(ModifierCalculator, :get_battle_modifiers, fn _, _ -> %{} end)
    :ok
  end

  defp mode_value(renewal, pre_renewal) do
    %{renewal: renewal, pre_renewal: pre_renewal}[GameMode.mode()]
  end

  # Blitz Beat: a misc skill with neither IgnoreDefCard nor IgnoreElement.
  @blitz_beat 129
  @land_mine 116
  @bio_explosion 8016
  @short_misc BattleFlags.build(:misc, :short, true)
  @any_range_misc @short_misc ||| BattleFlags.range_bit(:long)
  @any_range_weapon_skill BattleFlags.build(:weapon, :short, true) |||
                            BattleFlags.range_bit(:long)

  defp attacker do
    struct(Combatant,
      unit_type: :player,
      unit_id: 1001,
      combat_stats: %{},
      race: :demi_human,
      size: :medium
    )
  end

  defp player_defender(equip_modifiers) do
    struct(Combatant,
      unit_type: :player,
      unit_id: 3001,
      combat_stats: %{},
      element: {:neutral, 1},
      race: :demi_human,
      size: :medium,
      equip_modifiers: equip_modifiers
    )
  end

  defp misc(opts), do: Keyword.merge([skill_id: @blitz_beat, attack_flag: @short_misc], opts)

  defp defender(hard_def, opts \\ []) do
    struct(Combatant,
      unit_type: :mob,
      unit_id: 2001,
      combat_stats: %{
        def: hard_def,
        soft_mdef: Keyword.get(opts, :soft_mdef, 0),
        mdef: Keyword.get(opts, :mdef, 0)
      },
      element: Keyword.get(opts, :element, {:neutral, 1})
    )
  end

  describe "calculate_misc_damage/3" do
    test "applies NO defense reduction: base damage passes through neutral-on-neutral" do
      # rAthena battle_calc_misc_attack never reduces by DEF; hard def 10 is ignored.
      assert {:ok, %{damage: 100, is_critical: false}} =
               MiscDamageCalculator.calculate_misc_damage(
                 attacker(),
                 defender(10),
                 misc(base_damage: 100)
               )
    end

    test "ignores hard-DEF, soft-DEF and MDEF entirely" do
      with_defenses = defender(999, soft_mdef: 999, mdef: 999)
      without_defenses = defender(0, soft_mdef: 0, mdef: 0)

      assert MiscDamageCalculator.calculate_misc_damage(
               attacker(),
               with_defenses,
               misc(base_damage: 100)
             ) ==
               MiscDamageCalculator.calculate_misc_damage(
                 attacker(),
                 without_defenses,
                 misc(base_damage: 100)
               )
    end

    test "applies the active element modifier without defense" do
      assert {:ok, %{damage: damage, is_critical: false}} =
               MiscDamageCalculator.calculate_misc_damage(
                 attacker(),
                 defender(10, element: {:earth, 1}),
                 misc(base_damage: 100, element: :fire)
               )

      assert damage == mode_value(150, 150)
    end

    test "a skill declaring IgnoreElement bypasses the element table" do
      assert {:ok, %{damage: 100, is_critical: false}} =
               MiscDamageCalculator.calculate_misc_damage(
                 attacker(),
                 defender(10, element: {:earth, 1}),
                 misc(skill_id: @bio_explosion, base_damage: 100, element: :fire)
               )
    end

    test "a zero base deals 0: misc damage has no minimum" do
      assert {:ok, %{damage: 0, is_critical: false}} =
               MiscDamageCalculator.calculate_misc_damage(
                 attacker(),
                 defender(0),
                 misc(base_damage: 0)
               )
    end

    test "fixed_damage short-circuits the whole pipeline" do
      assert {:ok, %{damage: 50, is_critical: false}} =
               MiscDamageCalculator.calculate_misc_damage(
                 attacker(),
                 defender(999),
                 misc(fixed_damage: 50, base_damage: 9999, element: :fire)
               )
    end

    test "a matching {:element_ratio, _} attacker modifier applies the active field rule" do
      stub(ModifierCalculator, :get_battle_modifiers, fn :player, 1001 ->
        %{{:element_ratio, :fire} => 20}
      end)

      assert {:ok, %{damage: damage, is_critical: false}} =
               MiscDamageCalculator.calculate_misc_damage(
                 attacker(),
                 defender(10, element: {:earth, 1}),
                 misc(base_damage: 100, element: :fire)
               )

      assert damage == mode_value(170, 180)
    end

    test "a non-matching {:element_ratio, _} modifier is ignored" do
      stub(ModifierCalculator, :get_battle_modifiers, fn :player, 1001 ->
        %{{:element_ratio, :wind} => 20}
      end)

      assert {:ok, %{damage: damage, is_critical: false}} =
               MiscDamageCalculator.calculate_misc_damage(
                 attacker(),
                 defender(10, element: {:earth, 1}),
                 misc(base_damage: 100, element: :fire)
               )

      assert damage == mode_value(150, 150)
    end

    test "the field bonus preserves Renewal recovery but classic immunity" do
      stub(ModifierCalculator, :get_battle_modifiers, fn :player, 1001 ->
        %{{:element_ratio, :poison} => 20}
      end)

      assert {:ok, %{damage: damage, is_critical: false}} =
               MiscDamageCalculator.calculate_misc_damage(
                 attacker(),
                 defender(10, element: {:poison, 1}),
                 misc(base_damage: 100, element: :poison)
               )

      assert damage == mode_value(20, 0)
    end

    test "a player target's cards reduce the hit as one factor before the skill rates" do
      # Fire resist 10 plus an exact-element misc entry 10 (the all-element misc
      # entry does not apply to misc hits), race 20, size 10, class 10, misc 10,
      # near 10: 1000 -> 800 -> 640 -> 576 -> 518 -> 466 -> 419, so 419 damage;
      # then +10% skill attack (460) and -5% skill resist (437).
      defender =
        player_defender(%{
          {:subele, :fire} => 10,
          {:subele, {:fire, @any_range_misc}} => 10,
          {:subele, {:all, @any_range_misc}} => 30,
          {:subrace, :demi_human} => 20,
          {:subsize, :medium} => 10,
          {:subclass, :normal} => 10,
          :misc_atk_def => 10,
          :near_atk_def => 10,
          :long_atk_def => 50,
          {:sub_skill, @blitz_beat} => 5
        })

      attacker = %{attacker() | equip_modifiers: %{{:skill_atk, @blitz_beat} => 10}}

      assert {:ok, %{damage: 437}} =
               MiscDamageCalculator.calculate_misc_damage(
                 attacker,
                 defender,
                 misc(base_damage: 1000, element: :fire)
               )
    end

    test "a skill declaring IgnoreDefCard skips the target's cards" do
      defender = player_defender(%{{:subrace, :demi_human} => 20, :misc_atk_def => 10})

      assert {:ok, %{damage: 1000}} =
               MiscDamageCalculator.calculate_misc_damage(
                 attacker(),
                 defender,
                 misc(skill_id: @land_mine, base_damage: 1000)
               )
    end

    test "a monster's misc hit also matches the target's weapon-flagged cards" do
      monster = struct(Combatant, unit_type: :mob, unit_id: 2002, combat_stats: %{}, race: :brute)
      defender = player_defender(%{{:subrace, {:brute, @any_range_weapon_skill}} => 50})

      assert {:ok, %{damage: 500}} =
               MiscDamageCalculator.calculate_misc_damage(
                 monster,
                 defender,
                 misc(base_damage: 1000)
               )

      assert {:ok, %{damage: 1000}} =
               MiscDamageCalculator.calculate_misc_damage(
                 attacker(),
                 %{
                   defender
                   | equip_modifiers: %{{:subrace, {:demi_human, @any_range_weapon_skill}} => 50}
                 },
                 misc(base_damage: 1000)
               )
    end
  end
end
