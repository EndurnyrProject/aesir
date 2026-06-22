defmodule Aesir.ZoneServer.Unit.MovementTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  describe "set_position/4" do
    test "updates the spatial index and registry and marks the unit dirty" do
      char_id = 1001
      map_name = "prontera"
      UnitRegistry.register_unit(:player, char_id, __MODULE__, %{movement_state: :standing}, nil)
      SpatialIndex.add_unit(:player, char_id, 50, 50, map_name)

      updated_state = %{movement_state: :moving, x: 55, y: 60}
      assert :ok = Movement.set_position(:player, char_id, updated_state, map_name)

      assert {:ok, {55, 60, ^map_name}} = SpatialIndex.get_unit_position(:player, char_id)
      assert {:ok, {__MODULE__, ^updated_state, nil}} = UnitRegistry.get_unit(:player, char_id)
      assert [{:player, ^char_id, 1}] = Movement.drain_dirty(map_name)
    end
  end

  describe "mark_dirty/4 and drain_dirty/1" do
    test "drain returns each dirty unit once and then clears them" do
      map_name = "prontera"
      Movement.mark_dirty(map_name, :player, 1, 1)
      Movement.mark_dirty(map_name, :mob, 2, 0)

      drained = Movement.drain_dirty(map_name)
      assert Enum.sort(drained) == [{:mob, 2, 0}, {:player, 1, 1}]

      assert Movement.drain_dirty(map_name) == []
    end

    test "the latest mark_dirty for a unit wins" do
      map_name = "prontera"
      Movement.mark_dirty(map_name, :player, 1, 1)
      Movement.mark_dirty(map_name, :player, 1, 0)

      assert Movement.drain_dirty(map_name) == [{:player, 1, 0}]
    end

    test "drain for one map does not return units marked on another map" do
      Movement.mark_dirty("prontera", :player, 1, 1)
      Movement.mark_dirty("geffen", :player, 2, 1)

      assert Movement.drain_dirty("prontera") == [{:player, 1, 1}]
      assert Movement.drain_dirty("geffen") == [{:player, 2, 1}]
    end
  end
end
