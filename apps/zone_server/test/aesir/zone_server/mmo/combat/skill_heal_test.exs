defmodule Aesir.ZoneServer.Mmo.Combat.SkillHealTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat.SkillHeal
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  @caster %{
    player?: true,
    base_level: 60,
    int: 40,
    vit: 0,
    learned: %{},
    brain_rate: 0,
    equipment: %{},
    heal_matk_min: 150,
    heal_matk_max: 150,
    hplus: 0
  }
  @target {:player, 2000}

  test "level 11 and above return 9999 before bonuses, halving, MATK and penalties" do
    caster = %{@caster | equipment: %{heal_power: 100}, hplus: 100}
    :ok = StatusStorage.apply_status(:player, 2000, :sc_norecover_state, duration: 60_000)

    for level <- [11, 12], heal? <- [true, false] do
      assert SkillHeal.amount(caster, @target, 28, level, heal?) == 9999
    end
  end

  test "Sanctuary uses 100 per level through 6, then 777, without MATK" do
    assert SkillHeal.amount(@caster, nil, 70, 6, true) == 600
    assert SkillHeal.amount(@caster, nil, 70, 7, true) == 777
    assert SkillHeal.amount(@caster, nil, 70, 11, true) == 777
    assert SkillHeal.amount(@caster, nil, 70, 7, false) == 388
  end

  describe "renewal" do
    @describetag game_mode: :renewal

    test "adds MATK after the level-and-INT base, halving only the base on a strike" do
      assert SkillHeal.amount(@caster, nil, 28, 10, true) == 750
      assert SkillHeal.amount(@caster, nil, 28, 10, false) == 450
    end

    test "retains the low, mid and high level Heal vectors" do
      low = %{@caster | base_level: 10, int: 10, heal_matk_min: 0, heal_matk_max: 0}
      mid = %{@caster | base_level: 50, int: 50, heal_matk_min: 50, heal_matk_max: 50}
      high = %{@caster | base_level: 99, int: 50, heal_matk_min: 100, heal_matk_max: 100}

      assert SkillHeal.amount(low, nil, 28, 1, true) == 12
      assert SkillHeal.amount(mid, nil, 28, 5, true) == 350
      assert SkillHeal.amount(high, nil, 28, 10, true) == 970

      assert SkillHeal.amount(%{mid | heal_matk_min: 150, heal_matk_max: 150}, nil, 28, 5, true) ==
               450
    end

    test "MATK rolls use the half-open band, and the minimum when bounds do not increase" do
      caster = %{@caster | base_level: 50, int: 50, heal_matk_min: 10, heal_matk_max: 20}

      amounts = for _ <- 1..100, do: SkillHeal.amount(caster, nil, 28, 5, true)

      assert Enum.all?(amounts, &(&1 in 310..319))
      assert SkillHeal.amount(%{caster | heal_matk_max: 11}, nil, 28, 5, true) == 310
      assert SkillHeal.amount(%{caster | heal_matk_max: 10}, nil, 28, 5, true) == 310
      assert SkillHeal.amount(%{caster | heal_matk_max: 9}, nil, 28, 5, true) == 310
    end

    test "heal power and the matching skill bonus add before MATK" do
      caster = %{@caster | equipment: %{heal_power: 20}}
      mid = %{caster | base_level: 50, int: 50, heal_matk_min: 50, heal_matk_max: 50}

      specific = %{
        mid
        | equipment: %{:heal_power => 10, {:skill_heal, 28} => 15, {:skill_heal, 29} => 100}
      }

      assert SkillHeal.amount(caster, nil, 28, 10, true) == 870
      assert SkillHeal.amount(mid, nil, 28, 5, true) == 410
      assert SkillHeal.amount(specific, nil, 28, 5, true) == 425
    end

    test "H.Plus increases the final amount after heal power and MATK" do
      caster = %{@caster | hplus: 10}
      mid = %{caster | base_level: 50, int: 50, heal_matk_min: 50, heal_matk_max: 50}

      assert SkillHeal.amount(caster, nil, 28, 10, true) == 825
      assert SkillHeal.amount(mid, nil, 28, 5, true) == 385
      assert SkillHeal.amount(%{mid | equipment: %{heal_power: 20}}, nil, 28, 5, true) == 451
    end

    test "Meditatio, Assumptio and heal power pool into one percentage" do
      caster = %{@caster | learned: %{363 => 10}, equipment: %{heal_power: 15}}
      :ok = StatusStorage.apply_status(:player, 2000, :sc_assumptio, val1: 5, duration: 60_000)

      assert SkillHeal.amount(caster, @target, 28, 10, true) == 1020
      assert SkillHeal.amount(@caster, @target, 28, 10, false) == 480
    end

    test "Meditatio applies with and without Assumptio, including on a strike" do
      caster = %{
        @caster
        | base_level: 50,
          int: 50,
          heal_matk_min: 50,
          heal_matk_max: 50,
          learned: %{363 => 10}
      }

      :ok = StatusStorage.apply_status(:player, 2000, :sc_assumptio, val1: 5, duration: 60_000)

      assert SkillHeal.amount(caster, @target, 28, 5, true) == 440
      assert SkillHeal.amount(caster, @target, 28, 5, false) == 245
      assert SkillHeal.amount(caster, nil, 28, 5, true) == 410
    end

    test "received heal power, matching skill bonus and Increase Heal Rate pool with caster power" do
      register_target(%{:heal_power2 => 13, {:skill_heal2, 28} => 7, {:skill_heal2, 29} => 100})
      :ok = StatusStorage.apply_status(:player, 2000, :sc_inchealrate, val1: 17, duration: 60_000)
      caster = %{@caster | equipment: %{heal_power: 15}}

      assert SkillHeal.amount(caster, @target, 28, 10, true) == 1062
    end

    test "No Recovery zeroes a heal before its one-point floor, but does not penalize a strike" do
      caster = %{@caster | hplus: 10}
      :ok = StatusStorage.apply_status(:player, 2000, :sc_norecover_state, duration: 60_000)

      assert SkillHeal.amount(caster, @target, 28, 10, true) == 1
      assert SkillHeal.amount(caster, @target, 28, 10, false) == 495
    end

    test "only a heal is floored to one" do
      caster = %{@caster | base_level: 1, int: 0, heal_matk_min: 0, heal_matk_max: 0}

      assert SkillHeal.amount(caster, nil, 28, 1, true) == 1
      assert SkillHeal.amount(caster, nil, 28, 1, false) == 0
    end

    test "a Homunculus pools Brain Surgery before adding MATK, without player equipment or H.Plus" do
      caster = %{
        @caster
        | player?: false,
          brain_rate: 20,
          equipment: %{heal_power: 100},
          hplus: 100
      }

      assert SkillHeal.amount(caster, nil, 28, 10, true) == 870
      assert SkillHeal.amount(caster, nil, 28, 10, false) == 510
    end
  end

  describe "pre-renewal" do
    @describetag game_mode: :pre_renewal

    test "uses the classic base, ignores MATK and H.Plus, and halves a strike" do
      caster = %{@caster | hplus: 10}
      mid = %{caster | base_level: 50, int: 50, heal_matk_min: 10, heal_matk_max: 20}

      assert SkillHeal.amount(caster, nil, 28, 10, true) == 1008

      assert SkillHeal.amount(%{caster | heal_matk_min: 0, heal_matk_max: 0}, nil, 28, 10, true) ==
               1008

      assert SkillHeal.amount(caster, nil, 28, 10, false) == 504
      assert SkillHeal.amount(mid, nil, 28, 5, true) == 528
      assert SkillHeal.amount(mid, nil, 28, 5, false) == 264
    end

    test "generic and matching skill heal power add into one truncating step" do
      caster = %{@caster | equipment: %{heal_power: 20}}
      mid = %{caster | base_level: 50, int: 50}

      specific = %{
        mid
        | equipment: %{:heal_power => 10, {:skill_heal, 28} => 15, {:skill_heal, 29} => 100}
      }

      assert SkillHeal.amount(caster, nil, 28, 10, true) == 1209
      assert SkillHeal.amount(mid, nil, 28, 5, true) == 633
      assert SkillHeal.amount(specific, nil, 28, 5, true) == 660
    end

    test "Meditatio truncates before halving and heal power; Assumptio is ignored" do
      caster = %{@caster | learned: %{363 => 10}, equipment: %{heal_power: 15}}
      :ok = StatusStorage.apply_status(:player, 2000, :sc_assumptio, val1: 5, duration: 60_000)

      assert SkillHeal.amount(caster, @target, 28, 10, true) == 1390
      assert SkillHeal.amount(caster, @target, 28, 10, false) == 694

      assert SkillHeal.amount(
               %{caster | base_level: 50, int: 50, equipment: %{}},
               @target,
               28,
               5,
               true
             ) == 633
    end

    test "received bonuses truncate after caster power and before Increase Heal Rate" do
      register_target(%{:heal_power2 => 13, {:skill_heal2, 28} => 7, {:skill_heal2, 29} => 100})
      :ok = StatusStorage.apply_status(:player, 2000, :sc_inchealrate, val1: 17, duration: 60_000)
      caster = %{@caster | equipment: %{heal_power: 15}}

      assert SkillHeal.amount(caster, @target, 28, 10, true) == 1626
    end

    test "Apple of Idun uses VIT and Music Lessons, excludes caster power and target rate, but keeps skill and received bonuses" do
      caster = %{
        @caster
        | vit: 41,
          learned: %{315 => 3},
          equipment: %{:heal_power => 100, {:skill_heal, 322} => 10}
      }

      register_target(%{heal_power2: 20})

      :ok =
        StatusStorage.apply_status(:player, 2000, :sc_inchealrate, val1: 100, duration: 60_000)

      assert SkillHeal.amount(caster, nil, 322, 4, true) == 93
      assert SkillHeal.amount(caster, @target, 322, 4, true) == 111
    end

    test "No Recovery zeroes a heal without penalizing a strike" do
      :ok = StatusStorage.apply_status(:player, 2000, :sc_norecover_state, duration: 60_000)

      assert SkillHeal.amount(@caster, @target, 28, 10, true) == 0
      assert SkillHeal.amount(@caster, @target, 28, 10, false) == 504
    end

    test "a Homunculus applies Brain Surgery before halving and ignores player bonuses" do
      caster = %{
        @caster
        | player?: false,
          brain_rate: 20,
          equipment: %{heal_power: 100},
          hplus: 100
      }

      assert SkillHeal.amount(caster, nil, 28, 10, true) == 1209
      assert SkillHeal.amount(caster, nil, 28, 10, false) == 604
    end
  end

  defp register_target(equipment) do
    target =
      PlayerState.new(%Character{
        id: 2000,
        account_id: 2000,
        name: "HealTarget",
        class: 0,
        sex: "M",
        last_map: "prontera",
        last_x: 100,
        last_y: 100,
        base_level: 60,
        hp: 100,
        sp: 100
      })

    target = put_in(target.stats.modifiers.equipment, equipment)
    :ok = UnitRegistry.register_unit(:player, 2000, PlayerState, target, self())
  end
end
