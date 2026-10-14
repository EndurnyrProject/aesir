defmodule Aesir.ZoneServer.Mmo.Mechanics.MobFormulasTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Mechanics.MobFormulas.PreRenewal
  alias Aesir.ZoneServer.Mmo.Mechanics.MobFormulas.Renewal
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition

  test "mode-specific combat leaves use their ruleset formulas" do
    mob = mob_fixture()

    # rAthena src/map/status.cpp:2639-2719.
    assert {
             Renewal.calculate_hit(mob),
             Renewal.calculate_flee(mob),
             Renewal.calculate_soft_defense(mob),
             Renewal.calculate_soft_mdef(mob)
           } === {235, 180, 45, 17}

    assert {
             PreRenewal.calculate_hit(mob),
             PreRenewal.calculate_flee(mob),
             PreRenewal.calculate_soft_defense(mob),
             PreRenewal.calculate_soft_mdef(mob)
           } === {85, 80, 40, 40}
  end

  test "mode-shared leaves preserve the extracted formulas" do
    mob = mob_fixture()

    expected = {0, 100, 50, 25, 10}

    assert shared_leaves(Renewal, mob) === expected
    assert shared_leaves(PreRenewal, mob) === expected
  end

  test "status ATK takes the flat statuses, then the rate's truncated share" do
    mob = mob_fixture()
    modifiers = %{batk: 7, batk_rate: 20}

    # Renewal: STR 10 + level 50 + Guard Up 0 + 7 = 67, plus 67 * 20 / 100 = 13.
    assert Renewal.status_attack(mob, 10, 0, modifiers) === 80
    # A classic guardian: Guard Up 10 + 7 = 17, plus 17 * 20 / 100 = 3.
    assert PreRenewal.status_attack(mob, 10, 10, modifiers) === 20
    # A classic monster without Guard Up has no status ATK to scale.
    assert PreRenewal.status_attack(mob, 10, 0, modifiers) === 0
  end

  test "a negative status ATK rate truncates its share toward zero" do
    mob = mob_fixture()

    # 67 - 67 * 50 / 100 = 67 - 33.
    assert Renewal.status_attack(mob, 10, 0, %{batk: 7, batk_rate: -50}) === 34
  end

  defp shared_leaves(formulas, mob) do
    {
      formulas.calculate_perfect_dodge(mob),
      formulas.calculate_aspd(mob),
      formulas.calculate_base_attack(mob),
      formulas.calculate_defense(mob),
      formulas.calculate_magic_defense(mob)
    }
  end

  defp mob_fixture do
    %MobDefinition{
      id: 1_001,
      aegis_name: "TEST_MOB",
      name: "Test Mob",
      level: 50,
      hp: 1_000,
      stats: %{str: 10, agi: 30, vit: 40, int: 20, dex: 35, luk: 15},
      atk: 50,
      matk: 60,
      def: 25,
      mdef: 10,
      attack_range: 1,
      size: :medium,
      race: :formless,
      element: {:neutral, 1},
      walk_speed: 200,
      attack_delay: 1_200,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300
    }
  end
end
