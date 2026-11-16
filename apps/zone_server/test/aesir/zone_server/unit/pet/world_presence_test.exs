defmodule Aesir.ZoneServer.Unit.Pet.WorldPresenceTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Net.UnitDespawn
  alias Aesir.Net.UnitSpawn
  alias Aesir.ZoneServer.Constants.DespawnReason
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skills.Wizard.WzQuagmire
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Pet.PetState
  alias Aesir.ZoneServer.Unit.Pet.Runtime
  alias Aesir.ZoneServer.Unit.Pet.SpawnView
  alias Aesir.ZoneServer.Unit.Pet.StateCommit
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.VisibilityHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :set_mimic_private
  setup :verify_on_exit!

  describe "SpawnView.build/1" do
    test "shows a pet with the class as job and the accessory's view id" do
      stub(Items, :by_id, fn 10_001 -> {:ok, %{view: 77}} end)

      assert %UnitSpawn{object_type: 2, job: 1_002, clevel: 5, name: "Poring", accessory: 77} =
               SpawnView.build(%{pet() | world_gid: 70_001, equip: 10_001})
    end

    test "falls back to the accessory item id when it has no view id" do
      stub(Items, :by_id, fn 10_001 -> {:ok, %{view: 0}} end)

      assert %UnitSpawn{accessory: 10_001} =
               SpawnView.build(%{pet() | world_gid: 70_001, equip: 10_001})

      assert %UnitSpawn{accessory: 0} = SpawnView.build(%{pet() | world_gid: 70_001, equip: 0})
    end
  end

  describe "StateCommit" do
    test "spawn registers the pet and remove unregisters it and bumps the generation" do
      observer = player_state(42, 100, 121)
      UnitRegistry.register_player(observer, self())
      SpatialIndex.add_player(observer.character_id, observer.x, observer.y, observer.map_name)
      session = session(observer)

      assert {:ok, spawned} = StateCommit.spawn(session, pet())
      gid = spawned.pet.world_gid

      assert {:ok, {PetState, %PetState{world_gid: ^gid}, _pid}} =
               UnitRegistry.get_unit(:pet, gid)

      assert {:ok, {100, 120, "pet_test_map"}} = SpatialIndex.get_unit_position(:pet, gid)
      assert_receive {:"$gen_cast", {:visibility, {:pet_entered_view, ^gid}}}

      removed = StateCommit.remove(spawned, DespawnReason.logged_out())

      assert removed.pet == nil
      assert removed.pet_runtime.generation == session.pet_runtime.generation + 1
      assert {:error, :not_found} = UnitRegistry.get_unit(:pet, gid)
      assert {:error, :not_found} = SpatialIndex.get_unit_position(:pet, gid)
      reason = DespawnReason.logged_out()
      assert_receive {:"$gen_cast", {:visibility, {:pet_vanished, ^gid, ^reason}}}
    end
  end

  describe "area queries" do
    test "a pet is only reachable through the typed pet queries" do
      {:ok, spawned} = StateCommit.spawn(session(player_state(7, 100, 120)), pet())
      gid = spawned.pet.world_gid

      refute {:pet, gid} in SpatialIndex.units_in_area("pet_test_map", 100, 120, 100, 120)
      refute {:pet, gid} in SpatialIndex.get_all_units_in_range("pet_test_map", 100, 120, 1)
      refute {:pet, gid} in SpatialIndex.units_in_cell("pet_test_map", 100, 120)
      assert gid in SpatialIndex.get_pets_in_range("pet_test_map", 100, 120, 1)
    end
  end

  describe "ground units" do
    setup do
      manager = start_supervised!({Manager, name: nil, schedule_tick: fn _, _ -> :ok end})
      Process.put({Manager, :server}, manager)
      %{manager: manager}
    end

    test "a pet spawning and walking inside a Quagmire is ignored by the field", %{
      manager: manager
    } do
      caster = player_state(1, 90, 120)
      UnitRegistry.register_player(caster, self())

      quagmire = %Group{
        group_id: 1,
        skill_id: 92,
        skill_name: :wz_quagmire,
        level: 5,
        caster_id: 1,
        caster_type: :player,
        map_name: "pet_test_map",
        center: {100, 120},
        cells: for(x <- 99..101, y <- 119..121, do: {x, y}),
        created_at: 0,
        next_tick_at: 1_000,
        expires_at: 25_000,
        interval: 1_000,
        handler: WzQuagmire
      }

      :ok = Storage.insert(quagmire)

      assert {:ok, spawned} = StateCommit.spawn(session(player_state(7, 100, 120)), pet())
      gid = spawned.pet.world_gid
      moved = StateCommit.commit(spawned, %{spawned.pet | x: 101, movement_state: :moving})

      assert {:ok, {101, 120, "pet_test_map"}} = SpatialIndex.get_unit_position(:pet, gid)
      assert moved.pet.x == 101
      assert Process.alive?(manager)
      assert Storage.get(1) == quagmire
      refute StatusStorage.has_status?(:pet, gid, :sc_quagmire)
    end
  end

  describe "visibility" do
    test "a pet enters and leaves a stationary observer's visibility set" do
      observer = player_state(42, 100, 121)
      UnitRegistry.register_player(observer, self())
      {:ok, spawned} = StateCommit.spawn(session(player_state(7, 100, 120)), pet())
      gid = spawned.pet.world_gid

      assert {:noreply, entered} = VisibilityHandler.pet_entered_view(gid, session(observer))
      assert entered.game_state.visible_pets == MapSet.new([gid])
      assert_receive {:send, :world, {:unit_spawn, %UnitSpawn{gid: ^gid, object_type: 2}}}

      reason = DespawnReason.out_of_sight()
      assert {:noreply, left} = VisibilityHandler.pet_vanished(gid, reason, entered)
      assert left.game_state.visible_pets == MapSet.new()
      assert_receive {:send, :world, {:unit_despawn, %UnitDespawn{gid: ^gid}}}
    end

    test "a moving observer spawns and despawns a nearby pet" do
      {:ok, spawned} = StateCommit.spawn(session(player_state(7, 100, 120)), pet())
      gid = spawned.pet.world_gid
      observer = player_state(42, 100, 121)
      UnitRegistry.register_player(observer, self())
      SpatialIndex.add_player(observer.character_id, observer.x, observer.y, observer.map_name)

      visible = MovementHandler.handle_visibility_update(observer)

      assert visible.visible_pets == MapSet.new([gid])
      assert_receive {:"$gen_cast", {:send_packet, %UnitSpawn{gid: ^gid}}}

      hidden = MovementHandler.handle_visibility_update(%{visible | x: 10, y: 10})

      assert hidden.visible_pets == MapSet.new()
      assert_receive {:"$gen_cast", {:send_packet, %UnitDespawn{gid: ^gid}}}
    end
  end

  defp session(player) do
    %SessionState{
      game_state: player,
      connection_pid: self(),
      pet_runtime: %Runtime{generation: 3}
    }
  end

  defp player_state(id, x, y) do
    %PlayerState{
      character_id: id,
      character_name: "Observer",
      account_id: id + 1_000,
      map_name: "pet_test_map",
      x: x,
      y: y,
      dir: 0,
      movement_state: :standing,
      view_range: 14,
      visible_players: MapSet.new(),
      visible_mobs: MapSet.new(),
      visible_homunculi: MapSet.new(),
      visible_pets: MapSet.new(),
      visible_warps: MapSet.new(),
      visible_npcs: MapSet.new(),
      visible_shops: MapSet.new(),
      visible_items: MapSet.new(),
      visible_skill_units: MapSet.new(),
      party_id: 0,
      stats: %{current_state: %{hp: 100}, derived_stats: %{max_hp: 100}}
    }
  end

  defp pet do
    %PetState{
      pet_id: 9,
      owner_char_id: 7,
      owner_account_id: 1_007,
      class_id: 1_002,
      name: "Poring",
      level: 5,
      egg_id: 9_001,
      equip: 0,
      intimate: 250,
      hungry: 80,
      map_name: "pet_test_map",
      x: 100,
      y: 120,
      dir: 0,
      walk_speed: 150
    }
  end
end
