defmodule Aesir.ZoneServer.Unit.Mob.StatsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Mechanics.MobFormulas.Renewal
  alias Aesir.ZoneServer.Mmo.MobManagement.Importer
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.Stats

  setup do
    {:ok, form} =
      Importer.to_definition(%{
        "Id" => 1002,
        "AegisName" => "STATS_SNAPSHOT",
        "Name" => "Stats Snapshot",
        "Level" => 10
      })

    form = %{form | hp: 1_000, sp: 100, walk_speed: 300, element: {:neutral, 2}}
    spawn = %MobSpawn{mob: form.id, amount: 1, respawn_time: 0, spawn_area: nil}
    %{form: form, spawn: spawn}
  end

  test "the raw base is the untouched form seed through every calculation", %{
    form: form,
    spawn: spawn
  } do
    state = MobState.new(1201, form, spawn, "prontera", 100, 100)
    raw = Stats.base(state)

    assert raw == state.base
    assert state.calculated == raw

    held = [entry(:sc_incallstatus, 5), entry(:sc_incmhprate, 20)]
    calculated = Stats.recalculate(state, held, flags(["All"]))

    assert calculated.str == raw.str + 5
    assert calculated.max_hp == div(raw.max_hp * 120, 100)

    assert Stats.base(state) == raw
    assert Stats.recalculate(state, held, flags(["All"])) == calculated
    assert state.base == raw
    assert state.mob_data.stats == form.stats
  end

  test "a selective calculation keeps every unselected field and All restores the rest", %{
    form: form,
    spawn: spawn
  } do
    state = MobState.new(1202, form, spawn, "prontera", 100, 100)
    raw = Stats.base(state)

    held = [
      entry(:sc_incallstatus, 5),
      entry(:sc_incmhprate, 20),
      entry(:sc_decreaseagi, 1, 3),
      entry(:sc_freeze, 1),
      entry(:sc_waterweapon, 1),
      entry(:sc_twohandquicken, 10, 300)
    ]

    str_only = Stats.recalculate(state, held, flags(["Str"]))
    assert str_only.str == raw.str + 5
    assert Map.drop(str_only, [:str, :batk]) == Map.drop(raw, [:str, :batk])

    restored = Stats.recalculate(state, held, flags(["All"]))

    assert restored.str == raw.str + 5
    assert restored.agi == raw.agi + 2
    assert restored.max_hp == div(raw.max_hp * 120, 100)
    assert {restored.def_ele, restored.ele_lv} == {:water, 1}
    assert restored.attack_element == :water
    assert restored.aspd_rate == raw.aspd_rate - 300
    assert {restored.race, restored.size, restored.mode} == {raw.race, raw.size, raw.mode}
    assert Stats.base(state) == raw
  end

  test "recalculating a selected field never compounds an earlier calculation", %{
    form: form,
    spawn: spawn
  } do
    state = MobState.new(1203, form, spawn, "prontera", 100, 100)
    raw = Stats.base(state)
    held = [entry(:sc_incmhprate, 20)]

    once = Stats.recalculate(state, held, flags(["MaxHp"]))
    again = Stats.recalculate(%{state | calculated: once}, held, flags(["MaxHp"]))

    assert once.max_hp == div(raw.max_hp * 120, 100)
    assert again == once

    restored = Stats.recalculate(%{state | calculated: once}, held, flags(["All"]))
    assert restored.max_hp == once.max_hp
  end

  test "the prepared base and the form seed agree for a plain spawn", %{form: form, spawn: spawn} do
    state = MobState.new(1204, form, spawn, "prontera", 100, 100)

    assert Stats.prepare_base(state, []) == Stats.base(state)
  end

  defp flags(selection), do: Renewal.expand_calc_flags(selection)

  defp entry(type, val1, val2 \\ 0) do
    StatusEntry.new(type, val1, val2, 0, 0, 0, 0)
  end
end
