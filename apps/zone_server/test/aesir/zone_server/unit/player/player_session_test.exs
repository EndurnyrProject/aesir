defmodule Aesir.ZoneServer.Unit.Player.PlayerSessionTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Guild.State, as: GuildState
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Lifecycle
  alias Aesir.ZoneServer.Unit.Lifecycle.Event
  alias Aesir.ZoneServer.Unit.Player.Handlers.WarpHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.QuestPersistence
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.StatusPersistence
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

  defmodule ResurrectionSource do
    use GenServer

    alias Aesir.ZoneServer.Unit.Player.PlayerState
    alias Aesir.ZoneServer.Unit.SpatialIndex
    alias Aesir.ZoneServer.Unit.UnitRegistry

    def start_link(%PlayerState{} = game_state), do: GenServer.start_link(__MODULE__, game_state)

    def get_state(pid), do: GenServer.call(pid, :get_state)
    def warp(pid, map_name), do: GenServer.cast(pid, {:warp, map_name})

    @impl true
    def init(%PlayerState{} = game_state) do
      :ok = UnitRegistry.register_player(game_state, self())

      :ok =
        SpatialIndex.add_player(
          game_state.character_id,
          game_state.x,
          game_state.y,
          game_state.map_name
        )

      {:ok, game_state}
    end

    @impl true
    def handle_call(:get_state, _from, game_state),
      do: {:reply, %{game_state: game_state}, game_state}

    @impl true
    def handle_cast({:warp, map_name}, game_state) do
      :ok = SpatialIndex.remove_player(game_state.character_id)

      game_state = PlayerState.relocate(game_state, map_name, game_state.x, game_state.y)
      :ok = UnitRegistry.update_unit_state(:player, game_state.character_id, game_state)

      {:noreply, game_state}
    end

    def handle_cast(_message, game_state), do: {:noreply, game_state}
  end

  defmodule ExitingSession do
    use GenServer

    def start, do: GenServer.start(__MODULE__, :ok)

    @impl true
    def init(:ok), do: {:ok, :ok}

    @impl true
    def handle_call(_message, _from, state), do: {:stop, :shutdown, state}
  end

  defmodule ResurrectionCaller do
    use GenServer

    alias Aesir.ZoneServer.Unit.Player.PlayerSession
    alias Aesir.ZoneServer.Unit.Player.PlayerState
    alias Aesir.ZoneServer.Unit.SpatialIndex
    alias Aesir.ZoneServer.Unit.UnitRegistry

    def start_link(%PlayerState{} = game_state, target_pid),
      do: GenServer.start_link(__MODULE__, {game_state, target_pid})

    def resurrect(pid), do: GenServer.call(pid, :resurrect, 500)

    @impl true
    def init({%PlayerState{} = game_state, target_pid}) do
      :ok = UnitRegistry.register_player(game_state, self())

      :ok =
        SpatialIndex.add_player(
          game_state.character_id,
          game_state.x,
          game_state.y,
          game_state.map_name
        )

      {:ok, %{game_state: game_state, target_pid: target_pid}}
    end

    @impl true
    def handle_call(:resurrect, _from, %{game_state: game_state, target_pid: target_pid} = state) do
      {:reply, PlayerSession.resurrect(target_pid, game_state.character_id, 30), state}
    end
  end

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Mimic.copy(Persistence)
    Mimic.copy(StatusPersistence)
    Mimic.copy(QuestPersistence)

    stub(Persistence, :load_inventory, fn _char_id -> [] end)
    stub(StatusPersistence, :restore_on_spawn, fn state -> state end)
    stub(StatusPersistence, :save_statuses, fn _char_id -> :ok end)
    stub(QuestPersistence, :load_on_spawn, fn state -> state end)

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
      assert state.game_state.view_range == 20

      # Verify player is registered in UnitRegistry
      assert {:ok, {_module, %{account_id: 100}, _pid}} = UnitRegistry.get_unit(:player, 1)
    end

    test "starts with no pending skill menu", %{character: character} do
      {:ok, state} =
        PlayerSession.init(%{character: character, connection_pid: self()})

      assert state.pending_skill_menu == nil
    end

    # The pending menu is process-local session state with no ETS/DB backing, so
    # a disconnect drops it with the session rather than orphaning it (contrast
    # StatusStorage, which terminate/2 has to clean up explicitly). Disconnecting
    # with a menu open must still tear the session down cleanly.
    test "a disconnect tears down a session holding a pending skill menu", %{
      character: character
    } do
      Mimic.copy(CharacterPersistence)
      stub(CharacterPersistence, :update_position, fn _, _, _, _ -> {:ok, %Character{}} end)

      {:ok, state} = PlayerSession.init(%{character: character, connection_pid: self()})

      state = %{
        state
        | pending_skill_menu: %{skill_id: 380, kind: :SKILLS, entry_ids: [11], level: 1}
      }

      assert :ok = PlayerSession.terminate(:normal, state)
      assert {:error, :not_found} = UnitRegistry.get_unit(:player, character.id)
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

  describe "UnitRegistry.register_player/2" do
    test "stores PlayerState so get_unit_info resolves player entity info", %{
      character: character
    } do
      game_state = PlayerState.new(character)

      assert :ok = UnitRegistry.register_player(game_state, self())

      assert {:ok, {PlayerState, %PlayerState{account_id: 100}, _pid}} =
               UnitRegistry.get_unit(:player, character.id)

      # Regression: previously the player was registered under the UnitRegistry
      # module itself, so this dispatched UnitRegistry.get_entity_info/1 and
      # crashed the session with an UndefinedFunctionError.
      assert {:ok, %{entity_type: :player}} = UnitRegistry.get_unit_info(:player, character.id)
    end
  end

  describe "handle_info(:spawn_player)" do
    test "adds player to spatial index and checks visibility", %{character: character} do
      expect(SpatialIndex, :add_player, fn 1, 50, 50, "prontera" -> :ok end)
      expect(SpatialIndex, :get_players_in_range, fn "prontera", 50, 50, 20 -> [] end)

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
        PlayerSession.handle_info(
          {:message, %Aesir.Net.MoveRequest{dest_x: 60, dest_y: 60}},
          state
        )

      assert new_state.game_state.movement_state == :moving
      assert length(new_state.game_state.walk_path) > 0
      assert new_state.game_state.movement_state == :moving

      assert_receive {:send, :gameplay, {:self_move, %Aesir.Net.SelfMove{}}}
    end

    test "movement_tick updates position along path", %{character: character} do
      expect(SpatialIndex, :update_unit_position, fn :player, 1, 51, 50, "prontera" -> :ok end)
      expect(SpatialIndex, :get_players_in_range, fn "prontera", 51, 50, 20 -> [] end)

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

      {:noreply, new_state} = PlayerSession.handle_info({:movement, :movement_tick}, state)

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

      {:noreply, new_state} = PlayerSession.handle_cast({:movement, :force_stop_movement}, state)

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
      UnitRegistry.register_player(other_game_state, other_pid)

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
                         guild_id: 0,
                         guild_name: "",
                         emblem_id: 0,
                         moving: false
                       }}}

      Process.exit(other_pid, :kill)
    end

    test "player_entered_view spawn carries the unit's guild identity", %{character: character} do
      other_character = %{character | id: 2, account_id: 200, name: "OtherPlayer"}

      other_game_state = %{
        PlayerState.new(other_character)
        | movement_state: :standing,
          guild_id: 7
      }

      expect(GuildManager, :get, fn 7 ->
        {:ok, %GuildState{guild_id: 7, name: "Aesir", master_char_id: 2, emblem_id: 4}}
      end)

      other_pid = spawn(fn -> Process.sleep(1000) end)
      UnitRegistry.register_player(other_game_state, other_pid)

      state = %{
        character: character,
        game_state: PlayerState.new(character),
        connection_pid: self()
      }

      {:noreply, _new_state} = PlayerSession.handle_cast({:player_entered_view, 2}, state)

      assert_receive {:send, :world,
                      {:unit_spawn,
                       %Aesir.Net.UnitSpawn{
                         gid: 2,
                         guild_id: 7,
                         guild_name: "Aesir",
                         emblem_id: 4
                       }}}

      Process.exit(other_pid, :kill)
    end

    test "player_entered_view spawn defaults guild fields when the entry is not live", %{
      character: character
    } do
      other_character = %{character | id: 2, account_id: 200, name: "OtherPlayer"}

      other_game_state = %{
        PlayerState.new(other_character)
        | movement_state: :standing,
          guild_id: 7
      }

      expect(GuildManager, :get, fn 7 -> {:error, :not_found} end)

      other_pid = spawn(fn -> Process.sleep(1000) end)
      UnitRegistry.register_player(other_game_state, other_pid)

      state = %{
        character: character,
        game_state: PlayerState.new(character),
        connection_pid: self()
      }

      {:noreply, _new_state} = PlayerSession.handle_cast({:player_entered_view, 2}, state)

      assert_receive {:send, :world,
                      {:unit_spawn,
                       %Aesir.Net.UnitSpawn{
                         gid: 2,
                         guild_id: 7,
                         guild_name: "",
                         emblem_id: 0
                       }}}

      Process.exit(other_pid, :kill)
    end

    test "player_entered_view spawn derives appearance from the unit's equipped gear", %{
      character: character
    } do
      # Ribbon (2208) is a head_top with sprite view 17; Adventurer's Backpack
      # (2576) is a garment with view 2. accessory3 used to be hardcoded 0 and
      # robe came from a stale character field; both must now reflect the gear.
      equipment =
        Stats.equipment_from_inventory([
          %InventoryItem{nameid: 2208, equip: 0x100},
          %InventoryItem{nameid: 2576, equip: 0x004}
        ])

      other_character = %{character | id: 2, account_id: 200, name: "OtherPlayer"}
      base = %{PlayerState.new(other_character) | movement_state: :standing}
      other_game_state = %{base | stats: %{base.stats | equipment: equipment}}

      other_pid = spawn(fn -> Process.sleep(1000) end)
      UnitRegistry.register_player(other_game_state, other_pid)

      state = %{
        character: character,
        game_state: PlayerState.new(character),
        connection_pid: self()
      }

      {:noreply, _new_state} = PlayerSession.handle_cast({:player_entered_view, 2}, state)

      assert_receive {:send, :world,
                      {:unit_spawn,
                       %Aesir.Net.UnitSpawn{
                         gid: 2,
                         accessory3: 17,
                         robe: 2
                       }}}

      Process.exit(other_pid, :kill)
    end

    test "player_entered_view carries the unit's sprite-state aggregate in the spawn", %{
      character: character
    } do
      stub(StatusDisplay, :spawn_state, fn :player, 2 ->
        %{body_state: 3, health_state: 5, effect_state: 9, virtue: 7}
      end)

      stub(StatusDisplay, :active_icons, fn :player, 2 -> [] end)

      other_character = %{character | id: 2, account_id: 200, name: "OtherPlayer"}
      other_game_state = %{PlayerState.new(other_character) | movement_state: :standing}

      other_pid = spawn(fn -> Process.sleep(1000) end)
      UnitRegistry.register_player(other_game_state, other_pid)

      state = %{
        character: character,
        game_state: PlayerState.new(character),
        connection_pid: self()
      }

      {:noreply, _new_state} = PlayerSession.handle_cast({:player_entered_view, 2}, state)

      assert_receive {:send, :world,
                      {:unit_spawn,
                       %Aesir.Net.UnitSpawn{
                         gid: 2,
                         body_state: 3,
                         health_state: 5,
                         effect_state: 9,
                         virtue: 7
                       }}}

      Process.exit(other_pid, :kill)
    end

    test "player_entered_view follows the spawn with the unit's active icons to the observer", %{
      character: character
    } do
      test_pid = self()

      stub(StatusDisplay, :spawn_state, fn :player, 2 ->
        %{body_state: 0, health_state: 0, effect_state: 0, virtue: 0}
      end)

      icon = %Aesir.Net.StatusChange{unit_id: 2, efst: 0, on: true}
      stub(StatusDisplay, :active_icons, fn :player, 2 -> [icon] end)

      stub(Broadcast, :to_player, fn observer, packet ->
        send(test_pid, {:icon_to, observer, packet})
        :ok
      end)

      other_character = %{character | id: 2, account_id: 200, name: "OtherPlayer"}
      other_game_state = %{PlayerState.new(other_character) | movement_state: :standing}

      other_pid = spawn(fn -> Process.sleep(1000) end)
      UnitRegistry.register_player(other_game_state, other_pid)

      state = %{
        character: character,
        game_state: PlayerState.new(character),
        connection_pid: self()
      }

      {:noreply, _new_state} = PlayerSession.handle_cast({:player_entered_view, 2}, state)

      assert_received {:icon_to, 1, ^icon}

      Process.exit(other_pid, :kill)
    end

    test "player_entered_view sends no icon follow-up when the unit has no active icons", %{
      character: character
    } do
      test_pid = self()

      stub(StatusDisplay, :spawn_state, fn :player, 2 ->
        %{body_state: 0, health_state: 0, effect_state: 0, virtue: 0}
      end)

      stub(StatusDisplay, :active_icons, fn :player, 2 -> [] end)

      stub(Broadcast, :to_player, fn observer, packet ->
        send(test_pid, {:icon_to, observer, packet})
        :ok
      end)

      other_character = %{character | id: 2, account_id: 200, name: "OtherPlayer"}
      other_game_state = %{PlayerState.new(other_character) | movement_state: :standing}

      other_pid = spawn(fn -> Process.sleep(1000) end)
      UnitRegistry.register_player(other_game_state, other_pid)

      state = %{
        character: character,
        game_state: PlayerState.new(character),
        connection_pid: self()
      }

      {:noreply, _new_state} = PlayerSession.handle_cast({:player_entered_view, 2}, state)

      refute_received {:icon_to, _observer, _packet}

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

      {:noreply, new_state} = PlayerSession.handle_info({:stats, :recalculate}, state)

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

      {:noreply, new_state} = PlayerSession.handle_info({:skill, {:cast_complete, token}}, state)

      assert new_state.game_state.action_state == :idle
      assert new_state.game_state.stats.current_state.sp == 40 - 18
    end

    test "cast_complete with a stale token is ignored", %{character: character} do
      reject(&Aesir.ZoneServer.Mmo.StatusEffect.Interpreter.apply_status/4)

      token = make_ref()
      state = casting_state(character, token, sp: 40)

      {:noreply, new_state} =
        PlayerSession.handle_info({:skill, {:cast_complete, make_ref()}}, state)

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

    test "publishes exactly one normalized disconnect event", %{character: character} do
      :ok = Lifecycle.subscribe()
      expect(SpatialIndex, :get_visible_players, fn 1 -> [] end)
      expect(SpatialIndex, :remove_player, fn 1 -> :ok end)
      expect(SpatialIndex, :clear_visibility, fn 1 -> :ok end)

      state = %{
        character: character,
        game_state: PlayerState.new(character),
        connection_pid: self(),
        connection_monitor_ref: make_ref()
      }

      assert :ok = PlayerSession.terminate(:normal, state)

      assert_receive {:unit_lifecycle,
                      %Event{
                        unit_type: :player,
                        unit_id: 1,
                        reason: :disconnect,
                        old_map: "prontera",
                        new_map: nil
                      } = event}

      refute_receive {:unit_lifecycle, ^event}
    end

    test "disconnect removes a retained corpse and publishes only the death event", %{
      character: character
    } do
      :ok = Lifecycle.subscribe()

      SpatialIndex.add_player(1, 50, 50, "prontera")
      SpatialIndex.add_player(2, 55, 50, "prontera")
      SpatialIndex.update_visibility(1, 2, true)

      game_state = %{PlayerState.new(character) | action_state: :dead}

      state = %{
        character: character,
        game_state: game_state,
        connection_pid: self(),
        connection_monitor_ref: make_ref()
      }

      assert :ok = Lifecycle.publish_death(:player, 1, "prontera")

      assert_receive {:unit_lifecycle,
                      %Event{
                        unit_type: :player,
                        unit_id: 1,
                        reason: :death,
                        old_map: "prontera",
                        new_map: nil
                      }}

      assert :ok = PlayerSession.terminate(:normal, state)

      assert {:error, :not_found} = SpatialIndex.get_position(1)
      refute 1 in SpatialIndex.get_players_on_map("prontera")
      refute SpatialIndex.can_see?(1, 2)
      refute_receive {:unit_lifecycle, %Event{}}
    end

    test "publishes termination for an abnormal session stop", %{character: character} do
      :ok = Lifecycle.subscribe()
      expect(SpatialIndex, :get_visible_players, fn 1 -> [] end)
      expect(SpatialIndex, :remove_player, fn 1 -> :ok end)
      expect(SpatialIndex, :clear_visibility, fn 1 -> :ok end)

      state = %{
        character: character,
        game_state: PlayerState.new(character),
        connection_pid: self(),
        connection_monitor_ref: make_ref()
      }

      assert :ok = PlayerSession.terminate(:shutdown, state)

      assert_receive {:unit_lifecycle,
                      %Event{
                        unit_type: :player,
                        unit_id: 1,
                        reason: :termination,
                        old_map: "prontera",
                        new_map: nil
                      } = event}

      refute_receive {:unit_lifecycle, ^event}
    end

    test "death followed by an abnormal stop publishes only the death event", %{
      character: character
    } do
      :ok = Lifecycle.subscribe()
      expect(SpatialIndex, :get_visible_players, fn 1 -> [] end)
      expect(SpatialIndex, :remove_player, fn 1 -> :ok end)
      expect(SpatialIndex, :clear_visibility, fn 1 -> :ok end)

      game_state = %{PlayerState.new(character) | action_state: :dead}

      state = %{
        character: character,
        game_state: game_state,
        connection_pid: self(),
        connection_monitor_ref: make_ref()
      }

      assert :ok = Lifecycle.publish_death(:player, 1, "prontera")

      assert_receive {:unit_lifecycle,
                      %Event{
                        unit_type: :player,
                        unit_id: 1,
                        reason: :death,
                        old_map: "prontera",
                        new_map: nil
                      }}

      assert :ok = PlayerSession.terminate(:shutdown, state)

      refute_receive {:unit_lifecycle, %Event{}}
    end

    test "cleans up ETS entries", %{character: character} do
      UnitRegistry.register_player(PlayerState.new(character), self())

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

      UnitRegistry.register_player(
        %PlayerState{character_id: 2, account_id: 200, character_name: "TestPlayer"},
        other_pid
      )

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

      {:noreply, new_state} = PlayerSession.handle_info({:movement, :movement_tick}, state)

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
      expect(SpatialIndex, :get_players_in_range, fn "prontera", 50, 50, 20 ->
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

  describe "handle_info({:combat, {:apply_heal, amount, source_id}})" do
    test "delegates to HealthHandler and raises HP", %{character: character} do
      stub(UnitRegistry, :update_unit_state, fn _, _, _ -> :ok end)
      stub(CharacterPersistence, :update_stats, fn _, _, _ -> {:ok, %Character{}} end)

      game_state = PlayerState.new(character)

      game_state =
        put_in(
          game_state,
          [Access.key!(:stats), Access.key!(:current_state), Access.key!(:hp)],
          1
        )

      state = %{character: character, game_state: game_state, connection_pid: self()}

      {:noreply, new_state} = PlayerSession.handle_info({:combat, {:apply_heal, 10, nil}}, state)

      assert new_state.game_state.stats.current_state.hp == 11
    end
  end

  describe "cross-session health commands" do
    test "resurrect revalidates and commits through the target session", %{character: character} do
      Mimic.copy(CharacterPersistence)
      stub(CharacterPersistence, :update_stats, fn _, _, _ -> {:ok, %Character{}} end)
      stub(CharacterPersistence, :update_position, fn _, _, _, _ -> {:ok, %Character{}} end)

      {:ok, pid} = PlayerSession.start_link(%{character: character, connection_pid: self()})
      source_character = %{character | id: 2, account_id: 200, name: "ResurrectionSource"}
      {:ok, _source_pid} = ResurrectionSource.start_link(PlayerState.new(source_character))

      PlayerSession.apply_damage(pid, 1_000)
      assert %{game_state: %{action_state: :dead}} = PlayerSession.get_state(pid)

      assert :ok = PlayerSession.resurrect(pid, 2, 30)

      assert %{game_state: game_state} = PlayerSession.get_state(pid)
      assert game_state.action_state == :idle

      assert game_state.stats.current_state.hp ==
               div(game_state.stats.derived_stats.max_hp * 30, 100)
    end

    test "returns a typed source error when a source warp is queued before resurrection", %{
      character: character
    } do
      Mimic.copy(CharacterPersistence)
      stub(CharacterPersistence, :update_stats, fn _, _, _ -> {:ok, %Character{}} end)
      stub(CharacterPersistence, :update_position, fn _, _, _, _ -> {:ok, %Character{}} end)

      {:ok, target_pid} =
        PlayerSession.start_link(%{character: character, connection_pid: self()})

      source_character = %{character | id: 2, account_id: 200, name: "ResurrectionSource"}
      {:ok, source_pid} = ResurrectionSource.start_link(PlayerState.new(source_character))

      PlayerSession.apply_damage(target_pid, 1_000)
      assert %{game_state: %{action_state: :dead}} = PlayerSession.get_state(target_pid)

      ResurrectionSource.warp(source_pid, "geffen")
      assert %{game_state: %{map_name: "geffen"}} = ResurrectionSource.get_state(source_pid)

      assert {:error, :source_unavailable} = PlayerSession.resurrect(target_pid, 2, 30)
      assert %{game_state: %{action_state: :dead}} = PlayerSession.get_state(target_pid)
    end

    test "resurrection from a live source session does not create a cyclic call", %{
      character: character
    } do
      Mimic.copy(CharacterPersistence)
      stub(CharacterPersistence, :update_stats, fn _, _, _ -> {:ok, %Character{}} end)
      stub(CharacterPersistence, :update_position, fn _, _, _, _ -> {:ok, %Character{}} end)

      {:ok, target_pid} =
        PlayerSession.start_link(%{character: character, connection_pid: self()})

      source_character = %{character | id: 2, account_id: 200, name: "ResurrectionSource"}

      {:ok, source_pid} =
        ResurrectionCaller.start_link(PlayerState.new(source_character), target_pid)

      PlayerSession.apply_damage(target_pid, 1_000)
      assert %{game_state: %{action_state: :dead}} = PlayerSession.get_state(target_pid)

      assert :ok = ResurrectionCaller.resurrect(source_pid)
    end

    test "returns a typed stale error when a target warp is queued before resurrection", %{
      character: character
    } do
      Mimic.copy(CharacterPersistence)
      Mimic.copy(WarpHandler)
      stub(CharacterPersistence, :update_stats, fn _, _, _ -> {:ok, %Character{}} end)
      stub(CharacterPersistence, :update_position, fn _, _, _, _ -> {:ok, %Character{}} end)

      stub(WarpHandler, :warp, fn state, "geffen", 1, 1 ->
        :ok = SpatialIndex.remove_player(state.game_state.character_id)

        game_state = PlayerState.relocate(state.game_state, "geffen", 1, 1)
        {:ok, %{state | game_state: game_state}}
      end)

      {:ok, target_pid} =
        PlayerSession.start_link(%{character: character, connection_pid: self()})

      source_character = %{character | id: 2, account_id: 200, name: "ResurrectionSource"}
      {:ok, _source_pid} = ResurrectionSource.start_link(PlayerState.new(source_character))

      PlayerSession.apply_damage(target_pid, 1_000)
      assert %{game_state: %{action_state: :dead}} = PlayerSession.get_state(target_pid)

      GenServer.cast(target_pid, {:warp, "geffen", 1, 1})
      assert %{game_state: %{map_name: "geffen"}} = PlayerSession.get_state(target_pid)

      assert {:error, :stale_target} = PlayerSession.resurrect(target_pid, 2, 30)
    end

    test "try_consume_sp charges synchronously without underflow", %{character: character} do
      Mimic.copy(CharacterPersistence)
      stub(CharacterPersistence, :update_stats, fn _, _, _ -> {:ok, %Character{}} end)

      {:ok, pid} = PlayerSession.start_link(%{character: character, connection_pid: self()})
      %{game_state: initial_state} = PlayerSession.get_state(pid)
      initial_sp = initial_state.stats.current_state.sp

      assert :ok = PlayerSession.try_consume_sp(pid, 1)
      assert %{game_state: %{stats: %{current_state: %{sp: sp}}}} = PlayerSession.get_state(pid)
      assert sp == initial_sp - 1

      assert {:error, :insufficient_sp} = PlayerSession.try_consume_sp(pid, initial_sp)
      assert %{game_state: %{stats: %{current_state: %{sp: ^sp}}}} = PlayerSession.get_state(pid)
    end

    test "resurrect returns a typed error when the target session is unavailable" do
      pid = spawn(fn -> :ok end)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

      assert {:error, :target_unavailable} = PlayerSession.resurrect(pid, 2_001, 30)
    end

    test "resurrect returns a typed error when the target exits during the call" do
      {:ok, pid} = ExitingSession.start()

      assert {:error, :target_unavailable} = PlayerSession.resurrect(pid, 2_001, 30)
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

    {:ok, game_state} = PlayerState.transition_to(%{base | stats: stats}, :casting, context)

    %{
      character: character,
      game_state: game_state,
      connection_pid: self()
    }
  end
end
