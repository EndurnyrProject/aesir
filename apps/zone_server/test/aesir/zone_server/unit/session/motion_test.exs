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

  alias Aesir.ZoneServer.SessionFixtures
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
      PlayerState.new(SessionFixtures.character(name: "Motion"))
      | movement_state: :moving,
        walk_path: [{151, 150}, {152, 150}]
    }

    %{game_state: game_state, connection_pid: self()}
  end

  defp mob_moving_state do
    %MobState{
      instance_id: 9001,
      mob_id: 1002,
      mob_data: SessionFixtures.mob_definition(),
      spawn_ref: SessionFixtures.mob_spawn(),
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
end
