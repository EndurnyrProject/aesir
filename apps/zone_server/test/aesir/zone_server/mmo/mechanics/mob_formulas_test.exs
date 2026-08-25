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
           } === {235, 180, 0, 17}

    assert {
             PreRenewal.calculate_hit(mob),
             PreRenewal.calculate_flee(mob),
             PreRenewal.calculate_soft_defense(mob),
             PreRenewal.calculate_soft_mdef(mob)
           } === {85, 80, 40, 40}
  end

  test "mode-shared leaves preserve the extracted formulas" do
    mob = mob_fixture()

    expected = {3, 100, 50, 25, 60, 10}

    assert shared_leaves(Renewal, mob) === expected
    assert shared_leaves(PreRenewal, mob) === expected
  end

  defp shared_leaves(formulas, mob) do
    {
      formulas.calculate_perfect_dodge(mob),
      formulas.calculate_aspd(mob),
      formulas.calculate_base_attack(mob),
      formulas.calculate_defense(mob),
      formulas.calculate_magic_attack(mob),
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
