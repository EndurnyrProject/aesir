defmodule Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttackTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack
  alias Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack.PreRenewal
  alias Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack.Renewal

  test "weapon bounds keep refine, primary-stat bonus and classic DEX minimum distinct" do
    inputs = weapon_inputs()

    assert Renewal.weapon_bounds(inputs) == {122, 152}
    assert PreRenewal.weapon_bounds(inputs) == {42, 99}

    maximum = %{inputs | max_weapon_damage?: true}
    assert Renewal.weapon_bounds(maximum) == {152, 152}
    assert PreRenewal.weapon_bounds(maximum) == {100, 100}

    critical = %{inputs | critical?: true}
    assert Renewal.weapon_bounds(critical) == {152, 152}
    assert PreRenewal.weapon_bounds(critical) == {100, 100}
  end

  test "base attack adds each component once and doubles only Renewal right-hand status ATK" do
    parts = parts()
    assert Renewal.base_attack(parts) == 165
    assert PreRenewal.base_attack(parts) == 155
    assert Renewal.base_attack(%{parts | hand: :left_hand}) == 145
  end

  test "element, size, cardfix and DEF act on the correct components and stages" do
    context = context()

    assert Renewal.calculate(parts(), context) == 203
    assert PreRenewal.calculate(parts(), context) == 230
  end

  test "Renewal equipment ATK rate is separate from cardfix and PAtk excludes mastery" do
    context =
      neutral_context()
      |> Map.put(:attacker_rates, %{race_class: 100, element: 0, size: 0})
      |> Map.merge(%{patk: 100, equipment_atk_rate: 50})

    assert Renewal.calculate(parts(), context) == 677
    assert PreRenewal.calculate(parts(), context) == 308
  end

  test "skill bonuses and classic refine/mastery retain their positions around DEF" do
    context =
      neutral_context()
      |> put_in([:defense, :soft_def], 10)
      |> Map.merge(%{skill_ratio: 200, bonus_atk: 5, skill_atk_rate: 50, skill_taken_rate: 20})

    assert Renewal.calculate(parts(), context) == 389
    assert PreRenewal.calculate(parts(), context) == 343
  end

  test "critical damage uses Renewal's final multiplier and classic DEF bypass" do
    context =
      neutral_context()
      |> put_in([:defense, :hard_def], 50)
      |> put_in([:defense, :soft_def], 10)
      |> Map.put(:critical?, true)

    assert Renewal.calculate(parts(), context) == 193
    assert PreRenewal.calculate(parts(), context) == 155
    assert Renewal.calculate(parts(), Map.put(context, :crit_atk_rate, 50)) == 296
    assert PreRenewal.calculate(parts(), Map.put(context, :crit_atk_rate, 50)) == 224
  end

  test "defender element resistance excludes Renewal status/mastery without dropping other reductions" do
    context =
      neutral_context()
      |> Map.merge(%{
        weapon_element: 1.5,
        neutral_element: 0.5,
        defender_rates: %{
          race_class: 0,
          monster: 0,
          element: 50,
          size: 0,
          long_def: 20,
          ranged: 0
        },
        res: 100,
        physical_reduction: 25
      })

    assert Renewal.calculate(parts(), context) == 57
    assert PreRenewal.calculate(parts(), context) == 69
  end

  test "global race, flat/status ATK and range channels survive component separation" do
    context =
      neutral_context()
      |> Map.merge(%{
        attacker_rates: %{race_class: 30, element: 0, size: 0},
        global_race_rate: 20,
        weapon_bonus: 5,
        flat_bonus: 4,
        atk_rate: 25,
        long_atk_rate: 20
      })

    assert Renewal.calculate(parts(), context) == 368
    assert PreRenewal.calculate(parts(), context) == 357
  end

  test "simple defense subtracts both DEF buckets and does not apply Renewal Res" do
    context =
      neutral_context()
      |> put_in([:defense, :hard_def], 20)
      |> put_in([:defense, :soft_def], 10)
      |> Map.merge(%{defense_mode: :simple, res: 100})

    assert Renewal.calculate(parts(), context) == 135
    assert PreRenewal.calculate(parts(), context) == 125
  end

  test "the shield replacement keeps one status contribution and classic DEF precedes its ratio" do
    shield = %{
      parts()
      | source: :shield,
        flat_atk: 0,
        refine_atk: 0,
        overrefine_atk: 0,
        mastery_atk: 0
    }

    context =
      neutral_context()
      |> put_in([:defense, :hard_def], 20)
      |> put_in([:defense, :soft_def], 10)
      |> Map.put(:skill_ratio, 300)

    assert Renewal.base_attack(shield) == 120
    assert PreRenewal.base_attack(shield) == 120
    assert Renewal.calculate(shield, context) == 334
    assert PreRenewal.calculate(shield, context) == 258
  end

  test "zero defender rates preserve signed flat equipment ATK instead of discarding its penalty" do
    penalized = %{parts() | flat_atk: -15}

    context =
      Map.put(neutral_context(), :defender_rates, %{
        race_class: 0,
        monster: 0,
        element: 0,
        size: 0,
        long_def: 0,
        ranged: 0
      })

    assert Renewal.calculate(penalized, context) == 135
    assert PreRenewal.calculate(penalized, context) == 124
  end

  defp neutral_context do
    %{
      context()
      | size_rate: 100,
        weapon_element: 1.0,
        neutral_element: 1.0,
        attacker_rates: %{race_class: 0, element: 0, size: 0},
        defense: %{hard_def: 0, soft_def: 0, attacker_level: nil, ignore_soft_def?: false}
    }
  end

  defp context do
    %{
      size_rate: 50,
      weapon_element: 1.5,
      neutral_element: 0.5,
      attacker_rates: %{race_class: 100, element: 0, size: 0},
      defense: %{hard_def: 20, soft_def: 10, attacker_level: nil, ignore_soft_def?: false}
    }
  end

  defp parts do
    %{
      status_atk: 20,
      flat_atk: 15,
      weapon_atk: 100,
      refine_atk: 10,
      overrefine_atk: 3,
      mastery_atk: 7,
      hand: :right_hand,
      source: :weapon
    }
  end

  defp weapon_inputs do
    %{
      base_atk: 100,
      refine_atk: 10,
      weapon_level: 3,
      primary_stat: 55,
      dex: 30,
      arrow?: false,
      critical?: false,
      max_weapon_damage?: false
    }
  end

  test "apply_defense/3 subtracts the ratio-scaled soft DEF for the soft-only mode" do
    context = %{
      defense_mode: :soft_only,
      defense: %{hard_def: 50, soft_def: 20},
      skill_ratio: 300
    }

    assert PhysicalAttack.apply_defense(1_000, context, nil) == 940
    assert PhysicalAttack.apply_defense(1_000, %{defense_mode: :ignore}, nil) == 1_000
  end
end
