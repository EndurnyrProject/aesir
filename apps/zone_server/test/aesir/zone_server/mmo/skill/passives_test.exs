defmodule Aesir.ZoneServer.Mmo.Skill.PassivesTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.WeaponTypes
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats

  defp build_player(learned_skills, weapon_atom) do
    stats = %Stats{
      base_stats: %BaseStats{str: 1, agi: 1, vit: 10, int: 10, dex: 1, luk: 1},
      derived_stats: %DerivedStats{max_hp: 1000, max_sp: 100},
      progression: %PlayerProgression{
        base_level: 50,
        job_level: 30,
        learned_skills: learned_skills
      },
      equipment: %Equipment{weapon: WeaponTypes.get_weapon_id(weapon_atom), shield: 0}
    }

    %PlayerState{stats: stats}
  end

  describe "atk_bonus/1" do
    test "SM_SWORD level 5 with a one-handed sword grants 20 ATK" do
      player = build_player(%{2 => 5}, :one_handed_sword)
      assert Passives.atk_bonus(player) == 20
    end

    test "SM_SWORD level 5 with a bow grants 0 ATK" do
      player = build_player(%{2 => 5}, :bow)
      assert Passives.atk_bonus(player) == 0
    end
  end

  describe "regen/1" do
    test "merges flat skill HP regen and the moving flag" do
      player = build_player(%{4 => 5, 144 => 1}, :one_handed_sword)

      regen = Passives.regen(player)

      assert regen.skill_hp_regen == 35
      assert regen.allow_while_moving == true
      assert regen.skill_sp_regen == 0
    end

    test "returns all keys defaulted when no regen passives are learned" do
      player = build_player(%{2 => 5}, :one_handed_sword)

      assert Passives.regen(player) ==
               %{skill_hp_regen: 0, skill_sp_regen: 0, allow_while_moving: false}
    end
  end

  describe "rider_for/3" do
    test "SM_FATALBLOW yields a stun rider for Bash above level 5" do
      player = build_player(%{145 => 1}, :one_handed_sword)

      assert [{:apply_status, :sc_stun, _opts}] = Passives.rider_for(:sm_bash, 6, player)
    end

    test "SM_FATALBLOW yields no rider for Bash at level 5" do
      player = build_player(%{145 => 1}, :one_handed_sword)

      assert Passives.rider_for(:sm_bash, 5, player) == []
    end
  end

  describe "skipping invalid learned ids" do
    test "an active-skill id is silently skipped" do
      player = build_player(%{5 => 10}, :one_handed_sword)

      assert Passives.atk_bonus(player) == 0

      assert Passives.regen(player) ==
               %{skill_hp_regen: 0, skill_sp_regen: 0, allow_while_moving: false}
    end

    test "an unknown id is silently skipped" do
      player = build_player(%{999_999 => 1}, :one_handed_sword)

      assert Passives.atk_bonus(player) == 0
    end
  end
end
