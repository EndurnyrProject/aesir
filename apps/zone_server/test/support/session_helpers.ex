defmodule Aesir.ZoneServer.SessionHelpers do
  @moduledoc """
  Helper functions for managing test sessions in integration tests.
  Provides utilities to create and manage simulated player sessions
  for testing multi-player interactions.
  """

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Starts a test player session with the given character data.

  ## Options
  - :character - A Character struct or map with character attributes
  - :connection_pid - Mock connection PID (optional, will create one if not provided)
  - :map_name - Map to spawn on (default: "prontera")
  - :position - Starting position as {x, y} tuple (default: {150, 150})

  ## Examples

      session = start_player_session(
        character: %Character{id: 1, name: "TestHero"},
        map_name: "prontera",
        position: {155, 180}
      )

  ## Returns

      %{
        pid: pid(),
        character: %Character{},
        connection_pid: pid(),
        map_name: binary(),
        position: {integer(), integer()}
      }
  """
  def start_player_session(opts \\ []) do
    # Create or use provided character
    character = opts[:character] || create_test_character(opts)

    # Create mock connection process if not provided
    test_pid = self()

    connection_pid =
      opts[:connection_pid] ||
        spawn_link(fn ->
          connection_process_loop(test_pid)
        end)

    map_name = opts[:map_name] || character.last_map || "prontera"
    {x, y} = opts[:position] || {character.last_x || 150, character.last_y || 150}

    # Start the PlayerSession
    {:ok, pid} =
      PlayerSession.start_link(%{
        character: character,
        connection_pid: connection_pid,
        map_name: map_name,
        x: x,
        y: y
      })

    # Register in UnitRegistry
    UnitRegistry.register_player(character.id, character.account_id, character.name, pid)

    # Register in SpatialIndex
    SpatialIndex.add_unit(:player, character.id, x, y, map_name)

    %{
      pid: pid,
      character: character,
      connection_pid: connection_pid,
      map_name: map_name,
      position: {x, y}
    }
  end

  @doc """
  Starts a test mob session.

  ## Options
  - :mob_id - The mob database ID (e.g., 1002 for Poring)
  - :unit_id - Unique unit ID for this mob instance
  - :map_name - Map to spawn on
  - :position - Starting position as {x, y} tuple
  - :hp - Current HP
  - :max_hp - Maximum HP
  - :level - Mob level

  ## Examples

      mob = start_mob_session(
        mob_id: 1002,
        map_name: "prontera",
        position: {160, 160}
      )
  """
  def start_mob_session(opts \\ []) do
    # Default to Poring
    mob_id = opts[:mob_id] || 1002
    unit_id = opts[:unit_id] || :erlang.unique_integer([:positive])
    map_name = opts[:map_name] || "prontera"
    {x, y} = opts[:position] || {150, 150}

    # We need to create a minimal mob spawn and definition for the state
    mob_definition = %MobDefinition{
      id: mob_id,
      aegis_name: :TEST_MOB,
      name: "TestMob_#{mob_id}",
      level: opts[:level] || 1,
      hp: opts[:max_hp] || 100,
      sp: 50,
      base_exp: 10,
      job_exp: 5,
      atk_min: 10,
      atk_max: 20,
      def: 5,
      mdef: 3,
      stats: %{str: 10, agi: 10, vit: 10, int: 5, dex: 10, luk: 5},
      attack_range: 1,
      skill_range: 10,
      chase_range: 12,
      element: {:neutral, 1},
      race: :formless,
      size: :medium,
      walk_speed: 200,
      attack_delay: 1000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 400,
      ai_type: 0,
      modes: [],
      drops: []
    }

    mob_spawn = %MobSpawn{
      mob_id: mob_id,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %MobSpawn.SpawnArea{
        x: x,
        y: y,
        xs: 0,
        ys: 0
      }
    }

    # Create mob state with all required fields
    mob_state = %MobState{
      instance_id: unit_id,
      mob_id: mob_id,
      mob_data: mob_definition,
      spawn_ref: mob_spawn,
      x: x,
      y: y,
      map_name: map_name,
      hp: opts[:hp] || opts[:max_hp] || 100,
      max_hp: opts[:max_hp] || 100,
      sp: opts[:sp] || 50,
      max_sp: opts[:max_sp] || 50,
      spawned_at: System.system_time(:second),
      aggro_list: %{}
    }

    # Start the MobSession with correct argument structure
    {:ok, pid} = MobSession.start_link(%{state: mob_state})

    # Register in UnitRegistry with proper format
    UnitRegistry.register_unit(:mob, unit_id, MobSession, mob_state, pid)

    # Register in SpatialIndex
    SpatialIndex.add_unit(:mob, unit_id, x, y, map_name)

    %{
      pid: pid,
      unit_id: unit_id,
      mob_id: mob_id,
      mob_state: mob_state,
      map_name: map_name,
      position: {x, y}
    }
  end

  @doc """
  Gets the current state of a player session.

  ## Examples

      state = get_player_state(session.pid)
      assert state.hp > 0
  """
  def get_player_state(player_pid) when is_pid(player_pid) do
    PlayerSession.get_state(player_pid)
  end

  @doc """
  Gets the current state of a mob session.

  ## Examples

      state = get_mob_state(mob.pid)
      assert state.hp < state.max_hp
  """
  def get_mob_state(mob_pid) when is_pid(mob_pid) do
    MobSession.get_state(mob_pid)
  end

  @doc """
  Ends a player session, cleaning up all associated resources.

  ## Examples

      session = start_player_session()
      # ... run tests ...
      end_player_session(session)
  """
  def end_player_session(%{pid: pid, character: character}) do
    # Unregister from UnitRegistry
    UnitRegistry.unregister_player(character.id)

    # Remove from SpatialIndex
    SpatialIndex.remove_unit(:player, character.id)

    # Stop the process
    if Process.alive?(pid), do: GenServer.stop(pid, :normal)

    :ok
  end

  @doc """
  Ends a mob session, cleaning up all associated resources.

  ## Examples

      mob = start_mob_session()
      # ... run tests ...
      end_mob_session(mob)
  """
  def end_mob_session(%{pid: pid, unit_id: unit_id}) do
    # Unregister from UnitRegistry
    UnitRegistry.unregister_unit(:mob, unit_id)

    # Remove from SpatialIndex
    SpatialIndex.remove_unit(:mob, unit_id)

    # Stop the process
    if Process.alive?(pid), do: GenServer.stop(pid, :normal)

    :ok
  end

  @doc """
  Starts multiple player sessions for testing multi-player scenarios.

  ## Examples

      players = start_player_sessions(3, map_name: "prontera")
      assert length(players) == 3
  """
  def start_player_sessions(count, opts \\ []) when is_integer(count) and count > 0 do
    Enum.map(1..count, fn index ->
      character =
        create_test_character(
          Keyword.merge(opts,
            id: 1000 + index,
            name: "Player#{index}"
          )
        )

      start_player_session(Keyword.put(opts, :character, character))
    end)
  end

  @doc """
  Creates a PvP scenario with two players positioned near each other.

  ## Examples

      {attacker, defender} = create_pvp_scenario()
  """
  def create_pvp_scenario(attacker_opts \\ [], defender_opts \\ []) do
    attacker =
      start_player_session(
        Keyword.merge(
          [
            character: create_test_character(id: 1001, name: "Attacker"),
            position: {150, 150}
          ],
          attacker_opts
        )
      )

    defender =
      start_player_session(
        Keyword.merge(
          [
            character: create_test_character(id: 1002, name: "Defender"),
            position: {151, 150}
          ],
          defender_opts
        )
      )

    {attacker, defender}
  end

  @doc """
  Creates a player vs mob combat scenario.

  ## Examples

      {player, mob} = create_combat_scenario()
  """
  def create_combat_scenario(player_opts \\ [], mob_opts \\ []) do
    player =
      start_player_session(
        Keyword.merge(
          [
            position: {150, 150}
          ],
          player_opts
        )
      )

    mob =
      start_mob_session(
        Keyword.merge(
          [
            position: {151, 150}
          ],
          mob_opts
        )
      )

    {player, mob}
  end

  # Private helper functions

  defp create_test_character(opts) do
    %Character{
      id: opts[:id] || :erlang.unique_integer([:positive]),
      account_id: opts[:account_id] || 1,
      name: opts[:name] || "TestChar#{:rand.uniform(9999)}",
      char_num: opts[:char_num] || 0,
      class: opts[:class] || 0,
      base_level: opts[:base_level] || 1,
      base_exp: 0,
      job_level: opts[:job_level] || 1,
      job_exp: 0,
      zeny: opts[:zeny] || 500,
      str: opts[:str] || 5,
      agi: opts[:agi] || 5,
      vit: opts[:vit] || 5,
      int: opts[:int] || 5,
      dex: opts[:dex] || 5,
      luk: opts[:luk] || 5,
      hp: opts[:hp] || 100,
      max_hp: opts[:max_hp] || 100,
      sp: opts[:sp] || 50,
      max_sp: opts[:max_sp] || 50,
      status_point: opts[:status_point] || 0,
      skill_point: opts[:skill_point] || 0,
      last_map: opts[:last_map] || opts[:map_name] || "prontera",
      last_x: opts[:last_x] || elem(opts[:position] || {150, 150}, 0),
      last_y: opts[:last_y] || elem(opts[:position] || {150, 150}, 1),
      save_map: "prontera",
      save_x: 150,
      save_y: 150,
      hair: opts[:hair] || 1,
      hair_color: opts[:hair_color] || 1,
      clothes_color: opts[:clothes_color] || 0,
      weapon: opts[:weapon] || 0,
      shield: opts[:shield] || 0,
      head_top: opts[:head_top] || 0,
      head_mid: opts[:head_mid] || 0,
      head_bottom: opts[:head_bottom] || 0,
      robe: opts[:robe] || 0,
      online: true,
      delete_date: nil
    }
  end

  defp connection_process_loop(test_pid) do
    receive do
      :stop ->
        :ok

      {:send_packet, packet} ->
        # When PlayerSession sends a packet to connection,
        # forward it to the test process using the mocked Connection
        # The packet should already be a struct from PlayerSession
        if is_struct(packet) do
          # Send to test process via the mocked Connection.send_packet
          send(test_pid, {:packet_sent, packet, packet.__struct__.build(packet)})
        else
          # Ignore unexpected non-struct packet
          :ok
        end

        connection_process_loop(test_pid)

      msg ->
        # Ignore unexpected messages
        connection_process_loop(test_pid)
    end
  end
end
