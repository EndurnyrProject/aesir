defmodule Aesir.ZoneServer.Unit.Mob.StatsBaseTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Mechanics.MobFormulas.PreRenewal
  alias Aesir.ZoneServer.Mmo.Mechanics.MobFormulas.Renewal
  alias Aesir.ZoneServer.Mmo.MobManagement
  alias Aesir.ZoneServer.Mmo.MobManagement.Importer
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.Woe.Guardians
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.Stats

  test "construction initializes a raw snapshot without applying held entries" do
    setup_ets_tables(%{})
    {:ok, form} = MobManagement.get_mob_by_id(1002)
    spawn = %MobSpawn{mob: form.id, amount: 1, respawn_time: 0, spawn_area: nil}
    StatusStorage.apply_status(:mob, 902, :sc_incallstatus, val1: 20)

    state = MobState.new(902, form, spawn, "prontera", 100, 100)

    assert state.base.str == form.stats.str
    assert state.calculated == state.base
    assert Stats.base(state) == state.base
    assert StatusStorage.has_status?(:mob, 902, :sc_incallstatus)
  end

  test "construction initializes current resources from the raw base ceilings" do
    {:ok, form} = MobManagement.get_mob_by_id(1002)
    form = %{form | hp: 0, sp: 0}
    spawn = %MobSpawn{mob: form.id, amount: 1, respawn_time: 0, spawn_area: nil}

    state = MobState.new(909, form, spawn, "prontera", 100, 100)

    assert {state.hp, state.sp} == {state.base.max_hp, state.base.max_sp}
    assert {state.hp, state.sp} == {1, 1}
  end

  test "guardian adjustments become base data without prematurely refreshing attack motion" do
    {:ok, form} = MobManagement.get_mob_by_id(1002)

    form = %{
      form
      | level: 10,
        stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15},
        atk: 100,
        atk2: 180,
        matk: 100,
        def: 20,
        mdef: 10,
        attack_motion: 500
    }

    spawn = %MobSpawn{mob: form.id, amount: 1, respawn_time: 0, spawn_area: nil}
    state = MobState.new(903, form, spawn, "prontera", 100, 100)

    state =
      MobState.configure_summon(state,
        hp_override: 2_000,
        stat_bonus: %{atk: 10, def: 4, mdef: 4, aspd_rate: 5}
      )

    assert {state.base.max_hp, state.base.def, state.base.mdef} == {2_000, 24, 14}
    assert {state.base.aspd_rate, state.base.amotion} == {995, 500}
    assert state.calculated == state.base

    for {formulas, expected} <- [
          {Renewal, {60, 90, 130, 100, 160}},
          {PreRenewal, {10, 110, 190, 24, 36}}
        ] do
      base = formulas.base(state, stat_bonus: %{atk: 10})
      assert {base.batk, base.watk_min, base.watk_max, base.matk_min, base.matk_max} == expected
    end
  end

  test "castle HP additions follow custom level and size adjustments" do
    {:ok, form} = MobManagement.get_mob_by_id(1002)

    form = %{
      form
      | level: 10,
        hp: 1_000,
        stats: %{str: 1, agi: 1, vit: 50, int: 1, dex: 1, luk: 1}
    }

    spawn = %MobSpawn{mob: form.id, amount: 1, respawn_time: 0, spawn_area: nil}
    state = %{MobState.new(910, form, spawn, "prontera", 100, 100) | level: 12}

    for formulas <- [Renewal, PreRenewal] do
      base =
        formulas.base(state,
          level_up: true,
          special_size: :medium,
          size_influence: true,
          guardian_hp_bonus: 10_100,
          hp_override: 11_100
        )

      assert base.max_hp == 10_652
    end
  end

  test "custom level and size adjustments precede miscellaneous base derivation" do
    {:ok, form} = MobManagement.get_mob_by_id(1002)

    form = %{
      form
      | level: 10,
        hp: 1_000,
        sp: 200,
        walk_speed: 200,
        stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15}
    }

    spawn = %MobSpawn{mob: form.id, amount: 1, respawn_time: 0, spawn_area: nil}
    state = %{MobState.new(904, form, spawn, "prontera", 100, 100) | level: 12}

    for formulas <- [Renewal, PreRenewal] do
      base = formulas.base(state, level_up: true, special_size: :medium, size_influence: true)
      assert {base.str, base.vit, base.int, base.dex} == {21, 26, 11, 18}
      assert {base.max_hp, base.max_sp, base.speed} == {552, 122, 198}
      assert base.size == form.size
    end
  end

  test "captured master speed is clamped before level adjustments without baking a mode status" do
    {:ok, form} = MobManagement.get_mob_by_id(1002)
    form = %{form | level: 10, walk_speed: 200, modes: [:can_move, :can_attack, :aggressive]}
    spawn = %MobSpawn{mob: form.id, amount: 1, respawn_time: 0, spawn_area: nil}
    state = %{MobState.new(906, form, spawn, "prontera", 100, 100) | level: 12}

    for formulas <- [Renewal, PreRenewal] do
      base = formulas.base(state, master_speed: 1, level_up: true, form_modes: form.modes)
      assert base.speed == 18
      assert base.mode == 0x85
    end
  end

  test "base input loading keeps motion defaults, clamps and signed primary assignments" do
    entry = %{
      "Id" => 1002,
      "AegisName" => "BASE_INPUTS",
      "Name" => "Base Inputs",
      "AttackMotion" => 50,
      "AttackDelay" => 40,
      "WalkSpeed" => 1,
      "Str" => 65_535,
      "Defense" => 500,
      "MagicDefense" => 300,
      "Sp" => 0
    }

    for {mode, defense} <- [{:renewal, 500}, {:pre_renewal, 127}] do
      {:ok, form} = Importer.to_definition(entry, mode)
      assert {form.attack_delay, form.attack_motion, form.client_attack_motion} == {100, 50, 50}
      assert {form.walk_speed, form.stats.str, form.def, form.sp} == {20, -1, defense, 1}
    end

    {:ok, defaults} = Importer.to_definition(Map.drop(entry, ["AttackMotion", "AttackDelay"]))

    assert {defaults.attack_delay, defaults.attack_motion, defaults.client_attack_motion} ==
             {100, 100, 100}
  end

  test "Sphere Mine source inputs initialize level-dependent HP rather than database HP" do
    {:ok, form} = MobManagement.get_mob_by_id(1_142)
    spawn = %MobSpawn{mob: form.id, amount: 1, respawn_time: 0, spawn_area: nil}
    state = MobState.new(907, form, spawn, "prontera", 100, 100)

    for {level, hp} <- [{1, 2_400}, {5, 4_000}] do
      prepared =
        MobState.configure_summon(state,
          owner_player_id: 12,
          summon_kind: :sphere,
          summon_level: level
        )

      assert prepared.base.max_hp == hp
      assert {prepared.hp, prepared.calculated.max_hp} == {hp, hp}
    end
  end

  test "Flora's direct base mode is distinct from its held slave-mode status" do
    {:ok, form} = MobManagement.get_mob_by_id(1_589)
    form = %{form | modes: [:can_move]}
    spawn = %MobSpawn{mob: form.id, amount: 1, respawn_time: 0, spawn_area: nil}
    state = MobState.new(908, form, spawn, "prontera", 100, 100)

    prepared =
      MobState.configure_summon(state,
        owner_player_id: 12,
        summon_kind: :flora,
        master_speed: 150,
        hp_override: 2_200
      )

    assert prepared.base.mode == 0x85
    assert prepared.base.speed == 150
    assert prepared.mob_data.modes == [:can_move]
  end

  test "training-edition guardians omit the ordinary castle defense additions" do
    slot = %{type: :archer, cell: {100, 100}}

    for {mode, castle_hp} <- [{:renewal, 100}, {:pre_renewal, 10_000}] do
      ordinary = Guardians.summon_opts(slot, 10, 1, 7, mode, 0)
      training = Guardians.summon_opts(slot, 10, 1, 7, mode, 24)
      assert ordinary[:hp_override] - training[:hp_override] == castle_hp
      assert training[:stat_bonus] == %{atk: 10, aspd_rate: 5}
    end
  end

  test "base modes honor false overrides before adding declared class modes" do
    {:ok, form} =
      Importer.to_definition(%{
        "Id" => 1002,
        "AegisName" => "BASE_MODES",
        "Name" => "Base Modes",
        "Class" => "Boss",
        "Ai" => 1,
        "Modes" => %{
          "CanAttack" => false,
          "NoCast" => true,
          "Mvp" => true,
          "StatusImmune" => false
        }
      })

    refute :can_attack in form.modes
    assert :no_cast in form.modes
    assert :mvp in form.modes
    assert :status_immune in form.modes
    assert form.class == :boss
  end

  test "a raw database class survives first calculation until Mode is selected" do
    {:ok, form} =
      Importer.to_definition(%{
        "Id" => 1002,
        "AegisName" => "RAW_EVENT",
        "Name" => "Raw Event",
        "Class" => "Event"
      })

    spawn = %MobSpawn{mob: form.id, amount: 1, respawn_time: 0, spawn_area: nil}
    state = MobState.new(905, form, spawn, "prontera", 100, 100)

    assert Renewal.base(state).class == :event
    assert PreRenewal.base(state).class == :event
  end

  test "ordinary first calculations copy database-level baselines without refresh clamps" do
    {:ok, form} = MobManagement.get_mob_by_id(1002)

    form = %{
      form
      | level: 10,
        stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15},
        atk: 100,
        atk2: 180,
        matk: 100,
        attack_motion: 50,
        attack_delay: 100,
        element: {:fire, 2}
    }

    spawn = %MobSpawn{mob: form.id, amount: 1, respawn_time: 0, spawn_area: nil}
    state = MobState.new(901, form, spawn, "prontera", 100, 100)
    renewal = Renewal.base(state)
    classic = PreRenewal.base(state)

    for formulas <- [Renewal, PreRenewal] do
      assert formulas.base(%{state | level: 99}, []) == formulas.base(state)
    end

    assert {renewal.hit, renewal.flee, renewal.def2, renewal.mdef2} == {195, 140, 30, 7}
    assert {renewal.batk, renewal.watk_min, renewal.watk_max} == {50, 80, 120}
    assert {renewal.matk_min, renewal.matk_max} == {100, 160}
    assert {classic.hit, classic.flee, classic.def2, classic.mdef2} == {45, 40, 50, 45}
    assert {classic.batk, classic.watk_min, classic.watk_max} == {0, 100, 180}
    assert {classic.matk_min, classic.matk_max} == {24, 36}

    for base <- [renewal, classic] do
      assert {base.amotion, base.adelay, base.aspd_rate} == {50, 100, 1_000}
      assert {base.cri, base.flee2} == {0, 0}
      assert {base.def_ele, base.ele_lv, base.attack_element} == {:fire, 2, :neutral}
    end
  end
end
