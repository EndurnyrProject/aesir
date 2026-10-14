defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtShockwaveTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.ZoneServer.TrapTestHelper

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtShockwave
  alias Aesir.ZoneServer.Unit.Resource

  @caster_id 1_000
  @cell {50, 50}
  @now 10_000

  setup :verify_on_exit!

  setup do
    Mimic.copy(Resource)
    :ok
  end

  defp group(level, attrs \\ []) do
    struct(
      %Group{
        group_id: 1,
        skill_id: 118,
        skill_name: :ht_shockwave,
        level: level,
        caster_id: @caster_id,
        caster_type: :player,
        map_name: "prontera",
        center: {50, 50},
        cells: [{50, 50}],
        next_tick_at: 0,
        expires_at: 0,
        interval: 1_000,
        state: %{cast_origin: :normal, paid_return?: true}
      },
      attrs
    )
  end

  defp armed(level, attrs \\ []),
    do: group(level, Keyword.merge([expires_at: 120_000, state: %{trap: armed_trap()}], attrs))

  @tag game_mode: :renewal
  test "places a hidden armed trap that reclaims its catalyst" do
    assert {:ok, %{cells: [{50, 50}], visibility: :party_only, state: state}} =
             HtShockwave.on_place(group(1))

    assert %TrapState{
             phase: :armed,
             reclaim_item_id: 1065,
             claymore_spendable?: true,
             natural_expiry: :drop_item,
             return_item_on_expiry?: true
           } = state.trap
  end

  test "drains the level-scaled percentage from hostile player and mob contacts" do
    stub_units([player(@caster_id), mob(@caster_id)])

    for {percentage, level} <- Enum.with_index([20, 35, 50, 65, 80], 1) do
      expect(Resource, :drain_sp_percent, fn {:mob, 2_000}, ^percentage -> :ok end)

      assert {:ok, %Group{expires_at: 11_500, state: %{trap: %TrapState{phase: :used}}}} =
               HtShockwave.on_unit_hit(armed(level), @cell, {:mob, 2_000}, @now)
    end

    expect(Resource, :drain_sp_percent, fn {:player, 3_000}, 50 -> :ok end)

    assert {:ok, %Group{state: %{trap: %TrapState{phase: :used}}}} =
             HtShockwave.on_unit_hit(armed(3, caster_type: :mob), @cell, {:player, 3_000}, @now)
  end

  test "does not damage or trigger on same-side contacts" do
    stub_units([player(@caster_id), player(2_000), mob(2_001)])

    assert [{:mob, 2_001}] =
             HtShockwave.unit_targets(armed(1), @cell, [{:player, 2_000}, {:mob, 2_001}])

    stub_units([mob(@caster_id), mob(2_000), player(2_001)])

    assert [{:player, 2_001}] =
             HtShockwave.unit_targets(armed(1, caster_type: :mob), @cell, [
               {:mob, 2_000},
               {:player, 2_001}
             ])
  end
end
