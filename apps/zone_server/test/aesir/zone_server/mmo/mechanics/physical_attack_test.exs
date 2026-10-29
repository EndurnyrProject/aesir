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

  test "status weapon ATK shifts the renewal centre and raises the classic maximum" do
    inputs = %{weapon_inputs() | status_watk: 20}

    assert Renewal.weapon_bounds(inputs) == {142, 172}
    assert PreRenewal.weapon_bounds(inputs) == {42, 119}

    # The classic DEX minimum is capped by the raised maximum.
    low = %{inputs | base_atk: 10, dex: 30}
    assert PreRenewal.weapon_bounds(low) == {30, 30}
    assert PreRenewal.weapon_bounds(%{low | status_watk: 0}) == {10, 10}
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
      |> Map.put(:attacker_cards, [100])
      |> Map.merge(%{patk: 100, equipment_atk_rate: 50})

    assert renewal(parts(), context) == 677
    assert classic(parts(), context) == 308
  end

  test "Renewal EDP scales cardfixed weapon and equipment, not status mastery or percent ATK" do
    context = neutral_context() |> Map.merge(%{edp_level: 5, attacker_cards: [10]})
    assert renewal(parts(), context) == 563

    context = neutral_context() |> Map.merge(%{edp_level: 5, equipment_atk_rate: 50})
    assert renewal(parts(), context) == 578

    for skill_id <- [149, 141, 406, 137, 1004] do
      context = neutral_context() |> Map.merge(%{edp_level: 5, skill_id: skill_id})
      assert renewal(parts(), context) == 165
    end
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

    assert renewal(parts(), context) == 390
    assert classic(parts(), context) == 344
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
        defender_cards: %{weapon: [50, 20, 25], status: [20, 25]},
        res: 100
      })

    assert renewal(parts(), context) == 60
    assert classic(parts(), context) == 70
  end

  test "the race card scales only weapon and equipment ATK; flat, status ATK and range rate survive" do
    context =
      neutral_context()
      |> Map.merge(%{
        attacker_cards: [50],
        flat_bonus: 4,
        atk_rate: 25,
        long_atk_rate: 20
      })

    # Renewal: status 40 and mastery 7 take only the 25% rate (50, 8); weapon
    # 103 and equipment 19 take the card (154, 28) then the rate (192, 35);
    # 277 + 8, then the long rate: 342. Classic: 142 at 125% is 177, the
    # minimum soft DEF leaves 176, refine 10 and mastery 7 make 193, then the
    # card and the range rate as one product: 347.
    assert renewal(parts(), context) == 342
    assert classic(parts(), %{context | attacker_cards: [50, 20]}) == 347
  end

  test "the ATK percent starts the renewal skill ratio and multiplies the classic one after it" do
    context =
      neutral_context()
      |> Map.merge(%{skill_ratio: 200, status_skill_ratio: 50, atk_rate: 25})

    # Renewal: 165 at (200 + 50 + 25)% = 453. Classic: 138 at 250% = 345, then
    # at 125% = 431, the minimum soft DEF leaves 430, refine 10 and mastery 7.
    assert renewal(parts(), context) == 453
    assert classic(parts(), context) == 447

    # Without the status adds the classic percent is the same product; renewal
    # loses the 50 ratio points.
    assert renewal(parts(), Map.delete(context, :status_skill_ratio)) == 371
    assert classic(parts(), Map.delete(context, :status_skill_ratio)) == 361
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
      Map.put(neutral_context(), :defender_cards, %{weapon: [0], status: [0]})

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

  describe "Renewal Stave Crasher MATK insertion" do
    test "joins weapon ATK after the equipment percentage part and before weapon cards" do
      weapon_only = %{
        parts()
        | status_atk: 0,
          flat_atk: 0,
          refine_atk: 0,
          overrefine_atk: 0,
          mastery_atk: 0
      }

      context =
        neutral_context()
        |> Map.put(:defense_mode, :ignore)
        |> Map.put(:attacker_cards, [50])
        |> Map.merge(%{equipment_atk_rate: 20, stave_matk: 200})

      assert renewal(weapon_only, context) == 470
    end

    test "is not scaled by the weapon's preceding attribute step" do
      weapon_only = %{
        parts()
        | status_atk: 0,
          flat_atk: 0,
          refine_atk: 0,
          overrefine_atk: 0,
          mastery_atk: 0
      }

      context =
        neutral_context()
        |> Map.merge(%{defense_mode: :ignore, weapon_element: 1.5, stave_matk: 200})

      assert renewal(weapon_only, context) == 350
    end
  end

  describe "Renewal Advanced Katar Mastery rate" do
    test "raises the damage after the skill ratio and its constant addition" do
      weapon_only = %{
        parts()
        | status_atk: 0,
          flat_atk: 0,
          refine_atk: 0,
          overrefine_atk: 0,
          mastery_atk: 0
      }

      context =
        neutral_context()
        |> Map.merge(%{defense_mode: :ignore, skill_ratio: 200, bonus_atk: 10})

      # 100 * 200% + 10 = 210; + 20% = 252 (250 if the rate came before the + 10).
      assert renewal(weapon_only, context) == 210
      assert renewal(weapon_only, Map.put(context, :katar_atk_rate, 20)) == 252
    end
  end

  describe "Renewal weapon element property rate (SC_WATK_ELEMENT)" do
    test "raises only the weapon component, after its cards and before EDP" do
      weapon_only = %{
        parts()
        | weapon_atk: 103,
          status_atk: 0,
          flat_atk: 0,
          refine_atk: 0,
          overrefine_atk: 0,
          mastery_atk: 0
      }

      context = neutral_context() |> Map.merge(%{defense_mode: :ignore, edp_level: 1})

      # EDP level 1 is 280%. 103 + 20% = 123, * 2.8 = 344 (345 if EDP came first).
      assert renewal(weapon_only, context) == 288
      assert renewal(weapon_only, Map.put(context, :watk_element_rate, 20)) == 344
    end

    test "leaves the equipment component alone" do
      equipment_only = %{
        parts()
        | weapon_atk: 0,
          status_atk: 0,
          refine_atk: 0,
          overrefine_atk: 0,
          mastery_atk: 0
      }

      context = Map.put(neutral_context(), :defense_mode, :ignore)

      assert renewal(equipment_only, Map.put(context, :watk_element_rate, 20)) ==
               renewal(equipment_only, context)
    end
  end

  defp neutral_context do
    %{
      context()
      | size_rate: 100,
        weapon_element: 1.0,
        neutral_element: 1.0,
        attacker_cards: [],
        defense: %{hard_def: 0, soft_def: 0, attacker_level: nil, ignore_soft_def?: false}
    }
  end

  defp context do
    %{
      size_rate: 50,
      weapon_element: 1.5,
      neutral_element: 0.5,
      attacker_cards: [100],
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
      max_weapon_damage?: false,
      status_watk: 0
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

  describe "classic normal-attack base for Magnum Break" do
    test "normal_base sizes the weapon and takes the critical or non-critical rate" do
      context = %{size_rate: 50, non_crit_atk_rate: 10, crit_atk_rate: 20}

      # 20 status + 15 flat + 100 * 50% + 3 overrefine = 88.
      assert PreRenewal.normal_base(parts(), context) == 96
      assert PreRenewal.normal_base(parts(), Map.put(context, :critical?, true)) == 105
      assert PreRenewal.normal_base(%{parts() | source: :shield}, context) == 96
    end

    test "magnum_break_base takes ATK rate, full DEF, refine and masteries with its minimums" do
      context = %{
        atk_rate: 20,
        critical?: true,
        defense_mode: :ignore,
        defense: %{hard_def: 10, soft_def: 5, ignore_soft_def?: false}
      }

      # 100 * 120% = 120, * 90% - 5 = 103, + 7 refine, + 4 masteries.
      assert PreRenewal.magnum_break_base(100, context, %{refine_atk: 7, mastery_atk: 4}) == 114

      weak = %{
        context
        | atk_rate: 0,
          defense: %{hard_def: 0, soft_def: 10, ignore_soft_def?: false}
      }

      assert PreRenewal.magnum_break_base(3, weak, %{refine_atk: 2, mastery_atk: 0}) == 1
    end
  end

  describe "equipment critical reduction (bCritDefRate)" do
    test "classic reduces a critical normal attack's base after the critical bonus only" do
      context = %{size_rate: 50, crit_atk_rate: 20, crit_def_rate: 30, critical?: true}

      # 88 base, + 20% = 105, - 30% (truncating the removed share) = 74.
      assert PreRenewal.normal_base(parts(), context) == 74
      assert PreRenewal.normal_base(parts(), %{context | critical?: false}) == 88

      flat = %{size_rate: 100, critical?: true, crit_def_rate: 30, defense: %{}}
      plain = %{parts() | weapon_atk: 100, status_atk: 0, flat_atk: 0, overrefine_atk: 0}
      plain = %{plain | refine_atk: 0, mastery_atk: 0}

      assert PreRenewal.pre_element(plain, flat) == 70
      assert PreRenewal.pre_element(plain, Map.put(flat, :skill_id, 5)) == 100
      assert PreRenewal.pre_element(plain, %{flat | crit_def_rate: -10}) == 110
    end

    test "renewal reduces any critical after the critical multiplier" do
      context = %{critical?: true, crate: 0, crit_def_rate: 25}

      # 100 * 1.4 = 140, - 25% = 105.
      assert Renewal.finish_attack(100, context) == 105
      assert Renewal.finish_attack(100, Map.put(context, :skill_id, 5)) == 105
      assert Renewal.finish_attack(100, %{context | critical?: false}) == 100
    end
  end

  test "classic post-defense keeps the right hand at 1 and the left hand at 0" do
    parts = %{parts() | status_atk: 0, flat_atk: 0, weapon_atk: 10, refine_atk: 0}
    parts = %{parts | overrefine_atk: 0, mastery_atk: 0}
    context = %{size_rate: 100, defense: %{hard_def: 100, soft_def: 5, ignore_soft_def?: false}}

    assert PreRenewal.pre_element(parts, context) == 1
    assert PreRenewal.pre_element(%{parts | hand: :left_hand}, context) == 0
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
