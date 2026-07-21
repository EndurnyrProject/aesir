defmodule Aesir.ZoneServer.Unit.KnockbackCancelWalkTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Combat.PendingWeaponHit
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  @map_name "prontera"

  describe "player knocked back while moving" do
    test "cancels the in-flight walk, stands at the landing cell, and the next tick does not move it" do
      char_id = 7001

      game_state = %PlayerState{
        character_id: char_id,
        map_name: @map_name,
        x: 50,
        y: 50,
        dir: 0,
        movement_state: :moving,
        walk_path: [{51, 50}, {52, 50}, {53, 50}],
        walk_speed: 150,
        view_range: 14,
        visible_players: MapSet.new(),
        visible_mobs: MapSet.new()
      }

      pending =
        PendingWeaponHit.new(
          make_ref(),
          {:player, char_id},
          {:mob, 9001},
          %{unit: {:player, 303}, pid: self()},
          5_000,
          3_000,
          4_200
        )

      game_state = PlayerState.put_pending_weapon_hit(game_state, pending)
      pending_id = pending.id
      assert_received {:pending_weapon_hit_offer, ^pending_id, _, _, _, _}

      UnitRegistry.register_unit(:player, char_id, PlayerState, game_state, self())
      SpatialIndex.add_player(char_id, 50, 50, @map_name)

      state = %{game_state: game_state, connection_pid: self()}

      {:noreply, knocked_state} =
        PlayerSession.handle_cast({:movement, {:knocked_back, 60, 50}}, state)

      assert knocked_state.game_state.x == 60
      assert knocked_state.game_state.y == 50
      assert knocked_state.game_state.movement_state == :standing
      assert knocked_state.game_state.walk_path == []
      assert knocked_state.game_state.pending_weapon_hit == nil
      assert_received {:pending_weapon_hit_cancelled, ^pending_id, {:offer, {:player, ^char_id}}}

      assert {:player, ^char_id, _move_state} =
               Enum.find(Movement.drain_dirty(@map_name), fn {_t, id, _ms} -> id == char_id end)

      {:noreply, after_tick} = MovementHandler.handle_movement_tick(knocked_state)

      assert after_tick.game_state.x == 60
      assert after_tick.game_state.y == 50
    end
  end

  describe "mob knocked back while moving" do
    test "cancels the in-flight walk, stands at the landing cell, and the next tick does not move it" do
      instance_id = 9001

      mob_state = %MobState{
        instance_id: instance_id,
        mob_id: 1002,
        mob_data: %{},
        spawn_ref: %{},
        x: 50,
        y: 50,
        dir: 0,
        map_name: @map_name,
        movement_state: :moving,
        walk_path: [{51, 50}, {52, 50}, {53, 50}],
        walk_speed: 150,
        view_range: 14,
        hp: 100,
        max_hp: 100,
        sp: 50,
        max_sp: 50,
        spawned_at: 0
      }

      UnitRegistry.register_unit(:mob, instance_id, MobState, mob_state, self())
      SpatialIndex.add_unit(:mob, instance_id, 50, 50, @map_name)

      {:noreply, knocked_state} =
        MobSession.handle_cast({:movement, {:knocked_back, 60, 50}}, mob_state)

      assert knocked_state.x == 60
      assert knocked_state.y == 50
      assert knocked_state.movement_state == :standing
      assert knocked_state.walk_path == []

      assert {:mob, ^instance_id, _move_state} =
               Enum.find(Movement.drain_dirty(@map_name), fn {_t, id, _ms} ->
                 id == instance_id
               end)

      {:noreply, after_tick} = MobSession.handle_info({:movement, :tick}, knocked_state)

      assert after_tick.x == 60
      assert after_tick.y == 50
    end
  end
end
