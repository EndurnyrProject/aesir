defmodule Aesir.ZoneServer.Unit.Session.MotionTest do
  @moduledoc """
  Shared knockback-landing behavior, exercised through both real adapters.

  Locks the body that used to be copy-pasted across the player and mob
  sessions: the in-flight walk is cleared, the landing cell is written, and the
  new position is published through `Aesir.ZoneServer.Unit.Movement.set_position/4`
  - in that order, so the published snapshot never shows a unit still mid-walk
  at its old cell.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.SessionAdapter, as: MobAdapter
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionAdapter, as: PlayerAdapter
  alias Aesir.ZoneServer.Unit.Session.Motion

  setup :verify_on_exit!

  describe "knocked_back/4" do
    test "player lands at the cell, stops moving, and publishes the standing snapshot" do
      state = player_moving_state()
      test_pid = self()

      expect(Movement, :set_position, fn :player, 1, published, "prontera" ->
        assert published.movement_state == :standing
        assert published.walk_path == []
        send(test_pid, {:published, published.x, published.y})
        :ok
      end)

      landed = Motion.knocked_back(state, 160, 170, PlayerAdapter)

      assert landed.game_state.x == 160
      assert landed.game_state.y == 170
      assert landed.game_state.movement_state == :standing
      assert landed.game_state.walk_path == []
      assert_received {:published, 160, 170}
    end

    test "mob lands at the cell, stops moving, and publishes the standing snapshot" do
      state = mob_moving_state()
      test_pid = self()

      expect(Movement, :set_position, fn :mob, 9001, published, "prontera" ->
        assert published.movement_state == :standing
        assert published.walk_path == []
        send(test_pid, {:published, published.x, published.y})
        :ok
      end)

      landed = Motion.knocked_back(state, 160, 170, MobAdapter)

      assert landed.x == 160
      assert landed.y == 170
      assert landed.movement_state == :standing
      assert landed.walk_path == []
      assert_received {:published, 160, 170}
    end
  end

  # Builders -----------------------------------------------------------------

  defp player_moving_state do
    game_state = %{
      PlayerState.new(character())
      | movement_state: :moving,
        walk_path: [{151, 150}, {152, 150}]
    }

    %{game_state: game_state, connection_pid: self()}
  end

  defp character do
    %Character{
      id: 1,
      account_id: 100,
      name: "Motion",
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      class: 0,
      base_level: 50,
      job_level: 50,
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 7
    }
  end

  defp mob_moving_state do
    %MobState{
      instance_id: 9001,
      mob_id: 1002,
      mob_data: mob_definition(),
      spawn_ref: mob_spawn(),
      x: 150,
      y: 150,
      map_name: "prontera",
      movement_state: :moving,
      walk_path: [{151, 150}, {152, 150}],
      hp: 100,
      max_hp: 100,
      sp: 50,
      max_sp: 50,
      spawned_at: System.system_time(:second)
    }
  end

  defp mob_definition do
    %MobDefinition{
      id: 1002,
      aegis_name: "PORING",
      name: "Poring",
      level: 1,
      hp: 100,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 6, luk: 5},
      attack_range: 1,
      size: :medium,
      race: :plant,
      element: {:water, 1},
      walk_speed: 400,
      attack_delay: 1000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 400
    }
  end

  defp mob_spawn do
    %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %MobSpawn.SpawnArea{x: 150, y: 150, xs: 0, ys: 0}
    }
  end
end
