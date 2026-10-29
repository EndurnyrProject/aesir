defmodule Aesir.ZoneServer.Mmo.Combat.InfiniteDefenseTest do
  @moduledoc """
  Monsters with the Ignore modes take every matching hit as a 1-damage contact:
  weapon hits skip their recipe and run only the blocking statuses, magic and
  misc hits deal 1 and keep their delivery tail.
  """

  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup
  import Bitwise

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.HandedAttack
  alias Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.MiscDamageCalculator
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Player.WeaponHand
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @all_modes [:ignore_melee, :ignore_magic, :ignore_ranged, :ignore_misc]

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    stub(ModifierCalculator, :get_all_modifiers, fn _type, _id -> %{} end)
    :ok
  end

  describe "Combatant.infinite_defense?/2" do
    test "each mode matches only its battle flag" do
      melee = BattleFlags.build(:weapon, :short, false)
      ranged = BattleFlags.build(:weapon, :long, true)
      magic = BattleFlags.build(:magic, :short, true)
      misc = BattleFlags.build(:misc, :long, true)

      assert Combatant.infinite_defense?(target([:ignore_melee]), melee)
      refute Combatant.infinite_defense?(target([:ignore_melee]), ranged)
      assert Combatant.infinite_defense?(target([:ignore_ranged]), ranged)
      refute Combatant.infinite_defense?(target([:ignore_ranged]), melee)
      assert Combatant.infinite_defense?(target([:ignore_magic]), magic)
      refute Combatant.infinite_defense?(target([:ignore_magic]), misc)
      assert Combatant.infinite_defense?(target([:ignore_misc]), misc)
      refute Combatant.infinite_defense?(target([:ignore_misc]), magic)
      refute Combatant.infinite_defense?(target([]), melee)
    end

    test "a misc hit that also carries the weapon bit matches the weapon modes" do
      thrown = BattleFlags.build(:misc, :short, true) ||| BattleFlags.type_bit(:weapon)

      assert Combatant.infinite_defense?(target([:ignore_melee]), thrown)
      refute Combatant.infinite_defense?(target([:ignore_ranged]), thrown)
    end
  end

  describe "misc hits" do
    @land_mine 116

    defp misc(defender, opts) do
      flag = Keyword.get(opts, :attack_flag, BattleFlags.build(:misc, :short, true))

      MiscDamageCalculator.calculate_misc_damage(
        attacker(),
        defender,
        Keyword.merge([skill_id: @land_mine, attack_flag: flag, element: :neutral], opts)
      )
    end

    test "any positive damage becomes 1" do
      assert {:ok, %{damage: 1}} = misc(target([:ignore_misc]), base_damage: 500)
      assert {:ok, %{damage: 500}} = misc(target([:ignore_magic]), base_damage: 500)
    end

    test "an element-immune hit stays 0" do
      defender = target([:ignore_misc], element: {:ghost, 4})

      assert {:ok, %{damage: 0}} = misc(defender, base_damage: 500)
    end

    test "the hit's own battle flag decides the weapon modes" do
      thrown = BattleFlags.build(:misc, :short, true) ||| BattleFlags.type_bit(:weapon)

      assert {:ok, %{damage: 1}} =
               misc(target([:ignore_melee]), base_damage: 500, attack_flag: thrown)

      assert {:ok, %{damage: 500}} = misc(target([:ignore_melee]), base_damage: 500)
    end
  end

  describe "magic hits" do
    test "deal 1 before any other step, fixed amounts included" do
      assert {:ok, %{damage: 1}} =
               MagicDamageCalculator.calculate_magic_damage(attacker(), target([:ignore_magic]),
                 skill_ratio: 1_000
               )

      assert {:ok, %{damage: 1}} =
               MagicDamageCalculator.calculate_magic_damage(attacker(), target([:ignore_magic]),
                 fixed_damage: 999
               )

      assert {:ok, %{damage: 999}} =
               MagicDamageCalculator.calculate_magic_damage(attacker(), target([:ignore_melee]),
                 fixed_damage: 999
               )
    end
  end

  describe "weapon hits" do
    test "a melee hit on an :ignore_melee target is a 1-damage contact" do
      assert {:ok, %{damage: 1, plant: :ordinary}} =
               DamageCalculator.calculate_damage(strong(), target([:ignore_melee]),
                 skill_ratio: 10_000,
                 skip_crit: true
               )

      assert {:ok, %{damage: 1, plant: :ordinary}} =
               DamageCalculator.calculate_damage(strong(), target([:ignore_melee]),
                 fixed_damage: 500
               )
    end

    test "the range decides between :ignore_melee and :ignore_ranged" do
      assert {:ok, result} =
               DamageCalculator.calculate_damage(strong(), target([:ignore_melee]),
                 ranged: true,
                 skip_crit: true
               )

      assert result.damage > 1
      refute Map.has_key?(result, :plant)

      assert {:ok, %{damage: 1}} =
               DamageCalculator.calculate_damage(strong(), target([:ignore_ranged]),
                 ranged: true,
                 skip_crit: true
               )
    end

    test "only the Emperium's contact takes the attribute step" do
      assert {:ok, %{damage: 0, plant: :emperium}} =
               DamageCalculator.calculate_damage(strong(), emperium(),
                 element: :holy,
                 skip_crit: true
               )

      assert {:ok, %{damage: 1, plant: :ordinary}} =
               DamageCalculator.calculate_damage(
                 strong(),
                 target(@all_modes, element: {:holy, 1}),
                 element: :holy,
                 skip_crit: true
               )
    end

    test "Triple Attack keeps its hit count; classic requires exactly 100 DEF" do
      opts = [skill_id: 263, skill_ratio: 300, skip_crit: true]

      assert {:ok, low_def} =
               DamageCalculator.calculate_damage(strong(), target(@all_modes), opts)

      assert {:ok, %{plant: :unsplit}} =
               DamageCalculator.calculate_damage(strong(), target(@all_modes, def: 100), opts)

      case GameMode.mode() do
        :renewal -> assert low_def.plant == :unsplit
        :pre_renewal -> assert low_def.plant == :ordinary
      end
    end

    test "normalize_divisions multiplies, splits, keeps or never splits a contact" do
      contact = %{damage: 1, is_critical: false}

      assert {%{damage: 2}, 2} =
               DamageCalculator.normalize_divisions(Map.put(contact, :plant, :ordinary), 2)

      assert {%{damage: 0}, 3} =
               DamageCalculator.normalize_divisions(Map.put(contact, :plant, :ordinary), -3)

      assert {%{damage: 3, plant: :unsplit}, 3} =
               DamageCalculator.normalize_divisions(Map.put(contact, :plant, :unsplit), -3)

      assert {%{damage: 1, plant: :emperium}, 2} =
               DamageCalculator.normalize_divisions(Map.put(contact, :plant, :emperium), 2)

      assert {%{damage: 300}, 3} =
               DamageCalculator.normalize_divisions(%{contact | damage: 100}, 3)
    end
  end

  describe "ordinary swings" do
    test "Double Attack deals 2, except on the Emperium" do
      stub(Passives, :attack_procs, fn _player -> %{multi_hit: 2} end)

      assert {:ok, %HandedAttack{raw_total: 2, display_divisions: 2, secondary: nil}} =
               HandedAttack.calculate(player(), accurate(), target(@all_modes),
                 rng: fn 100 -> 1 end
               )

      assert {:ok, %HandedAttack{raw_total: 1, display_divisions: 2}} =
               HandedAttack.calculate(player(), accurate(), emperium(), rng: fn 100 -> 1 end)
    end

    test "each hand deals 1 without hand rates, capped at 1 each" do
      dual = dual_wield(:neutral)

      assert {:ok, %HandedAttack{primary: %{damage: 1}, secondary: %{damage: 1}, raw_total: 2}} =
               HandedAttack.calculate(player(), dual, target(@all_modes))

      stub(Passives, :attack_procs, fn _player -> %{multi_hit: 2} end)

      assert {:ok, %HandedAttack{primary: %{damage: 1}, secondary: %{damage: 1}, raw_total: 2}} =
               HandedAttack.calculate(player(), dual, target(@all_modes), rng: fn 100 -> 1 end)
    end

    test "a katar has no off-hand contact" do
      katar =
        accurate(weapon_type: :katar)
        |> Map.put(:right_hand, hand(:right_hand, :katar, :neutral))

      assert {:ok, %HandedAttack{raw_total: 1, secondary: nil}} =
               HandedAttack.calculate(player(), katar, target(@all_modes))
    end

    test "an immune right hand on the Emperium leaves the off-hand's 1" do
      assert {:ok, %HandedAttack{primary: %{damage: 0}, secondary: %{damage: 1}, raw_total: 1}} =
               HandedAttack.calculate(player(), dual_wield(:holy), emperium())
    end
  end

  describe "delivery" do
    setup :setup_ets_tables

    test "a contact runs only the blocking statuses on a monster" do
      reject(&Interpreter.absorb_hit/4)

      expect(Interpreter, :block_hit, fn :mob, 2001, %{attacker: {:player, 1001}} -> {1, :hit} end)

      assert {2, %{pre_delivery_prepared?: true}} =
               DamageApplication.prepare_unit_damage(
                 :mob,
                 2001,
                 2,
                 contact_hit(),
                 {:player, 1001}
               )
    end

    test "a blocked contact deals nothing" do
      expect(Interpreter, :block_hit, fn :mob, 2001, _hit -> {0, :block} end)

      assert {0, %{blocked?: true}} =
               DamageApplication.prepare_unit_damage(
                 :mob,
                 2001,
                 1,
                 contact_hit(),
                 {:player, 1001}
               )
    end

    test "a blocking status stops the single point of a contact" do
      stub(UnitRegistry, :get_unit_info, fn :mob, id ->
        {:ok, %{unit_id: id, unit_type: :mob, stats: %{max_hp: 100, hp: 100, level: 1}}}
      end)

      :ok = StatusStorage.apply_status(:mob, 2002, :sc_pneuma)

      assert {0, :block} =
               Interpreter.block_hit(:mob, 2002, %{
                 dmg_type: :physical,
                 is_short: false,
                 attacker: nil
               })

      assert {1, :hit} =
               Interpreter.block_hit(:mob, 2003, %{
                 dmg_type: :physical,
                 is_short: false,
                 attacker: nil
               })
    end

    test "Kyrie Eleison absorbing the point stops the contact without a block" do
      stub(UnitRegistry, :get_unit_info, fn :mob, id ->
        {:ok, %{unit_id: id, unit_type: :mob, stats: %{max_hp: 100, hp: 100, level: 1}}}
      end)

      :ok =
        Interpreter.apply_status(:mob, 2004, :sc_kyrie,
          loaded: true,
          duration: 60_000,
          val2: 100,
          val3: 5
        )

      assert {0, hit} =
               DamageApplication.prepare_unit_damage(
                 :mob,
                 2004,
                 1,
                 contact_hit(),
                 {:player, 1001}
               )

      refute Map.has_key?(hit, :blocked?)

      assert %{state: %{shield_hp: 99, hits_remaining: 4}} =
               StatusStorage.get_status(:mob, 2004, :sc_kyrie)
    end

    @tag game_mode: :pre_renewal
    test "a Soul Destroyer contact on a plant deals 1, without its INT part" do
      stub(UnitRegistry, :get_unit_info, fn :mob, id ->
        {:ok, %{unit_id: id, unit_type: :mob, stats: %{max_hp: 100, hp: 100, level: 1}}}
      end)

      :ok = Interpreter.apply_status(:mob, 2005, :sc_aeterna, [])
      hit = %{contact_hit() | skill_id: 379} |> Map.put(:misc_part, 500)

      assert {1, _hit} =
               DamageApplication.prepare_unit_damage(:mob, 2005, 1, hit, {:player, 1001})

      assert StatusStorage.has_status?(:mob, 2005, :sc_aeterna)
    end

    test "mark_infinite_defense copies only a contact's plant kind" do
      assert %{infinite_defense: :ordinary} =
               DamageApplication.mark_infinite_defense(%{}, %{damage: 1, plant: :ordinary})

      assert %{} == DamageApplication.mark_infinite_defense(%{}, %{damage: 1})
    end
  end

  defp contact_hit,
    do: %{dmg_type: :physical, is_short: true, skill_id: 5, infinite_defense: :ordinary}

  defp target(modes, opts \\ []) do
    [element: {:neutral, 1}, def: 10]
    |> Keyword.merge(opts)
    |> CombatTestHelper.create_mob_combatant()
    |> Map.put(:ignore_modes, modes)
    |> no_dodge()
  end

  defp emperium do
    [monster_id: 1288, race: :angel, element: {:holy, 1}, def: 64, soft_def: 80]
    |> CombatTestHelper.create_mob_combatant()
    |> Map.put(:ignore_modes, @all_modes)
    |> no_dodge()
  end

  defp no_dodge(defender),
    do: %{defender | combat_stats: Map.put(defender.combat_stats, :perfect_dodge, 0)}

  defp attacker, do: CombatTestHelper.create_player_combatant()

  defp strong, do: CombatTestHelper.create_player_combatant(str: 300, flat_atk: 500)

  defp accurate(opts \\ []) do
    opts
    |> Keyword.put_new(:dex, 500)
    |> Keyword.put_new(:flat_atk, 500)
    |> CombatTestHelper.create_player_combatant()
    |> Map.put(:equip_modifiers, %{perfect_hit_rate: 100})
  end

  defp dual_wield(element) do
    accurate(weapon_element: element)
    |> Map.put(:right_hand, hand(:right_hand, :dagger, element))
    |> Map.put(:left_hand, hand(:left_hand, :dagger, element))
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

  defp player do
    %PlayerState{
      stats: %Stats{
        base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
        derived_stats: %DerivedStats{max_hp: 100, max_sp: 100},
        progression: %PlayerProgression{base_level: 50, job_level: 30, learned_skills: %{}}
      }
    }
  end
end
