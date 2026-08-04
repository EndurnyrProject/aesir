defmodule Aesir.ZoneServer.Unit.Homunculus.VisibilityTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Net.UnitDespawn
  alias Aesir.Net.UnitSpawn
  alias Aesir.ZoneServer.Constants.ObjectType
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.SpawnView
  alias Aesir.ZoneServer.Unit.Homunculus.StateCommit
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.VisibilityHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.SnapshotBuilder
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :verify_on_exit!

  setup do
    Mimic.copy(Movement)
    :ok
  end

  test "spawn view exposes only public Homunculus fields" do
    homunculus = homunculus()

    assert %UnitSpawn{
             gid: 70_001,
             aid: 70_001,
             object_type: object_type,
             job: 6_001,
             name: "Lif",
             clevel: 50,
             hp: 950,
             max_hp: 1_000,
             x: 100,
             y: 120,
             dir: 4
           } = SpawnView.build(homunculus)

    assert object_type == ObjectType.homunculus()
    refute inspect(SpawnView.build(homunculus)) =~ "owner_character_id"
    refute inspect(SpawnView.build(homunculus)) =~ "intimacy"
    refute inspect(SpawnView.build(homunculus)) =~ "learned_skills"
  end

  test "moving observer spawns and despawns a Homunculus" do
    homunculus = homunculus()
    register_homunculus(homunculus)
    observer = player_state(42, 100, 121)
    UnitRegistry.register_player(observer, self())
    SpatialIndex.add_player(observer.character_id, observer.x, observer.y, observer.map_name)

    visible = MovementHandler.handle_visibility_update(observer)

    assert visible.visible_homunculi == MapSet.new([homunculus.world_gid])
    assert_receive {:"$gen_cast", {:send_packet, %UnitSpawn{gid: 70_001}}}

    hidden = MovementHandler.handle_visibility_update(%{visible | x: 10, y: 10})

    assert hidden.visible_homunculi == MapSet.new()
    assert_receive {:"$gen_cast", {:send_packet, %UnitDespawn{gid: 70_001}}}
  end

  test "cross-map Homunculus movement notifies old-map leavers before entrants" do
    old_observer = player_state(41, 100, 120)
    new_observer = %{player_state(42, 100, 120) | map_name: "destination_map"}

    UnitRegistry.register_player(old_observer, self())
    UnitRegistry.register_player(new_observer, self())
    SpatialIndex.add_player(41, 100, 120, old_observer.map_name)
    SpatialIndex.add_player(42, 100, 120, new_observer.map_name)

    active = homunculus()
    register_homunculus(active)

    assert :ok =
             Movement.set_position(
               :homunculus,
               active.world_gid,
               %{active | map_name: "destination_map"},
               "destination_map"
             )

    assert_receive {:"$gen_cast", {:visibility, {:homunculus_left_view, 70_001}}}
    assert_receive {:"$gen_cast", {:visibility, {:homunculus_entered_view, 70_001}}}
  end

  test "moving Homunculus notifies stationary observers on enter and leave" do
    observer = player_state(42, 100, 100)
    UnitRegistry.register_player(observer, self())
    SpatialIndex.add_player(observer.character_id, observer.x, observer.y, observer.map_name)

    homunculus = %{homunculus() | x: 130, y: 100}
    register_homunculus(homunculus)

    assert :ok =
             Movement.set_position(
               :homunculus,
               homunculus.world_gid,
               %{homunculus | x: 101},
               homunculus.map_name
             )

    assert_receive {:"$gen_cast", {:visibility, {:homunculus_entered_view, 70_001}}}

    assert :ok =
             Movement.set_position(
               :homunculus,
               homunculus.world_gid,
               %{homunculus | x: 130},
               homunculus.map_name
             )

    assert_receive {:"$gen_cast", {:visibility, {:homunculus_left_view, 70_001}}}
  end

  test "boundary casts reconcile duplicate and stale Homunculus events" do
    observer = player_state(42, 100, 121)
    UnitRegistry.register_player(observer, self())
    register_homunculus(homunculus())
    session = session(observer)

    assert {:noreply, entered} = VisibilityHandler.homunculus_entered_view(70_001, session)
    assert entered.game_state.visible_homunculi == MapSet.new([70_001])
    assert_receive {:send, :world, {:unit_spawn, %UnitSpawn{gid: 70_001}}}

    assert {:noreply, ^entered} = VisibilityHandler.homunculus_entered_view(70_001, entered)
    refute_receive {:send, _channel, _packet}, 20

    assert {:noreply, ^entered} = VisibilityHandler.homunculus_left_view(70_001, entered)
    refute_receive {:send, _channel, _packet}, 20

    SpatialIndex.update_unit_position(:homunculus, 70_001, 140, 120, "visibility_test_map")

    absent = %{entered | game_state: %{entered.game_state | visible_homunculi: MapSet.new()}}
    UnitRegistry.update_unit_state(:player, observer.character_id, absent.game_state)

    assert {:noreply, ^absent} = VisibilityHandler.homunculus_entered_view(70_001, absent)
    refute_receive {:send, _channel, _packet}, 20

    present = %{
      absent
      | game_state: %{absent.game_state | visible_homunculi: MapSet.new([70_001])}
    }

    UnitRegistry.update_unit_state(:player, observer.character_id, present.game_state)

    assert {:noreply, left} = VisibilityHandler.homunculus_left_view(70_001, present)
    assert left.game_state.visible_homunculi == MapSet.new()
    assert_receive {:send, :world, {:unit_despawn, %UnitDespawn{gid: 70_001}}}

    assert {:ok, {PlayerState, published, _pid}} =
             UnitRegistry.get_unit(:player, observer.character_id)

    assert published.visible_homunculi == MapSet.new()
  end

  test "same-position public commits dirty once without routing through movement" do
    active = homunculus()
    register_homunculus(active)
    session = %{session(player_state(42, 100, 121)) | homunculus: active}

    reject(&Movement.set_position/4)

    updated = %{active | hp: 900, dir: 5}
    committed = StateCommit.commit(session, updated)

    assert Movement.drain_dirty(active.map_name) == [{:homunculus, active.world_gid, 0}]

    assert {:ok, {100, 120, "visibility_test_map"}} =
             SpatialIndex.get_unit_position(:homunculus, active.world_gid)

    privately_updated = %{updated | intimacy_hundredths: 9_600}
    StateCommit.commit(committed, privately_updated)
    assert Movement.drain_dirty(active.map_name) == []
  end

  test "appearance refresh replaces registry state without a pending snapshot" do
    active = homunculus()

    observer = %{
      player_state(42, 100, 121)
      | visible_homunculi: MapSet.new([active.world_gid])
    }

    pending_observer = player_state(43, 100, 122)
    UnitRegistry.register_player(observer, self())
    UnitRegistry.register_player(pending_observer, self())
    SpatialIndex.add_player(observer.character_id, observer.x, observer.y, observer.map_name)

    SpatialIndex.add_player(
      pending_observer.character_id,
      pending_observer.x,
      pending_observer.y,
      pending_observer.map_name
    )

    SpatialIndex.add_player(44, 100, 123, active.map_name)

    register_homunculus(active)
    Movement.mark_dirty(active.map_name, :homunculus, active.world_gid, 0)
    session = %{session(observer) | homunculus: active}
    evolved = %{active | class_id: 6_009, max_hp: 1_100}

    committed = StateCommit.commit_appearance_refresh(session, evolved)

    assert committed.homunculus.class_id == 6_009
    assert committed.homunculus_runtime.private_dirty
    assert Movement.drain_dirty(active.map_name) == []

    assert {:ok, {HomunculusState, registered, _pid}} =
             UnitRegistry.get_unit(:homunculus, active.world_gid)

    assert registered.class_id == 6_009
    assert registered.max_hp == 1_100
    assert_receive {:send, :world, {:unit_despawn, %UnitDespawn{gid: 70_001}}}
    assert_receive {:send, :world, {:unit_spawn, %UnitSpawn{gid: 70_001, job: 6_009}}}
    refute_receive {:"$gen_cast", {:send_packet, %UnitDespawn{gid: 70_001}}}, 20
    refute_receive {:"$gen_cast", {:send_packet, %UnitSpawn{gid: 70_001}}}, 20
  end

  test "invalid active public state fails before world mutation" do
    observer = player_state(42, 100, 121)
    session = session(observer)

    invalid_states = [
      %{homunculus() | hp: 0},
      %{homunculus() | action_state: :dead},
      %{homunculus() | name: ""}
    ]

    Enum.each(invalid_states, fn invalid ->
      assert_raise ArgumentError, ~r/complete living world state/, fn ->
        StateCommit.commit(session, invalid)
      end

      assert {:error, :not_found} = UnitRegistry.get_unit(:homunculus, invalid.world_gid)
      assert {:error, :not_found} = SpatialIndex.get_unit_position(:homunculus, invalid.world_gid)
      assert Movement.drain_dirty(invalid.map_name) == []
    end)
  end

  test "StateCommit registers active presence and removes it in cleanup order" do
    observer = player_state(42, 100, 121)
    UnitRegistry.register_player(observer, self())
    SpatialIndex.add_player(observer.character_id, observer.x, observer.y, observer.map_name)
    session = session(observer)
    active = homunculus()

    committed = StateCommit.commit(session, active)

    assert committed.homunculus.owner_session_pid == self()
    assert {:ok, {HomunculusState, _, pid}} = UnitRegistry.get_unit(:homunculus, 70_001)
    assert pid == self()

    assert {:ok, {100, 120, "visibility_test_map"}} =
             SpatialIndex.get_unit_position(:homunculus, 70_001)

    assert_receive {:"$gen_cast", {:visibility, {:homunculus_entered_view, 70_001}}}

    StatusStorage.apply_status(:homunculus, 70_001, :sc_test)
    StateCommit.commit(committed, %{active | lifecycle: :rested})

    assert_receive {:"$gen_cast", {:visibility, {:homunculus_left_view, 70_001}}}
    assert {:error, :not_found} = UnitRegistry.get_unit(:homunculus, 70_001)
    assert {:error, :not_found} = SpatialIndex.get_unit_position(:homunculus, 70_001)
    assert StatusStorage.get_unit_statuses(:homunculus, 70_001) == []

    refute Enum.any?(
             Movement.drain_dirty("visibility_test_map"),
             &match?({:homunculus, 70_001, _}, &1)
           )

    StateCommit.commit(committed, %{active | lifecycle: :rested})
    refute_receive {:"$gen_cast", {:visibility, {:homunculus_left_view, 70_001}}}, 20
  end

  test "invalid activation validates without reading modifiers from the dummy gid" do
    owner = player_state(42, 50, 50)
    StatusStorage.apply_status(:homunculus, 1, :sc_fleet, val2: 120, val3: 25)

    assert_raise ArgumentError, ~r/complete living world state/, fn ->
      StateCommit.activate(
        session(owner),
        %{homunculus() | world_gid: 1, hp: 0},
        world_id_range: 5..5
      )
    end

    refute UnitRegistry.unit_id_exists?(5)
    assert UnitRegistry.list_units_by_type(:homunculus) == []
    assert SpatialIndex.get_unit_position(:homunculus, 5) == {:error, :not_found}
    assert Movement.drain_dirty(owner.map_name) == []
  end

  test "activation removes a dead ghost, rejects a live duplicate, and allocates one unique gid" do
    owner = player_state(42, 50, 50)
    session = session(owner)
    ghost_owner = spawn(fn -> Process.sleep(:infinity) end)
    ghost = %{homunculus() | world_gid: 2, owner_session_pid: ghost_owner, x: 55, y: 50}
    register_homunculus(ghost, ghost_owner)
    ref = Process.monitor(ghost_owner)
    Process.exit(ghost_owner, :kill)
    assert_receive {:DOWN, ^ref, :process, ^ghost_owner, :killed}

    UnitRegistry.register_unit(:mob, 3, __MODULE__, %{}, nil)

    assert {:ok, activated} =
             StateCommit.activate(session, %{homunculus() | world_gid: nil}, world_id_range: 2..4)

    assert activated.homunculus.world_gid in [2, 4]
    refute activated.homunculus.world_gid == 3

    assert {:ok, {HomunculusState, registered, pid}} =
             UnitRegistry.get_unit(:homunculus, activated.homunculus.world_gid)

    assert registered.owner_session_pid == self()
    assert pid == self()
    assert UnitRegistry.count_units_by_type(:homunculus) == 1

    assert {:error, :duplicate_session} =
             StateCommit.activate(session, %{homunculus() | world_gid: nil}, world_id_range: 5..5)

    refute UnitRegistry.unit_id_exists?(5)
  end

  test "snapshot conversion adds Homunculi without changing player and mob allocation" do
    homunculus = homunculus()
    register_homunculus(homunculus)

    assert [%{id: 70_001, x: 100, y: 120, dir: 4, move_state: 0, hp_pct: 95}] =
             SnapshotBuilder.entities_for([{:homunculus, 70_001}])
  end

  defp register_homunculus(state, pid \\ self()) do
    UnitRegistry.register_unit(:homunculus, state.world_gid, HomunculusState, state, pid)
    SpatialIndex.add_unit(:homunculus, state.world_gid, state.x, state.y, state.map_name)
  end

  defp session(owner), do: %SessionState{game_state: owner, connection_pid: self()}

  defp player_state(id, x, y) do
    %PlayerState{
      character_id: id,
      character_name: "Observer",
      account_id: id + 1_000,
      map_name: "visibility_test_map",
      x: x,
      y: y,
      dir: 0,
      movement_state: :standing,
      view_range: 14,
      visible_players: MapSet.new(),
      visible_mobs: MapSet.new(),
      visible_homunculi: MapSet.new(),
      visible_warps: MapSet.new(),
      visible_npcs: MapSet.new(),
      visible_shops: MapSet.new(),
      visible_items: MapSet.new(),
      visible_skill_units: MapSet.new(),
      party_id: 0,
      stats: %{current_state: %{hp: 100}, derived_stats: %{max_hp: 100}}
    }
  end

  defp homunculus do
    %HomunculusState{
      id: 123,
      owner_character_id: 42,
      owner_session_pid: self(),
      class_id: 6_001,
      name: "Lif",
      lifecycle: :active,
      level: 50,
      hp: 950,
      max_hp: 1_000,
      sp: 150,
      max_sp: 200,
      hunger: 80,
      intimacy_hundredths: 9_500,
      learned_skills: %{8001 => 3},
      cooldowns: %{8001 => 123_456},
      ai_config: %{stance: :assist},
      world_gid: 70_001,
      map_name: "visibility_test_map",
      x: 100,
      y: 120,
      dir: 4,
      movement_state: :standing
    }
  end
end
