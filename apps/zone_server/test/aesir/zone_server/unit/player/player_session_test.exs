defmodule Aesir.ZoneServer.Unit.Player.PlayerSessionTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

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

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Mimic.copy(Persistence)

    stub(Persistence, :load_inventory, fn _char_id -> {:ok, []} end)

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

      assert state.game_state.character_id == character.id
      assert state.game_state.character_name == character.name
      assert state.connection_pid == connection_pid
      assert state.game_state.x == 50
      assert state.game_state.y == 50
      assert state.game_state.map_name == "prontera"
      assert state.game_state.movement_state == :standing
      assert state.game_state.walk_speed == 150
      assert state.game_state.view_range == 14

      # Verify player is registered in UnitRegistry
      assert {:ok, {_module, %{account_id: 100}, _pid}} = UnitRegistry.get_unit(:player, 1)
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

      assert new_state.game_state.movement_state == :moving
      assert length(new_state.game_state.walk_path) > 0
      assert new_state.game_state.movement_state == :moving

      assert_receive {:send, :gameplay, {:self_move, %Aesir.Net.SelfMove{}}}
    end

    test "movement_tick updates position along path", %{character: character} do
      expect(SpatialIndex, :update_position, fn 1, 51, 50, "prontera" -> :ok end)
      expect(SpatialIndex, :get_players_in_range, fn "prontera", 51, 50, 14 -> [] end)

      game_state = %{
        PlayerState.new(character)
        | walk_path: [{51, 50}, {52, 50}, {53, 50}],
          walk_speed: 150,
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
        | walk_path: [{51, 50}, {52, 50}],
          movement_state: :moving
      }

      state = %{
        character: character,
        game_state: game_state,
        connection_pid: self()
      }

      {:noreply, new_state} = PlayerSession.handle_cast(:force_stop_movement, state)

      assert new_state.game_state.movement_state == :standing
      assert new_state.game_state.walk_path == []
      assert new_state.game_state.movement_state == :standing

      assert_receive {:send, :gameplay, {:move_stop, %Aesir.Net.MoveStop{}}}
    end
  end

  describe "visibility system" do
    test "player_entered_view sends spawn packet built from the registry", %{
      character: character
    } do
      other_character = %{character | id: 2, account_id: 200, name: "OtherPlayer"}
      other_game_state = %{PlayerState.new(other_character) | movement_state: :standing}

      other_pid = spawn(fn -> Process.sleep(1000) end)
      UnitRegistry.register_player(2, 200, "OtherPlayer", other_pid)
      UnitRegistry.update_unit_state(:player, 2, other_game_state)

      state = %{
        character: character,
        game_state: PlayerState.new(character),
        connection_pid: self()
      }

      {:noreply, _new_state} = PlayerSession.handle_cast({:player_entered_view, 2}, state)

      assert_receive {:send, :world,
                      {:unit_spawn,
                       %Aesir.Net.UnitSpawn{
                         aid: 200,
                         gid: 2,
                         name: "OtherPlayer",
                         moving: false
                       }}}

      Process.exit(other_pid, :kill)
    end

    test "player_entered_view is a no-op for an unknown player", %{character: character} do
      state = %{
        character: character,
        game_state: PlayerState.new(character),
        connection_pid: self()
      }

      {:noreply, _new_state} = PlayerSession.handle_cast({:player_entered_view, 999}, state)

      refute_receive {:send, _channel, _msg}
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

      assert_receive {:send, :world,
                      {:unit_despawn,
                       %Aesir.Net.UnitDespawn{
                         gid: 2,
                         reason: 0
                       }}}
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

      assert_receive {:send, _channel, {_tag, %Aesir.Net.ParamChange{}}}
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
      assert_receive {:send, _channel, {_tag, %Aesir.Net.ParamChange{}}}
    end

    test "recalculate_stats via pubsub message updates stats", %{character: character} do
      expect(Stats, :calculate_stats, fn stats, player_id ->
        assert player_id == character.id
        %{stats | base_stats: %{stats.base_stats | str: 25}}
      end)

      game_state = PlayerState.new(character)

      state = %{
        character: character,
        game_state: game_state,
        connection_pid: self()
      }

      {:noreply, new_state} = PlayerSession.handle_info(:recalculate_stats, state)

      assert new_state.game_state.stats.base_stats.str == 25
      assert_receive {:send, _channel, {_tag, %Aesir.Net.ParamChange{}}}
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

  describe "cast lifecycle" do
    setup do
      Mimic.copy(Aesir.ZoneServer.Mmo.StatusEffect.Interpreter)
      Mimic.copy(Aesir.ZoneServer.Unit.Player.StatusSync)
      Mimic.copy(CharacterPersistence)

      stub(Aesir.ZoneServer.Unit.Player.StatusSync, :send_stat_updates, fn _conn, _stats ->
        :ok
      end)

      stub(CharacterPersistence, :update_character, fn _id, _attrs, _opts -> {:ok, %{}} end)

      :ok
    end

    test "cast_complete with a matching token runs the behavior and returns to idle", %{
      character: character
    } do
      stub(Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, :apply_status, fn :player,
                                                                            1,
                                                                            :sc_increaseagi,
                                                                            _ ->
        :ok
      end)

      stub(Stats, :calculate_stats, fn stats, 1 -> stats end)

      token = make_ref()
      state = casting_state(character, token, sp: 40)

      {:noreply, new_state} = PlayerSession.handle_info({:cast_complete, token}, state)

      assert new_state.game_state.action_state == :idle
      assert new_state.game_state.stats.current_state.sp == 40 - 18
    end

    test "cast_complete with a stale token is ignored", %{character: character} do
      reject(&Aesir.ZoneServer.Mmo.StatusEffect.Interpreter.apply_status/4)

      token = make_ref()
      state = casting_state(character, token, sp: 40)

      {:noreply, new_state} = PlayerSession.handle_info({:cast_complete, make_ref()}, state)

      assert new_state == state
      assert new_state.game_state.action_state == :casting
      assert new_state.game_state.stats.current_state.sp == 40
    end
  end

  describe "packet handling" do
    test "send_packet forwards packet to connection", %{character: character} do
      packet = %Aesir.Net.UnitDespawn{gid: character.id, reason: 0}

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

      assert_receive {:send, :world, {:unit_despawn, ^packet}}
    end

    test "send_status_update sends correct packet type", %{character: character} do
      state = %{
        character: character,
        game_state: PlayerState.new(character),
        connection_pid: self()
      }

      # Regular param emits a ParamChange.
      {:noreply, _} =
        PlayerSession.handle_cast(
          # STR param
          {:send_status_update, 13, 100},
          state
        )

      assert_receive {:send, _channel, {_tag, %Aesir.Net.ParamChange{}}}

      # The formerly-long (ZC_LONGPAR_CHANGE) experience param collapses into the
      # same ParamChange; uint64 carries the wide value without truncation.
      {:noreply, _} =
        PlayerSession.handle_cast(
          {:send_status_update, 1, 999_999},
          state
        )

      assert_receive {:send, _exp_channel, {_exp_tag, %Aesir.Net.ParamChange{value: 999_999}}}
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

      assert_receive {:send, _ch1, {_t1, %Aesir.Net.ParamChange{}}}
      assert_receive {:send, _ch2, {_t2, %Aesir.Net.ParamChange{}}}
      assert_receive {:send, _ch3, {_t3, %Aesir.Net.ParamChange{}}}
    end
  end

  describe "terminate/2" do
    setup do
      # terminate/2 persists the final position synchronously. These tests run
      # without a DB sandbox, so stub the persistence layer to avoid hitting it.
      Mimic.copy(CharacterPersistence)

      stub(CharacterPersistence, :update_position, fn _id, _x, _y, _map -> {:ok, %Character{}} end)

      :ok
    end

    test "cleans up ETS entries", %{character: character} do
      UnitRegistry.register_player(1, 100, "TestPlayer", self())

      expect(SpatialIndex, :get_visible_players, fn 1 -> [] end)
      expect(SpatialIndex, :remove_player, fn 1 -> :ok end)
      expect(SpatialIndex, :clear_visibility, fn 1 -> :ok end)

      state = %{
        character: character,
        game_state: PlayerState.new(character),
        connection_pid: self(),
        connection_monitor_ref: make_ref()
      }

      :ok = PlayerSession.terminate(:normal, state)

      assert {:error, :not_found} = UnitRegistry.get_player_pid(1)
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
        connection_pid: dead_pid,
        connection_monitor_ref: make_ref()
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

      UnitRegistry.register_player(2, 200, "TestPlayer", other_pid)

      # Set up expectations for SpatialIndex
      expect(SpatialIndex, :get_visible_players, fn 1 -> [2] end)
      expect(SpatialIndex, :remove_player, fn 1 -> :ok end)
      expect(SpatialIndex, :clear_visibility, fn 1 -> :ok end)

      state = %{
        character: character,
        game_state: PlayerState.new(character),
        connection_pid: self(),
        connection_monitor_ref: make_ref()
      }

      # Call terminate directly to test the broadcast
      :ok = PlayerSession.terminate(:normal, state)

      # Verify vanish packet was sent to the other player
      assert_receive {:vanish_packet,
                      %Aesir.Net.UnitDespawn{
                        # character_id
                        gid: 1,
                        # logged_out reason
                        reason: 2
                      }},
                     500

      # Stop the test GenServer
      GenServer.stop(other_pid, :normal)
    end

    test "handles connection process death via :DOWN message", %{character: character} do
      # Start a process that will die
      connection_pid = spawn(fn -> :timer.sleep(100) end)

      # Initialize player session
      {:ok, state} =
        PlayerSession.init(%{
          character: character,
          connection_pid: connection_pid
        })

      # Verify the monitor reference was created
      assert is_reference(state.connection_monitor_ref)
      assert state.connection_pid == connection_pid

      # Kill the connection process
      Process.exit(connection_pid, :kill)

      # Simulate receiving the :DOWN message
      {:stop, :normal, _new_state} =
        PlayerSession.handle_info(
          {:DOWN, state.connection_monitor_ref, :process, connection_pid, :killed},
          state
        )
    end
  end

  describe "edge cases" do
    test "handles movement when path is empty", %{character: character} do
      game_state = %{
        PlayerState.new(character)
        | walk_path: [],
          movement_state: :moving
      }

      state = %{
        character: character,
        game_state: game_state,
        connection_pid: self()
      }

      {:noreply, new_state} = PlayerSession.handle_info(:movement_tick, state)

      assert new_state.game_state.movement_state == :standing
      assert new_state.game_state.movement_state == :standing
    end

    test "raises when trying to send packet with nil connection_pid", %{character: character} do
      packet = %Aesir.Net.UnitDespawn{gid: character.id, reason: 0}

      state = build_state(character, nil)

      assert_raise RuntimeError, "No connection PID for player #{character.id}", fn ->
        PlayerSession.handle_cast(
          {:send_packet, packet},
          state
        )
      end
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

  defp build_state(character, connection_pid) do
    %{
      character: character,
      game_state: PlayerState.new(character),
      connection_pid: connection_pid
    }
  end

  # A player mid-cast of AL_INCAGI (id 29) on self, with the given token in the
  # cast context so the cast_complete handler can match (or reject) it.
  defp casting_state(character, token, opts) do
    sp = Keyword.fetch!(opts, :sp)
    base = PlayerState.new(character)

    stats =
      put_in(base.stats, [Access.key!(:current_state), Access.key!(:sp)], sp)

    context = %{
      skill_id: 29,
      skill_level: 1,
      target: :self,
      element: :neutral,
      started_at: 0,
      fixed_until: 0,
      total_until: 800,
      timer_ref: make_ref(),
      token: token,
      interruptible: true
    }

    game_state = %{base | action_state: :casting, state_context: context, stats: stats}

    %{
      character: character,
      game_state: game_state,
      connection_pid: self()
    }
  end
end
