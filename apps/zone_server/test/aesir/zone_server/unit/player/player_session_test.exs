defmodule Aesir.ZoneServer.Unit.Player.PlayerSessionTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.SpatialIndex

  # Test helper GenServer for receiving cast messages
  defmodule TestPlayerSession do
    use GenServer

    def init(test_pid) do
      {:ok, test_pid}
    end

    def handle_cast({:send_packet, packet}, test_pid) do
      send(test_pid, {:vanish_packet, packet})
      {:noreply, test_pid}
    end
  end

  setup do
    Mimic.copy(SpatialIndex)
    Mimic.copy(Stats)
    Mimic.copy(MapCache)
    Mimic.copy(Pathfinding)

    :ok
  end

  setup :verify_on_exit!
  setup :set_mimic_global

  setup do
    SpatialIndex.init()

    character = %Character{
      id: 1,
      account_id: 100,
      name: "TestPlayer",
      last_map: "prontera",
      last_x: 50,
      last_y: 50,
      class: 1,
      base_level: 99,
      job_level: 50,
      sex: "M",
      head_top: 1,
      head_mid: 0,
      head_bottom: 0,
      hair_color: 0,
      clothes_color: 0,
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10
    }

    {:ok, character: character}
  end

  describe "init/1" do
    test "initializes player session with correct state", %{character: character} do
      connection_pid = self()

      {:ok, state} =
        PlayerSession.init(%{
          character: character,
          connection_pid: connection_pid
        })

      assert state.character == character
      assert state.connection_pid == connection_pid
      assert state.game_state.x == 50
      assert state.game_state.y == 50
      assert state.game_state.map_name == "prontera"
      assert state.game_state.movement_state == :just_spawned
      assert state.game_state.walk_speed == 150
      assert state.game_state.view_range == 14

      assert [{1, _, 100}] = :ets.lookup(:zone_players, 1)
    end

    test "sends spawn_player message on init", %{character: character} do
      connection_pid = self()

      {:ok, _state} =
        PlayerSession.init(%{
          character: character,
          connection_pid: connection_pid
        })

      assert_receive :spawn_player, 100
    end
  end

  describe "handle_info(:spawn_player)" do
    test "adds player to spatial index and checks visibility", %{character: character} do
      expect(SpatialIndex, :add_player, fn 1, 50, 50, "prontera" -> :ok end)
      expect(SpatialIndex, :get_players_in_range, fn "prontera", 50, 50, 14 -> [] end)

      game_state = PlayerState.new(character)

      state = %{
        character: character,
        game_state: game_state,
        connection_pid: self()
      }

      {:noreply, new_state} = PlayerSession.handle_info(:spawn_player, state)

      assert new_state.character == character
      assert_receive :complete_spawn, 200
    end
  end

  describe "handle_info(:complete_spawn)" do
    test "transitions from just_spawned to standing", %{character: character} do
      game_state = PlayerState.new(character)

      state = %{
        character: character,
        game_state: game_state,
        connection_pid: self()
      }

      {:noreply, new_state} = PlayerSession.handle_info(:complete_spawn, state)

      assert new_state.game_state.movement_state == :standing
    end
  end

  describe "movement handling" do
    test "request_move calculates path and starts movement", %{character: character} do
      expect(MapCache, :get, fn "prontera" ->
        {:ok, %{width: 200, height: 200}}
      end)

      expect(Pathfinding, :find_path, fn _map_data, {50, 50}, {60, 60} ->
        {:ok,
         [
           {51, 50},
           {52, 50},
           {53, 50},
           {54, 50},
           {55, 50},
           {56, 50},
           {57, 50},
           {58, 50},
           {59, 50},
           {60, 60}
         ]}
      end)

      game_state = PlayerState.new(character)

      state = %{
        character: character,
        game_state: game_state,
        connection_pid: self()
      }

      {:noreply, new_state} =
        PlayerSession.handle_cast(
          {:request_move, 60, 60},
          state
        )

      assert new_state.game_state.is_walking == true
      assert length(new_state.game_state.walk_path) > 0
      assert new_state.game_state.movement_state == :moving

      assert_receive {:send_packet, _packet}
    end

    test "movement_tick updates position along path", %{character: character} do
      expect(SpatialIndex, :update_position, fn 1, 51, 50, "prontera" -> :ok end)
      expect(SpatialIndex, :get_players_in_range, fn "prontera", 51, 50, 14 -> [] end)

      game_state = %{
        PlayerState.new(character)
        | is_walking: true,
          walk_path: [{51, 50}, {52, 50}, {53, 50}],
          walk_start_time: System.system_time(:millisecond) - 200,
          walk_speed: 150,
          path_progress: 0,
          movement_state: :moving
      }

      state = %{
        character: character,
        game_state: game_state,
        connection_pid: self()
      }

      {:noreply, new_state} = PlayerSession.handle_info(:movement_tick, state)

      assert new_state.game_state.x == 51
      assert new_state.game_state.y == 50
      assert length(new_state.game_state.walk_path) == 2
    end

    test "force_stop_movement stops walking and sends packet", %{character: character} do
      game_state = %{
        PlayerState.new(character)
        | is_walking: true,
          walk_path: [{51, 50}, {52, 50}],
          movement_state: :moving
      }

      state = %{
        character: character,
        game_state: game_state,
        connection_pid: self()
      }

      {:noreply, new_state} = PlayerSession.handle_cast(:force_stop_movement, state)

      assert new_state.game_state.is_walking == false
      assert new_state.game_state.walk_path == []
      assert new_state.game_state.movement_state == :standing

      assert_receive {:send_packet, %Aesir.ZoneServer.Packets.ZcNotifyMoveStop{}}
    end
  end

  describe "visibility system" do
    test "player_entered_view requests player info", %{character: character} do
      other_pid = spawn(fn -> :timer.sleep(1000) end)
      :ets.insert(:zone_players, {2, other_pid, 200})

      state = %{
        character: character,
        game_state: PlayerState.new(character),
        connection_pid: self()
      }

      {:noreply, _new_state} = PlayerSession.handle_cast({:player_entered_view, 2}, state)

      Process.exit(other_pid, :kill)
    end

    test "player_left_view sends vanish packet", %{character: character} do
      state = %{
        character: character,
        game_state: PlayerState.new(character),
        connection_pid: self()
      }

      {:noreply, _new_state} =
        PlayerSession.handle_cast(
          {:player_left_view, 2, 200},
          state
        )

      assert_receive {:send_packet,
                      %Aesir.ZoneServer.Packets.ZcNotifyVanish{
                        gid: 200,
                        type: 0
                      }}
    end

    test "request_player_info sends back player information", %{character: character} do
      requester_pid = self()
      game_state = PlayerState.new(character)

      state = %{
        character: character,
        game_state: game_state,
        connection_pid: self()
      }

      {:noreply, _new_state} =
        PlayerSession.handle_cast(
          {:request_player_info, requester_pid, 2},
          state
        )

      assert_receive {:"$gen_cast", {:player_info_response, info, 1}}
      assert info.character == character
      assert info.game_state == game_state
    end

    test "player_info_response sends spawn packet", %{character: character} do
      other_character = %{character | id: 2, account_id: 200, name: "OtherPlayer"}

      other_game_state = %{
        PlayerState.new(other_character)
        | movement_state: :standing
      }

      player_info = %{
        character: other_character,
        game_state: other_game_state,
        movement_state: :standing,
        is_walking: false,
        walk_path: []
      }

      state = %{
        character: character,
        game_state: PlayerState.new(character),
        connection_pid: self()
      }

      {:noreply, _new_state} =
        PlayerSession.handle_cast(
          {:player_info_response, player_info, 2},
          state
        )

      assert_receive {:send_packet,
                      %Aesir.ZoneServer.Packets.ZcNotifyStandentry{
                        aid: 200,
                        gid: 2,
                        name: "OtherPlayer"
                      }}
    end
  end

  describe "stats management" do
    test "update_base_stat recalculates and sends updates", %{character: character} do
      expect(Stats, :calculate_stats, fn stats, player_id ->
        assert player_id == character.id
        %{stats | base_stats: %{stats.base_stats | str: 20}}
      end)

      game_state = PlayerState.new(character)

      state = %{
        character: character,
        game_state: game_state,
        connection_pid: self()
      }

      {:reply, :ok, new_state} =
        PlayerSession.handle_call(
          {:update_base_stat, :str, 20},
          {self(), make_ref()},
          state
        )

      assert new_state.game_state.stats.base_stats.str == 20

      assert_receive {:send_packet, _packet}
    end

    test "sync recalculate_stats via call updates all stats", %{character: character} do
      expect(Stats, :calculate_stats, fn stats, player_id ->
        assert player_id == character.id
        stats
      end)

      game_state = PlayerState.new(character)

      state = %{
        character: character,
        game_state: game_state,
        connection_pid: self()
      }

      {:reply, stats, _new_state} =
        PlayerSession.handle_call(
          :recalculate_stats,
          {self(), make_ref()},
          state
        )

      assert stats == game_state.stats
    end

    test "async recalculate_stats via cast updates stats", %{character: character} do
      expect(Stats, :calculate_stats, fn stats, player_id ->
        assert player_id == character.id

        %{
          stats
          | base_stats: %{stats.base_stats | str: 25},
            derived_stats: %{stats.derived_stats | max_hp: 500}
        }
      end)

      game_state = PlayerState.new(character)

      state = %{
        character: character,
        game_state: game_state,
        connection_pid: self()
      }

      {:noreply, new_state} =
        PlayerSession.handle_cast(
          :recalculate_stats,
          state
        )

      assert new_state.game_state.stats.base_stats.str == 25
      assert new_state.game_state.stats.derived_stats.max_hp == 500

      # Verify stats updates are sent to client
      assert_receive {:send_packet, _packet}
    end

    test "get_current_stats returns stats", %{character: character} do
      game_state = PlayerState.new(character)

      state = %{
        character: character,
        game_state: game_state,
        connection_pid: self()
      }

      {:reply, stats, _new_state} =
        PlayerSession.handle_call(
          :get_current_stats,
          {self(), make_ref()},
          state
        )

      assert stats == game_state.stats
    end
  end

  describe "packet handling" do
    test "send_packet forwards packet to connection", %{character: character} do
      packet = %Aesir.ZoneServer.Packets.ZcNotifyTime{server_tick: 12_345}

      state = %{
        character: character,
        game_state: PlayerState.new(character),
        connection_pid: self()
      }

      {:noreply, _new_state} =
        PlayerSession.handle_cast(
          {:send_packet, packet},
          state
        )

      assert_receive {:send_packet, ^packet}
    end

    test "send_status_update sends correct packet type", %{character: character} do
      state = %{
        character: character,
        game_state: PlayerState.new(character),
        connection_pid: self()
      }

      # Test regular param (uses ZcParChange)
      {:noreply, _} =
        PlayerSession.handle_cast(
          # STR param
          {:send_status_update, 13, 100},
          state
        )

      assert_receive {:send_packet, %Aesir.ZoneServer.Packets.ZcParChange{}}

      # Test experience param (uses ZcLongparChange)
      {:noreply, _} =
        PlayerSession.handle_cast(
          {:send_status_update, 1, 999_999},
          state
        )

      assert_receive {:send_packet, %Aesir.ZoneServer.Packets.ZcLongparChange{}}
    end

    test "send_status_updates sends multiple updates", %{character: character} do
      state = %{
        character: character,
        game_state: PlayerState.new(character),
        connection_pid: self()
      }

      status_map = %{
        # STR
        13 => 20,
        # AGI
        14 => 15,
        # VIT
        15 => 10
      }

      {:noreply, _} =
        PlayerSession.handle_cast(
          {:send_status_updates, status_map},
          state
        )

      assert_receive {:send_packet, %Aesir.ZoneServer.Packets.ZcParChange{}}
      assert_receive {:send_packet, %Aesir.ZoneServer.Packets.ZcParChange{}}
      assert_receive {:send_packet, %Aesir.ZoneServer.Packets.ZcParChange{}}
    end
  end

  describe "terminate/2" do
    test "cleans up ETS entries and notifies connection", %{character: character} do
      :ets.insert(:zone_players, {1, self(), 100})

      expect(SpatialIndex, :get_visible_players, fn 1 -> [] end)
      expect(SpatialIndex, :remove_player, fn 1 -> :ok end)
      expect(SpatialIndex, :clear_visibility, fn 1 -> :ok end)

      state = %{
        character: character,
        game_state: PlayerState.new(character),
        connection_pid: self()
      }

      :ok = PlayerSession.terminate(:normal, state)

      assert :ets.lookup(:zone_players, 1) == []
      assert_receive :player_session_terminated
    end

    test "handles dead connection process gracefully", %{character: character} do
      expect(SpatialIndex, :remove_player, fn 1 -> :ok end)
      expect(SpatialIndex, :clear_visibility, fn 1 -> :ok end)
      expect(SpatialIndex, :get_visible_players, fn 1 -> [] end)

      dead_pid = spawn(fn -> :ok end)
      Process.exit(dead_pid, :kill)
      :timer.sleep(10)

      state = %{
        character: character,
        game_state: PlayerState.new(character),
        connection_pid: dead_pid
      }

      :ok = PlayerSession.terminate(:normal, state)
    end

    test "broadcasts vanish packet to visible players on disconnect", %{character: character} do
      # Create a test GenServer that will act as another player session
      test_pid = self()

      {:ok, other_pid} =
        GenServer.start_link(
          __MODULE__.TestPlayerSession,
          test_pid,
          []
        )

      :ets.insert(:zone_players, {2, other_pid, 200})

      # Set up expectations for SpatialIndex
      expect(SpatialIndex, :get_visible_players, fn 1 -> [2] end)
      expect(SpatialIndex, :remove_player, fn 1 -> :ok end)
      expect(SpatialIndex, :clear_visibility, fn 1 -> :ok end)

      state = %{
        character: character,
        game_state: PlayerState.new(character),
        connection_pid: self()
      }

      # Call terminate directly to test the broadcast
      :ok = PlayerSession.terminate(:normal, state)

      # Verify vanish packet was sent to the other player
      assert_receive {:vanish_packet,
                      %Aesir.ZoneServer.Packets.ZcNotifyVanish{
                        # account_id
                        gid: 100,
                        # logged_out type
                        type: 2
                      }},
                     500

      assert_receive :player_session_terminated

      # Stop the test GenServer
      GenServer.stop(other_pid, :normal)
    end
  end

  describe "edge cases" do
    test "handles movement when path is empty", %{character: character} do
      game_state = %{
        PlayerState.new(character)
        | is_walking: true,
          walk_path: [],
          movement_state: :moving
      }

      state = %{
        character: character,
        game_state: game_state,
        connection_pid: self()
      }

      {:noreply, new_state} = PlayerSession.handle_info(:movement_tick, state)

      assert new_state.game_state.is_walking == false
      assert new_state.game_state.movement_state == :standing
    end

    test "handles packet send when connection_pid is nil", %{character: character} do
      packet = %Aesir.ZoneServer.Packets.ZcNotifyTime{server_tick: 12_345}

      state = %{
        character: character,
        game_state: PlayerState.new(character),
        connection_pid: nil
      }

      {:noreply, _new_state} =
        PlayerSession.handle_cast(
          {:send_packet, packet},
          state
        )

      refute_receive {:send_packet, _}
    end

    test "handles visibility update with self in range", %{character: character} do
      expect(SpatialIndex, :get_players_in_range, fn "prontera", 50, 50, 14 ->
        [1, 2, 3]
      end)

      # Only expect visibility updates for others
      expect(SpatialIndex, :update_visibility, fn 1, 2, true -> :ok end)
      expect(SpatialIndex, :update_visibility, fn 1, 3, true -> :ok end)

      game_state = PlayerState.new(character)

      state = %{
        character: character,
        game_state: game_state,
        connection_pid: self()
      }

      {:noreply, new_state} = PlayerSession.handle_info(:spawn_player, state)

      assert MapSet.member?(new_state.game_state.visible_players, 1)
      assert MapSet.member?(new_state.game_state.visible_players, 2)
      assert MapSet.member?(new_state.game_state.visible_players, 3)
    end
  end
end
