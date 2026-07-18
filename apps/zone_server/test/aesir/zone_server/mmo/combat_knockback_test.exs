defmodule Aesir.ZoneServer.Mmo.CombatKnockbackTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Net.Knockback
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  setup do
    Mimic.copy(Cell)
    Mimic.copy(MapCache)
    :ok
  end

  @map_name "prontera"
  @mob_id 2001
  @from {150, 150}

  defp mob_state(x, y, modes \\ []) do
    %MobState{
      instance_id: @mob_id,
      mob_id: 1002,
      mob_data: %{modes: modes},
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
    stub(Cell, :traversable?, fn @map_name, x, _y -> x < 154 end)

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

  test "knockback leaves a boss mob's position unchanged and broadcasts nothing" do
    stub(SpatialIndex, :get_unit_position, fn :mob, @mob_id ->
      {:ok, {151, 150, @map_name}}
    end)

    stub(MapCache, :get, fn @map_name -> {:ok, :map} end)

    stub(UnitRegistry, :get_unit, fn :mob, @mob_id ->
      {:ok, {MobState, mob_state(151, 150, [:boss]), self()}}
    end)

    reject(&Cell.traversable?/3)
    reject(&Broadcast.to_in_range/5)

    {from_x, from_y} = @from
    assert {:ok, {151, 150}} = Combat.knockback(:mob, @mob_id, from_x, from_y, 5)
    refute_received {:"$gen_cast", {:knocked_back, _, _}}
  end

  test "knockback with no walkable cell leaves the unit in place" do
    stub(SpatialIndex, :get_unit_position, fn :mob, @mob_id ->
      {:ok, {151, 150, @map_name}}
    end)

    stub(MapCache, :get, fn @map_name -> {:ok, :map} end)

    stub(Cell, :traversable?, fn @map_name, _x, _y -> false end)

    {from_x, from_y} = @from
    assert {:ok, {151, 150}} = Combat.knockback(:mob, @mob_id, from_x, from_y, 5)
  end

  test "knockback ignores skill-unit cells without casting to their manager" do
    test_pid = self()

    stub(SpatialIndex, :get_unit_position, fn :skill_unit, @mob_id ->
      {:ok, {151, 150, @map_name}}
    end)

    stub(MapCache, :get, fn @map_name -> {:ok, :map} end)
    stub(Cell, :traversable?, fn _map_name, _x, _y -> true end)

    stub(UnitRegistry, :get_unit, fn :skill_unit, @mob_id ->
      {:ok, {__MODULE__, %{}, test_pid}}
    end)

    reject(&Broadcast.to_in_range/5)

    {from_x, from_y} = @from
    assert :ok = Combat.knockback(:skill_unit, @mob_id, from_x, from_y, 5)
    refute_received {:"$gen_cast", {:knocked_back, _, _}}
  end

  test "knockback returns an error when the unit map is unavailable" do
    stub(SpatialIndex, :get_unit_position, fn :mob, @mob_id ->
      {:ok, {151, 150, "missing"}}
    end)

    stub(MapCache, :get, fn "missing" -> {:error, :not_found} end)

    {from_x, from_y} = @from
    assert {:error, :not_found} = Combat.knockback(:mob, @mob_id, from_x, from_y, 5)
  end
end
