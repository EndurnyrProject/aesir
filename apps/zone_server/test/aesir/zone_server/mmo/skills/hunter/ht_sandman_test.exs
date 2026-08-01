defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtSandmanTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtSandman
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.Trap
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  setup do
    Mimic.copy(StatusInterpreter)
    :ok
  end

  @caster_id 1000

  defp group(attrs \\ []) do
    base = %Group{
      group_id: 1,
      skill_id: 119,
      skill_name: :ht_sandman,
      level: 3,
      caster_id: @caster_id,
      caster_type: :player,
      map_name: "prontera",
      center: {50, 50},
      cells: [{50, 50}],
      next_tick_at: 0,
      expires_at: 0,
      interval: 1_000,
      state: %{trap: %TrapState{reclaim_item_id: 1065}}
    }

    struct(base, attrs)
  end

  test "registers canonical Sandman placement metadata" do
    assert {:ok, HtSandman} = Catalog.ground_module_for(:ht_sandman)

    definition = HtSandman.definition()

    assert definition.id == 119
    assert definition.max_level == 5
    assert definition.target_type == :ground
    assert definition.sp_cost == List.duplicate(12, 5)
    assert definition.item_cost == [%{id: 1065, amount: 1}]
    assert definition.range == 3
    assert definition.hit_interval == 1_000
    assert definition.unit_duration == [150_000, 120_000, 90_000, 60_000, 30_000]
  end

  test "places a hidden typed trap with the level-scaled armed lifetime" do
    stub(UnitRegistry, :get_unit_info, fn :player, @caster_id ->
      {:ok, %{stats: %{dex: 50, int: 40, base_level: 50}}}
    end)

    assert {:ok, placement} = HtSandman.on_place(group())
    assert placement.cells == [{50, 50}]
    assert placement.visibility == :none
    assert placement.duration == 90_000

    assert %TrapState{
             phase: :armed,
             natural_expiry: :drop_item,
             reclaim_item_id: 1065,
             claymore_spendable?: true
           } = placement.state.trap
  end

  test "uses the canonical chance at every level" do
    caster = %{unit_type: :player, unit_id: @caster_id}
    stub(Combat, :resolve_combatant, fn :player, @caster_id -> {:ok, caster} end)
    stub(SpatialIndex, :get_unit_position, fn :mob, 2001 -> {:ok, {50, 50, "prontera"}} end)
    stub(Combat, :splash_targets, fn "prontera", {50, 50}, 2, ^caster -> [{:mob, 2001}] end)

    test_pid = self()

    stub(StatusInterpreter, :apply_status, fn :mob, 2001, :sc_sleep, params ->
      send(test_pid, {:chance, params[:success_rate]})
      :ok
    end)

    for {chance, level} <- Enum.with_index([50, 60, 70, 80, 90], 1) do
      assert :expire = HtSandman.on_touch(group(level: level), {:mob, 2001})
      assert_receive {:chance, ^chance}
    end
  end

  test "centers independent Sleep attempts on the triggering mob's 5x5 area" do
    activator = {:mob, 2001}
    caster = %{unit_type: :player, unit_id: @caster_id}

    expect(Combat, :resolve_combatant, fn :player, @caster_id -> {:ok, caster} end)

    expect(SpatialIndex, :get_unit_position, fn :mob, 2001 ->
      {:ok, {80, 75, "prontera"}}
    end)

    expect(Combat, :splash_targets, fn "prontera", {80, 75}, 2, ^caster ->
      [activator, {:mob, 2002}, {:player, 3001}]
    end)

    test_pid = self()

    stub(StatusInterpreter, :apply_status, fn target_type, target_id, :sc_sleep, params ->
      send(test_pid, {:sleep_attempt, target_type, target_id, params})
      :ok
    end)

    assert Trap.enemy?(group(), activator)
    assert :expire = HtSandman.on_touch(group(), activator)

    for target_id <- [2001, 2002] do
      assert_receive {:sleep_attempt, :mob, ^target_id, params}
      assert params[:duration] == 18_000
      assert params[:success_rate] == 70
      assert params[:caster_id] == @caster_id
      assert params[:source_type] == :player
    end

    refute_receive {:sleep_attempt, :player, 3001, _}
  end

  test "uses the same activator-centered area for mob casters and leaves status immunity authoritative" do
    activator = {:player, 3001}
    caster = %{unit_type: :mob, unit_id: 2000}
    mob_group = group(caster_type: :mob, caster_id: 2000, level: 5)

    expect(Combat, :resolve_combatant, fn :mob, 2000 -> {:ok, caster} end)

    expect(SpatialIndex, :get_unit_position, fn :player, 3001 ->
      {:ok, {80, 75, "prontera"}}
    end)

    expect(Combat, :splash_targets, fn "prontera", {80, 75}, 2, ^caster ->
      [activator, {:mob, 2002}]
    end)

    test_pid = self()

    stub(StatusInterpreter, :apply_status, fn :player, 3001, :sc_sleep, params ->
      send(test_pid, {:sleep_attempt, params})
      {:error, :immune}
    end)

    assert Trap.enemy?(mob_group, activator)
    assert :expire = HtSandman.on_touch(mob_group, activator)
    assert_receive {:sleep_attempt, params}
    assert params[:success_rate] == 90
    assert params[:source_type] == :mob
  end

  test "does not activate for a same-side contact" do
    reject(&Combat.resolve_combatant/2)

    assert {:ok, %Group{group_id: 1}} = HtSandman.on_touch(group(), {:player, 3001})
  end
end
