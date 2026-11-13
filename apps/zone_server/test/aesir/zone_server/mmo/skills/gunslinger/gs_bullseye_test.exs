defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsBullseyeTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.Coma
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsBullseye
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Autoguard
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.SpecialEffect

  setup :set_mimic_private
  setup :verify_on_exit!

  test "bullseye_ratio_test" do
    for race <- [:brute, :demi_human, :player_human, :player_doram] do
      assert GsBullseye.ratio(target(race, false)) == 500
      assert GsBullseye.ratio(target(race, true)) == 100
    end

    assert GsBullseye.ratio(target(:formless, false)) == 100
  end

  test "a surviving landed hit on a coma race rolls a 0.1% coma, others do not" do
    for {report, race, attempts} <- [
          {%{hit?: true, target_survives?: true}, :brute, 1},
          {%{hit?: true, target_survives?: true}, :plant, 0},
          {%{hit?: false, target_survives?: true}, :brute, 0},
          {%{hit?: true, target_survives?: false}, :brute, 0}
        ] do
      expect(Combat, :execute_skill_attack, fn %{}, {:mob, 7}, opts ->
        assert opts[:skip_crit] and opts[:report_hit]
        assert {:target, _ratio} = opts[:skill_ratio]
        {:ok, report}
      end)

      stub(TargetResolver, :resolve_combatant, fn {:mob, 7} ->
        {:ok, %{target(race, false) | unit_type: :mob, unit_id: 7}}
      end)

      stub(Coma, :attempt, fn :mob, 7, [rate: 10] ->
        send(self(), :coma)
        :resisted
      end)

      assert {:ok, _} = GsBullseye.cast(%{}, {:unit, {:mob, 7}}, 1, GsBullseye.definition())
      if attempts == 1, do: assert_received(:coma), else: refute_received(:coma)
    end
  end

  test "bullseye_flags_test: attacker cards and Auto Guard do not touch the hit" do
    plain = CombatTestHelper.create_player_combatant(weapon_type: :revolver)
    carded = %{plain | equip_modifiers: %{{:addrace, :brute} => 50}}
    defender = CombatTestHelper.create_mob_combatant(race: :brute, def: 0)
    opts = [skill_id: 503, base_damage: 1_000, skip_crit: true]

    assert DamageCalculator.calculate_damage(carded, defender, opts) ==
             DamageCalculator.calculate_damage(plain, defender, opts)

    guard = %StatusEntry{type: :sc_autoguard, val1: 10, state: %{block_chance: 100}}
    hit = %{damage: 40, dmg_type: :physical, skill_id: 503, attacker: {:player, 1}}
    reject(&SpecialEffect.play/3)

    assert {:ok, 40, _entry} = Autoguard.absorb_damage({:mob, 9}, guard, hit, %{})
  end

  defp target(race, immune), do: struct(Combatant, race: race, status_immune: immune)
end
