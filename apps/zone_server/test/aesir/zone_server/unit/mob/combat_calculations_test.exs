defmodule Aesir.ZoneServer.Unit.Mob.CombatCalculationsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Unit.Mob.CombatCalculations

  defp create_test_mob(overrides) do
    default_mob = %MobDefinition{
      id: 1001,
      aegis_name: "test_mob",
      name: "Test Mob",
      level: 25,
      hp: 1000,
      stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15},
      atk: 50,
      matk: 60,
      def: 25,
      mdef: 10,
      attack_range: 1,
      walk_speed: 200,
      attack_delay: 1200,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      element: {:neutral, 1},
      race: :formless,
      size: :medium
    }

    Map.merge(default_mob, overrides)
  end

  test "mobs have no natural perfect dodge, regardless of LUK" do
    for luk <- [0, 3, 25, 30, 42, 47, 50, 60, 85, 255] do
      mob = create_test_mob(%{stats: %{luk: luk}})
      assert CombatCalculations.calculate_perfect_dodge(mob) == 0
    end
  end

  test "ASPD follows attack delay with a minimum of 100" do
    for {delay, expected} <- [
          {200, 180},
          {500, 150},
          {600, 140},
          {800, 120},
          {1000, 100},
          {1200, 100},
          {2000, 100},
          {3000, 100}
        ] do
      mob = create_test_mob(%{attack_delay: delay})
      assert CombatCalculations.calculate_aspd(mob) == expected
    end
  end

  test "base attack preserves database ATK for weak, ordinary and boss mobs" do
    for atk <- [10, 25, 75, 80, 150, 300, 500] do
      assert CombatCalculations.calculate_base_attack(create_test_mob(%{atk: atk})) == atk
    end
  end

  test "hard defense preserves database DEF" do
    for defense <- [0, 5, 15, 30, 40, 60, 120, 200, 250] do
      assert CombatCalculations.calculate_defense(create_test_mob(%{def: defense})) == defense
    end
  end

  test "magic attack and hard MDEF preserve database values" do
    mob = create_test_mob(%{matk: 95, mdef: 22})
    assert CombatCalculations.calculate_magic_attack(mob) == 95
    assert CombatCalculations.calculate_magic_defense(mob) == 22
  end

  test "implements all required CombatCalculations callbacks" do
    functions = CombatCalculations.__info__(:functions)

    for callback <- [
          :calculate_hit,
          :calculate_flee,
          :calculate_perfect_dodge,
          :calculate_aspd,
          :calculate_base_attack,
          :calculate_defense
        ] do
      assert {callback, 1} in functions
    end
  end

  test "all callbacks handle normal, zero and maximum reasonable stats" do
    for {level, stat} <- [{45, 50}, {1, 0}, {200, 255}] do
      mob =
        create_test_mob(%{
          level: level,
          stats: %{str: stat, agi: stat, vit: stat, int: stat, dex: stat, luk: stat},
          atk: 9999,
          def: 999,
          attack_delay: 100
        })

      assert is_integer(CombatCalculations.calculate_hit(mob))
      assert is_integer(CombatCalculations.calculate_flee(mob))
      assert is_integer(CombatCalculations.calculate_perfect_dodge(mob))
      assert is_integer(CombatCalculations.calculate_aspd(mob))
      assert is_integer(CombatCalculations.calculate_base_attack(mob))
      assert is_integer(CombatCalculations.calculate_defense(mob))
    end

    mob = create_test_mob(%{atk: 1, def: 0, attack_delay: 1000})
    assert CombatCalculations.calculate_base_attack(mob) == 1
    assert CombatCalculations.calculate_defense(mob) == 0
    assert CombatCalculations.calculate_aspd(mob) == 100
  end
end

defmodule Aesir.ZoneServer.Unit.Mob.AccuracyTest do
  use ExUnit.Case,
    async: true,
    parameterize: [
      %{
        level: 30,
        dex: 45,
        agi: 55,
        int: 30,
        vit: 1,
        renewal: {225, 185, 15},
        classic: {75, 85, 30}
      },
      %{
        level: 5,
        dex: 10,
        agi: 10,
        int: 20,
        vit: 50,
        renewal: {165, 115, 6},
        classic: {15, 15, 45}
      },
      %{
        level: 80,
        dex: 90,
        agi: 80,
        int: 20,
        vit: 50,
        renewal: {320, 260, 25},
        classic: {170, 160, 45}
      },
      %{
        level: 99,
        dex: 120,
        agi: 95,
        int: 20,
        vit: 50,
        renewal: {369, 294, 29},
        classic: {219, 194, 45}
      },
      %{
        level: 35,
        dex: 35,
        agi: 55,
        int: 20,
        vit: 50,
        renewal: {220, 190, 13},
        classic: {70, 90, 45}
      },
      %{
        level: 20,
        dex: 35,
        agi: 10,
        int: 20,
        vit: 50,
        renewal: {205, 130, 10},
        classic: {55, 30, 45}
      },
      %{
        level: 40,
        dex: 35,
        agi: 80,
        int: 20,
        vit: 50,
        renewal: {225, 220, 15},
        classic: {75, 120, 45}
      },
      %{
        level: 85,
        dex: 35,
        agi: 95,
        int: 20,
        vit: 50,
        renewal: {270, 280, 26},
        classic: {120, 180, 45}
      },
      %{
        level: 50,
        dex: 1,
        agi: 1,
        int: 30,
        vit: 1,
        renewal: {201, 151, 20},
        classic: {51, 51, 30}
      },
      %{level: 1, dex: 0, agi: 0, int: 0, vit: 0, renewal: {151, 101, 0}, classic: {1, 1, 0}}
    ]

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Unit.Mob.CombatCalculations

  setup context do
    mob = %MobDefinition{
      id: 1001,
      aegis_name: "test_mob",
      name: "Test Mob",
      level: context.level,
      hp: 1000,
      stats: %{dex: context.dex, agi: context.agi, int: context.int, vit: context.vit},
      attack_range: 1,
      walk_speed: 200,
      attack_delay: 1200,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      element: {:neutral, 1},
      race: :formless,
      size: :medium
    }

    {:ok, mob: mob}
  end

  @tag game_mode: :renewal
  test "Renewal adds actor baselines and level-scaled soft MDEF", %{mob: mob, renewal: expected} do
    assert {CombatCalculations.calculate_hit(mob), CombatCalculations.calculate_flee(mob),
            CombatCalculations.calculate_soft_mdef(mob)} == expected
  end

  @tag game_mode: :pre_renewal
  test "classic uses unshifted accuracy and VIT-based soft MDEF", %{mob: mob, classic: expected} do
    assert {CombatCalculations.calculate_hit(mob), CombatCalculations.calculate_flee(mob),
            CombatCalculations.calculate_soft_mdef(mob)} == expected
  end
end
