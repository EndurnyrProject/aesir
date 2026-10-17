defmodule Aesir.ZoneServer.Integration.SetcellIcewallPenTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Map.ScriptCells
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit.Mob.Handlers.MovementHandler

  @map "setcell_icewall_pen"

  setup do
    # A synthetic walkable 12x12 map with a 4x4 icewall band in the middle. Its
    # last row and column (11) are impassable, and (0, 0) is never a path goal
    # (the client search's zeroed first slot), so the walks stay inside 1..10.
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 12, 12)})
    :ok = ScriptCells.set(@map, {4, 4}, {7, 7}, :icewall, 1)
    :ok
  end

  test "a mob walking into the band from the south-west is held on its first band cell" do
    map_data = MapCache.get!(@map)

    assert {:ok, mob_path} = Pathfinding.find_path(map_data, {1, 1}, {9, 9})
    assert Enum.any?(mob_path, fn {x, y} -> Cell.icewall?(@map, x, y) end)

    mob = start_mob_session(map_name: @map, position: {1, 1}, awake: false)
    {:noreply, state} = MovementHandler.handle_move_to(mob.mob_state, 9, 9)
    {state, _positions} = drive(state)

    assert Cell.icewall?(@map, state.x, state.y)
    assert state.movement_state == :standing
    assert state.walk_fail_count == 1
  end

  test "a mob inside the band walks out of it west and south" do
    mob = start_mob_session(map_name: @map, position: {5, 5}, awake: false)

    {:noreply, state} = MovementHandler.handle_move_to(mob.mob_state, 1, 1)
    {state, _positions} = drive(state)

    assert {state.x, state.y} == {1, 1}
    assert state.walk_fail_count == 0
  end

  test "a mob inside the band cannot step east or north" do
    mob = start_mob_session(map_name: @map, position: {5, 5}, awake: false)

    state =
      Enum.reduce([{10, 5}, {5, 10}, {10, 10}], mob.mob_state, fn {gx, gy}, acc ->
        {:noreply, acc} = MovementHandler.handle_move_to(acc, gx, gy)
        {acc, positions} = drive(acc)
        assert Enum.all?(positions, &(&1 == {5, 5}))
        acc
      end)

    assert state.walk_fail_count == 3
  end

  test "player-profile pathing crosses the band freely" do
    map_data = MapCache.get!(@map)

    assert {:ok, player_path} = Pathfinding.find_path(map_data, {0, 0}, {9, 9})
    assert Enum.any?(player_path, fn {x, y} -> Cell.icewall?(@map, x, y) end)
  end

  test "clearing the band releases a held mob" do
    mob = start_mob_session(map_name: @map, position: {5, 5}, awake: false)

    {:noreply, state} = MovementHandler.handle_move_to(mob.mob_state, 10, 10)
    {state, _} = drive(state)
    assert {state.x, state.y} == {5, 5}

    :ok = ScriptCells.set(@map, {4, 4}, {7, 7}, :icewall, 0)

    {:noreply, state} = MovementHandler.handle_move_to(state, 10, 10)
    {state, _positions} = drive(state)

    assert {state.x, state.y} == {10, 10}
  end

  defp drive(state, max_ticks \\ 100) do
    {state, positions} = drive_ticks(state, [{state.x, state.y}], max_ticks)
    {state, Enum.reverse(positions)}
  end

  defp drive_ticks(%{movement_state: :standing} = state, positions, _remaining),
    do: {state, positions}

  defp drive_ticks(_state, _positions, 0),
    do: flunk("mob did not stop moving within the tick budget")

  defp drive_ticks(state, positions, remaining) do
    {:noreply, next} = MovementHandler.handle_movement_tick(state)
    drive_ticks(next, [{next.x, next.y} | positions], remaining - 1)
  end
end
