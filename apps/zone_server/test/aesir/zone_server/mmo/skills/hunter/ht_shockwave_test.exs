defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtShockwaveTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtShockwave
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.Trap
  alias Aesir.ZoneServer.Unit.Resource

  @caster_id 1_000

  setup :verify_on_exit!

  setup do
    Mimic.copy(Resource)
    Mimic.copy(Trap)

    stub(Trap, :enemy?, fn
      %Group{caster_type: :player}, {:mob, _id} -> true
      %Group{caster_type: :mob}, {type, _id} when type in [:player, :homunculus] -> true
      %Group{}, {_type, _id} -> false
    end)

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
    for {percentage, level} <- Enum.with_index([20, 35, 50, 65, 80], 1) do
      expect(Resource, :drain_sp_percent, fn {:mob, 2_000}, ^percentage -> :ok end)
      assert :expire = HtShockwave.on_touch(group(level), {:mob, 2_000})
    end

    expect(Resource, :drain_sp_percent, fn {:player, 3_000}, 50 -> :ok end)

    assert :expire =
             HtShockwave.on_touch(group(3, caster_type: :mob), {:player, 3_000})
  end

  test "does not damage or trigger on same-side contacts" do
    reject(&Resource.drain_sp_percent/2)

    assert {:ok, %Group{}} = HtShockwave.on_touch(group(1), {:player, 2_000})
    assert {:ok, %Group{}} = HtShockwave.on_touch(group(1, caster_type: :mob), {:mob, 2_000})
  end
end
