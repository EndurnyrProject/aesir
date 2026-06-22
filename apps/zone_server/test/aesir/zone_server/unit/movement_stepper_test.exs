defmodule Aesir.ZoneServer.Unit.MovementStepperTest do
  @moduledoc """
  Verifies that the player and mob per-cell steppers route their position
  updates through the `Movement` choke point, so every step marks the unit
  dirty for the per-map delta-snapshot broadcaster.
  """

  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.MoveStop
  alias Aesir.ZoneServer.Map.GatType
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  @map_name "prontera"

  setup :setup_ets_tables

  describe "player stepper" do
    test "a movement tick marks the player dirty for its map" do
      game_state = %{
        PlayerState.new(character())
        | walk_path: [{51, 50}],
          movement_state: :moving
      }

      char_id = game_state.character_id

      UnitRegistry.register_unit(:player, char_id, MovementHandler, game_state, nil)
      SpatialIndex.add_unit(:player, char_id, 50, 50, @map_name)

      {:noreply, _state} = MovementHandler.handle_movement_tick(%{game_state: game_state})

      assert {:player, ^char_id, _move_state} =
               @map_name |> Movement.drain_dirty() |> find_unit(:player, char_id)
    end

    test "a blocked next cell re-paths to the destination without stepping into it" do
      block_cell(51, 50)

      game_state = %{
        PlayerState.new(character())
        | walk_path: [{51, 50}, {52, 50}],
          movement_state: :moving
      }

      char_id = game_state.character_id

      UnitRegistry.register_unit(:player, char_id, MovementHandler, game_state, nil)
      SpatialIndex.add_unit(:player, char_id, 50, 50, @map_name)

      {:noreply, new_state} =
        MovementHandler.handle_movement_tick(%{game_state: game_state, connection_pid: self()})

      assert {new_state.game_state.x, new_state.game_state.y} == {50, 50}
      assert new_state.game_state.movement_state == :moving
      assert new_state.game_state.walk_path != [{51, 50}, {52, 50}]
      refute {51, 50} in new_state.game_state.walk_path
    end

    test "a blocked next cell with no path stops the player and sends MoveStop" do
      block_cell(51, 50)

      game_state = %{
        PlayerState.new(character())
        | walk_path: [{51, 50}],
          movement_state: :moving
      }

      char_id = game_state.character_id

      UnitRegistry.register_unit(:player, char_id, MovementHandler, game_state, nil)
      SpatialIndex.add_unit(:player, char_id, 50, 50, @map_name)

      {:noreply, new_state} =
        MovementHandler.handle_movement_tick(%{game_state: game_state, connection_pid: self()})

      assert {new_state.game_state.x, new_state.game_state.y} == {50, 50}
      assert new_state.game_state.movement_state == :standing
      assert_received {:send, :gameplay, {:move_stop, %MoveStop{gid: ^char_id, x: 50, y: 50}}}

      assert {:player, ^char_id, _move_state} =
               @map_name |> Movement.drain_dirty() |> find_unit(:player, char_id)
    end
  end

  describe "mob stepper" do
    test "a movement tick marks the mob dirty for its map" do
      mob_state = %{mob_state() | walk_path: [{101, 100}], movement_state: :moving}
      instance_id = mob_state.instance_id

      SpatialIndex.add_unit(:mob, instance_id, 100, 100, @map_name)

      {:noreply, _state} = MobSession.handle_info(:movement_tick, mob_state)

      assert {:mob, ^instance_id, _move_state} =
               @map_name |> Movement.drain_dirty() |> find_unit(:mob, instance_id)
    end

    test "a blocked next cell re-paths to the destination without stepping into it" do
      block_cell(101, 100)

      mob_state = %{mob_state() | walk_path: [{101, 100}, {102, 100}], movement_state: :moving}
      instance_id = mob_state.instance_id

      SpatialIndex.add_unit(:mob, instance_id, 100, 100, @map_name)

      {:noreply, new_state} = MobSession.handle_info(:movement_tick, mob_state)

      assert {new_state.x, new_state.y} == {100, 100}
      assert new_state.movement_state == :moving
      assert new_state.walk_path != [{101, 100}, {102, 100}]
      refute {101, 100} in new_state.walk_path
    end

    test "a blocked next cell with no path stops the mob" do
      block_cell(101, 100)

      mob_state = %{mob_state() | walk_path: [{101, 100}], movement_state: :moving}
      instance_id = mob_state.instance_id

      SpatialIndex.add_unit(:mob, instance_id, 100, 100, @map_name)

      {:noreply, new_state} = MobSession.handle_info(:movement_tick, mob_state)

      assert {new_state.x, new_state.y} == {100, 100}
      assert new_state.movement_state == :standing
      assert new_state.walk_path == []

      assert {:mob, ^instance_id, _move_state} =
               @map_name |> Movement.drain_dirty() |> find_unit(:mob, instance_id)
    end
  end

  defp block_cell(x, y) do
    {:ok, map_data} = MapCache.get(@map_name)
    blocked = MapData.set_cell(map_data, x, y, GatType.wall())
    :ets.insert(table_for(:map_cache), {map_data.name, blocked})
    refute MapData.walkable?(blocked, x, y)
  end

  defp find_unit(drained, unit_type, unit_id) do
    Enum.find(drained, fn {type, id, _} -> type == unit_type and id == unit_id end)
  end

  defp mob_state do
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
      modes: [],
      drops: []
    }

    %MobState{
      instance_id: 42,
      mob_id: mob_data.id,
      mob_data: mob_data,
      spawn_ref: nil,
      map_name: @map_name,
      x: 100,
      y: 100,
      dir: 0,
      hp: mob_data.hp,
      max_hp: mob_data.hp,
      sp: 0,
      max_sp: 0,
      spawned_at: System.system_time(:second),
      walk_speed: mob_data.walk_speed,
      view_range: 12,
      is_dead: false
    }
  end

  defp character do
    %Character{
      id: 1001,
      account_id: 100,
      name: "Mover",
      last_map: @map_name,
      last_x: 50,
      last_y: 50,
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
