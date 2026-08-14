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
    # A synthetic walkable 12x12 map with a 4x4 icewall band in the middle.
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 12, 12)})
    :ok = ScriptCells.set(@map, {4, 4}, {7, 7}, :icewall, 1)
    :ok
  end

  test "a mob inside the band stays penned across path requests and ticks" do
    mob = start_mob_session(map_name: @map, position: {5, 5}, awake: false)

    # The mob can wander within the band.
    {:noreply, state} = MovementHandler.handle_move_to(mob.mob_state, 6, 6)
    {state, in_band_positions} = drive(state)
    assert {state.x, state.y} == {6, 6}
    assert Enum.all?(in_band_positions, fn {x, y} -> Cell.icewall?(@map, x, y) end)

    # Repeated requests toward outside goals cannot take it out of the band.
    state =
      Enum.reduce([{0, 0}, {11, 11}, {0, 11}, {11, 0}], state, fn {gx, gy}, acc ->
        {:noreply, acc} = MovementHandler.handle_move_to(acc, gx, gy)
        {acc, positions} = drive(acc)
        assert Enum.all?(positions, fn {x, y} -> Cell.icewall?(@map, x, y) end)
        acc
      end)

    assert Cell.icewall?(@map, state.x, state.y)
  end

  test "a mob outside the band detours around it and never enters" do
    map_data = MapCache.get!(@map)

    assert {:ok, mob_path} = Pathfinding.find_path(map_data, {1, 1}, {9, 9}, profile: :mob)
    refute Enum.any?(mob_path, fn {x, y} -> Cell.icewall?(@map, x, y) end)

    mob = start_mob_session(map_name: @map, position: {1, 1}, awake: false)
    {:noreply, state} = MovementHandler.handle_move_to(mob.mob_state, 9, 9)
    {state, positions} = drive(state)

    assert {state.x, state.y} == {9, 9}
    refute Enum.any?(positions, fn {x, y} -> Cell.icewall?(@map, x, y) end)
  end

  test "player-profile pathing crosses the band freely" do
    map_data = MapCache.get!(@map)

    assert {:ok, player_path} = Pathfinding.find_path(map_data, {0, 0}, {9, 9})
    assert Enum.any?(player_path, fn {x, y} -> Cell.icewall?(@map, x, y) end)
  end

  test "clearing the band releases a penned mob" do
    map_data = MapCache.get!(@map)

    assert {:error, :no_path} = Pathfinding.find_path(map_data, {5, 5}, {0, 0}, profile: :mob)

    mob = start_mob_session(map_name: @map, position: {5, 5}, awake: false)

    # Penned while the band is up: the request cannot produce a path out.
    {:noreply, state} = MovementHandler.handle_move_to(mob.mob_state, 0, 0)
    {state, _} = drive(state)
    assert Cell.icewall?(@map, state.x, state.y)

    # Clearing the band frees the same mob.
    :ok = ScriptCells.set(@map, {4, 4}, {7, 7}, :icewall, 0)

    {:noreply, state} = MovementHandler.handle_move_to(state, 0, 0)
    {state, positions} = drive(state)

    assert {state.x, state.y} == {0, 0}
    refute Enum.any?(positions, fn {x, y} -> Cell.icewall?(@map, x, y) end)
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
