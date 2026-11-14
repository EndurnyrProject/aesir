defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.PiercingshotRatioTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Combat.SizeModifiers
  alias Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsPiercingshot
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment

  setup :set_mimic_private
  setup :verify_on_exit!

  test "uses the player rifle bonus only in renewal and ignores defense" do
    for {caster, renewal_ratio} <- [
          {%PlayerState{
             character_id: 1,
             stats: %Stats{equipment: %Equipment{right_hand: 13_150}}
           }, 400},
          {%PlayerState{
             character_id: 1,
             stats: %Stats{equipment: %Equipment{right_hand: 13_100}}
           }, 300},
          {%{instance_id: 1}, 300}
        ] do
      expected = if GameMode.mode() == :renewal, do: renewal_ratio, else: 200

      expect(Combat, :execute_skill_attack, fn ^caster, {:mob, 2}, opts ->
        assert opts[:skill_ratio] == expected
        assert opts[:ignore_defense]
        {:ok, %{hit?: false}}
      end)

      assert {:ok, ^caster} =
               GsPiercingshot.cast(caster, {:unit, {:mob, 2}}, 5, GsPiercingshot.definition())
    end
  end

  describe "piercingshot_ratio_test: the ignoring-defense pipeline it selects" do
    setup do
      Mimic.copy(ElementModifiers)
      Mimic.copy(SizeModifiers)
      Mimic.copy(RaceModifiers)

      CombatTestHelper.stub_element_coefficient(fn _, _, _, _ -> 1.0 end)
      stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
      stub(RaceModifiers, :player_race, fn -> :human end)
      stub(ModifierCalculator, :get_battle_modifiers, fn _, _ -> %{} end)
      :ok
    end

    test "hard and soft DEF leave the damage untouched" do
      attacker = CombatTestHelper.create_player_combatant(flat_atk: 101)
      armored = CombatTestHelper.create_mob_combatant(def: 50, soft_def: 30)
      bare = CombatTestHelper.create_mob_combatant(def: 0, soft_def: 0)

      assert {:ok, %{damage: ignoring}} =
               DamageCalculator.calculate_damage_ignoring_defense(attacker, armored,
                 base_damage: 101,
                 skip_crit: true
               )

      assert {:ok, %{damage: reference}} =
               DamageCalculator.calculate_damage_ignoring_defense(attacker, bare,
                 base_damage: 101,
                 skip_crit: true
               )

      assert ignoring == reference

      assert {:ok, %{damage: ordinary}} =
               DamageCalculator.calculate_damage(attacker, armored,
                 base_damage: 101,
                 skip_crit: true
               )

      assert ordinary < ignoring
    end
  end
end
