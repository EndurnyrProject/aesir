defmodule Aesir.ZoneServer.Unit.WalkCornerTest do
  @moduledoc """
  A walk decides corner cutting when its path is built; each step re-checks
  only that the next cell is passable, plus the Ice Wall rule for monsters.
  """

  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit.HitStop
  alias Aesir.ZoneServer.Unit.Mob.Handlers.MovementHandler, as: MobMovementHandler
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "walk_corner_map"

  setup :setup_ets_tables

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 20, 20)})
    :ok
  end

  describe "path building" do
    test "an ordinary path never steps diagonally between two blocked corners" do
      block(6, 5)
      block(5, 6)

      assert {:ok, path} = Pathfinding.find_path(MapData.new(@map, 20, 20), {5, 5}, {6, 6})

      refute hd(path) == {6, 6}
      assert List.last(path) == {6, 6}

      [{5, 5} | path]
      |> Enum.zip(path)
      |> Enum.each(fn {{x, y}, {nx, ny}} ->
        if nx != x and ny != y do
          assert Cell.traversable?(@map, nx, y) and Cell.traversable?(@map, x, ny)
        end
      end)
    end

    test "an easy path steps diagonally between two blocked corners" do
      block(6, 5)
      block(5, 6)

      assert {:ok, [{6, 6}, {7, 7}]} =
               Pathfinding.find_path(MapData.new(@map, 20, 20), {5, 5}, {7, 7}, easy: true)
    end

    test "a path crosses icewall cells" do
      for y <- 0..19, do: :ok = Cell.put_traits(@map, 10, y, :npc_script, 0, icewall: true)

      assert {:ok, path} = Pathfinding.find_path(MapData.new(@map, 20, 20), {8, 5}, {12, 5})
      assert {10, 5} in path
    end
  end

  describe "player step" do
    test "an ordinary walk steps diagonally between corners blocked after its path was built" do
      state = walking_player([{6, 6}, {7, 7}])
      block(6, 5)
      block(5, 6)

      {:noreply, stepped} = MovementHandler.handle_movement_tick(state)

      assert {stepped.game_state.x, stepped.game_state.y} == {6, 6}
      assert stepped.game_state.walk_path == [{7, 7}]
    end

    test "a hit stop finishes a diagonal step between two blocked corners" do
      state = walking_player([{6, 6}, {7, 7}])
      block(6, 5)
      block(5, 6)
      state = put_in(state.game_state.pending_step, {HitStop.now() - 1, 200, make_ref()})

      {:noreply, stopped} = MovementHandler.handle_hit_stop(state)

      assert {stopped.game_state.x, stopped.game_state.y} == {6, 6}
      assert stopped.game_state.movement_state == :standing
    end
  end

  describe "mob step" do
    test "an ordinary walk steps diagonally between corners blocked after its path was built" do
      state = walking_mob([{6, 6}])
      block(6, 5)
      block(5, 6)

      {:noreply, stepped} = MobMovementHandler.handle_movement_tick(state)

      assert {stepped.x, stepped.y} == {6, 6}
    end

    test "a hit stop finishes a diagonal step between two blocked corners" do
      state = %{
        walking_mob([{6, 6}, {7, 7}])
        | pending_step: {HitStop.now() - 1, 200, make_ref()}
      }

      block(6, 5)
      block(5, 6)

      stopped = MobMovementHandler.handle_hit_stop(state)

      assert {stopped.x, stopped.y} == {6, 6}
      assert stopped.movement_state == :standing
    end

    test "a mob on an icewall cell cannot step east, counts the failure and drops its target" do
      icewall(5, 5)
      state = %{walking_mob([{6, 5}]) | target_ref: {:player, 7}}

      {:noreply, held} = MobMovementHandler.handle_movement_tick(state)

      assert {held.x, held.y} == {5, 5}
      assert held.movement_state == :standing
      assert held.walk_fail_count == 1
      assert held.target_ref == nil
    end

    test "a mob on an icewall cell cannot step north" do
      icewall(5, 5)

      {:noreply, held} = MobMovementHandler.handle_movement_tick(walking_mob([{5, 6}]))

      assert {held.x, held.y} == {5, 5}
      assert held.walk_fail_count == 1
    end

    test "a mob on an icewall cell steps west and south" do
      icewall(5, 5)

      {:noreply, west} = MobMovementHandler.handle_movement_tick(walking_mob([{4, 5}]))
      assert {west.x, west.y} == {4, 5}

      {:noreply, south} = MobMovementHandler.handle_movement_tick(walking_mob([{5, 4}]))
      assert {south.x, south.y} == {5, 4}
    end

    test "after 75 held steps the mob leaves the icewall and its count resets" do
      icewall(5, 5)
      state = %{walking_mob([{6, 5}]) | walk_fail_count: 74}

      {:noreply, held} = MobMovementHandler.handle_movement_tick(state)
      assert {held.x, held.y} == {5, 5}
      assert held.walk_fail_count == 75

      {:noreply, stepped} =
        MobMovementHandler.handle_movement_tick(%{
          held
          | walk_path: [{6, 5}],
            movement_state: :moving
        })

      assert {stepped.x, stepped.y} == {6, 5}
      assert stepped.walk_fail_count == 0
    end

    test "a status-immune mob leaves an icewall cell in any direction" do
      icewall(5, 5)

      {:noreply, stepped} =
        MobMovementHandler.handle_movement_tick(walking_mob([{6, 5}], [:status_immune]))

      assert {stepped.x, stepped.y} == {6, 5}
      assert stepped.walk_fail_count == 0
    end

    test "a walking mob enters a blocking icewall cell from the west" do
      ice_wall(6, 5)

      {:noreply, stepped} = MobMovementHandler.handle_movement_tick(walking_mob([{6, 5}, {7, 5}]))

      assert {stepped.x, stepped.y} == {6, 5}
    end

    test "a walking mob re-paths around a blocking icewall cell from the east" do
      ice_wall(4, 5)

      {:noreply, repathed} =
        MobMovementHandler.handle_movement_tick(walking_mob([{4, 5}, {3, 5}]))

      assert {repathed.x, repathed.y} == {5, 5}
      refute {4, 5} in repathed.walk_path
    end

    test "a status-immune mob re-paths around a blocking icewall cell from the west" do
      ice_wall(6, 5)

      {:noreply, repathed} =
        MobMovementHandler.handle_movement_tick(walking_mob([{6, 5}, {7, 5}], [:status_immune]))

      assert {repathed.x, repathed.y} == {5, 5}
      refute {6, 5} in repathed.walk_path
    end

    test "a hit stop's finishing step obeys the icewall hold" do
      icewall(5, 5)

      state = %{
        walking_mob([{6, 5}, {7, 5}])
        | pending_step: {HitStop.now() - 1, 200, make_ref()},
          target_ref: {:player, 7}
      }

      stopped = MobMovementHandler.handle_hit_stop(state)

      assert {stopped.x, stopped.y} == {5, 5}
      assert stopped.walk_fail_count == 1
      assert stopped.target_ref == nil
    end
  end

  defp block(x, y) do
    :ok = Cell.put(@map, x, y, :barrier, x * 1_000 + y, blocks_movement: true)
  end

  defp icewall(x, y), do: :ok = Cell.put_traits(@map, x, y, :npc_script, 0, icewall: true)

  defp ice_wall(x, y) do
    :ok = Cell.put(@map, x, y, :skill_unit, x * 1_000 + y, blocks_movement: true, icewall: true)
  end

  defp walking_player(path) do
    game_state = %{
      PlayerState.new(character())
      | walk_path: path,
        movement_state: :moving
    }

    UnitRegistry.register_unit(:player, game_state.character_id, MovementHandler, game_state, nil)
    SpatialIndex.add_unit(:player, game_state.character_id, 5, 5, @map)
    %{game_state: game_state, connection_pid: self()}
  end

  defp walking_mob(path, modes \\ []) do
    mob_data = %MobDefinition{
      id: 1002,
      aegis_name: "PORING",
      name: "Poring",
      level: 3,
      hp: 60,
      sp: 0,
      atk: 7,
      matk: 0,
      def: 0,
      mdef: 5,
      stats: %{str: 1, agi: 1, vit: 1, int: 0, dex: 6, luk: 30},
      attack_range: 1,
      skill_range: 10,
      chase_range: 12,
      element: {:water, 1},
      race: :plant,
      size: :medium,
      walk_speed: 200,
      attack_delay: 1_000,
      attack_motion: 672,
      client_attack_motion: 500,
      damage_motion: 480,
      ai_type: 0,
      modes: modes,
      drops: []
    }

    SpatialIndex.add_unit(:mob, 42, 5, 5, @map)

    %MobState{
      instance_id: 42,
      mob_id: mob_data.id,
      mob_data: mob_data,
      spawn_ref: nil,
      map_name: @map,
      x: 5,
      y: 5,
      dir: 0,
      hp: mob_data.hp,
      max_hp: mob_data.hp,
      sp: 0,
      max_sp: 0,
      spawned_at: System.system_time(:second),
      walk_speed: mob_data.walk_speed,
      view_range: 12,
      is_dead: false,
      walk_path: path,
      movement_state: :moving
    }
  end

  defp character do
    %Character{
      id: 1001,
      account_id: 100,
      name: "Walker",
      last_map: @map,
      last_x: 5,
      last_y: 5,
      sex: "M",
      hair: 1,
      hair_color: 0,
      clothes_color: 0,
      head_mid: 0,
      head_bottom: 0,
      robe: 0,
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 1,
      job_level: 1,
      class: 0
    }
  end
end
