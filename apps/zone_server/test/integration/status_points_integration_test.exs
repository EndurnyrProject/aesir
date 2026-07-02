defmodule Aesir.ZoneServer.Integration.StatusPointsIntegrationTest do
  @moduledoc """
  Drives the real session path for status points: leveling up grants points,
  and a StatUp request spends them.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.StatusParams
  alias Aesir.Net.MapLoaded
  alias Aesir.Net.ParamChange
  alias Aesir.Net.StatUp
  alias Aesir.Net.StatUpResult
  alias Aesir.ZoneServer.Mmo.JobManagement

  describe "leveling up" do
    test "grants the table's status points on a base level-up" do
      player = start_player_session(id: 8101, base_level: 1, status_point: 0)
      {:ok, req} = JobManagement.get_base_exp(:novice, 1)

      flush_packets()
      send(player.pid, {:mob_killed, %{base_exp: req, job_exp: 0, mob_level: 1}})

      status_point_id = StatusParams.status_point()
      assert_receive {:packet_sent, %ParamChange{var_id: ^status_point_id, value: 3}, _}, 1_000

      progression = get_player_state(player.pid).stats.progression
      assert progression.base_level == 2
      assert progression.status_point == 3
    end
  end

  describe "map enter" do
    test "sends the status-point balance and per-stat cost indicators" do
      player = start_player_session(id: 8104, str: 5, status_point: 7)
      flush_packets()

      simulate_incoming_message(player.pid, %MapLoaded{})

      status_point_id = StatusParams.status_point()
      ustr_id = StatusParams.ustr()
      assert_receive {:packet_sent, %ParamChange{var_id: ^status_point_id, value: 7}, _}, 1_000
      assert_receive {:packet_sent, %ParamChange{var_id: ^ustr_id, value: 2}, _}, 1_000
    end
  end

  describe "spending status points" do
    test "raising STR deducts the renewal cost and acks success" do
      player = start_player_session(id: 8102, str: 5, status_point: 100)
      flush_packets()

      simulate_incoming_message(player.pid, %StatUp{stat_id: 13, amount: 1})

      assert_receive {:packet_sent, %StatUpResult{stat_id: 13, ok: true, value: 6}, _}, 1_000

      state = get_player_state(player.pid)
      assert state.stats.base_stats.str == 6
      assert state.stats.progression.status_point == 98
    end

    test "rejects a raise the player cannot afford" do
      player = start_player_session(id: 8103, str: 5, status_point: 1)
      flush_packets()

      simulate_incoming_message(player.pid, %StatUp{stat_id: 13, amount: 1})

      assert_receive {:packet_sent, %StatUpResult{stat_id: 13, ok: false, value: 5}, _}, 1_000

      state = get_player_state(player.pid)
      assert state.stats.base_stats.str == 5
      assert state.stats.progression.status_point == 1
    end
  end
end
