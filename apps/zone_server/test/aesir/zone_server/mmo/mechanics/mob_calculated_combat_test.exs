defmodule Aesir.ZoneServer.Mmo.Mechanics.MobCalculatedCombatTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Mechanics.MobFormulas.PreRenewal
  alias Aesir.ZoneServer.Mmo.Mechanics.MobFormulas.Renewal
  alias Aesir.ZoneServer.Mmo.MobManagement.Importer
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.Mob.MobState

  test "monster primary dependencies retain the mode split without player resource or timing edges" do
    assert Renewal.expand_calc_flags(["Agi", "Dex"]) ==
             ~w(Agi Batk Def2 Dex Flee Hit Matk Mdef2)

    assert PreRenewal.expand_calc_flags(["Agi", "Dex"]) == ~w(Agi Batk Dex Flee Hit)

    for formulas <- [Renewal, PreRenewal] do
      flags = formulas.expand_calc_flags(~w(Str Vit Int Luk))
      assert Enum.all?(~w(Batk Cri Def2 Flee2 Matk Mdef2), &(&1 in flags))
      refute Enum.any?(~w(MaxHp MaxSp Aspd Dspd), &(&1 in flags))
      assert formulas.expand_calc_flags(flags ++ flags) == flags
      all = formulas.expand_calc_flags(["All"])
      assert "Base" in all
      refute "Dye" in all
    end
  end

  test "a selected primary uses helper order and latched Blessing without refreshing other fields" do
    {:ok, form} =
      Importer.to_definition(%{
        "Id" => 1002,
        "AegisName" => "SELECTIVE_PRIMARY",
        "Name" => "Selective Primary",
        "Level" => 10,
        "Str" => 101
      })

    spawn = %MobSpawn{mob: form.id, amount: 1, respawn_time: 0, spawn_area: nil}
    state = MobState.new(301, form, spawn, "prontera", 100, 100)

    entries = [
      StatusEntry.new(:sc_incallstatus, 1, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_battleorder, 1, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_loud, 1, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_truesight, 1, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_blessing, 10, 0, 0, 0, 0, 0)
    ]

    for {formulas, batk} <- [{Renewal, 98}, {PreRenewal, 777}] do
      base = formulas.base(state)
      calculated = %{base | int: 999, batk: 777}
      state = %{state | base: base, calculated: calculated}
      flags = formulas.expand_calc_flags(["Str"])
      result = formulas.recalculate_combat(state, entries, flags)

      assert result == %{calculated | str: 58, batk: batk}
      assert formulas.recalculate_combat(%{state | calculated: result}, [], []) == result
      restored = formulas.recalculate_combat(state, entries, formulas.expand_calc_flags(["All"]))
      assert {restored.str, restored.int, restored.dex} == {58, 6, 6}
    end
  end

  test "primary recipes order concentration, flat additions, strip rates and renewal ensemble stats" do
    {:ok, form} =
      Importer.to_definition(%{
        "Id" => 1002,
        "AegisName" => "ORDERED_PRIMARIES",
        "Name" => "Ordered Primaries",
        "Str" => 101,
        "Agi" => 41,
        "Vit" => 53,
        "Int" => 37,
        "Dex" => 43,
        "Luk" => 47
      })

    spawn = %MobSpawn{mob: form.id, amount: 1, respawn_time: 0, spawn_area: nil}
    state = MobState.new(302, form, spawn, "prontera", 100, 100)

    entries = [
      StatusEntry.new(:sc_concentrate, 3, 20, 7, 9, 0, 0),
      StatusEntry.new(:sc_incallstatus, 3, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_battleorder, 1, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_gd_leadership, 2, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_gd_soulcold, 4, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_gd_glorywounds, 6, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_gd_hawkeyes, 8, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_truesight, 1, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_increaseagi, 1, 7, 0, 0, 0, 0),
      StatusEntry.new(:sc_decreaseagi, 1, 4, 0, 0, 0, 0),
      StatusEntry.new(:sc_change, 1, 11, 13, 0, 0, 0),
      StatusEntry.new(:sc_blessing, 10, 10, 0, 0, 0, 0),
      StatusEntry.new(:sc_striparmor, 1, 40, 0, 0, 0, 0),
      StatusEntry.new(:sc_striphelm, 1, 40, 0, 0, 0, 0),
      StatusEntry.new(:sc_gloria, 1, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_nibelungen, 1, 6, 0, 0, 0, 0)
    ]

    for {formulas, expected, slowed} <- [
          {Renewal, %{str: 141, agi: 77, vit: 62, int: 59, dex: 95, luk: 100}, {51, 69}},
          {PreRenewal, %{str: 126, agi: 62, vit: 47, int: 44, dex: 80, luk: 85}, {36, 54}}
        ] do
      base = formulas.base(state)
      state = %{state | base: base, calculated: base}
      flags = formulas.expand_calc_flags(~w(Str Agi Vit Int Dex Luk))
      calculated = formulas.recalculate_combat(state, entries, flags)
      assert Map.take(calculated, [:str, :agi, :vit, :int, :dex, :luk]) == expected
      quagmire = StatusEntry.new(:sc_quagmire, 1, 20, 0, 0, 0, 0)
      calculated = formulas.recalculate_combat(state, [quagmire | entries], flags)
      assert {calculated.agi, calculated.dex} == slowed
    end
  end

  test "accuracy and source-unit critical recipes use selected primary deltas and ordered rates" do
    {:ok, form} =
      Importer.to_definition(%{
        "Id" => 1002,
        "AegisName" => "ACCURACY",
        "Name" => "Accuracy",
        "Level" => 10,
        "Dex" => 17,
        "Agi" => 19,
        "Luk" => 17
      })

    spawn = %MobSpawn{mob: form.id, amount: 1, respawn_time: 0, spawn_area: nil}
    state = MobState.new(303, form, spawn, "prontera", 100, 100)

    entries = [
      StatusEntry.new(:sc_inchit, 11, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_truesight, 1, 13, 13, 0, 0, 0),
      StatusEntry.new(:sc_humming, 1, 7, 0, 0, 0, 0),
      StatusEntry.new(:sc_concentration, 1, 0, 9, 0, 0, 0),
      StatusEntry.new(:sc_inchitrate, 20, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_blind, 1, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_blessing, 2, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_twohandquicken, 3, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_adrenaline, 4, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_nibelungen, 1, 7, 0, 0, 0, 0),
      StatusEntry.new(:sc_provoke, 10, 50, 100, 0, 0, 0),
      StatusEntry.new(:sc_incflee, 11, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_whistle, 1, 7, 17, 0, 0, 0),
      StatusEntry.new(:sc_windwalk, 1, 9, 0, 0, 0, 0),
      StatusEntry.new(:sc_violentgale, 1, 13, 0, 0, 0, 0),
      StatusEntry.new(:sc_closeconfine, 1, 0, 17, 0, 0, 0),
      StatusEntry.new(:sc_speed, 2, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_spearquicken, 3, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_incfleerate, 20, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_spiderweb, 1, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_explosionspirits, 1, 75, 0, 0, 0, 0),
      StatusEntry.new(:sc_fortunekiss, 1, 11, 0, 0, 0, 0),
      StatusEntry.new(:sc_cloaking, 1, 0, 0, 0, 0, 0)
    ]

    for {formulas, expected} <- [
          {Renewal, {278, 102, 468, 62}},
          {PreRenewal, {65, 54, 330, 62}}
        ] do
      base = %{formulas.base(state) | cri: 50, flee2: 40}
      calculated = %{base | dex: 22, agi: 22, luk: 22}
      state = %{state | base: base, calculated: calculated}
      result = formulas.recalculate_combat(state, entries, ~w(Hit Flee Cri Flee2))
      assert {result.hit, result.flee, result.cri, result.flee2} == expected
      fields = [:hit, :flee, :cri, :flee2]
      assert Map.drop(result, fields) == Map.drop(calculated, fields)
    end
  end

  test "defenses apply source-ordered halves, poison OR, Angelus and separate Joint Beat truncation" do
    {:ok, form} =
      Importer.to_definition(%{
        "Id" => 1002,
        "AegisName" => "DEFENSES",
        "Name" => "Defenses",
        "Level" => 10,
        "Vit" => 11,
        "Agi" => 13,
        "Int" => 17,
        "Dex" => 19,
        "Defense" => 101,
        "MagicDefense" => 51
      })

    spawn = %MobSpawn{mob: form.id, amount: 1, respawn_time: 0, spawn_area: nil}
    state = MobState.new(304, form, spawn, "prontera", 100, 100)

    entries = [
      StatusEntry.new(:sc_drumbattle, 1, 0, 7, 0, 0, 0),
      StatusEntry.new(:sc_assumptio, 2, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_incdefrate, 20, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_stone, 1, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_freeze, 1, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_poison, 1, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_dpoison, 1, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_signumcrucis, 1, 10, 0, 0, 0, 0),
      StatusEntry.new(:sc_concentration, 1, 0, 0, 10, 0, 0),
      StatusEntry.new(:sc_provoke, 1, 0, 15, 0, 0, 0),
      StatusEntry.new(:sc_stripshield, 1, 15, 0, 0, 0, 0),
      StatusEntry.new(:sc_angelus, 1, 20, 0, 0, 0, 0),
      StatusEntry.new(:sc_jointbeat, 1, 0x18, 0, 0, 0, 0),
      StatusEntry.new(:sc_endure, 7, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_mindbreaker, 1, 0, 30, 0, 0, 0),
      StatusEntry.new(:sc_defence, 1, 100, 0, 0, 0, 0)
    ]

    for {formulas, expected} <- [{Renewal, {29, 4, 90, 10}}, {PreRenewal, {15, 3, 90, 22}}] do
      base = formulas.base(state)
      calculated = %{base | vit: 18, agi: 21, int: 23, dex: 26}
      state = %{state | base: base, calculated: calculated}
      result = formulas.recalculate_combat(state, entries, ~w(Def Def2 Mdef Mdef2))
      assert {result.def, result.def2, result.mdef, result.mdef2} == expected
      steelbody = StatusEntry.new(:sc_steelbody, 1, 0, 0, 0, 0, 0)
      result = formulas.recalculate_combat(state, [steelbody | entries], ~w(Def Mdef))
      assert {result.def, result.mdef} == if(formulas == Renewal, do: {29, 90}, else: {90, 90})
      chaos = StatusEntry.new(:sc_eternalchaos, 1, 0, 0, 0, 0, 0)
      result = formulas.recalculate_combat(state, [chaos | entries], ~w(Def Def2))
      assert {result.def, result.def2} == if(formulas == Renewal, do: {0, 0}, else: {15, 0})
    end
  end

  test "attack recipes preserve base residuals, separate renewal weapon slots and latch classic amplification" do
    {:ok, form} =
      Importer.to_definition(%{
        "Id" => 1002,
        "AegisName" => "ATTACKS",
        "Name" => "Attacks",
        "Level" => 10,
        "Str" => 40,
        "Int" => 20,
        "Attack" => 100,
        "Attack2" => 100
      })

    form = %{form | atk2: 180}
    spawn = %MobSpawn{mob: form.id, amount: 1, respawn_time: 0, spawn_area: nil}
    state = MobState.new(305, form, spawn, "prontera", 100, 100)

    entries = [
      StatusEntry.new(:sc_volcano, 1, 7, 0, 0, 0, 0),
      StatusEntry.new(:sc_loud, 1, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_nibelungen, 1, 2, 0, 0, 0, 0),
      StatusEntry.new(:sc_impositio, 1, 11, 0, 0, 0, 0),
      StatusEntry.new(:sc_watkfood, 13, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_drumbattle, 1, 17, 0, 0, 0, 0),
      StatusEntry.new(:sc_provoke, 1, 100, 0, 0, 0, 0),
      StatusEntry.new(:sc_incmatkrate, 100, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_mindbreaker, 1, 100, 0, 0, 0, 0)
    ]

    amplification = StatusEntry.new(:sc_magicpower, 5, 1, 25, 0, 0, 0)

    for {formulas, attack, unarmed_matk, armed_matk} <- [
          {Renewal, {123, 80, 120, 0, 36}, {146, 221}, {146, 221}},
          {PreRenewal, {18, 150, 230, 999, 5}, {32, 39}, {40, 48}}
        ] do
      base = formulas.base(state)
      base = %{base | batk: base.batk + 11, watk2: 5}
      calculated = %{base | str: 45, int: 23, watk: 999}
      state = %{state | base: base, calculated: calculated}
      result = formulas.recalculate_combat(state, [amplification | entries], ~w(Batk Watk Matk))
      assert {result.batk, result.watk_min, result.watk_max, result.watk, result.watk2} == attack
      assert {result.matk_min, result.matk_max} == unarmed_matk
      armed = %{amplification | state: %{armed: true}}
      result = formulas.recalculate_combat(state, [armed | entries], ["Matk"])
      assert {result.matk_min, result.matk_max} == armed_matk
    end
  end

  test "renewal soft defense rounds each floating stage to single precision before the combined cast" do
    {:ok, form} =
      Importer.to_definition(%{
        "Id" => 1002,
        "AegisName" => "FLOAT_DELTA",
        "Name" => "Float Delta",
        "Level" => 10,
        "Vit" => 1,
        "Agi" => 1
      })

    spawn = %MobSpawn{mob: form.id, amount: 1, respawn_time: 0, spawn_area: nil}
    state = MobState.new(306, form, spawn, "prontera", 100, 100)

    for {formulas, expected} <- [{Renewal, 8}, {PreRenewal, 1}] do
      base = formulas.base(state)
      state = %{state | base: base, calculated: %{base | agi: 21}}
      result = formulas.recalculate_combat(state, [], ["Def2"])
      assert result.def2 == expected
    end
  end

  test "zero-base guards and signed primary assignments survive selective refreshes and soft floors" do
    {:ok, form} =
      Importer.to_definition(%{
        "Id" => 1002,
        "AegisName" => "STAT_LIMITS",
        "Name" => "Stat Limits",
        "Agi" => 20
      })

    spawn = %MobSpawn{mob: form.id, amount: 1, respawn_time: 0, spawn_area: nil}
    state = MobState.new(307, form, spawn, "prontera", 100, 100)

    entries = [
      StatusEntry.new(:sc_incallstatus, 32_752, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_nibelungen, 1, 6, 0, 0, 0, 0),
      StatusEntry.new(:sc_curse, 1, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_gloria, 1, 0, 0, 0, 0, 0),
      StatusEntry.new(:sc_explosionspirits, 1, 75, 0, 0, 0, 0),
      StatusEntry.new(:sc_whistle, 1, 0, 50, 0, 0, 0)
    ]

    for {formulas, str, defenses} <- [{Renewal, -32_768, {-3, -1}}, {PreRenewal, 32_753, {1, 1}}] do
      base = %{formulas.base(state) | batk: 0}
      calculated = %{base | agi: 0, int: 0, dex: 0, batk: 555, cri: 99, flee2: 777}
      state = %{state | base: base, calculated: calculated}

      result =
        formulas.recalculate_combat(
          state,
          entries,
          formulas.expand_calc_flags(~w(Str Luk Cri Flee2))
        )

      assert {result.str, result.luk, result.batk, result.cri, result.flee2} ==
               {str, 0, 555, 99, 777}

      result = formulas.recalculate_combat(state, [], ~w(Def2 Mdef2))
      assert {result.def2, result.mdef2} == defenses
    end
  end

  test "hard defense additions saturate at the assigned mode widths" do
    {:ok, form} =
      Importer.to_definition(%{
        "Id" => 1002,
        "AegisName" => "DEFENSE_LIMITS",
        "Name" => "Defense Limits",
        "Defense" => 32_767,
        "MagicDefense" => 32_767
      })

    spawn = %MobSpawn{mob: form.id, amount: 1, respawn_time: 0, spawn_area: nil}
    state = MobState.new(309, form, spawn, "prontera", 100, 100)

    entries = [
      StatusEntry.new(:sc_drumbattle, 1, 0, 15, 0, 0, 0),
      StatusEntry.new(:sc_endure, 10, 0, 0, 0, 0, 0)
    ]

    for {formulas, limit} <- [{Renewal, 32_767}, {PreRenewal, 127}] do
      base = formulas.base(state)

      result =
        formulas.recalculate_combat(
          %{state | base: base, calculated: base},
          entries,
          ~w(Def Mdef)
        )

      assert {result.def, result.mdef} == {limit, limit}
    end
  end

  test "MATK helper assignment wraps before amplification and renewal right-slot writes preserve the left" do
    {:ok, form} =
      Importer.to_definition(%{
        "Id" => 1002,
        "AegisName" => "ATTACK_LIMITS",
        "Name" => "Attack Limits",
        "Level" => 10,
        "Attack2" => 65_535
      })

    spawn = %MobSpawn{mob: form.id, amount: 1, respawn_time: 0, spawn_area: nil}
    state = MobState.new(308, form, spawn, "prontera", 100, 100)
    amplification = StatusEntry.new(:sc_magicpower, 10, 0, 50, 1, 0, 0)

    for {formulas, expected, right} <- [
          {Renewal, {19_672, 65_535}, 5},
          {PreRenewal, {65_535, 65_535}, 999}
        ] do
      base = %{formulas.base(state) | watk: 5, watk2: 10}
      state = %{state | base: base, calculated: %{base | int: 32_767, watk: 999, watk2: 777}}
      result = formulas.recalculate_combat(state, [amplification], ~w(Watk Matk))
      assert {result.matk_min, result.matk_max} == expected
      assert {result.watk, result.watk2} == {right, 777}
    end
  end
end
