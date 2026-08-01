defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtShockwaveTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtShockwave
  alias Aesir.ZoneServer.Unit.Resource

  @caster_id 1_000

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

  test "defines the hidden two-catalyst trap" do
    assert {:ok, HtShockwave} = Catalog.ground_module_for(:ht_shockwave)

    assert %{
             id: 118,
             max_level: 5,
             target_type: :ground,
             damage_type: :no_damage,
             damage_kind: :misc,
             range: 3,
             hit_interval: 1_000,
             sp_cost: [45, 45, 45, 45, 45],
             item_cost: [%{id: 1065, amount: 2}],
             unit_duration: [200_000, 160_000, 120_000, 80_000, 40_000]
           } =
             HtShockwave.definition()

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
      expect(Resource, :drain_sp_percent, fn :mob, 2_000, ^percentage -> :ok end)
      assert :expire = HtShockwave.on_touch(group(level), {:mob, 2_000})
    end

    expect(Resource, :drain_sp_percent, fn :player, 3_000, 50 -> :ok end)

    assert :expire =
             HtShockwave.on_touch(group(3, caster_type: :mob), {:player, 3_000})
  end

  test "does not damage or trigger on same-side contacts" do
    reject(&Resource.drain_sp_percent/3)

    assert {:ok, %Group{}} = HtShockwave.on_touch(group(1), {:player, 2_000})
    assert {:ok, %Group{}} = HtShockwave.on_touch(group(1, caster_type: :mob), {:mob, 2_000})
  end
end
