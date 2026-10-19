defmodule Aesir.ZoneServer.Unit.Mob.MobEscapeWalkTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Unit.Mob.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @map "mob_escape_walk_map"

  setup :setup_ets_tables

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 60, 60)})
    SpatialIndex.add_unit(:mob, 7, 30, 30, @map)
    :ok
  end

  describe "chase walks" do
    test "a chase that starts a walk enters the rush state before its first cell" do
      {:noreply, chasing} = MovementHandler.handle_move_to(mob(), 30, 33, chase: true)

      assert chasing.movement_state == :moving
      assert chasing.skill_state == :rush
    end

    test "a chase redirecting a walk in progress enters the rush state at once" do
      {:noreply, walking} = MovementHandler.handle_move_to(mob(), 30, 33)
      refute walking.skill_state == :rush

      {:noreply, chasing} = MovementHandler.handle_move_to(walking, 33, 30, chase: true)

      assert chasing.walk_target == {33, 30}
      assert chasing.skill_state == :rush
    end
  end

  describe "escape/3" do
    test "walks eight cells straight away from the target" do
      escaped = MovementHandler.escape(mob(), {27, 30}, 8)

      assert escaped.movement_state == :moving
      assert escaped.walk_path == for(x <- 31..38, do: {x, 30})
      assert escaped.walk_easy
    end

    test "runs along the target's diagonal sector" do
      escaped = MovementHandler.escape(mob(), {28, 28}, 8)

      assert escaped.walk_path == for(i <- 1..8, do: {30 + i, 30 + i})
    end

    test "a target on the mob's own cell sends it east" do
      escaped = MovementHandler.escape(mob(), {30, 30}, 8)

      assert List.last(escaped.walk_path) == {38, 30}
    end

    test "stops on the last walkable cell before a wall" do
      block_cell(35, 30)
      block_cell(37, 30)

      escaped = MovementHandler.escape(mob(), {27, 30}, 8)

      assert escaped.walk_path == [{31, 30}, {32, 30}, {33, 30}, {34, 30}]
    end

    test "no walk starts when the first cell is blocked" do
      block_cell(31, 30)

      escaped = MovementHandler.escape(mob(), {27, 30}, 8)

      assert escaped.movement_state == :standing
      assert escaped.walk_path == []
    end

    test "an easy walk steps diagonally between two blocked corners" do
      block_cell(31, 30)
      block_cell(30, 31)

      escaped = MovementHandler.escape(mob(), {28, 28}, 2)
      assert escaped.walk_path == [{31, 31}, {32, 32}]

      {:noreply, stepped} = MovementHandler.handle_movement_tick(escaped)
      assert {stepped.x, stepped.y} == {31, 31}
    end

    test "a walking mob re-paths straight from the cell its step lands on" do
      {:noreply, walking} = MovementHandler.handle_move_to(mob(), 30, 33)
      escaped = MovementHandler.escape(walking, {30, 26}, 8)

      assert escaped.walk_path == walking.walk_path
      assert escaped.walk_target == {30, 38}

      {:noreply, landed} = MovementHandler.handle_movement_tick(escaped)

      assert {landed.x, landed.y} == {30, 31}
      assert landed.walk_path == for(y <- 32..38, do: {30, y})
    end

    test "a normal move request ends the easy walk mode" do
      escaped = MovementHandler.escape(mob(), {27, 30}, 8)
      {:noreply, moved} = MovementHandler.handle_move_to(escaped, 30, 20)

      refute moved.walk_easy
      assert MobState.stop_movement(escaped).walk_easy == false
    end
  end

  describe "walk-time skill check" do
    test "Speed Up keeps a trick-casting mob walking, faster" do
      now = System.system_time(:millisecond)

      {:noreply, stepped} =
        MovementHandler.handle_movement_tick(walking_sphere(now + 3_000, now - 700))

      assert {stepped.x, stepped.y} == {31, 30}
      assert stepped.calculated.speed == 550
      assert stepped.movement_state == :moving
      assert stepped.last_skill_id == 332
      assert stepped.last_skillcheck >= now
    end

    test "Speed Up stops the walk once under 700 ms of trick cast are left" do
      now = System.system_time(:millisecond)

      {:noreply, stopped} =
        MovementHandler.handle_movement_tick(walking_sphere(now + 500, now - 700))

      assert {stopped.x, stopped.y} == {31, 30}
      assert stopped.movement_state == :standing
      assert stopped.trickcasting == nil
      refute stopped.can_escape
      assert stopped.calculated.speed == 800
      assert stopped.last_skillcheck == now + 500
    end

    test "no skill is checked within the skill interval less half the speed" do
      now = System.system_time(:millisecond)

      {:noreply, stepped} =
        MovementHandler.handle_movement_tick(walking_sphere(now + 3_000, now - 500))

      assert stepped.calculated.speed == 800
      assert stepped.last_skill_id == nil
      assert stepped.movement_state == :moving
    end
  end

  # A Marine Sphere escaping east with its trick cast running; at full HP only
  # its Speed Up row can fire.
  defp walking_sphere(trickcasting, last_skillcheck) do
    {:ok, marine_sphere} = Mobs.by_id(1142)
    escaping = MovementHandler.escape(%{mob() | mob_data: marine_sphere}, {27, 30}, 8)

    %{
      escaping
      | trickcasting: trickcasting,
        can_escape: true,
        last_skillcheck: last_skillcheck
    }
  end

  defp block_cell(x, y) do
    :ok = Cell.put(@map, x, y, :barrier, x * 1_000 + y, blocks_movement: true)
  end

  defp mob do
    struct(MobState,
      instance_id: 7,
      mob_id: 1142,
      mob_data: Aesir.TestMob.definition(id: 1142),
      map_name: @map,
      x: 30,
      y: 30,
      hp: 10,
      last_skillcheck: System.system_time(:millisecond),
      is_dead: false
    )
    |> Aesir.TestMob.publish(max_hp: 10, walk_speed: 800)
  end
end
