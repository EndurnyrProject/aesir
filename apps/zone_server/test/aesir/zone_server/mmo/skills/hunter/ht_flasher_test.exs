defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtFlasherTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtFlasher
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  defp group(attrs \\ []) do
    struct(
      %Group{
        group_id: 1,
        skill_id: 120,
        skill_name: :ht_flasher,
        level: 3,
        caster_id: 1000,
        caster_type: :player,
        map_name: "prontera",
        center: {50, 50},
        cells: [{50, 50}],
        next_tick_at: 0,
        expires_at: 0,
        interval: 1_000,
        state: %{}
      },
      attrs
    )
  end

  test "registers canonical costs and armed durations" do
    assert {:ok, HtFlasher} = Catalog.ground_module_for(:ht_flasher)
    definition = HtFlasher.definition()
    assert definition.id == 120
    assert definition.sp_cost == [12, 12, 12, 12, 12]
    assert definition.item_cost == [%{id: 1065, amount: 2}]
    assert definition.unit_duration == [150_000, 120_000, 90_000, 60_000, 30_000]
  end

  test "places a hidden armed trap with typed natural-reclaim lifecycle" do
    assert {:ok, placement} = HtFlasher.on_place(group())
    assert placement.cells == [{50, 50}]
    assert placement.visibility == :party_only

    assert %TrapState{
             phase: :armed,
             reclaim_item_id: 1065,
             natural_expiry: :drop_item,
             claymore_spendable?: true
           } = placement.state.trap
  end

  test "blinds only the eligible activator for 18 seconds before resistance" do
    expect(StatusInterpreter, :apply_status, fn :mob, 2001, :sc_blind, params ->
      assert params[:duration] == 18_000
      assert params[:success_rate] == 100
      assert params[:caster_id] == 1000
      assert params[:source_type] == :player
      :ok
    end)

    assert :expire = HtFlasher.on_touch(group(), {:mob, 2001})
  end

  test "does not trigger for same-side contacts" do
    reject(&StatusInterpreter.apply_status/4)
    assert {:ok, %Group{}} = HtFlasher.on_touch(group(), {:player, 2001})
  end

  defp plant_boss do
    %MobState{
      instance_id: 2001,
      mob_id: 1002,
      mob_data: %{race: :plant, modes: [:boss]},
      spawn_ref: nil,
      x: 50,
      y: 50,
      map_name: "prontera",
      hp: 100,
      max_hp: 100,
      sp: 0,
      max_sp: 0,
      spawned_at: 0
    }
  end

  test "plant bosses do not activate the trap" do
    plant_boss = plant_boss()
    stub(UnitRegistry, :get_unit, fn :mob, 2001 -> {:ok, {MobState, plant_boss, self()}} end)
    reject(&StatusInterpreter.apply_status/4)

    assert {:ok, %Group{}} = HtFlasher.on_touch(group(), {:mob, 2001})
  end

  test "mob-owned traps attempt Blind on player activators with a mob source" do
    expect(StatusInterpreter, :apply_status, fn :player, 2001, :sc_blind, params ->
      assert params[:source_type] == :mob
      assert params[:caster_id] == 1000
      :ok
    end)

    assert :expire = HtFlasher.on_touch(group(caster_type: :mob), {:player, 2001})
  end
end
