defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtFlasherTest do
  use ExUnit.Case, async: true
  import Mimic
  import Aesir.ZoneServer.TrapTestHelper

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtFlasher
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :verify_on_exit!

  @cell {50, 50}
  @now 10_000

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

  defp armed(attrs \\ []),
    do: group(Keyword.merge([expires_at: 90_000, state: %{trap: armed_trap()}], attrs))

  @tag game_mode: :renewal
  test "registers canonical costs and armed durations" do
    definition = HtFlasher.definition()
    assert definition.sp_cost == [12, 12, 12, 12, 12]
    assert definition.item_cost == [%{id: 1065, amount: 2}]
    assert HtFlasher.definition(:pre_renewal).item_cost == [%{id: 1065, amount: 1}]
    assert definition.unit_duration == [150_000, 120_000, 90_000, 60_000, 30_000]
  end

  @tag game_mode: :renewal
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

  @tag game_mode: :renewal
  test "blinds only the eligible activator for 18 seconds before resistance" do
    stub_units([player(1000)])

    expect(StatusInterpreter, :apply_status, fn :mob, 2001, :sc_blind, params ->
      assert params[:duration] == 18_000
      assert params[:success_rate] == 100
      assert params[:caster_id] == 1000
      assert params[:source_type] == :player
      :ok
    end)

    assert {:ok, %Group{expires_at: 11_500, state: %{trap: %TrapState{phase: :used}}}} =
             HtFlasher.on_unit_hit(armed(), @cell, {:mob, 2001}, @now)
  end

  @tag game_mode: :pre_renewal
  test "a pre-renewal flash blinds for 30 seconds" do
    stub_units([player(1000)])

    expect(StatusInterpreter, :apply_status, fn :mob, 2001, :sc_blind, params ->
      assert params[:duration] == 30_000
      :ok
    end)

    assert {:ok, %Group{state: %{trap: %TrapState{phase: :used}}}} =
             HtFlasher.on_unit_hit(armed(), @cell, {:mob, 2001}, @now)
  end

  test "does not trigger for same-side contacts" do
    stub_units([player(1000), player(2001), mob(2002)])

    assert [{:mob, 2002}] =
             HtFlasher.unit_targets(armed(), @cell, [{:player, 2001}, {:mob, 2002}])
  end

  test "plant bosses do not activate the trap" do
    stub_units([player(1000), mob(2001, race: :plant, modes: [:boss])])
    reject(&StatusInterpreter.apply_status/4)

    armed = armed()
    assert {:ok, ^armed} = HtFlasher.on_unit_hit(armed, @cell, {:mob, 2001}, @now)
  end

  test "mob-owned traps attempt Blind on player activators with a mob source" do
    stub_units([mob(1000)])

    expect(StatusInterpreter, :apply_status, fn :player, 2001, :sc_blind, params ->
      assert params[:source_type] == :mob
      assert params[:caster_id] == 1000
      :ok
    end)

    assert {:ok, %Group{state: %{trap: %TrapState{phase: :used}}}} =
             HtFlasher.on_unit_hit(armed(caster_type: :mob), @cell, {:player, 2001}, @now)
  end
end
