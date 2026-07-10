defmodule Aesir.ZoneServer.NpcEventsIntegrationTest do
  @moduledoc """
  End-to-end coverage for the "NPC On Events" feature: each scenario chains
  several event mechanisms together the way real rAthena content does,
  rather than exercising one primitive in isolation (already covered by
  `on_touch_test.exs`, `on_my_mob_dead_test.exs`, `on_init_test.exs`,
  `npc_visibility_test.exs`, `dsl_events_test.exs`, `dsl_npctalk_test.exs`,
  `session_test.exs`, `events_test.exs` and `clock_scheduler_test.exs`).

  1. A touch-area warper with no `OnTouch` label falls back to `on_talk/1`,
     which warps the player away; the warp resets touch hysteresis
     (`inside_npc_areas`), so walking back into the same rect fires again.
  2. `OnInit` arms the NPC's own timer (`initnpctimer`); its `OnTimer` label
     `npctalk`s to a nearby player and self-stops (`stopnpctimer`) before a
     later label would otherwise fire.
  3. `donpcevent` choreography: NPC A dispatches NPC B, which `enablenpc`s a
     disabled NPC C; a standing in-range player sees C's spawn packet.
  4. A detached handler `summon_mob`s a mob tagged `event:
     "Self::OnMyMobDead"` at its own placement; a real player's kill runs the
     owner event attached to the killer's own session, mutating a char var.
  5. `OnInit` composed with `disablenpc`: the NPC is disabled before any
     player ever sees it.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ChatMessage
  alias Aesir.Net.UnitSpawn
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.MobManagement
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Npc.Events
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Session, as: NpcSession
  alias Aesir.ZoneServer.Npc.Warps
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  defmodule TouchWarperNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 120, y: 60, sprite: 45, name: "Warper", trigger: {1, 1}}]

    @impl true
    def on_talk(ctx) do
      send(:npc_events_integration_probe, :warped)
      warp(ctx, {"prontera", 150, 150})
    end
  end

  defmodule SelfStoppingTimerNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 130, y: 60, sprite: 58, name: "TimerTalker"}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnInit", ctx), do: initnpctimer(ctx)

    def on_event("OnTimer50", ctx) do
      ctx
      |> npctalk("Tick!")
      |> stopnpctimer()
    end

    def on_event("OnTimer250", ctx) do
      send(:npc_events_integration_probe, :should_not_fire)
      ctx
    end
  end

  defmodule ChoreoNpcA do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 140, y: 60, sprite: 58, name: "ChoreoA"}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnStart", ctx), do: donpcevent(ctx, "ChoreoB::OnStart")
  end

  defmodule ChoreoNpcB do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 141, y: 60, sprite: 58, name: "ChoreoB"}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnStart", ctx), do: enablenpc(ctx, "ChoreoC")
  end

  defmodule ChoreoNpcC do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 142, y: 60, sprite: 58, name: "ChoreoC"}]

    @impl true
    def on_talk(ctx), do: ctx
  end

  defmodule SummonerNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 160, y: 60, sprite: 58, name: "Summoner"}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnSummon", ctx) do
      summon_mob(ctx, mob_id: 1002, event: "Summoner::OnMyMobDead")
    end

    def on_event("OnMyMobDead", ctx) do
      ctx = set_char_var(ctx, :last_kill_owner, ctx.char_id)
      send(:npc_events_integration_probe, {:owner_event_done, ctx.char_id})
      ctx
    end
  end

  defmodule SelfDisablingNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 150, y: 70, sprite: 58, name: "SelfDisabling"}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnInit", ctx), do: disablenpc(ctx)
  end

  setup :set_mimic_global

  setup do
    Process.register(self(), :npc_events_integration_probe)
    :ok
  end

  describe "touch-area warper: OnTouch-less fallback warps and resets hysteresis" do
    # Isolates this describe's real-time movement/warp cycle from the actual,
    # permanently-running "prontera" `Map.Coordinator` (started by boot's
    # `MapManager`, sharing `IntegrationCase`'s default un-seeded tables):
    # without a fresh per-test `EtsTable` seed, the live coordinator's own
    # broadcast tick races this test's direct `UnitRegistry` reads/writes for
    # the same char_id, flickering the position back and forth. See
    # `Aesir.TestEtsSetup` and `on_touch_test.exs`/`warp_integration_test.exs`,
    # which take on this same isolation directly instead of `IntegrationCase`.
    setup :isolate_world_state

    setup do
      NpcRegistry.reload([TouchWarperNpc])
      gid = gid_for(TouchWarperNpc)

      on_exit(fn ->
        :persistent_term.erase(NpcRegistry)
        :ets.delete(:npc_session_flags, gid)
      end)

      stub(SpatialIndex, :get_players_in_range, fn _, _, _, _ -> [] end)
      stub(SpatialIndex, :get_units_in_range, fn _, _, _, _, _ -> [] end)
      stub(SpatialIndex, :update_visibility, fn _, _, _ -> :ok end)
      stub(SpatialIndex, :get_visible_players, fn _ -> [] end)
      stub(SpatialIndex, :remove_player, fn _ -> :ok end)
      stub(SpatialIndex, :clear_visibility, fn _ -> :ok end)
      stub(Broadcast, :to_players, fn _, _, _ -> :ok end)
      stub(Broadcast, :subscribe_mob_despawns, fn _ -> :ok end)
      stub(Broadcast, :unsubscribe_mob_despawns, fn _ -> :ok end)
      stub(Warps, :for_map, fn _ -> :error end)

      {:ok, gid: gid}
    end

    test "walking into the rect warps via on_talk; walking back after the warp fires again", %{
      gid: gid
    } do
      char_id = 9101

      game_state =
        char_id
        |> character()
        |> PlayerState.new()
        |> Map.put(:x, 117)
        |> Map.put(:y, 60)
        |> Map.put(:walk_path, [{118, 60}, {119, 60}])
        |> Map.put(:movement_state, :moving)

      register_moving_player(char_id, game_state)

      state = %{game_state: game_state, connection_pid: self(), interaction_lock: nil}

      {:noreply, state} = PlayerSession.handle_info(:movement_tick, state)
      refute_receive :warped, 50
      refute MapSet.member?(state.game_state.inside_npc_areas, gid)

      {:noreply, state} = PlayerSession.handle_info(:movement_tick, state)
      assert_receive :warped
      assert {_pid, ref, ^gid} = state.interaction_lock

      assert_receive {:DOWN, ^ref, :process, pid, reason}
      {:noreply, state} = PlayerSession.handle_info({:DOWN, ref, :process, pid, reason}, state)
      assert state.interaction_lock == nil

      {:ok, {PlayerState, warped_gs, _pid}} = UnitRegistry.get_unit(:player, char_id)
      assert warped_gs.map_name == "prontera"
      assert {warped_gs.x, warped_gs.y} == {150, 150}
      refute MapSet.member?(warped_gs.inside_npc_areas, gid)

      return_gs =
        warped_gs
        |> Map.put(:x, 117)
        |> Map.put(:y, 60)
        |> Map.put(:walk_path, [{118, 60}, {119, 60}])
        |> Map.put(:movement_state, :moving)

      state = %{state | game_state: return_gs}

      {:noreply, state} = PlayerSession.handle_info(:movement_tick, state)
      refute_receive :warped, 50

      {:noreply, state} = PlayerSession.handle_info(:movement_tick, state)
      assert_receive :warped
      assert MapSet.member?(state.game_state.inside_npc_areas, gid)
    end
  end

  describe "self-stopping OnInit timer that npctalks" do
    setup do
      NpcRegistry.reload([SelfStoppingTimerNpc])
      gid = gid_for(SelfStoppingTimerNpc)

      on_exit(fn ->
        :persistent_term.erase(NpcRegistry)
        :ets.delete(:npc_session_flags, gid)
      end)

      {:ok, gid: gid}
    end

    test "OnInit arms its own timer; OnTimer50 npctalks then stops itself before OnTimer250", %{
      gid: gid
    } do
      register_observer(9201, 132, 60)

      assert :ok = Events.run_on_init()

      assert_receive {:"$gen_cast",
                      {:send_packet, %ChatMessage{gid: ^gid, message: "TimerTalker : Tick!"}}},
                     400

      refute_receive :should_not_fire, 400

      frozen = NpcSession.get_timer(gid)
      Process.sleep(30)
      assert NpcSession.get_timer(gid) == frozen
    end
  end

  describe "donpcevent choreography enables a disabled NPC" do
    setup do
      NpcRegistry.reload([ChoreoNpcA, ChoreoNpcB, ChoreoNpcC])
      gids = Enum.map([ChoreoNpcA, ChoreoNpcB, ChoreoNpcC], &gid_for/1)

      on_exit(fn ->
        :persistent_term.erase(NpcRegistry)
        Enum.each(gids, &:ets.delete(:npc_session_flags, &1))
      end)

      {:ok, gid_c: gid_for(ChoreoNpcC)}
    end

    test "A donpcevents B, which enablenpcs C; an in-range player sees C spawn", %{gid_c: gid_c} do
      NpcSession.set_enabled(gid_c, false)
      register_observer(9301, 142, 62)

      assert :ok = Events.trigger("ChoreoA::OnStart")

      assert_receive {:"$gen_cast", {:send_packet, %UnitSpawn{gid: ^gid_c, name: "ChoreoC"}}},
                     500
    end
  end

  describe "OnMyMobDead quest flow: detached summon reaches the real killer's char vars" do
    setup do
      NpcRegistry.reload([SummonerNpc])
      gid = gid_for(SummonerNpc)

      on_exit(fn ->
        :persistent_term.erase(NpcRegistry)
        :ets.delete(:npc_session_flags, gid)
      end)

      :ok
    end

    test "a detached summon tags an owner event; a real player's kill runs it attached" do
      test_pid = self()

      stub(Coordinator, :summon_mob, fn map_name, mob_id, x, y, opts ->
        {:ok, mob_data} = MobManagement.get_mob_by_id(mob_id)
        instance_id = System.unique_integer([:positive])

        spawn_ref = %MobSpawn{
          mob: mob_id,
          amount: 1,
          respawn_time: 5_000,
          spawn_area: %MobSpawn.SpawnArea{x: x, y: y}
        }

        mob_state =
          instance_id
          |> MobState.new(mob_data, spawn_ref, map_name, x, y)
          |> MobState.set_owner_event(Keyword.get(opts, :event))
          |> Map.put(:hp, 1)
          |> Map.put(:max_hp, 1)

        {:ok, pid} = MobSession.start_link(%{state: mob_state, awake: false})
        UnitRegistry.register_unit(:mob, instance_id, MobState, mob_state, pid)
        SpatialIndex.add_unit(:mob, instance_id, x, y, map_name)

        send(test_pid, {:mob_summoned, instance_id, pid})
        {:ok, instance_id}
      end)

      # Real MobSession death calls Coordinator.mob_died/3, a GenServer.cast to
      # the live "prontera" Coordinator process; stubbing only replaces that
      # mailbox hop (to avoid racing the shared, permanently-running boot-time
      # coordinator, same reasoning as isolate_world_state/1 above) by running
      # its own handle_cast/2 inline on a throwaway struct. Everything past
      # that dispatch -- dispatch_owner_event, PlayerSession.run_attached_event,
      # the attached Interaction, set_char_var -- is the real, unstubbed path.
      stub(Coordinator, :mob_died, fn map_name, instance_id, killer_char_id ->
        Coordinator.handle_cast(
          {:mob_died, instance_id, killer_char_id},
          %Coordinator{map_name: map_name, respawn_timers: %{}}
        )

        :ok
      end)

      killer = start_player_session(id: 9501)

      assert :ok = Events.trigger("Summoner::OnSummon")
      assert_receive {:mob_summoned, _instance_id, mob_pid}, 500

      MobSession.apply_damage(mob_pid, 999, killer.character.id)

      assert_receive {:owner_event_done, char_id}, 500
      assert char_id == killer.character.id

      assert get_player_state(killer.pid).vars["last_kill_owner"] == killer.character.id
    end
  end

  describe "OnInit composes with disablenpc: never visible from the very first tick" do
    setup do
      NpcRegistry.reload([SelfDisablingNpc])
      gid = gid_for(SelfDisablingNpc)

      on_exit(fn ->
        :persistent_term.erase(NpcRegistry)
        :ets.delete(:npc_session_flags, gid)
      end)

      stub(SpatialIndex, :get_players_in_range, fn _, _, _, _ -> [] end)
      stub(SpatialIndex, :get_units_in_range, fn _, _, _, _, _ -> [] end)
      stub(SpatialIndex, :update_visibility, fn _, _, _ -> :ok end)
      stub(Broadcast, :to_players, fn _, _, _ -> :ok end)

      {:ok, gid: gid}
    end

    test "a player walking into range never sees the NPC", %{gid: gid} do
      assert :ok = Events.run_on_init()
      refute NpcSession.visible?(gid)

      game_state = %{PlayerState.new(character(9401)) | x: 150, y: 70, map_name: "prontera"}
      UnitRegistry.register_unit(:player, 9401, PlayerState, game_state, self())

      new_state = MovementHandler.handle_visibility_update(game_state)

      refute_received {:"$gen_cast", {:send_packet, %UnitSpawn{gid: ^gid}}}
      refute MapSet.member?(new_state.visible_npcs, gid)
    end
  end

  defp isolate_world_state(tags), do: Aesir.TestEtsSetup.setup_ets_tables(tags)

  defp gid_for(module) do
    {^module, placement} = Enum.find(NpcRegistry.entries(), fn {mod, _} -> mod == module end)
    NpcRegistry.entity_id(placement)
  end

  defp register_moving_player(char_id, game_state) do
    UnitRegistry.register_unit(:player, char_id, PlayerState, game_state, self())
    SpatialIndex.add_unit(:player, char_id, game_state.x, game_state.y, game_state.map_name)
    Movement.drain_dirty(game_state.map_name)
  end

  defp register_observer(char_id, x, y) do
    game_state = %{PlayerState.new(character(char_id)) | x: x, y: y, map_name: "prontera"}
    UnitRegistry.register_unit(:player, char_id, PlayerState, game_state, self())
    SpatialIndex.add_player(char_id, x, y, "prontera")
    :ok
  end

  defp character(char_id) do
    %Character{
      id: char_id,
      account_id: 100 + char_id,
      name: "Char#{char_id}",
      last_map: "prontera",
      last_x: 50,
      last_y: 50,
      sex: "M",
      hair: 1,
      hair_color: 0,
      clothes_color: 0,
      head_mid: 0,
      head_bottom: 0,
      robe: 0,
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 1,
      job_level: 1,
      class: 0
    }
  end
end
