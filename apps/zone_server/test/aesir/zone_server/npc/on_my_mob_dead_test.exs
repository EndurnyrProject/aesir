defmodule Aesir.ZoneServer.Npc.OnMyMobDeadTest do
  @moduledoc """
  Covers Task 11: mob-spawning ops tagging a summoned mob with an `event:
  "Name::OnLabel"` owner event (rAthena OnMyMobDead), fired with the killer
  attached when a tagged mob dies to a player; the killer id threaded from
  `MobSession`'s death path through `Map.Coordinator.mob_died/3`; and the
  Task 3 follow-up making `summon_mob/2`/`summon_random_mob/2` detached-capable
  off the calling NPC's own placement.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Mob.MobState

  defmodule OwnerEventNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 70, y: 70, sprite: 58, name: "OwnerEventNpc"}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnMyMobDead", ctx) do
      send(:on_my_mob_dead_probe, {:owner_event_ran, ctx.char_id})
      ctx
    end
  end

  defmodule PlacementNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 80, y: 80, sprite: 58, name: "PlacementNpc"}]

    @impl true
    def on_talk(ctx), do: ctx
  end

  setup do
    Process.register(self(), :on_my_mob_dead_probe)
    on_exit(fn -> :persistent_term.erase(NpcRegistry) end)
    :ok
  end

  describe "mob_died dispatch" do
    test "dispatches the owner event to the killer with the killer attached" do
      NpcRegistry.reload([OwnerEventNpc])
      player = start_player_session(id: 9001)

      mob_state = build_mob_state(owner_event: "OwnerEventNpc::OnMyMobDead")
      register_mob(mob_state)

      coordinator_state = %Coordinator{map_name: "prontera", respawn_timers: %{}}

      {:noreply, _state} =
        Coordinator.handle_cast(
          {:mob_died, mob_state.instance_id, player.character.id},
          coordinator_state
        )

      assert_receive {:owner_event_ran, char_id}, 500
      assert char_id == player.character.id
    end

    test "an untagged mob dying dispatches nothing and still schedules a respawn" do
      player = start_player_session(id: 9002)
      mob_state = build_mob_state(owner_event: nil)
      register_mob(mob_state)

      coordinator_state = %Coordinator{map_name: "prontera", respawn_timers: %{}}

      {:noreply, new_state} =
        Coordinator.handle_cast(
          {:mob_died, mob_state.instance_id, player.character.id},
          coordinator_state
        )

      assert Map.has_key?(new_state.respawn_timers, mob_state.instance_id)
      refute_receive {:owner_event_ran, _char_id}
    end

    test "a tagged mob dying with no killer fires nothing" do
      NpcRegistry.reload([OwnerEventNpc])
      mob_state = build_mob_state(owner_event: "OwnerEventNpc::OnMyMobDead")
      register_mob(mob_state)

      coordinator_state = %Coordinator{map_name: "prontera", respawn_timers: %{}}

      {:noreply, _state} =
        Coordinator.handle_cast({:mob_died, mob_state.instance_id, nil}, coordinator_state)

      refute_receive {:owner_event_ran, _char_id}
    end

    test "a tagged mob dying to a non-player killer fires nothing" do
      NpcRegistry.reload([OwnerEventNpc])
      mob_state = build_mob_state(owner_event: "OwnerEventNpc::OnMyMobDead")
      register_mob(mob_state)

      coordinator_state = %Coordinator{map_name: "prontera", respawn_timers: %{}}

      {:noreply, _state} =
        Coordinator.handle_cast(
          {:mob_died, mob_state.instance_id, 424_242},
          coordinator_state
        )

      refute_receive {:owner_event_ran, _char_id}
    end

    test "an unknown npc name logs a warning and fires nothing" do
      player = start_player_session(id: 9003)
      mob_state = build_mob_state(owner_event: "Nowhere::OnMyMobDead")
      register_mob(mob_state)

      coordinator_state = %Coordinator{map_name: "prontera", respawn_timers: %{}}

      log =
        capture_log(fn ->
          Coordinator.handle_cast(
            {:mob_died, mob_state.instance_id, player.character.id},
            coordinator_state
          )
        end)

      assert log =~ "unknown name"
      refute_receive {:owner_event_ran, _char_id}
    end

    test "an undeclared label logs a warning and fires nothing" do
      NpcRegistry.reload([PlacementNpc])
      player = start_player_session(id: 9004)
      mob_state = build_mob_state(owner_event: "PlacementNpc::OnUndeclared")
      register_mob(mob_state)

      coordinator_state = %Coordinator{map_name: "prontera", respawn_timers: %{}}

      log =
        capture_log(fn ->
          Coordinator.handle_cast(
            {:mob_died, mob_state.instance_id, player.character.id},
            coordinator_state
          )

          Process.sleep(50)
        end)

      assert log =~ "no_handler"
      refute_receive {:owner_event_ran, _char_id}
    end
  end

  describe "MobSession death path" do
    setup :set_mimic_global

    test "passes the killing blow's attacker id through to Coordinator.mob_died" do
      test_pid = self()

      stub(Coordinator, :mob_died, fn map, id, killer ->
        send(test_pid, {:mob_died_called, map, id, killer})
        :ok
      end)

      mob = start_mob_session(hp: 1, max_hp: 1)

      MobSession.apply_damage(mob.pid, 100, 777)

      assert_receive {:mob_died_called, "prontera", instance_id, 777}
      assert instance_id == mob.unit_id
    end

    test "a death with no attacker passes nil through to Coordinator.mob_died" do
      test_pid = self()

      stub(Coordinator, :mob_died, fn map, id, killer ->
        send(test_pid, {:mob_died_called, map, id, killer})
        :ok
      end)

      mob = start_mob_session(hp: 1, max_hp: 1)

      MobSession.apply_damage(mob.pid, 100, nil)

      assert_receive {:mob_died_called, "prontera", _instance_id, nil}
    end
  end

  describe "summon_mob/2 and summon_random_mob/2 detached-capable spawn position" do
    test "summon_mob/2 spawns at the calling NPC's own placement on a detached ctx" do
      NpcRegistry.reload([PlacementNpc])
      {PlacementNpc, placement} = hd(NpcRegistry.entries())
      gid = NpcRegistry.entity_id(placement)
      test_pid = self()

      stub(Coordinator, :summon_mob, fn map, mob_id, x, y, _opts ->
        send(test_pid, {:summoned, map, mob_id, {x, y}})
        {:ok, 1}
      end)

      ctx = Ctx.detached(PlacementNpc, gid)
      result = Dsl.summon_mob(ctx, mob_id: 1002)

      assert result.status == :ok
      assert_received {:summoned, "prontera", 1002, {80, 80}}
    end

    test "summon_mob/2 :at overrides the NPC's placement on a detached ctx" do
      NpcRegistry.reload([PlacementNpc])
      {PlacementNpc, placement} = hd(NpcRegistry.entries())
      gid = NpcRegistry.entity_id(placement)
      test_pid = self()

      stub(Coordinator, :summon_mob, fn map, mob_id, x, y, _opts ->
        send(test_pid, {:summoned, map, mob_id, {x, y}})
        {:ok, 1}
      end)

      ctx = Ctx.detached(PlacementNpc, gid)
      result = Dsl.summon_mob(ctx, mob_id: 1002, at: {10, 20})

      assert result.status == :ok
      assert_received {:summoned, "prontera", 1002, {10, 20}}
    end

    test "summon_random_mob/2 spawns at the calling NPC's own placement on a detached ctx" do
      NpcRegistry.reload([PlacementNpc])
      {PlacementNpc, placement} = hd(NpcRegistry.entries())
      gid = NpcRegistry.entity_id(placement)
      test_pid = self()

      stub(Coordinator, :summon_mob, fn map, mob_id, x, y, _opts ->
        send(test_pid, {:summoned, map, mob_id, {x, y}})
        {:ok, 1}
      end)

      ctx = Ctx.detached(PlacementNpc, gid)
      result = Dsl.summon_random_mob(ctx, [])

      assert result.status == :ok
      assert_received {:summoned, "prontera", _mob_id, {80, 80}}
    end

    test "summon_mob/2 still halts :no_player when npc_gid is nil" do
      ctx = %Ctx{
        char_id: nil,
        account_id: nil,
        connection_pid: nil,
        game_state: nil,
        source: {:npc, :test_npc},
        npc_gid: nil
      }

      result = Dsl.summon_mob(ctx, mob_id: 1002, at: {10, 10})

      assert result.status == {:error, :no_player}
    end

    test "summon_mob/2 still halts :no_player when npc_gid doesn't resolve" do
      ctx = Ctx.detached(PlacementNpc, 0x5000_0000 - 1)

      result = Dsl.summon_mob(ctx, mob_id: 1002, at: {10, 10})

      assert result.status == {:error, :no_player}
    end
  end

  defp build_mob_state(opts) do
    mob_data = %MobDefinition{
      id: 1001,
      aegis_name: "test_mob",
      name: "Test Mob",
      level: 1,
      base_exp: 10,
      job_exp: 5,
      drops: [],
      hp: 100,
      sp: 0,
      stats: %{str: 10, agi: 10, vit: 10, int: 10, dex: 10, luk: 10},
      atk: 10,
      matk: 0,
      def: 0,
      mdef: 0,
      attack_range: 1,
      walk_speed: 200,
      attack_delay: 1000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 400,
      element: {:neutral, 1},
      race: :formless,
      size: :medium
    }

    spawn_ref = %MobSpawn{
      mob: 1001,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %MobSpawn.SpawnArea{x: 100, y: 100}
    }

    instance_id = System.unique_integer([:positive])

    instance_id
    |> MobState.new(mob_data, spawn_ref, "prontera", 100, 100)
    |> MobState.set_owner_event(Keyword.get(opts, :owner_event))
  end

  defp register_mob(%MobState{} = mob_state) do
    UnitRegistry.register_unit(:mob, mob_state.instance_id, MobState, mob_state, self())
  end
end
