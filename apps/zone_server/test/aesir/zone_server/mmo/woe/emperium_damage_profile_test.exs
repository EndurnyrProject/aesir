defmodule Aesir.ZoneServer.Mmo.Woe.EmperiumDamageProfileTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.HandedAttack
  alias Aesir.ZoneServer.Mmo.Mechanics
  alias Aesir.ZoneServer.Mmo.Mechanics.MobFormulas
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Player.WeaponHand
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats

  @emperium_mob_id 1288

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    stub(ModifierCalculator, :get_all_modifiers, fn _type, _id -> %{} end)
    :ok
  end

  test "the Emperium profile and imported HP follow the boot-selected mode" do
    assert MobFormulas.Renewal.emperium_damage_mode() == :plant
    assert MobFormulas.PreRenewal.emperium_damage_mode() == :normal

    {profile, hp} =
      case GameMode.mode() do
        :renewal -> {:plant, 100}
        :pre_renewal -> {:normal, 68_430}
      end

    assert Mechanics.mob_formulas().emperium_damage_mode() == profile
    assert {:ok, %{hp: ^hp, race: :angel}} = Mobs.by_id(@emperium_mob_id)
  end

  test "ordinary STR, critical, and multiplier inflation obey the active profile" do
    attacker =
      CombatTestHelper.create_player_combatant(str: 500, dex: 500, base_level: 200)
      |> maximize_weapon_damage()

    contacts = [
      DamageCalculator.calculate_damage(attacker, emperium(), skip_crit: true),
      DamageCalculator.calculate_damage(attacker, emperium(), force_crit: true),
      DamageCalculator.calculate_damage(attacker, emperium(),
        skill_ratio: 10_000,
        skip_crit: true
      )
    ]

    damages = Enum.map(contacts, fn {:ok, result} -> result.damage end)

    case GameMode.mode() do
      :renewal -> assert damages == [1, 1, 1]
      :pre_renewal -> assert Enum.all?(damages, &(&1 > 1))
    end
  end

  test "Double Attack changes display divisions without multiplying raw damage" do
    stub(Passives, :attack_procs, fn _player -> %{multi_hit: 2} end)
    attacker = accurate_player() |> maximize_weapon_damage()

    assert {:ok, result} =
             HandedAttack.calculate(player(%{48 => 10}), attacker, emperium(),
               rng: fn 100 -> 1 end
             )

    assert result.display_divisions == 2
    assert result.raw_total == result.primary.damage
    assert result.secondary == nil

    case GameMode.mode() do
      :renewal -> assert result.raw_total == 1
      :pre_renewal -> assert result.raw_total > 1
    end
  end

  test "misses and perfect dodge remain zero-damage swing outcomes" do
    miss_attacker =
      CombatTestHelper.create_player_combatant()
      |> then(fn attacker ->
        %{attacker | combat_stats: Map.put(attacker.combat_stats, :hit_rate_bonus_pct, -100)}
      end)

    assert {:ok, %{outcome: :miss, raw_total: 0}} =
             HandedAttack.calculate(player(), miss_attacker, emperium())

    perfect_dodge =
      emperium()
      |> then(fn defender ->
        %{defender | combat_stats: Map.put(defender.combat_stats, :perfect_dodge, 1_000)}
      end)

    assert {:ok, %{outcome: :perfect_dodge, raw_total: 0}} =
             HandedAttack.calculate(player(), accurate_player(), perfect_dodge)
  end

  test "the selected hand and explicit, status, then weapon element precedence are preserved" do
    stub(ModifierCalculator, :get_all_modifiers, fn
      :player, 1102 -> %{attack_element: :neutral}
      :player, 1103 -> %{attack_element: :holy}
      _type, _id -> %{}
    end)

    weapon_only =
      accurate_player(unit_id: 1101, weapon_element: :neutral)
      |> Map.put(:right_hand, hand(:right_hand, :dagger, :neutral))
      |> Map.put(:left_hand, hand(:left_hand, :dagger, :holy))
      |> maximize_weapon_damage()

    assert {:ok, primary} =
             DamageCalculator.calculate_damage(weapon_only, emperium(), skip_crit: true)

    assert {:ok, secondary} =
             DamageCalculator.calculate_secondary_hand_damage(weapon_only, emperium(),
               skip_crit: true
             )

    endow = accurate_player(unit_id: 1102, weapon_element: :holy) |> maximize_weapon_damage()
    override = accurate_player(unit_id: 1103, weapon_element: :holy) |> maximize_weapon_damage()

    assert {:ok, status_element} =
             DamageCalculator.calculate_damage(endow, emperium(), skip_crit: true)

    assert {:ok, explicit_element} =
             DamageCalculator.calculate_damage(override, emperium(),
               element: :neutral,
               skip_crit: true
             )

    case GameMode.mode() do
      :renewal ->
        assert {primary.damage, secondary.damage, status_element.damage, explicit_element.damage} ==
                 {1, 0, 1, 1}

      :pre_renewal ->
        assert primary.damage > secondary.damage
        assert secondary.damage == 1
        assert status_element.damage > secondary.damage
        assert explicit_element.damage > secondary.damage
    end
  end

  test "resisted and weak elements remain contacts while immunity remains zero" do
    attacker = accurate_player(str: 500) |> maximize_weapon_damage()

    damages =
      Map.new([:fire, :water, :earth, :wind, :poison, :shadow, :holy], fn element ->
        assert {:ok, result} =
                 DamageCalculator.calculate_damage(attacker, emperium(),
                   element: element,
                   skip_crit: true
                 )

        {element, result.damage}
      end)

    resisted = Map.take(damages, [:fire, :water, :earth, :wind, :poison])

    case GameMode.mode() do
      :renewal ->
        assert Enum.all?(resisted, fn {_element, damage} -> damage == 1 end)
        assert damages.shadow == 1
        assert damages.holy == 0

      :pre_renewal ->
        assert Enum.all?(resisted, fn {_element, damage} -> damage > 1 end)
        assert damages.shadow > Enum.max(Map.values(resisted))
        assert damages.holy == 1
    end
  end

  test "normalization precedes status absorption" do
    assert {:ok, swing} = HandedAttack.calculate(player(), accurate_player(), emperium())
    expected = swing.raw_total
    test_pid = self()

    expect(StatusInterpreter, :absorb_damage, fn :mob, 2001, incoming, hit_info ->
      send(test_pid, {:absorbed, incoming, hit_info})
      0
    end)

    assert {0, %{pre_delivery_prepared?: true}} =
             DamageApplication.prepare_unit_damage(
               :mob,
               2001,
               swing.raw_total,
               %{dmg_type: :physical, skill_id: nil},
               {:player, 1001}
             )

    assert_received {:absorbed, ^expected, %{dmg_type: :physical, skill_id: nil}}

    case GameMode.mode() do
      :renewal -> assert expected == 1
      :pre_renewal -> assert expected > 1
    end
  end

  test "Renewal suppresses the Katar secondary by typed Emperium identity" do
    attacker =
      accurate_player(weapon_type: :katar)
      |> Map.put(:right_hand, hand(:right_hand, :katar, :neutral))
      |> maximize_weapon_damage()

    assert {:ok, result} = HandedAttack.calculate(player(), attacker, emperium())

    case GameMode.mode() do
      :renewal ->
        assert result.primary.damage == 1
        assert result.secondary == nil
        assert result.raw_total == 1

      :pre_renewal ->
        assert result.secondary.damage > 0
        assert result.raw_total > result.primary.damage
    end
  end

  test "dual-hand scaling cannot resurrect an element-immune Renewal contact" do
    attacker =
      accurate_player(weapon_element: :holy)
      |> Map.put(:right_hand, hand(:right_hand, :dagger, :holy))
      |> Map.put(:left_hand, hand(:left_hand, :dagger, :holy))
      |> maximize_weapon_damage()

    assert {:ok, result} = HandedAttack.calculate(player(), attacker, emperium())

    case GameMode.mode() do
      :renewal ->
        assert result.primary.damage == 0
        assert result.secondary.damage == 0
        assert result.raw_total == 0

      :pre_renewal ->
        assert result.raw_total > 0
    end
  end

  test "non-handed ordinary attacks use the profile while non-objective mobs remain ordinary" do
    mob_attacker = CombatTestHelper.create_mob_combatant(atk: 5_000)
    player_attacker = accurate_player(str: 500) |> maximize_weapon_damage()
    angel = emperium(monster_id: 1002, element: {:neutral, 1}, def: 0, soft_def: 0)

    assert {:ok, non_handed} =
             DamageCalculator.calculate_damage(mob_attacker, emperium(), skip_crit: true)

    assert {:ok, non_objective} =
             DamageCalculator.calculate_damage(player_attacker, angel, skip_crit: true)

    case GameMode.mode() do
      :renewal -> assert non_handed.damage == 1
      :pre_renewal -> assert non_handed.damage > 1
    end

    assert non_objective.damage > 1
  end

  test "the pre-renewal ordinary and permitted Triple Attack calculations remain normal" do
    attacker = accurate_player(str: 500) |> maximize_weapon_damage()

    assert {:ok, ordinary} =
             DamageCalculator.calculate_damage(attacker, emperium(), skip_crit: true)

    assert {:ok, triple} =
             DamageCalculator.calculate_damage(attacker, emperium(),
               skill_id: 263,
               skill_ratio: 300,
               skip_crit: true
             )

    case GameMode.mode() do
      :renewal ->
        assert ordinary.damage == 1
        assert triple.damage > ordinary.damage

      :pre_renewal ->
        assert ordinary.damage > 1
        assert triple.damage > ordinary.damage
    end
  end

  defp emperium(opts \\ []) do
    defaults = [
      monster_id: @emperium_mob_id,
      race: :angel,
      element: {:holy, 1},
      def: 64,
      soft_def: 80,
      luk: 0
    ]

    defaults
    |> Keyword.merge(opts)
    |> CombatTestHelper.create_mob_combatant()
    |> then(fn defender ->
      %{defender | combat_stats: Map.put(defender.combat_stats, :perfect_dodge, 0)}
    end)
  end

  defp player(learned_skills \\ %{}) do
    %PlayerState{
      stats: %Stats{
        base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
        derived_stats: %DerivedStats{max_hp: 100, max_sp: 100},
        progression: %PlayerProgression{
          base_level: 50,
          job_level: 30,
          learned_skills: learned_skills
        }
      }
    }
  end

  defp accurate_player(opts \\ []) do
    opts
    |> Keyword.put_new(:dex, 500)
    |> Keyword.put_new(:flat_atk, 500)
    |> CombatTestHelper.create_player_combatant()
    |> Map.put(:equip_modifiers, %{perfect_hit_rate: 100})
  end

  defp maximize_weapon_damage(attacker) do
    %{attacker | combat_stats: Map.put(attacker.combat_stats, :max_weapon_damage, true)}
  end

  defp hand(slot, subtype, element) do
    %WeaponHand{
      weapon_level: 1,
      item_id: 1,
      subtype: subtype,
      element: element,
      base_atk: 100,
      refine_atk: 0,
      overrefine_band: 0,
      slot: slot
    }
  end
end
