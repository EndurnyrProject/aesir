defmodule Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculatorTest do
  @moduledoc """
  Tests for the renewal magic damage calculator.

  Numbers are hand-computed against the rAthena renewal MDEF formula
  (`battle.cpp:6105`): `dmg = matk * (1000 + hardMDEF) / (1000 + 10*hardMDEF) - softMDEF`,
  floored at 1. Magic always hits and never crits.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator

  @element_status_keys [
    water: :subele_water,
    earth: :subele_earth,
    fire: :subele_fire,
    wind: :subele_wind
  ]

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Mimic.copy(ModifierCalculator)
    stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)
    :ok
  end

  defp attacker(matk, extra \\ %{}) do
    %{unit_type: :player, unit_id: 1001, combat_stats: Map.merge(%{matk: matk}, extra)}
  end

  defp banded_attacker(min, max) do
    %{
      unit_type: :player,
      unit_id: 1001,
      combat_stats: %{matk: max, matk_min: min, matk_max: max}
    }
  end

  defp defender(hard_mdef, soft_mdef, element \\ {:neutral, 1}, extra \\ %{}) do
    %{
      unit_type: :mob,
      unit_id: 2001,
      combat_stats: Map.merge(%{mdef: hard_mdef, soft_mdef: soft_mdef}, extra),
      element: element
    }
  end

  # Equipment reads require a real `%Combatant{}` (only those carry an
  # `equip_modifiers` map); the plain-map fixtures above exercise the
  # equipment-inert path.
  defp full_combatant(overrides) do
    defaults = %{
      unit_id: 1,
      unit_type: :player,
      base_stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      combat_stats: %{matk: 100, matk_min: 100, matk_max: 100, mdef: 0, soft_mdef: 0},
      progression: %{base_level: 1, job_level: 1},
      element: {:neutral, 1},
      race: :formless,
      size: :medium,
      weapon: %{type: :fist, element: :neutral, size: :medium},
      attack_range: 1,
      attack_delay_ms: 1000,
      class: :normal,
      equip_modifiers: %{}
    }

    struct!(Combatant, Map.merge(defaults, Map.new(overrides)))
  end

  defp c_attacker(matk, equip, extra \\ []) do
    full_combatant(
      [
        unit_id: 1001,
        unit_type: :player,
        combat_stats: %{matk: matk, matk_min: matk, matk_max: matk, mdef: 0, soft_mdef: 0},
        equip_modifiers: equip
      ] ++ extra
    )
  end

  defp c_defender(hard_mdef, soft_mdef, extra \\ []) do
    full_combatant(
      [
        unit_id: 2001,
        unit_type: :mob,
        combat_stats: %{matk: 0, matk_min: 0, matk_max: 0, mdef: hard_mdef, soft_mdef: soft_mdef}
      ] ++ extra
    )
  end

  defp magic_damage_with_defender_modifiers(attacker, defender, element, modifiers) do
    defender_type = defender.unit_type
    defender_id = defender.unit_id

    stub(ModifierCalculator, :get_all_modifiers, fn
      ^defender_type, ^defender_id -> modifiers
      _, _ -> %{}
    end)

    {:ok, result} =
      MagicDamageCalculator.calculate_magic_damage(attacker, defender, element: element)

    result.damage
  end

  describe "calculate_magic_damage/3" do
    test "baseline single hit applies MDEF reduction and floors" do
      # matk 100, ratio 100, neutral vs neutral, hard 10 / soft 5:
      # 100 * 1010 / 1100 = 91.818..., - 5 = 86.818... -> trunc 86
      assert {:ok, %{damage: 86, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(attacker(100), defender(10, 5))
    end

    test "skill_ratio scales the base MATK" do
      # ratio 300: skilled = 300; 300 * 1010 / 1100 = 275.454..., - 5 = 270.454... -> 270
      assert {:ok, %{damage: 270, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(attacker(100), defender(10, 5),
                 skill_ratio: 300
               )
    end

    test "bonus_matk adds a flat amount after the skill ratio" do
      # skilled = div(100*100,100) + 50 = 150; 150 * 1010 / 1100 = 137.727..., - 5 = 132.727 -> 132
      assert {:ok, %{damage: 132, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(attacker(100), defender(10, 5),
                 bonus_matk: 50
               )
    end

    test "fixed_damage short-circuits the whole pipeline" do
      assert {:ok, %{damage: 50, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(attacker(9999), defender(500, 500),
                 fixed_damage: 50,
                 skill_ratio: 400,
                 element: :fire
               )
    end

    test "element modifier multiplies before MDEF reduction" do
      # fire vs earth (level 1) = 2.0: skilled 100 -> 200; 200 * 1010 / 1100 = 183.636, - 5 = 178.636 -> 178
      assert {:ok, %{damage: 178, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(
                 attacker(100),
                 defender(10, 5, {:earth, 1}),
                 element: :fire
               )
    end

    test "status damage_multiplier scales damage" do
      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{damage_multiplier: 0.5} end)

      # skilled 100, element 1.0, *1.5 = 150; 150 * 1010 / 1100 = 137.727, - 5 = 132.727 -> 132
      assert {:ok, %{damage: 132, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(attacker(100), defender(10, 5))
    end

    test "target race and size select consecutive Renewal magic bonuses" do
      stub(ModifierCalculator, :get_all_modifiers, fn
        :player, 1001 ->
          %{
            {:magic_addsize, :large} => 20,
            {:magic_addsize, :all} => 5,
            {:magic_addrace, :demon} => 30,
            {:magic_addrace, :all} => 5
          }

        _, _ ->
          %{}
      end)

      target =
        defender(0, 0)
        |> Map.put(:size, :large)
        |> Map.put(:race, :demon)

      # Renewal applies size then race, flooring each stage:
      # 100 * 125% = 125; 125 * 135% = 168.75 -> 168.
      assert {:ok, %{damage: 168, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(attacker(100), target)
    end

    test "target size and race bonuses apply before S.MAtk and the skill ratio" do
      stub(ModifierCalculator, :get_all_modifiers, fn
        :player, 1001 ->
          %{{:magic_addsize, :large} => 5, {:magic_addrace, :demon} => 5}

        _, _ ->
          %{}
      end)

      target =
        defender(0, 0)
        |> Map.put(:size, :large)
        |> Map.put(:race, :demon)

      # rAthena cardfix: 50 -> 52 (+5% size) -> 54 (+5% race), then 200% = 108.
      # Applying cardfix after the ratio would incorrectly produce 110.
      assert {:ok, %{damage: 108, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(attacker(50), target,
                 skill_ratio: 200
               )
    end

    test "negative magic cardfix truncates the removed amount like APPLY_CARDFIX_RE" do
      stub(ModifierCalculator, :get_all_modifiers, fn
        :player, 1001 -> %{{:magic_addsize, :large} => -5}
        _, _ -> %{}
      end)

      target = defender(0, 0) |> Map.put(:size, :large) |> Map.put(:race, :formless)

      # APPLY_CARDFIX_RE removes trunc(101 * 5 / 100) = 5, yielding 96.
      # Multiplying by 95% and flooring would incorrectly yield 95.
      assert {:ok, %{damage: 96, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(attacker(101), target)
    end

    test "race and size bonuses do not apply to a different target profile" do
      stub(ModifierCalculator, :get_all_modifiers, fn
        :player, 1001 ->
          %{{:magic_addsize, :large} => 20, {:magic_addrace, :demon} => 30}

        _, _ ->
          %{}
      end)

      target =
        defender(0, 0)
        |> Map.put(:size, :small)
        |> Map.put(:race, :brute)

      assert {:ok, %{damage: 100, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(attacker(100), target)
    end

    test "hard mdef of -100 uses -99 and does not crash" do
      # effective -99: 100 * (1000-99) / (1000-990) - 0 = 100 * 901 / 10 = 9010
      assert {:ok, %{damage: 9010, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(attacker(100), defender(-100, 0))
    end

    test "ignore_mdef bypasses hard and soft MDEF but preserves MRes" do
      target = defender(500, 50, {:neutral, 1}, %{mres: 400})

      # MRes first reduces 100 to 60. IgnoreDefense then bypasses both MDEF
      # components, leaving that supported pre-defense reduction intact.
      assert {:ok, %{damage: 60, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(attacker(100), target,
                 ignore_mdef: true
               )
    end

    test "ignore_mdef keeps element and attacker cardfix stages" do
      stub(ModifierCalculator, :get_all_modifiers, fn
        :player, 1001 -> %{{:magic_addsize, :large} => 20}
        _, _ -> %{}
      end)

      target =
        defender(500, 100, {:earth, 1})
        |> Map.put(:size, :large)

      # Size cardfix raises 100 to 120, then fire vs earth doubles it to 240.
      assert {:ok, %{damage: 240, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(attacker(100), target,
                 element: :fire,
                 ignore_mdef: true
               )
    end

    test "ignore_mdef false preserves the existing MDEF pipeline" do
      assert {:ok, %{damage: 86, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(attacker(100), defender(10, 5),
                 ignore_mdef: false
               )
    end

    test "damage is floored at 1 when reduction would go to zero or below" do
      # matk 1, hard 0, soft 100: 1 * 1000/1000 - 100 = -99 -> clamp 1
      assert {:ok, %{damage: 1, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(attacker(1), defender(0, 100))
    end

    test "smatk raises base_matk by a percentage before the skill ratio" do
      # smatk 50: base_matk 100 + 100*50/100 = 150; skilled 150;
      # 150 * 1010 / 1100 = 137.727..., - 5 = 132.727... -> trunc 132
      assert {:ok, %{damage: 132, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(
                 attacker(100, %{smatk: 50}),
                 defender(10, 5)
               )
    end

    test "attacker without :smatk key applies no S.MAtk bonus" do
      assert {:ok, %{damage: 86, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(attacker(100), defender(10, 5))
    end

    test "mres reduces magic damage on the soft-capped curve before MDEF" do
      # skilled 100; mres 400 -> reduction 400/800*0.8 = 0.4 -> 100 - 40 = 60
      # 60 * 1010 / 1100 = 55.09..., - 5 = 50.09... -> trunc 50
      assert {:ok, %{damage: 50, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(
                 attacker(100),
                 defender(10, 5, {:neutral, 1}, %{mres: 400})
               )
    end

    test "defender combat_stats without :mres takes full magic damage (no crash)" do
      assert {:ok, %{damage: 86, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(attacker(100), defender(10, 5))
    end

    test "fixed_damage bypasses S.MAtk entirely" do
      # smatk only applies to the rolled base_matk in the computed-damage
      # branch (calculate_pipeline_damage), so a huge smatk here must not
      # change the fixed result. Note: AL_HEAL's undead/demon heal-as-damage
      # branch does NOT use this module's fixed_damage option -- it goes
      # through Combat.execute_magic_damage/4 directly (see al_heal_test.exs
      # for the real heal/smatk guard).
      assert {:ok, %{damage: 50, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(
                 attacker(9999, %{smatk: 500}),
                 defender(500, 500),
                 fixed_damage: 50,
                 skill_ratio: 400,
                 element: :fire
               )
    end

    test "rolls the band per call: a degenerate band (min == max) is deterministic" do
      assert {:ok, %{damage: 86, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(
                 banded_attacker(100, 100),
                 defender(10, 5)
               )
    end

    test "a wide band stays within its derived damage bounds across rolls" do
      # band 1..101 -> skilled in [1, 100]; 1 * 1010/1100 - 5 floors to 1,
      # 100 * 1010/1100 - 5 = 86. So every roll lands in [1, 86].
      for _ <- 1..200 do
        assert {:ok, %{damage: damage}} =
                 MagicDamageCalculator.calculate_magic_damage(
                   banded_attacker(1, 101),
                   defender(10, 5)
                 )

        assert damage >= 1 and damage <= 86
      end
    end
  end

  describe "status magic modifiers (matk_rate / mdef_rate / magic_damage_reduction)" do
    test "matk_rate scales the skill-scaled MATK additively" do
      # matk_rate 50: skilled 100 -> 150; 150 * 1010 / 1100 - 5 = 132.727... -> 132
      stub(ModifierCalculator, :get_all_modifiers, fn
        :player, 1001 -> %{matk_rate: 50}
        _, _ -> %{}
      end)

      assert {:ok, %{damage: 132, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(attacker(100), defender(10, 5))
    end

    test "mdef_rate raises the defender's hard MDEF and lowers damage" do
      # mdef_rate 100: hard 10 -> 20; 100 * 1020 / 1200 - 5 = 85 - 5 = 80
      stub(ModifierCalculator, :get_all_modifiers, fn
        :mob, 2001 -> %{mdef_rate: 100}
        _, _ -> %{}
      end)

      assert {:ok, %{damage: 80, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(attacker(100), defender(10, 5))
    end

    test "magic_damage_reduction shrugs off a percent of final magic damage" do
      # reduction 50: 86.818... * 0.5 = 43.409... -> trunc 43
      stub(ModifierCalculator, :get_all_modifiers, fn
        :mob, 2001 -> %{magic_damage_reduction: 50}
        _, _ -> %{}
      end)

      assert {:ok, %{damage: 43, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(attacker(100), defender(10, 5))
    end

    test "magic_damage_reduction clamps at 100 and floors damage at 1" do
      stub(ModifierCalculator, :get_all_modifiers, fn
        :mob, 2001 -> %{magic_damage_reduction: 150}
        _, _ -> %{}
      end)

      assert {:ok, %{damage: 1, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(attacker(100), defender(10, 5))
    end
  end

  describe "Dragonology magic race modifier (vs Dragon race)" do
    test "raises magic damage vs a Dragon-race target by 2*lv percent, levels 1 and 5" do
      target = defender(0, 0) |> Map.put(:race, :dragon)

      lv0 = attacker(100) |> Map.put(:dragonology_level, 0)
      lv1 = attacker(100) |> Map.put(:dragonology_level, 1)
      lv5 = attacker(100) |> Map.put(:dragonology_level, 5)

      assert {:ok, %{damage: 100}} = MagicDamageCalculator.calculate_magic_damage(lv0, target)
      assert {:ok, %{damage: 102}} = MagicDamageCalculator.calculate_magic_damage(lv1, target)
      assert {:ok, %{damage: 110}} = MagicDamageCalculator.calculate_magic_damage(lv5, target)
    end

    test "leaves magic damage unchanged vs a non-Dragon target" do
      target = defender(0, 0) |> Map.put(:race, :brute)
      with_skill = attacker(100) |> Map.put(:dragonology_level, 5)
      without_skill = attacker(100) |> Map.put(:dragonology_level, 0)

      assert {:ok, %{damage: with_dmg}} =
               MagicDamageCalculator.calculate_magic_damage(with_skill, target)

      assert {:ok, %{damage: without_dmg}} =
               MagicDamageCalculator.calculate_magic_damage(without_skill, target)

      assert with_dmg == without_dmg
    end

    test "reduces magic damage taken from a Dragon-race attacker by 4*lv percent" do
      dragon_attacker = attacker(100) |> Map.put(:race, :dragon)
      no_resist = defender(0, 0) |> Map.put(:dragonology_level, 0)
      resisted = defender(0, 0) |> Map.put(:dragonology_level, 5)

      assert {:ok, %{damage: 100}} =
               MagicDamageCalculator.calculate_magic_damage(dragon_attacker, no_resist)

      assert {:ok, %{damage: 80}} =
               MagicDamageCalculator.calculate_magic_damage(dragon_attacker, resisted)
    end

    test "resist applies before MDEF's soft-MDEF subtraction, not after" do
      # Regression test: subtraction does not commute with a later percentage
      # multiply. rAthena runs the defender's subrace cardfix inside the same
      # early battle_calc_cardfix as magic_addrace, well before the MDEF
      # formula's `- soft` term (battle.cpp:809-914).
      #
      # matk 1000, hard_mdef 0, soft_mdef 50, resist 20% (Dragonology lv5):
      #   correct (resist folded into the pre-MDEF cardfix): 1000*0.80 - 50 = 750
      #   wrong (resist applied as a late percentage multiply after MDEF):
      #     (1000 - 50) * 0.80 = 760
      dragon_attacker = attacker(1000) |> Map.put(:race, :dragon)
      resisted = defender(0, 50) |> Map.put(:dragonology_level, 5)

      assert {:ok, %{damage: 750}} =
               MagicDamageCalculator.calculate_magic_damage(dragon_attacker, resisted)
    end

    test "leaves magic damage unchanged from a non-Dragon attacker" do
      brute_attacker = attacker(100) |> Map.put(:race, :brute)
      with_skill = defender(0, 0) |> Map.put(:dragonology_level, 5)
      without_skill = defender(0, 0) |> Map.put(:dragonology_level, 0)

      assert {:ok, %{damage: with_dmg}} =
               MagicDamageCalculator.calculate_magic_damage(brute_attacker, with_skill)

      assert {:ok, %{damage: without_dmg}} =
               MagicDamageCalculator.calculate_magic_damage(brute_attacker, without_skill)

      assert with_dmg == without_dmg
    end
  end

  describe "equipment magic damage families" do
    test "status and equipment magic_addrace sum once into a single cardfix step" do
      stub(ModifierCalculator, :get_all_modifiers, fn
        :player, 1001 -> %{{:magic_addrace, :demon} => 10}
        _, _ -> %{}
      end)

      attacker = c_attacker(100, %{{:magic_addrace, :demon} => 10})
      defender = c_defender(0, 0, race: :demon)

      # One step summing both sources: 100 * (100 + 20)% = 120, not two x1.1
      # steps (which would yield 121).
      assert {:ok, %{damage: 120, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(attacker, defender)
    end

    test "magic_atk_ele boosts only spells cast with the keyed element" do
      attacker = c_attacker(100, %{{:magic_atk_ele, :fire} => 50})
      defender = c_defender(0, 0)

      assert {:ok, %{damage: 150}} =
               MagicDamageCalculator.calculate_magic_damage(attacker, defender, element: :fire)

      assert {:ok, %{damage: 100}} =
               MagicDamageCalculator.calculate_magic_damage(attacker, defender, element: :water)
    end

    test "skill_atk applies only when the cast skill id matches" do
      attacker = c_attacker(100, %{{:skill_atk, 42} => 30})
      defender = c_defender(0, 0)

      assert {:ok, %{damage: 130}} =
               MagicDamageCalculator.calculate_magic_damage(attacker, defender, skill_id: 42)

      assert {:ok, %{damage: 100}} =
               MagicDamageCalculator.calculate_magic_damage(attacker, defender, skill_id: 99)

      assert {:ok, %{damage: 100}} =
               MagicDamageCalculator.calculate_magic_damage(attacker, defender)
    end

    test "ignore_mdef bypasses a percent of hard MDEF; zero rate is identical to baseline" do
      defender = c_defender(10, 5, race: :formless)

      full_ignore = c_attacker(100, %{{:ignore_mdef_race, :formless} => 100})
      no_ignore = c_attacker(100, %{})

      # ignore 100: hard MDEF 10 -> 0, so 100 * 1000/1000 - 5 = 95.
      assert {:ok, %{damage: 95}} =
               MagicDamageCalculator.calculate_magic_damage(full_ignore, defender)

      # ignore 0: unchanged 86, matching the plain-map baseline.
      assert {:ok, %{damage: 86}} =
               MagicDamageCalculator.calculate_magic_damage(no_ignore, defender)
    end

    test "defender subele reduces magic damage keyed on the spell element" do
      attacker = c_attacker(100, %{}, unit_type: :mob, race: :formless)
      defender = c_defender(0, 0, unit_type: :player, equip_modifiers: %{{:subele, :fire} => 20})

      # fire vs neutral = 1.0, then -20% damage taken: 100 * 0.8 = 80.
      assert {:ok, %{damage: 80}} =
               MagicDamageCalculator.calculate_magic_damage(attacker, defender, element: :fire)

      # a non-matching spell element gets no reduction.
      assert {:ok, %{damage: 100}} =
               MagicDamageCalculator.calculate_magic_damage(attacker, defender, element: :neutral)
    end

    test "each elemental status key reduces matching magic damage for a player defender" do
      attacker = c_attacker(100, %{}, unit_type: :mob, race: :formless)
      defender = c_defender(0, 0, unit_type: :player)

      for {element, key} <- @element_status_keys do
        modifiers = %{key => 25}

        assert magic_damage_with_defender_modifiers(attacker, defender, element, modifiers) == 75
      end
    end

    test "each elemental status key reduces matching magic damage for a mob defender" do
      attacker = c_attacker(100, %{}, unit_type: :player, race: :human)
      defender = c_defender(0, 0, unit_type: :mob)

      for {element, key} <- @element_status_keys do
        modifiers = %{key => 25}

        assert magic_damage_with_defender_modifiers(attacker, defender, element, modifiers) == 75
      end
    end

    test "an elemental status key is inert against another magic element" do
      attacker = c_attacker(100, %{}, unit_type: :mob, race: :formless)
      defender = c_defender(0, 0, unit_type: :player)

      assert magic_damage_with_defender_modifiers(attacker, defender, :fire, %{
               subele_water: 25
             }) == 100
    end

    test "defender status subele_holy reduces magic damage like the equip family" do
      attacker = c_attacker(100, %{}, unit_type: :mob, race: :formless)
      defender = c_defender(0, 0, unit_type: :player)

      stub(ModifierCalculator, :get_all_modifiers, fn
        :player, _ -> %{subele_holy: 25}
        _, _ -> %{}
      end)

      # holy vs neutral = 1.0, then -25% damage taken: 100 * 0.75 = 75.
      assert {:ok, %{damage: 75}} =
               MagicDamageCalculator.calculate_magic_damage(attacker, defender, element: :holy)

      # a non-holy spell gets no reduction.
      assert {:ok, %{damage: 100}} =
               MagicDamageCalculator.calculate_magic_damage(attacker, defender, element: :fire)
    end

    test "defender subrace reduces magic damage keyed on the attacker race" do
      attacker = c_attacker(100, %{}, unit_type: :mob, race: :formless)

      defender =
        c_defender(0, 0, unit_type: :player, equip_modifiers: %{{:subrace, :formless} => 25})

      # -25% damage taken vs a formless attacker: 100 * 0.75 = 75.
      assert {:ok, %{damage: 75}} =
               MagicDamageCalculator.calculate_magic_damage(attacker, defender)
    end

    test "defender subclass reduces magic damage from a boss-class attacker" do
      defender =
        c_defender(0, 0, unit_type: :player, equip_modifiers: %{{:subclass, :boss} => 20})

      boss = c_attacker(100, %{}, unit_type: :mob, race: :formless, class: :boss)
      normal = c_attacker(100, %{}, unit_type: :mob, race: :formless, class: :normal)

      assert {:ok, %{damage: 80}} =
               MagicDamageCalculator.calculate_magic_damage(boss, defender)

      # the class family lives only on the damage-taken side; a normal-class
      # attacker triggers no reduction.
      assert {:ok, %{damage: 100}} =
               MagicDamageCalculator.calculate_magic_damage(normal, defender)
    end
  end
end
