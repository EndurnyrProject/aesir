defmodule Aesir.ZoneServer.Mmo.CombatKnockbackTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Net.Knockback
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @map_name "prontera"
  @mob_id 2001
  @from {150, 150}

  defp mob_state(x, y) do
    %MobState{
      instance_id: @mob_id,
      mob_id: 1002,
      mob_data: %{},
      spawn_ref: %{},
      x: x,
      y: y,
      map_name: @map_name,
      hp: 100,
      max_hp: 100,
      sp: 50,
      max_sp: 50,
      spawned_at: 0
    }
  end

  test "knockback walks the unit outward and casts the landing cell to the owning session" do
    test_pid = self()

    # Unit sits east of the source, so it is blown further east (+x).
    stub(SpatialIndex, :get_unit_position, fn :mob, @mob_id ->
      {:ok, {151, 150, @map_name}}
    end)

    stub(MapCache, :get, fn @map_name -> {:ok, :map} end)

    # A wall at x == 154: cells 152 and 153 are walkable, 154 is not.
    stub(MapData, :walkable?, fn :map, x, _y -> x < 154 end)

    # The owning session is the single writer: knockback routes the landing cell
    # to it via a {:knocked_back, x, y} cast (received by this test process).
    stub(UnitRegistry, :get_unit, fn :mob, @mob_id ->
      {:ok, {MobState, mob_state(151, 150), test_pid}}
    end)

    stub(Broadcast, :to_in_range, fn @map_name, _x, _y, _range, %Knockback{} = pkt ->
      send(test_pid, {:broadcast, pkt})
      :ok
    end)

    {from_x, from_y} = @from
    assert {:ok, {153, 150}} = Combat.knockback(:mob, @mob_id, from_x, from_y, 5)

    assert_received {:"$gen_cast", {:knocked_back, 153, 150}}
    assert_received {:broadcast, %Knockback{unit_id: @mob_id, dst_x: 153, dst_y: 150}}
  end

  test "knockback with no walkable cell leaves the unit in place" do
    stub(SpatialIndex, :get_unit_position, fn :mob, @mob_id ->
      {:ok, {151, 150, @map_name}}
    end)

    stub(MapCache, :get, fn @map_name -> {:ok, :map} end)
    stub(MapData, :walkable?, fn :map, _x, _y -> false end)

    {from_x, from_y} = @from
    assert {:ok, {151, 150}} = Combat.knockback(:mob, @mob_id, from_x, from_y, 5)
  end
end
