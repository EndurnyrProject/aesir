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

    assert renewal(parts(), context) == 203
    assert classic(parts(), context) == 230
  end

  test "Renewal equipment ATK rate is separate from cardfix and PAtk excludes mastery" do
    context =
      neutral_context()
      |> Map.put(:attacker_rates, %{race_class: 100, element: 0, size: 0})
      |> Map.merge(%{patk: 100, equipment_atk_rate: 50})

    assert renewal(parts(), context) == 677
    assert classic(parts(), context) == 308
  end

  test "post-defense ATK adds exactly 100 before later scaling in both modes" do
    context = neutral_context()

    for implementation <- [&renewal/2, &classic/2] do
      base = implementation.(parts(), context)

      assert implementation.(parts(), Map.put(context, :post_defense_atk, 100)) ==
               base + 100
    end
  end

  test "Renewal base ATK rate scales only the non-mastery core" do
    context = neutral_context()
    with_mastery = parts()
    without_mastery = %{with_mastery | mastery_atk: 0}

    assert renewal(with_mastery, Map.put(context, :base_atk_rate, 70)) ==
             div(renewal(without_mastery, context) * 70, 100) +
               with_mastery.mastery_atk
  end

  test "skill bonuses and classic refine/mastery retain their positions around DEF" do
    context =
      neutral_context()
      |> put_in([:defense, :soft_def], 10)
      |> Map.merge(%{skill_ratio: 200, bonus_atk: 5, skill_atk_rate: 50, skill_taken_rate: 20})

    assert renewal(parts(), context) == 389
    assert classic(parts(), context) == 343
  end

  test "critical damage uses Renewal's final multiplier and classic DEF bypass" do
    context =
      neutral_context()
      |> put_in([:defense, :hard_def], 50)
      |> put_in([:defense, :soft_def], 10)
      |> Map.put(:critical?, true)

    assert renewal(parts(), context) == 193
    assert classic(parts(), context) == 155
    assert renewal(parts(), Map.put(context, :crit_atk_rate, 50)) == 296
    assert classic(parts(), Map.put(context, :crit_atk_rate, 50)) == 224
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
          def_rate: 25
        },
        res: 100
      })

    assert renewal(parts(), context) == 56
    assert classic(parts(), context) == 69
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

    assert renewal(parts(), context) == 368
    assert classic(parts(), context) == 357
  end

  test "simple defense subtracts both DEF buckets and does not apply Renewal Res" do
    context =
      neutral_context()
      |> put_in([:defense, :hard_def], 20)
      |> put_in([:defense, :soft_def], 10)
      |> Map.merge(%{defense_mode: :simple, res: 100})

    assert renewal(parts(), context) == 135
    assert classic(parts(), context) == 125
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
    assert renewal(shield, context) == 334
    assert classic(shield, context) == 258
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
        def_rate: 0
      })

    assert renewal(penalized, context) == 135
    assert classic(penalized, context) == 124
  end

  test "non-critical rate adds its truncated share before the ratio, signed only in Renewal" do
    plain = %{parts() | status_atk: 0, flat_atk: 0, weapon_atk: 101, refine_atk: 0}
    plain = %{plain | overrefine_atk: 0, mastery_atk: 0}
    neutral = Map.put(neutral_context(), :defense_mode, :ignore)
    penalty = Map.put(neutral, :non_crit_atk_rate, -15)
    bonus = Map.merge(neutral, %{non_crit_atk_rate: 15, skill_ratio: 175})

    assert renewal(plain, penalty) == 86
    assert classic(plain, penalty) == 101
    assert renewal(plain, bonus) == 203
    assert classic(plain, bonus) == 203
  end

  test "critical hits, the ignore flag and the classic shield base exclude the non-critical rate" do
    plain = %{parts() | status_atk: 0, flat_atk: 0, weapon_atk: 101, refine_atk: 0}
    plain = %{plain | overrefine_atk: 0, mastery_atk: 0}
    neutral = Map.put(neutral_context(), :defense_mode, :ignore)
    rated = Map.put(neutral, :non_crit_atk_rate, 15)
    critical = Map.put(rated, :critical?, true)
    unrated_critical = Map.put(neutral, :critical?, true)
    ignored = Map.put(rated, :ignore_noncrit_atk_bonus, true)

    assert renewal(plain, critical) == renewal(plain, unrated_critical)
    assert classic(plain, critical) == 101
    assert renewal(plain, ignored) == 101
    assert classic(plain, ignored) == 101
    assert classic(%{plain | source: :shield}, rated) == 101
    assert renewal(%{plain | source: :shield}, rated) == 116
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

  # The stages composed as one hit, with `weapon_element` and `neutral_element`
  # standing in for the coordinator's attribute steps (default 1.0).
  defp renewal(parts, context) do
    weapon = Map.get(context, :weapon_element, 1.0)
    neutral = Map.get(context, :neutral_element, 1.0)
    multiplier = if parts.hand == :right_hand and parts.source == :weapon, do: 2, else: 1
    components = Renewal.prepare_components(parts, context)

    %{
      components
      | status_atk: trunc(components.status_atk * neutral) * multiplier,
        weapon_atk: trunc(components.weapon_atk * weapon),
        flat_atk: trunc(components.flat_atk * weapon)
    }
    |> Renewal.after_component_elements(context)
    |> Renewal.calculate_components(context)
    |> Renewal.finish_attack(context)
  end

  defp classic(parts, context) do
    parts
    |> PreRenewal.pre_element(context)
    |> Kernel.*(Map.get(context, :weapon_element, 1.0))
    |> trunc()
    |> PreRenewal.post_element(context)
  end
end
