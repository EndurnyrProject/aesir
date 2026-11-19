defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.BonusKeysTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.BonusKeys

  describe "destination/1" do
    test "bBaseAtk is equipment ATK and bAtk the running slot's hand weapon ATK" do
      assert BonusKeys.destination("bBaseAtk") == {:ok, :atk}
      assert BonusKeys.destination("bAtk") == {:ok, :weapon_atk}

      assert BonusKeys.slot_destination(:weapon_atk, nil) == :weapon_atk
      assert BonusKeys.slot_destination(:weapon_atk, :weapon) == :left_weapon_atk
      assert BonusKeys.slot_destination(:weapon_atk, :shield) == nil
      assert BonusKeys.slot_destination(:weapon_atk, :arrow) == nil

      assert BonusKeys.slot_destination(:atk, :shield) == :atk
      assert BonusKeys.slot_destination(:atk, :arrow) == nil
    end

    test "per-skill SP rates accumulate under the source cap" do
      assert BonusKeys.capped_rate_destination?({:skill_use_sp_rate, 28})
      refute BonusKeys.capped_rate_destination?({:skill_use_sp, 28})
      refute BonusKeys.capped_rate_destination?(:sp_cost_rate)

      assert BonusKeys.accumulate_capped_rate(nil, 12_000) == 10_000
      assert BonusKeys.accumulate_capped_rate(nil, -12_000) == -10_000
      assert BonusKeys.accumulate_capped_rate(9_000, 9_000) == 10_000
      assert BonusKeys.accumulate_capped_rate(-9_000, -9_000) == -18_000
    end
  end

  describe "bNonCritAtkRate" do
    test "resolves to its own destination, excluded for ammunition scripts" do
      assert BonusKeys.destination("bNonCritAtkRate") == {:ok, :non_crit_atk_rate}
      assert BonusKeys.slot_destination(:non_crit_atk_rate, :arrow) == nil
      assert BonusKeys.slot_destination(:short_atk_rate, :arrow) == nil
      assert BonusKeys.slot_destination(:crit_atk_rate, :arrow) == :crit_atk_rate
      assert BonusKeys.slot_destination(:non_crit_atk_rate, nil) == :non_crit_atk_rate
    end
  end

  describe "bMiscAtkDef" do
    test "resolves to its own destination, excluded for ammunition scripts" do
      assert BonusKeys.destination("bMiscAtkDef") == {:ok, :misc_atk_def}
      assert BonusKeys.slot_destination(:misc_atk_def, :arrow) == nil
    end
  end

  describe "bCriticalDef" do
    test "resolves to its own destination, excluded for ammunition scripts" do
      assert BonusKeys.destination("bCriticalDef") == {:ok, :critical_def}
      assert BonusKeys.slot_destination(:critical_def, :arrow) == nil
      assert BonusKeys.slot_destination(:critical_def, nil) == :critical_def
    end
  end

  describe "random option keys on ammunition" do
    test "only the magic defense-element resist accumulates from an ammunition script" do
      assert BonusKeys.slot_destination({:magic_sub_def_ele, :fire}, :arrow) ==
               {:magic_sub_def_ele, :fire}

      assert BonusKeys.slot_destination({:magic_subsize, :large}, :arrow) == nil
      assert BonusKeys.slot_destination(:crit_def_rate, :arrow) == nil
      assert BonusKeys.slot_destination(:hplus, :arrow) == nil
      assert BonusKeys.slot_destination(:reduce_damage_return, :arrow) == nil

      assert BonusKeys.slot_destination({:magic_subsize, :large}, :shield) ==
               {:magic_subsize, :large}
    end
  end

  describe "ammunition on-hit statuses" do
    test "bAddEff and bAddEff2 count for ranged attacks only; the rest are not armed" do
      assert BonusKeys.slot_destination({:add_eff, :sc_stun}, :arrow) ==
               {:arrow_add_eff, :sc_stun}

      assert BonusKeys.slot_destination({:add_eff2, :sc_curse}, :arrow) ==
               {:arrow_add_eff2, :sc_curse}

      assert BonusKeys.slot_destination({:add_eff_when_hit, :sc_stun}, :arrow) == nil
      assert BonusKeys.slot_destination({:add_eff_on_skill, 5, :sc_stun}, :arrow) == nil
      assert BonusKeys.slot_destination({:add_eff, :sc_stun}, :weapon) == {:add_eff, :sc_stun}
    end
  end

  describe "flag_kind/1" do
    test "is :error for bonus3 keys outside the allow-list" do
      for key <- ~w(bAddEffOnSkill bAutoSpell bAddMonsterDropItem bAddRace bStr) do
        assert :error = BonusKeys.flag_kind(key)
      end
    end
  end
end
