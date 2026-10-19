defmodule Aesir.ZoneServer.Mmo.Mechanics.MobCalculatedOtherTest do
  use ExUnit.Case, async: true

  import Bitwise, only: [bor: 2]

  alias Aesir.ZoneServer.Mmo.Mechanics.MobFormulas.PreRenewal
  alias Aesir.ZoneServer.Mmo.Mechanics.MobFormulas.Renewal
  alias Aesir.ZoneServer.Mmo.MobManagement.Importer
  alias Aesir.ZoneServer.Mmo.MobManagement.MobMode
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @modes [:can_move, :looter, :can_attack, :aggressive]

  setup do
    {:ok, form} =
      Importer.to_definition(%{
        "Id" => 1002,
        "AegisName" => "CALCULATED_OTHER",
        "Name" => "Calculated Other",
        "Level" => 10
      })

    form = %{
      form
      | hp: 1_000,
        sp: 100,
        walk_speed: 300,
        attack_motion: 800,
        attack_delay: 1_000,
        element: {:neutral, 2},
        modes: @modes
    }

    spawn = %MobSpawn{mob: form.id, amount: 1, respawn_time: 0, spawn_area: nil}
    %{form: form, spawn: spawn}
  end

  test "movement keeps the strongest slow and haste, then applies the overrides", %{
    form: form,
    spawn: spawn
  } do
    cases = [
      {[], 300},
      {[entry(:sc_decreaseagi, 5), entry(:sc_increaseagi, 5)], 300},
      {[entry(:sc_curse, 1), entry(:sc_increaseagi, 5)], 1_000},
      {[entry(:sc_quagmire, 1), entry(:sc_increaseagi, 5)], 375},
      {[entry(:sc_dontforgetme, 5, 0, 25), entry(:sc_increaseagi, 5)], 300},
      {[entry(:sc_slowdown, 50)], 450},
      {[entry(:sc_gospel_slow, 1)], 525},
      {[entry(:sc_jointbeat, 1, 0x05)], 540},
      {[entry(:sc_steelbody, 1)], 200},
      {[entry(:sc_steelbody, 1), entry(:sc_defender, 1)], 200},
      {[entry(:sc_curse, 1), entry(:sc_defender, 1)], 1_000},
      {[entry(:sc_cloaking, 5)], 345},
      {[entry(:sc_cloaking, 5, 0, 0, 0, %{adjacent_impassable?: true})], 264},
      {[entry(:sc_windwalk, 15), entry(:sc_increaseagi, 5)], 210},
      {[entry(:sc_curse, 1), entry(:sc_windwalk, 15)], 1_000}
    ]

    for {held, expected} <- cases do
      assert speed(Renewal, state(form, spawn), held) == expected
      assert speed(PreRenewal, state(form, spawn), held) == expected
    end
  end

  test "movement penalises a renewal-only fatigue and the emergency speed in both modes", %{
    form: form,
    spawn: spawn
  } do
    state = state(form, spawn)
    fatigue = [entry(:sc_ensemblefatigue, 1, 30)]

    assert speed(Renewal, state, fatigue) == 390
    assert speed(PreRenewal, state, fatigue) == 300

    assert speed(Renewal, state, [entry(:sc_emergency_move, 1, 40)]) == 180
    assert speed(PreRenewal, state, [entry(:sc_emergency_move, 1, 40)]) == 180
  end

  test "attack timing subtracts one bucket, the potion tier and each penalty in order", %{
    form: form,
    spawn: spawn
  } do
    cases = [
      {[], {1_000, 800, 1_000}},
      {[entry(:sc_twohandquicken, 10, 300)], {700, 560, 700}},
      {[entry(:sc_twohandquicken, 10, 300), entry(:sc_adrenaline, 5, 0, 200)], {700, 560, 700}},
      {[entry(:sc_adrenaline, 5, 0, 200), entry(:sc_fleet, 5, 300)], {700, 560, 700}},
      {[entry(:sc_assncross, 5, 250)], {750, 600, 750}},
      {[entry(:sc_aspdpotion3, 1, 250), entry(:sc_aspdpotion1, 1, 150)], {750, 600, 750}},
      {[entry(:sc_steelbody, 1)], {1_250, 1_000, 1_000}},
      {[entry(:sc_defender, 1, 0, 0, 0, %{aspd_penalty: 200})], {1_200, 960, 1_000}},
      {[entry(:sc_gospel_slow, 1)], {1_250, 1_000, 1_000}},
      {[entry(:sc_jointbeat, 1, 0x06)], {1_350, 1_080, 1_080}}
    ]

    for {held, expected} <- cases do
      assert timing(Renewal, state(form, spawn), held) == expected
      assert timing(PreRenewal, state(form, spawn), held) == expected
    end
  end

  test "only the classic Spear Quicken and Gravitation contribute their rate", %{
    form: form,
    spawn: spawn
  } do
    state = state(form, spawn)
    spear = [entry(:sc_spearquicken, 5, 250)]
    gravitation = [entry(:sc_gravitation, 5, 250)]

    assert timing(Renewal, state, spear) == {1_000, 800, 1_000}
    assert timing(PreRenewal, state, spear) == {750, 600, 750}
    assert timing(Renewal, state, gravitation) == {1_000, 800, 1_000}
    assert timing(PreRenewal, state, gravitation) == {1_250, 1_000, 1_000}
  end

  test "attack motion clamps to the source bounds and never exceeds its own delay", %{
    form: form,
    spawn: spawn
  } do
    slow = [entry(:sc_jointbeat, 1, 0x06)]

    assert timing(Renewal, state(%{form | attack_motion: 50}, spawn), []) == {1_000, 100, 1_000}

    assert timing(Renewal, state(%{form | attack_motion: 7_900}, spawn), slow) ==
             {1_350, 8_000, 8_000}
  end

  test "resources take the flat bonus first, then the aggregate rate, and only cap the ceiling",
       %{
         form: form,
         spawn: spawn
       } do
    cases = [
      {[], {1_000, 100}},
      {[entry(:sc_incmhprate, 20), entry(:sc_incmsprate, 50)], {1_200, 150}},
      {[entry(:sc_incmhprate, -150)], {1, 100}},
      {[entry(:sc_incmsprate, -150)], {1_000, 1}}
    ]

    for {held, expected} <- cases do
      state = state(form, spawn)

      assert {resource(Renewal, state, held, "MaxHp"), resource(Renewal, state, held, "MaxSp")} ==
               expected
    end
  end

  test "renewal resources add the Angelus flat HP and the Nibelungen outcome, classic does not",
       %{form: form, spawn: spawn} do
    state = state(form, spawn)

    held = [
      entry(:sc_angelus, 3),
      entry(:sc_incmhprate, 20),
      entry(:sc_appleidun, 1, 30),
      entry(:sc_deluge, 1, 12),
      entry(:sc_nibelungen, 1, 4)
    ]

    assert resource(Renewal, state, held, "MaxHp") == 2_208
    assert resource(PreRenewal, state, held, "MaxHp") == 1_620
  end

  test "attack element follows its fixed priority, not the most recent application", %{
    form: form,
    spawn: spawn
  } do
    state = state(form, spawn)

    for formulas <- [Renewal, PreRenewal] do
      assert attack(formulas, state, []) == :neutral
      assert attack(formulas, state, [entry(:sc_waterweapon, 1)]) == :water
      assert attack(formulas, state, [entry(:sc_earthweapon, 1)]) == :earth
      assert attack(formulas, state, [entry(:sc_fireweapon, 1)]) == :fire
      assert attack(formulas, state, [entry(:sc_windweapon, 1)]) == :wind
      assert attack(formulas, state, [entry(:sc_encpoison, 1)]) == :poison
      assert attack(formulas, state, [entry(:sc_aspersio, 1)]) == :holy

      assert attack(formulas, state, [entry(:sc_fireweapon, 1), entry(:sc_waterweapon, 1)]) ==
               :water

      assert attack(formulas, state, [entry(:sc_waterweapon, 1), entry(:sc_enchantarms, 3)]) ==
               :fire
    end
  end

  test "defence element and level follow their ordered overrides and the raw base", %{
    form: form,
    spawn: spawn
  } do
    state = state(form, spawn)

    for formulas <- [Renewal, PreRenewal] do
      assert defense(formulas, state, []) == {:neutral, 2}
      assert defense(formulas, state, [entry(:sc_freeze, 1)]) == {:water, 1}
      assert defense(formulas, state, [entry(:sc_stone, 1)]) == {:earth, 1}
      assert defense(formulas, state, [entry(:sc_benedictio, 1)]) == {:holy, 1}
      assert defense(formulas, state, [entry(:sc_freeze, 1), entry(:sc_stone, 1)]) == {:water, 1}
      assert defense(formulas, state, [entry(:sc_elementalchange, 3, 9)]) == {:undead, 3}
      assert defense(formulas, state, [entry(:sc_elementalchange, 0, 9)]) == {:undead, 1}

      assert defense(formulas, state, [entry(:sc_stone, 1), entry(:sc_elementalchange, 3, 9)]) ==
               {:earth, 1}
    end
  end

  test "mode applies the set, add and remove masks in order and derives the class", %{
    form: form,
    spawn: spawn
  } do
    state = state(form, spawn)
    base_mode = MobMode.mask(@modes)
    can_move = MobMode.mask([:can_move])
    aggressive = MobMode.mask([:aggressive])
    guardian = MobMode.mask([:status_immune])
    battlefield = MobMode.mask([:status_immune, :skill_immune])
    boss = MobMode.mask([:status_immune, :knockback_immune, :detector])

    assert selected_mode(state, []) == base_mode
    assert selected_mode(state, [entry(:sc_modechange, 1, can_move)]) == can_move

    assert selected_mode(state, [entry(:sc_modechange, 1, can_move, guardian)]) ==
             bor(can_move, guardian)

    assert selected_mode(state, [entry(:sc_modechange, 1, can_move, battlefield)]) ==
             bor(can_move, battlefield)

    assert selected_mode(state, [entry(:sc_modechange, 1, can_move, boss)]) == bor(can_move, boss)

    assert selected_mode(state, [entry(:sc_modechange, 1, can_move, aggressive, can_move)]) ==
             aggressive

    assert mode_class(state, [entry(:sc_modechange, 1, can_move, guardian)]) == :guardian
    assert mode_class(state, [entry(:sc_modechange, 1, can_move, battlefield)]) == :battlefield
    assert mode_class(state, [entry(:sc_modechange, 1, can_move, boss)]) == :boss
    assert mode_class(state, [entry(:sc_modechange, 1, can_move)]) == :normal

    mvp = state(%{form | modes: [:mvp]}, spawn)
    assert selected_mode(mvp, [entry(:sc_modechange, 1, can_move)]) == bor(can_move, 0x80000)
  end

  test "a selection only rewrites its own fields and an empty selection changes nothing", %{
    form: form,
    spawn: spawn
  } do
    held = [
      entry(:sc_decreaseagi, 5),
      entry(:sc_twohandquicken, 10, 300),
      entry(:sc_incmhprate, 20),
      entry(:sc_freeze, 1),
      entry(:sc_waterweapon, 1),
      entry(:sc_modechange, 1, 0, MobMode.mask([:status_immune]))
    ]

    untouched = [
      :speed,
      :aspd_rate,
      :amotion,
      :adelay,
      :dmotion,
      :client_amotion,
      :max_hp,
      :max_sp,
      :def_ele,
      :ele_lv,
      :attack_element,
      :mode,
      :class
    ]

    for formulas <- [Renewal, PreRenewal] do
      state = state(form, spawn)
      assert formulas.recalculate(state, held, []) == state.calculated

      speed_only = formulas.recalculate(state, held, ["Speed"])
      assert speed_only.speed == 375
      assert Map.drop(speed_only, untouched) == Map.drop(state.calculated, untouched)

      assert %{aspd_rate: 1_000, max_hp: 1_000, def_ele: :neutral, attack_element: :neutral} =
               speed_only

      restored = formulas.recalculate(state, held, formulas.expand_calc_flags(["All"]))
      assert restored.speed == 375
      assert restored.max_hp == 1_200
      assert {restored.def_ele, restored.ele_lv} == {:water, 1}
      assert restored.attack_element == :water
      assert restored.mode == bor(MobMode.mask(@modes), MobMode.mask([:status_immune]))
      assert restored.class == :guardian
      assert {restored.race, restored.size} == {state.calculated.race, state.calculated.size}
    end
  end

  defp state(form, spawn) do
    state = MobState.new(1101, form, spawn, "prontera", 100, 100)
    %{state | base: state.base, calculated: state.base}
  end

  defp speed(formulas, state, held), do: formulas.recalculate(state, held, ["Speed"]).speed

  defp timing(formulas, state, held) do
    calculated = formulas.recalculate(state, held, ["Aspd"])
    {calculated.aspd_rate, calculated.amotion, calculated.adelay}
  end

  defp resource(formulas, state, held, flag) do
    calculated = formulas.recalculate(state, held, [flag])

    if flag == "MaxHp", do: calculated.max_hp, else: calculated.max_sp
  end

  defp attack(formulas, state, held),
    do: formulas.recalculate(state, held, ["Atk_Ele"]).attack_element

  defp defense(formulas, state, held) do
    calculated = formulas.recalculate(state, held, ["Def_Ele"])
    {calculated.def_ele, calculated.ele_lv}
  end

  defp selected_mode(state, held), do: Renewal.recalculate(state, held, ["Mode"]).mode

  defp mode_class(state, held), do: Renewal.recalculate(state, held, ["Mode"]).class

  defp entry(type, val1, val2 \\ 0, val3 \\ 0, val4 \\ 0, state \\ %{}) do
    StatusEntry.new(type, val1, val2, val3, val4, 0, 0, nil, nil, state)
  end
end
