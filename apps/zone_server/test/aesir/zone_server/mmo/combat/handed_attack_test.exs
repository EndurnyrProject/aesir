defmodule Aesir.ZoneServer.Mmo.Combat.HandedAttackTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.HandedAttack
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Player.WeaponHand
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats

  @right_hand 2
  @both_hands 34
  @dagger_id 1201
  @katar_id 1250

  test "unarmed attacks return one immutable swing component" do
    attacker = accurate_player()
    defender = defender()
    player = %PlayerState{}
    inputs = {player, attacker, defender}

    assert {:ok,
            %HandedAttack{
              primary: %{damage: damage, is_critical: false},
              secondary: nil,
              raw_total: damage,
              display_divisions: 1,
              outcome: :hit,
              primary_element: :neutral
            }} = HandedAttack.calculate(player, attacker, defender)

    assert damage > 0
    assert {player, attacker, defender} == inputs
  end

  test "right-only and left-only weapons remain one-component attacks" do
    player = player(%{}, :dagger)
    defender = defender()

    for attacker <- [
          with_hands(hand(:right_hand, 100), nil),
          with_hands(nil, hand(:left_hand, 80))
        ] do
      assert {:ok, %HandedAttack{primary: %{damage: damage}, secondary: nil, raw_total: damage}} =
               HandedAttack.calculate(player, attacker, defender)

      assert damage > 0
    end
  end

  test "dual daggers calculate both hands and apply min and max mastery rates after damage" do
    attacker = with_hands(hand(:right_hand, 100), hand(:left_hand, 80))
    defender = defender()

    assert {:ok, raw_primary} =
             DamageCalculator.calculate_damage(attacker, defender, skip_crit: true)

    assert {:ok, raw_secondary} =
             DamageCalculator.calculate_secondary_hand_damage(attacker, defender, skip_crit: true)

    assert {:ok, minimum} = HandedAttack.calculate(player(%{}, :dagger), attacker, defender)

    assert minimum.primary.damage == max(div(raw_primary.damage * 50, 100), 1)
    assert minimum.secondary.damage == max(div(raw_secondary.damage * 30, 100), 1)
    assert minimum.raw_total == minimum.primary.damage + minimum.secondary.damage

    assert {:ok, maximum} =
             HandedAttack.calculate(player(%{132 => 5, 133 => 5}, :dagger), attacker, defender)

    assert maximum.primary.damage == raw_primary.damage
    assert maximum.secondary.damage == max(div(raw_secondary.damage * 80, 100), 1)
  end

  test "one critical decision governs both dual-dagger components" do
    attacker =
      with_hands(hand(:right_hand, 100), hand(:left_hand, 80))
      |> put_critical(1_000)

    assert {:ok,
            %HandedAttack{
              primary: %{is_critical: true},
              secondary: %{is_critical: true},
              outcome: :critical
            }} = HandedAttack.calculate(player(%{}, :dagger), attacker, defender())
  end

  test "successful Double Attack adds HIT before the shared roll and disables criticals" do
    attacker =
      with_hands(hand(:right_hand, 100), nil)
      |> put_hit(20)
      |> put_critical(1_000)

    target = defender() |> put_flee(20)
    double_attack = player(%{48 => 10}, :dagger)

    :rand.seed(:exsss, {2, 3, 4})

    assert {:ok,
            %HandedAttack{
              primary: %{damage: damage, is_critical: false},
              secondary: nil,
              raw_total: damage,
              display_divisions: 2,
              outcome: :hit
            }} = HandedAttack.calculate(double_attack, attacker, target, rng: fn 100 -> 1 end)

    assert damage > 0
  end

  test "failed Double Attack adds no HIT and leaves one display division" do
    attacker = with_hands(hand(:right_hand, 100), nil) |> put_hit(20)
    target = defender() |> put_flee(20)

    assert {:ok,
            %HandedAttack{
              primary: %{damage: 0, is_critical: false},
              secondary: nil,
              raw_total: 0,
              display_divisions: 1,
              outcome: :miss
            }} =
             HandedAttack.calculate(player(%{48 => 10}, :dagger), attacker, target,
               rng: fn 100 -> 100 end
             )
  end

  test "perfect dodge is one zero-damage swing outcome" do
    target = defender() |> put_perfect_dodge(1_000)

    assert {:ok,
            %HandedAttack{
              primary: %{damage: 0},
              secondary: nil,
              raw_total: 0,
              outcome: :perfect_dodge
            }} =
             HandedAttack.calculate(
               player(%{}, :dagger),
               with_hands(hand(:right_hand), nil),
               target
             )
  end

  test "Katar secondary derives from final primary at the Double Attack rate" do
    attacker = with_hands(hand(:right_hand, 100, :katar), nil)

    for {level, rate} <- [{0, 1}, {10, 21}] do
      learned = if level == 0, do: %{}, else: %{48 => level}

      assert {:ok, %HandedAttack{primary: primary, secondary: secondary, display_divisions: 1}} =
               HandedAttack.calculate(player(learned, :katar), attacker, defender())

      assert secondary.damage == div(primary.damage * rate, 100)
      assert secondary.is_critical == primary.is_critical
    end
  end

  test "Katar has no secondary against Aesir's plant target representation" do
    attacker = with_hands(hand(:right_hand, 100, :katar), nil)
    plant = defender() |> Map.put(:race, :plant)

    assert {:ok, %HandedAttack{primary: %{damage: damage}, secondary: nil, raw_total: damage}} =
             HandedAttack.calculate(player(%{48 => 10}, :katar), attacker, plant)
  end

  test "bCriticalLong applies only to ordinary ammunition-based ranged attacks" do
    ranged =
      accurate_player()
      |> put_critical(0)
      |> put_in([Access.key!(:weapon), Access.key!(:type)], :bow)
      |> Map.put(:equip_modifiers, %{critical_long: 100})

    melee =
      accurate_player()
      |> put_critical(0)
      |> Map.put(:equip_modifiers, %{critical_long: 100})

    assert {:ok, %HandedAttack{outcome: :critical}} =
             HandedAttack.calculate(%PlayerState{}, ranged, defender())

    assert {:ok, %HandedAttack{outcome: :hit}} =
             HandedAttack.calculate(%PlayerState{}, melee, defender())
  end

  test "minimal player context and mob combatants retain aggregate one-component behavior" do
    mob =
      CombatTestHelper.create_mob_combatant(atk: 50, dex: 200, luk: 0)
      |> put_hit(200)

    assert {:ok, %HandedAttack{primary: %{damage: damage}, secondary: nil, raw_total: damage}} =
             HandedAttack.calculate(%PlayerState{}, mob, defender())

    assert damage > 0
  end

  test "calculator errors are returned unchanged" do
    attacker = %{accurate_player() | unit_type: :unknown}

    assert {:error, :unknown_unit_type} =
             HandedAttack.calculate(%PlayerState{}, attacker, defender())
  end

  defp player(learned_skills, weapon_type) do
    {item_id, equip} =
      case weapon_type do
        :dagger -> {@dagger_id, @right_hand}
        :katar -> {@katar_id, @both_hands}
      end

    inventory = [%InventoryItem{nameid: item_id, amount: 1, equip: equip, identify: 1}]

    stats = %Stats{
      base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      derived_stats: %DerivedStats{max_hp: 100, max_sp: 100},
      progression: %PlayerProgression{
        base_level: 50,
        job_level: 30,
        learned_skills: learned_skills
      },
      equipment: Stats.equipment_from_inventory(inventory)
    }

    %PlayerState{stats: stats}
  end

  defp accurate_player do
    CombatTestHelper.create_player_combatant(dex: 200, luk: 0)
    |> put_hit(200)
  end

  defp defender do
    CombatTestHelper.create_mob_combatant(agi: 0, luk: 0, def: 0)
    |> put_flee(0)
    |> put_perfect_dodge(0)
  end

  defp with_hands(right, left) do
    aggregate_atk =
      40 + if(right, do: right.base_atk + right.refine_atk, else: 0) +
        if(left, do: left.base_atk + left.refine_atk, else: 0)

    accurate_player()
    |> Map.put(:right_hand, right)
    |> Map.put(:left_hand, left)
    |> Map.put(:weapon, %{
      type: if(right, do: right.subtype, else: left.subtype),
      element: if(right, do: right.element, else: left.element),
      size: :all
    })
    |> then(fn combatant ->
      %{
        combatant
        | combat_stats:
            Map.merge(combatant.combat_stats, %{atk: aggregate_atk, max_weapon_damage: true})
      }
    end)
  end

  defp hand(slot, base_atk \\ 100, subtype \\ :dagger) do
    %WeaponHand{
      item_id: if(subtype == :katar, do: @katar_id, else: @dagger_id),
      subtype: subtype,
      element: :neutral,
      base_atk: base_atk,
      refine_atk: 0,
      overrefine_band: 0,
      slot: slot
    }
  end

  defp put_hit(combatant, hit), do: put_in(combatant.combat_stats.hit, hit)
  defp put_flee(combatant, flee), do: put_in(combatant.combat_stats.flee, flee)

  defp put_perfect_dodge(combatant, perfect_dodge),
    do: put_in(combatant.combat_stats.perfect_dodge, perfect_dodge)

  defp put_critical(combatant, critical),
    do: %{combatant | combat_stats: Map.put(combatant.combat_stats, :critical, critical)}
end
