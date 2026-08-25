defmodule Aesir.ZoneServer.Mmo.Mechanics.PlayerFormulasTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat.CriticalHits
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator
  alias Aesir.ZoneServer.Mmo.JobManagement
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.JobManagement.Job
  alias Aesir.ZoneServer.Mmo.Mechanics
  alias Aesir.ZoneServer.Mmo.Mechanics.PlayerFormulas.PreRenewal
  alias Aesir.ZoneServer.Mmo.Mechanics.PlayerFormulas.Renewal
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Unit.Player.CombatCalculations
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers
  alias Aesir.ZoneServer.Unit.Player.WeaponHand
  alias Aesir.ZoneServer.Unit.Stats, as: UnitStats

  defmodule FormulaProbe do
    @moduledoc false

    def max_hp(inputs), do: probe(:max_hp_inputs, inputs)
    def max_sp(inputs), do: probe(:max_sp_inputs, inputs)
    def aspd(_inputs), do: 1

    defp probe(tag, inputs) do
      send(self(), {tag, inputs})
      1
    end
  end

  setup :set_mimic_private
  setup :verify_on_exit!

  test "classic scalar leaves use the trans-era formulas" do
    values = formula_values(stats_fixture())

    # rAthena src/map/status.cpp:2400-2414, 2475-2515, 2700-2738.
    assert {
             PreRenewal.base_atk(values, false),
             PreRenewal.base_atk(values, true),
             PreRenewal.base_def(values),
             PreRenewal.base_matk(values),
             PreRenewal.soft_mdef(values),
             PreRenewal.hit(values),
             PreRenewal.flee(values),
             PreRenewal.critical(values),
             PreRenewal.perfect_dodge(values)
           } ===
             {86, 58, 0, %{min: 98, max: 130}, 64, 95, 100,
              %{strategy: :exact_tenths, base_rate: 80}, 31}
  end

  test "classic formulas clamp Quagmire-shaped negative effective stats" do
    stats = %{
      stats_fixture()
      | base_stats: zero_base_stats(),
        modifiers: %Modifiers{
          status_effects: %{str: -50, agi: -40, vit: -30, int: -49, dex: -35, luk: -21}
        }
    }

    values = %{formula_values(stats) | base_level: 0}
    assert Enum.all?([:str, :agi, :vit, :int, :dex, :luk], &(Map.fetch!(values, &1) < 0))

    critical = PreRenewal.critical(values)

    assert {
             PreRenewal.base_atk(values, false),
             PreRenewal.base_atk(values, true),
             PreRenewal.soft_mdef(values),
             PreRenewal.hit(values),
             PreRenewal.flee(values),
             critical.base_rate,
             PreRenewal.perfect_dodge(values)
           } === {0, 0, 0, 1, 1, 10, 10}

    assert PreRenewal.base_matk(values) === %{min: 0, max: 0}

    aspd = %{
      agi: -40,
      dex: -35,
      weapon_delay: 650,
      left_weapon_delay: nil,
      ranged?: false,
      flat_bonus: 0,
      rate_bonus: 0,
      penalty_rate: 0
    }

    assert PreRenewal.aspd(aspd) === PreRenewal.aspd(%{aspd | agi: 0, dex: 0})

    hp = hp_inputs(vit: -30)
    sp = sp_inputs(int: -49)
    assert PreRenewal.max_hp(hp) === PreRenewal.max_hp(%{hp | vit: 0})
    assert PreRenewal.max_sp(sp) === PreRenewal.max_sp(%{sp | int: 0})
  end

  test "classic HIT and FLEE floor after the prepared flat bonus" do
    inputs = %{base_level: 1, dex: 1, agi: 1, luk: 0, con: 0, flat_bonus: -5}

    assert {PreRenewal.hit(inputs), PreRenewal.flee(inputs)} === {1, 1}
    assert {Renewal.hit(inputs), Renewal.flee(inputs)} === {-4, -4}
  end

  test "classic production HIT and FLEE floor the combined flat modifiers" do
    stub(Mechanics, :player_formulas, fn -> PreRenewal end)
    stub(Passives, :flee_bonus, fn _stats -> -1 end)
    fixture = stats_fixture()

    stats = %{
      fixture
      | base_stats: %UnitStats.BaseStats{fixture.base_stats | dex: 1, agi: 1},
        progression: %{fixture.progression | base_level: 1},
        modifiers: %Modifiers{
          status_effects: %{hit: -2, flee: -2},
          equipment: %{hit: -2, flee: -2},
          passive: %{hit: -1}
        }
    }

    assert {CombatCalculations.calculate_hit(stats), CombatCalculations.calculate_flee(stats)} ===
             {1, 1}
  end

  test "classic trait slots are always inert through stats and combat consumers" do
    stub(Mechanics, :player_formulas, fn -> PreRenewal end)
    stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)

    fixture = stats_fixture()

    stats = %{
      fixture
      | base_stats: %UnitStats.BaseStats{
          fixture.base_stats
          | pow: 41,
            sta: 43,
            wis: 47,
            spl: 53,
            con: 59,
            crt: 61
        },
        modifiers: %Modifiers{
          equipment: %{patk: 2, smatk: 3, res: 4, mres: 5, hplus: 6, crit_rate: 7},
          status_effects: %{patk: 11, smatk: 13, res: 17, mres: 19, hplus: 23, crit_rate: 29}
        }
    }

    result = Stats.calculate_combat_stats(stats)
    zero_slots = Map.new([:patk, :smatk, :res, :mres, :hplus, :crate], &{&1, 0})

    assert Map.take(result.combat_stats, Map.keys(zero_slots)) === zero_slots

    zero_crate = put_in(result.combat_stats.crate, 0)
    assert CriticalHits.apply_critical_damage(1_000, zero_crate) === 1_400

    assert CriticalHits.apply_critical_damage(1_000, result) ===
             CriticalHits.apply_critical_damage(1_000, zero_crate)

    attacker = %{
      unit_type: :player,
      unit_id: 1001,
      combat_stats: %{result.combat_stats | matk: 100, matk_min: 100, matk_max: 100}
    }

    defender = %{
      unit_type: :mob,
      unit_id: 2001,
      combat_stats: %{result.combat_stats | mdef: 0, soft_mdef: 0},
      element: {:neutral, 1}
    }

    zero_smatk = put_in(attacker.combat_stats.smatk, 0)
    zero_mres = put_in(defender.combat_stats.mres, 0)

    assert {:ok, %{damage: 100, is_critical: false}} =
             MagicDamageCalculator.calculate_magic_damage(zero_smatk, zero_mres)

    assert MagicDamageCalculator.calculate_magic_damage(attacker, zero_mres) ===
             MagicDamageCalculator.calculate_magic_damage(zero_smatk, zero_mres)

    assert MagicDamageCalculator.calculate_magic_damage(zero_smatk, defender) ===
             MagicDamageCalculator.calculate_magic_damage(zero_smatk, zero_mres)
  end

  test "HP and SP retain each mode's rate, equipment-stat, and upper-job stages" do
    hp = hp_inputs(equipment_rate: 10, modifier_rate: 10)
    sp = sp_inputs(equipment_rate: 10, modifier_rate: 10)

    assert {Renewal.max_hp(hp), Renewal.max_sp(sp)} === {1_200, 1_200}
    assert {PreRenewal.max_hp(hp), PreRenewal.max_sp(sp)} === {1_210, 1_210}

    assert PreRenewal.max_hp(
             hp_inputs(base_hp: 2, vit: 29, equipment_rate: 30, modifier_rate: 30)
           ) ===
             4

    assert {Renewal.max_hp(hp_inputs(vit: 10, equipment_vit: 10)),
            Renewal.max_sp(sp_inputs(int: 10, equipment_int: 10))} === {1_100, 1_100}

    assert {PreRenewal.max_hp(hp_inputs(vit: 10, equipment_vit: 10)),
            PreRenewal.max_sp(sp_inputs(int: 10, equipment_int: 10))} === {1_110, 1_110}

    assert {PreRenewal.max_hp(hp_inputs(transcendent?: true)),
            PreRenewal.max_sp(sp_inputs(transcendent?: true))} === {1_250, 1_250}
  end

  test "renewal production boundary matches parent HP and SP ordering" do
    stub(Mechanics, :player_formulas, fn -> Renewal end)

    stub(JobManagement, :get_base_stats_for_level, fn :swordman, 1 ->
      {:ok, %{hp: 1_000, sp: 1_000}}
    end)

    stub(JobManagement, :get_job_by_name, fn :swordman -> {:ok, %Job{name: :swordman}} end)
    stub(JobManagement, :get_base_aspd, fn :swordman, :fist -> {:ok, 650} end)

    cases = [
      {%Modifiers{
         equipment: %{max_hp_rate: 10, max_sp_rate: 10},
         status_effects: %{max_hp_rate: 10, max_sp_rate: 5},
         passive: %{max_sp_rate: 5}
       }, {1_200, 1_200}},
      {%Modifiers{
         equipment: %{max_hp: 1, max_sp: 1, max_hp_rate: -10, max_sp_rate: -10},
         status_effects: %{max_hp_rate: -10, max_sp_rate: -10},
         passive: %{max_sp_rate: 0}
       }, {800, 800}},
      {%Modifiers{equipment: %{vit: 10, int: 10}, passive: %{max_sp_rate: 0}}, {1_100, 1_100}}
    ]

    for {modifiers, {max_hp, max_sp}} <- cases do
      result = Stats.calculate_derived_stats(%{derived_fixture(1) | modifiers: modifiers})
      assert {result.derived_stats.max_hp, result.derived_stats.max_sp} === {max_hp, max_sp}
    end
  end

  test "classic dual wield keeps same-nameid weapons and one ASPD accumulator" do
    stub(Mechanics, :player_formulas, fn -> PreRenewal end)
    stub(JobManagement, :get_base_aspd, fn :swordman, :dagger -> {:ok, 650} end)

    dual = %{
      stats_fixture()
      | base_stats: %UnitStats.BaseStats{agi: 40, dex: 35},
        right_hand: weapon_hand(:dagger, :right_hand),
        left_hand: weapon_hand(:dagger, :left_hand)
    }

    penalized = %{
      stats_fixture()
      | base_stats: zero_base_stats(),
        right_hand: weapon_hand(:dagger, :right_hand),
        modifiers: %Modifiers{
          equipment: %{aspd_rate: 110},
          status_effects: %{aspd_penalty_rate: 100}
        }
    }

    # rAthena src/map/status.cpp:2400-2414 and db/pre-re/job_aspd.yml:94-101.
    assert Stats.calculate_aspd(dual) === 127
    assert Stats.calculate_aspd(penalized) === 135
  end

  test "classic hard DEF is zero and MATK bands reach combat and heal consumers" do
    stub(Mechanics, :player_formulas, fn -> PreRenewal end)

    stats = %{
      stats_fixture()
      | modifiers: %Modifiers{
          equipment: %{matk: 7, matk_rate: 10, wmatk_min: 10, wmatk_max: 20},
          status_effects: %{matk: 3}
        }
    }

    result = Stats.calculate_combat_stats(stats)

    assert result.combat_stats.def === 0
    assert result.combat_stats.matk_min === 129
    assert result.combat_stats.matk_max === 176
    assert result.combat_stats.matk === 176
    assert result.combat_stats.heal_matk_min === 108
    assert result.combat_stats.heal_matk_max === 150
  end

  test "classic critical transforms exact LUK tenths before deriving the display" do
    stub(Mechanics, :player_formulas, fn -> PreRenewal end)
    fixture = stats_fixture()

    cases = [
      {nil, %{}, {76, 7}},
      {weapon_hand(:katar, :right_hand), %{}, {152, 15}},
      {nil, %{critical_rate: 100}, {152, 15}}
    ]

    for {right_hand, status_effects, {expected_rate, expected_display}} <- cases do
      stats = %{
        fixture
        | base_stats: %UnitStats.BaseStats{fixture.base_stats | luk: 20},
          right_hand: right_hand,
          modifiers: %Modifiers{status_effects: status_effects}
      }

      result = Stats.calculate_combat_stats(stats)

      attacker = %{
        base_stats: result.base_stats,
        combat_stats: result.combat_stats,
        equip_modifiers: %{}
      }

      assert {result.combat_stats.critical_rate, result.combat_stats.critical} ===
               {expected_rate, expected_display}

      assert {:ok, critical} = DamageCalculator.apply_critical_hit(100, attacker)
      assert critical.critical_rate === expected_rate
    end
  end

  test "classic critical keeps passive and flat modifiers in their native precision" do
    stub(Mechanics, :player_formulas, fn -> PreRenewal end)
    stub(Passives, :critical_bonus, fn _stats -> 7 end)
    fixture = stats_fixture()

    stats = %{
      fixture
      | base_stats: %UnitStats.BaseStats{fixture.base_stats | luk: 20},
        right_hand: weapon_hand(:katar, :right_hand),
        modifiers: %Modifiers{
          equipment: %{critical: 1},
          status_effects: %{critical: 1, critical_rate: 50}
        }
    }

    result = Stats.calculate_combat_stats(stats)

    assert {result.combat_stats.critical_rate, result.combat_stats.critical} === {308, 30}
  end

  test "classic critical consumer uses exact modified effective LUK" do
    stub(Mechanics, :player_formulas, fn -> PreRenewal end)
    fixture = stats_fixture()

    stats = %{
      fixture
      | base_stats: %UnitStats.BaseStats{fixture.base_stats | luk: 20},
        modifiers: %Modifiers{equipment: %{luk: 1}}
    }

    result = Stats.calculate_combat_stats(stats)

    attacker = %{
      base_stats: result.base_stats,
      combat_stats: result.combat_stats,
      equip_modifiers: %{}
    }

    assert result.combat_stats.critical === 8
    assert {:ok, critical} = DamageCalculator.apply_critical_hit(100, attacker)
    assert critical.critical_rate === 80
  end

  test "renewal critical basis is identical to the legacy reconstruction" do
    stub(Mechanics, :player_formulas, fn -> Renewal end)

    for raw_luk <- -5..35,
        effective_bonus <- [-7, -1, 0, 1, 7],
        {equip_critical, status_critical, rate} <- [{-4, -3, -20}, {0, 0, 0}, {3, 7, 10}],
        katar? <- [false, true] do
      fixture = stats_fixture()

      stats = %{
        fixture
        | base_stats: %UnitStats.BaseStats{fixture.base_stats | luk: raw_luk},
          right_hand: if(katar?, do: weapon_hand(:katar, :right_hand)),
          modifiers: %Modifiers{
            equipment: %{luk: effective_bonus, critical: equip_critical},
            status_effects: %{critical: status_critical, critical_rate: rate}
          }
      }

      result = Stats.calculate_combat_stats(stats)

      display =
        legacy_critical_display(
          raw_luk + effective_bonus,
          equip_critical,
          status_critical,
          rate,
          katar?
        )

      legacy_rate = clamp(div(raw_luk * 10, 3), 0, 1_000) + (display - div(raw_luk, 3)) * 10

      assert {result.combat_stats.critical, result.combat_stats.critical_rate} ===
               {display, legacy_rate}
    end
  end

  test "mounted normal, baby, transcendent, and unknown jobs classify without a public normalizer" do
    stub(Mechanics, :player_formulas, fn -> FormulaProbe end)

    stub(AvailableJobs, :job_id_to_name, fn
      99_999 -> {:ok, :unknown}
      job_id -> call_original(AvailableJobs, :job_id_to_name, [job_id])
    end)

    stub(JobManagement, :get_base_stats_for_level, fn _job, 1 -> {:ok, %{hp: 100, sp: 10}} end)
    stub(JobManagement, :get_job_by_name, fn job -> {:ok, %Job{name: job}} end)
    stub(JobManagement, :get_base_aspd, fn _job, :fist -> {:ok, 650} end)

    for {job_id, expected?} <- [{13, false}, {4036, false}, {4014, true}, {99_999, false}] do
      Stats.calculate_derived_stats(derived_fixture(job_id))
      assert_receive {:max_hp_inputs, %{transcendent?: ^expected?}}
      assert_receive {:max_sp_inputs, %{transcendent?: ^expected?}}
    end
  end

  defp stats_fixture do
    %Stats{
      base_stats: %UnitStats.BaseStats{
        str: 50,
        agi: 40,
        vit: 30,
        int: 49,
        dex: 35,
        luk: 21,
        pow: 4,
        sta: 6,
        wis: 9,
        spl: 3,
        con: 2,
        crt: 12
      },
      progression: %Stats.PlayerProgression{base_level: 60, job_level: 40, job_id: 1},
      equipment: %Stats.Equipment{},
      modifiers: %Modifiers{}
    }
  end

  defp derived_fixture(job_id) do
    fixture = stats_fixture()

    %{
      fixture
      | base_stats: zero_base_stats(),
        progression: %{fixture.progression | base_level: 1, job_level: 1, job_id: job_id},
        modifiers: %Modifiers{passive: %{max_sp_rate: 0}}
    }
  end

  defp formula_values(stats) do
    Map.new(
      [:str, :agi, :vit, :int, :dex, :luk, :pow, :sta, :wis, :spl, :con, :crt],
      &{&1, Stats.get_effective_stat(stats, &1)}
    )
    |> Map.merge(%{
      base_level: stats.progression.base_level,
      raw_luk: stats.base_stats.luk,
      flat_bonus: 0
    })
  end

  defp zero_base_stats,
    do: %UnitStats.BaseStats{str: 0, agi: 0, vit: 0, int: 0, dex: 0, luk: 0}

  defp weapon_hand(subtype, slot) do
    %WeaponHand{
      item_id: 1,
      subtype: subtype,
      element: :neutral,
      base_atk: 1,
      refine_atk: 0,
      overrefine_band: 0,
      slot: slot
    }
  end

  defp hp_inputs(overrides) do
    inputs(
      %{
        base_hp: 1_000,
        vit: 0,
        equipment_vit: 0,
        hp_factor: 0,
        hp_increase: 0,
        flat_bonus: 0,
        equipment_rate: 0,
        modifier_rate: 0,
        transcendent?: false
      },
      overrides
    )
  end

  defp sp_inputs(overrides) do
    inputs(
      %{
        base_sp: 1_000,
        int: 0,
        equipment_int: 0,
        sp_increase: 0,
        flat_bonus: 0,
        equipment_rate: 0,
        modifier_rate: 0,
        transcendent?: false
      },
      overrides
    )
  end

  defp inputs(defaults, overrides), do: Map.merge(defaults, Map.new(overrides))

  defp legacy_critical_display(luk, equip, status, rate, katar?) do
    display = trunc((trunc(luk / 3) + equip + status) * (100 + rate) / 100)
    display * if(katar?, do: 2, else: 1)
  end

  defp clamp(value, low, high), do: value |> max(low) |> min(high)
end
