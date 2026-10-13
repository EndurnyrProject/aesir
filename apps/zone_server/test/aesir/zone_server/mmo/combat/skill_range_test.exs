defmodule Aesir.ZoneServer.Mmo.Combat.SkillRangeTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Combat.SkillRange

  defp unit(type, position, extra \\ %{}),
    do: Map.merge(%{unit_type: type, position: position}, extra)

  @bash 5
  @double_strafe 46
  @arrow_shower 47
  @brandish_spear 57
  @spear_stab 58
  @spear_boomerang 59
  @fire_pillar 80
  @ankle_snare 117
  @bomb 229
  @grand_cross 254
  @gravitation 484
  @spiral_pierce 397
  @frost_nova 88

  describe "classify/4 for a player" do
    test "a skill is short below 4 cells of its database range and long from 4" do
      player = unit(:player, {100, 100})
      target = unit(:mob, {101, 100})

      assert SkillRange.classify(player, target, @bash, 10) == :short
      assert SkillRange.classify(player, target, @grand_cross, 10) == :long
      assert SkillRange.classify(player, target, @frost_nova, 10) == :short
    end

    test "a negative database range counts its cells, not the weapon's reach" do
      spear_user = unit(:player, {100, 100}, %{attack_range: 3})

      assert SkillRange.classify(spear_user, unit(:mob, {101, 100}), @spear_stab, 1) == :long
    end

    test "a per-level range classifies by the level used" do
      player = unit(:player, {100, 100})
      target = unit(:mob, {101, 100})

      assert SkillRange.classify(player, target, @spear_boomerang, 1) == :short
      assert SkillRange.classify(player, target, @spear_boomerang, 2) == :long
    end

    test "traps are short at any distance" do
      player = unit(:player, {100, 100})

      assert SkillRange.classify(player, unit(:mob, {120, 100}), @ankle_snare, 1) == :short
    end

    test "an unknown skill has no range and is short" do
      assert SkillRange.classify(unit(:player, {1, 1}), unit(:mob, {9, 9}), 999_999, 1) ==
               :short
    end
  end

  describe "server_range/3" do
    test "Vulture's Eye extends a player's archer skill" do
      archer = unit(:player, {100, 100}, %{vulture_eye_level: 10})

      assert SkillRange.server_range(archer, @double_strafe, 10) == 19
      assert SkillRange.server_range(unit(:player, {100, 100}), @double_strafe, 10) == 9
    end

    test "the database range is capped at 14 before Vulture's Eye" do
      player = unit(:player, {100, 100}, %{vulture_eye_level: 10})

      assert SkillRange.server_range(player, @gravitation, 5) == 14
    end

    test "a non-player with no range reaches 9 cells" do
      assert SkillRange.server_range(unit(:npc, {1, 1}), @frost_nova, 10) == 9
      assert SkillRange.server_range(unit(:player, {1, 1}), @frost_nova, 10) == 0
    end
  end

  describe "classify/4 for a non-player" do
    test "monster and homunculus skills are short within 3 cells and long beyond" do
      target = unit(:player, {100, 100})

      for type <- [:mob, :homunculus] do
        assert SkillRange.classify(unit(type, {103, 97}), target, @grand_cross, 10) == :short
        assert SkillRange.classify(unit(type, {104, 100}), target, @bash, 10) == :long
      end
    end

    test "traps are short at any distance" do
      assert SkillRange.classify(
               unit(:mob, {100, 100}),
               unit(:player, {120, 100}),
               @ankle_snare,
               1
             ) ==
               :short
    end

    test "a monster's Arrow Shower and Bomb are short, a homunculus's follow distance" do
      target = unit(:player, {110, 100})

      assert SkillRange.classify(unit(:mob, {100, 100}), target, @arrow_shower, 10) == :short
      assert SkillRange.classify(unit(:mob, {100, 100}), target, @bomb, 5) == :short

      assert SkillRange.classify(unit(:homunculus, {100, 100}), target, @arrow_shower, 10) ==
               :long
    end

    test "a unit without a known position takes its skill range" do
      assert SkillRange.classify(unit(:mob, nil), unit(:player, {1, 1}), @bash, 10) == :short

      assert SkillRange.classify(unit(:mob, nil), unit(:player, {1, 1}), @grand_cross, 10) ==
               :long
    end
  end

  describe "classify/4 overrides" do
    test "Spiral Pierce is long for a non-player at any distance" do
      target = unit(:player, {101, 100})

      assert SkillRange.classify(unit(:mob, {100, 100}), target, @spiral_pierce, 5) == :long

      assert SkillRange.classify(unit(:homunculus, {100, 100}), target, @spiral_pierce, 5) ==
               :long
    end

    @tag game_mode: :renewal
    test "renewal Brandish Spear is long for every caster" do
      target = unit(:mob, {101, 100})

      assert SkillRange.classify(unit(:player, {100, 100}), target, @brandish_spear, 10) == :long
      assert SkillRange.classify(unit(:mob, {100, 100}), target, @brandish_spear, 10) == :long
    end

    @tag game_mode: :pre_renewal
    test "classic Brandish Spear takes its 2-cell range and Fire Pillar is a trap" do
      player = unit(:player, {100, 100})

      assert SkillRange.classify(player, unit(:mob, {101, 100}), @brandish_spear, 10) == :short
      assert SkillRange.classify(player, unit(:mob, {110, 100}), @fire_pillar, 10) == :short
    end

    @tag game_mode: :renewal
    test "renewal Fire Pillar is not a trap" do
      player = unit(:player, {100, 100})

      assert SkillRange.classify(player, unit(:mob, {110, 100}), @fire_pillar, 10) == :long
    end
  end
end
