defmodule Aesir.ZoneServer.Mmo.Mechanics.HomunculusFormulasTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Mechanics.HomunculusFormulas.PreRenewal
  alias Aesir.ZoneServer.Mmo.Mechanics.HomunculusFormulas.Renewal

  test "derives independent baseline combat snapshots for both modes" do
    common = %{critical: 4, critical_rate: 0, perfect_dodge: 0, flee: 60}

    for {module, expected} <- [
          {Renewal,
           %{
             atk: 111,
             atk_min: 14,
             atk_max: 27,
             hit: 230,
             def: 38,
             soft_def: 28,
             mdef: 27,
             soft_mdef: 21,
             matk: 90,
             matk_min: 90,
             matk_max: 90
           }},
          {PreRenewal,
           %{
             atk: 40,
             atk_min: 40,
             atk_max: 71,
             hit: 80,
             def: 7,
             soft_def: 18,
             mdef: 9,
             soft_mdef: 34,
             matk: 50,
             matk_min: 50,
             matk_max: 50
           }}
        ] do
      assert module.derive(input()) == %{
               combat_stats: Map.merge(common, expected),
               attack_delay_ms: 616
             }
    end
  end

  test "classic hard MDEF precedes Instruction Change while transient quotients stay incremental" do
    raw = %{stats() | int: 31}
    base = %{raw | int: 36, str: 35}
    effective = %{base | int: 41, vit: 47}

    inputs = %{
      input()
      | raw: raw,
        base: base,
        effective: effective,
        skin_rank: 4,
        modifiers: %{def: 15, mdef: 7}
    }

    assert %{combat_stats: %{def: 75, mdef: 40, soft_def: 42, soft_mdef: 37}} =
             Renewal.derive(inputs)

    assert %{combat_stats: %{def: 44, mdef: 18, soft_def: 47, soft_mdef: 64}} =
             PreRenewal.derive(inputs)
  end

  test "soft defenses preserve baseline and combined transient rounding stages" do
    base = %{stats() | vit: 19, agi: 21}
    inputs = %{input() | raw: base, base: base, effective: %{base | vit: 20, agi: 22, dex: 41}}

    assert %{combat_stats: %{soft_def: 29, soft_mdef: 22}} = Renewal.derive(inputs)
    assert %{combat_stats: %{soft_def: 20, soft_mdef: 34}} = PreRenewal.derive(inputs)

    inputs = %{inputs | effective: %{base | vit: 18, agi: 20, dex: 39}}
    assert %{combat_stats: %{soft_def: 29, soft_mdef: 22}} = Renewal.derive(inputs)
    assert %{combat_stats: %{soft_def: 18, soft_mdef: 34}} = PreRenewal.derive(inputs)
  end

  test "only Renewal transient LUK adds to accuracy, never natural critical or perfect dodge" do
    inputs = %{input() | effective: %{stats() | luk: 27}}

    assert %{
             combat_stats: %{hit: 236, flee: 63, critical: 10, critical_rate: 0, perfect_dodge: 0}
           } = Renewal.derive(inputs)

    assert %{combat_stats: %{hit: 80, flee: 60, critical: 10, critical_rate: 0, perfect_dodge: 0}} =
             PreRenewal.derive(inputs)
  end

  test "classic caps initial hard defenses before passive and flat additions" do
    base = %{stats() | vit: 1_000, int: 1_000}

    inputs = %{
      input()
      | raw: base,
        base: base,
        effective: base,
        skin_rank: 4,
        modifiers: %{def: 5, mdef: 2}
    }

    assert %{combat_stats: %{def: 120, mdef: 101}} = PreRenewal.derive(inputs)
  end

  test "classic excessive DEX collapses the weapon interval without inflating ATK" do
    inputs = %{input() | effective: %{stats() | dex: 500}}
    assert %{combat_stats: %{atk: 40, atk_min: 71, atk_max: 71}} = PreRenewal.derive(inputs)
  end

  test "attack delay distinguishes combined and separate truncation before haste" do
    inputs = %{input() | effective: %{stats() | agi: 11, dex: 11}}
    assert Renewal.derive(inputs).attack_delay_ms == 663
    assert PreRenewal.derive(inputs).attack_delay_ms == 661

    inputs = %{inputs | modifiers: %{hom_aspd_rate: 150}}
    assert Renewal.derive(inputs).attack_delay_ms == 563
    assert PreRenewal.derive(inputs).attack_delay_ms == 561
  end

  test "delay and haste limits remain bounded and accuracy floors at one" do
    zero = Map.new(stats(), fn {key, _value} -> {key, 0} end)
    inputs = %{input() | raw: zero, base: zero, effective: zero, base_attack_delay_ms: 20_000}

    for module <- [Renewal, PreRenewal] do
      assert module.derive(inputs).attack_delay_ms == 8_000
      assert module.derive(%{inputs | modifiers: %{hom_aspd_rate: 750}}).attack_delay_ms == 2_000
      assert module.derive(%{inputs | modifiers: %{hom_aspd_rate: -50}}).attack_delay_ms == 8_000
      assert module.derive(%{inputs | modifiers: %{hom_aspd_rate: 1_500}}).attack_delay_ms == 100
      assert module.derive(%{inputs | effective: %{zero | agi: 1_000}}).attack_delay_ms == 100

      assert %{combat_stats: %{hit: 1, flee: 1}} =
               module.derive(%{inputs | modifiers: %{hit: -1_000, flee: -1_000}})
    end

    assert PreRenewal.derive(inputs).combat_stats.soft_def == 1
    assert Renewal.derive(inputs).combat_stats.soft_def == 0
  end

  defp input do
    %{
      level: 40,
      base_attack_delay_ms: 700,
      raw: stats(),
      base: stats(),
      effective: stats(),
      skin_rank: 0,
      modifiers: %{}
    }
  end

  defp stats, do: %{str: 31, agi: 20, vit: 18, int: 25, dex: 40, luk: 10}
end
