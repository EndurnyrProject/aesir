defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.WarpPortalLifecycleTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlWarp
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private

  test "opening visits its occupants once, not on every subsequent manager pass" do
    now = System.monotonic_time(:millisecond)

    player = %PlayerState{
      character_id: 3000,
      action_state: :idle,
      map_name: "prontera",
      x: 100,
      y: 100,
      walk_path: [],
      stats: %{current_state: %{hp: 1}}
    }

    stub(UnitRegistry, :get_unit, fn :player, 3000 -> {:ok, {PlayerState, player, self()}} end)
    stub(SpatialIndex, :units_in_cell, fn "prontera", 100, 100 -> [{:player, 3000}] end)

    group = %Group{
      group_id: 1,
      skill_name: :al_warp,
      level: 2,
      center: {100, 100},
      map_name: "prontera",
      state: %{dest: {"izlude", 120, 120}, uses: 8, opens_at: now - 1}
    }

    assert {:ok, ^group} = AlWarp.on_touch(group, {:player, 3000})
    refute_received {:"$gen_cast", {:movement, {:warp, _, _, _}}}

    assert {:ok, opened} = AlWarp.on_interval(group, now)
    assert opened.state.uses == 7
    assert_received {:"$gen_cast", {:movement, {:warp, "izlude", 120, 120}}}

    assert {:ok, unchanged} = AlWarp.on_interval(opened, now + 1_000)
    assert unchanged.state.uses == 7
    refute_received {:"$gen_cast", {:movement, {:warp, _, _, _}}}
  end

  test "a walk through the cell does not enter, but its destination does" do
    now = System.monotonic_time(:millisecond)

    group = %Group{
      group_id: 1,
      skill_name: :al_warp,
      level: 2,
      center: {100, 100},
      map_name: "prontera",
      state: %{dest: {"izlude", 120, 120}, uses: 8, opens_at: now - 1, opened: true}
    }

    player = %PlayerState{
      character_id: 3000,
      action_state: :idle,
      x: 100,
      y: 100,
      map_name: "prontera",
      walk_path: [{101, 100}],
      stats: %{current_state: %{hp: 1}}
    }

    stub(UnitRegistry, :get_unit, fn :player, 3000 -> {:ok, {PlayerState, player, self()}} end)
    assert {:ok, unchanged} = AlWarp.on_touch(group, {:player, 3000})
    assert unchanged.state.uses == 8
    refute_received {:"$gen_cast", {:movement, {:warp, _, _, _}}}
  end

  test "a refused destination entry still spends its use" do
    target = %PlayerState{
      character_id: 3000,
      action_state: :idle,
      map_name: "prontera",
      x: 100,
      y: 100,
      stats: %{current_state: %{hp: 1}}
    }

    stub(UnitRegistry, :get_unit, fn :player, 3000 -> {:ok, {PlayerState, target, self()}} end)
    stub(MapCache, :get, fn "izlude" -> {:ok, %MapData{name: "izlude", cells: nil}} end)

    group = %Group{
      group_id: 1,
      skill_name: :al_warp,
      level: 2,
      center: {100, 100},
      state: %{
        dest: {"izlude", 120, 120},
        uses: 8,
        opens_at: System.monotonic_time(:millisecond) - 1,
        opened: true
      }
    }

    assert {:ok, used} = AlWarp.on_touch(group, {:player, 3000})
    assert used.state.uses == 7
    refute_received {:"$gen_cast", {:movement, {:warp, _, _, _}}}
  end

  test "an exact same-cell destination locks the whole portal after spending its first use" do
    now = System.monotonic_time(:millisecond)

    target = %PlayerState{
      character_id: 3000,
      action_state: :idle,
      map_name: "prontera",
      x: 100,
      y: 100,
      stats: %{current_state: %{hp: 1}}
    }

    stub(UnitRegistry, :get_unit, fn :player, 3000 -> {:ok, {PlayerState, target, self()}} end)

    group = %Group{
      group_id: 1,
      skill_name: :al_warp,
      level: 2,
      map_name: "prontera",
      center: {100, 100},
      state: %{dest: {"prontera", 100, 100}, uses: 8, opens_at: now - 1, opened: true}
    }

    assert {:ok, working} = AlWarp.on_touch(group, {:player, 3000})
    assert working.state.working
    assert working.state.uses == 7
    assert_received {:"$gen_cast", {:movement, {:warp, "prontera", 100, 100}}}
    assert {:ok, ^working} = AlWarp.on_touch(working, {:player, 3001})
    refute_received {:"$gen_cast", {:movement, {:warp, _, _, _}}}
  end
end
