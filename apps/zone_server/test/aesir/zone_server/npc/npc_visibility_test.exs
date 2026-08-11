defmodule Aesir.ZoneServer.Npc.NpcVisibilityTest do
  @moduledoc """
  Covers the Task 8 `enablenpc`/`disablenpc`/`hideonnpc`/`hideoffnpc` DSL ops
  and the engine wiring that makes a disabled or hidden NPC invisible,
  unclickable, and immediately vanish/spawn for a player already standing in
  range: an NPC is visible iff enabled and not hidden, and `enabled`/`hidden`
  are independent flags (rAthena semantics), so the matrix (disable+hideoff,
  hideon+enable, ...) is tested explicitly.
  """

  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup
  import ExUnit.CaptureLog

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.UnitDespawn
  alias Aesir.Net.UnitSpawn
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Session, as: NpcSession
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.NpcInteractionHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "prontera"

  defmodule ToggleNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 300, y: 300, sprite: 58, name: "Toggle"}]

    @impl true
    def on_talk(ctx) do
      send(:npc_visibility_probe, :talked)
      ctx
    end
  end

  defmodule DupNpcA do
    use Aesir.ZoneServer.Npc,
      spawn: [
        %{map: "prontera", x: 301, y: 301, sprite: 58, name: "Dup", unique_name: "ToggleDup"}
      ]

    @impl true
    def on_talk(ctx), do: ctx
  end

  defmodule DupNpcB do
    use Aesir.ZoneServer.Npc,
      spawn: [
        %{map: "prontera", x: 302, y: 302, sprite: 58, name: "Dup", unique_name: "ToggleDup"}
      ]

    @impl true
    def on_talk(ctx), do: ctx
  end

  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Aesir.TestProbe.register!(:npc_visibility_probe)
    NpcRegistry.reload([ToggleNpc, DupNpcA, DupNpcB])

    # `:npc_session_flags` is the one real table `Npc.Session` owns
    # (`SessionSupervisor`-owned, not per-test-seeded like the `EtsTable`
    # tables), so rows this file writes for these three gids would otherwise
    # survive into later tests. `NpcRegistry.reload/1` only clears rows for
    # gids with a *running* Session process — the "immediate visibility
    # transition broadcasts" describe below calls `handle_call/3` directly on
    # a bare struct, writing a row with no owning process to terminate — so
    # clear them here too, unconditionally. Computed once, before
    # `persistent_term.erase/1` below drops the registry these gids are
    # derived from.
    gids = Enum.map([ToggleNpc, DupNpcA, DupNpcB], &gid_for/1)

    on_exit(fn ->
      :persistent_term.erase(NpcRegistry)
      Enum.each(gids, &:ets.delete(:npc_session_flags, &1))
    end)

    :ok
  end

  describe "enablenpc/1 and disablenpc/1" do
    test "disablenpc makes the NPC not visible; enablenpc restores it" do
      gid = gid_for(ToggleNpc)
      ctx = npc_ctx(gid)

      assert Dsl.disablenpc(ctx) == ctx
      refute NpcSession.enabled?(gid)
      refute NpcSession.visible?(gid)

      assert Dsl.enablenpc(ctx) == ctx
      assert NpcSession.enabled?(gid)
      assert NpcSession.visible?(gid)
    end

    test "a nil npc_gid warns and no-ops" do
      ctx = npc_ctx(nil)

      log = capture_log(fn -> assert Dsl.enablenpc(ctx) == ctx end)
      assert log =~ "no npc_gid"

      log = capture_log(fn -> assert Dsl.disablenpc(ctx) == ctx end)
      assert log =~ "no npc_gid"
    end

    test "short-circuits on an already-halted ctx" do
      ctx = Ctx.halt(npc_ctx(gid_for(ToggleNpc)), :boom)

      assert Dsl.enablenpc(ctx) == ctx
      assert Dsl.disablenpc(ctx) == ctx
    end
  end

  describe "hideonnpc/1 and hideoffnpc/1" do
    test "hideonnpc makes the NPC not visible independent of enabled; hideoffnpc restores it" do
      gid = gid_for(ToggleNpc)
      ctx = npc_ctx(gid)

      assert Dsl.hideonnpc(ctx) == ctx
      assert NpcSession.hidden?(gid)
      assert NpcSession.enabled?(gid)
      refute NpcSession.visible?(gid)

      assert Dsl.hideoffnpc(ctx) == ctx
      refute NpcSession.hidden?(gid)
      assert NpcSession.visible?(gid)
    end

    test "a nil npc_gid warns and no-ops" do
      ctx = npc_ctx(nil)

      log = capture_log(fn -> assert Dsl.hideonnpc(ctx) == ctx end)
      assert log =~ "no npc_gid"

      log = capture_log(fn -> assert Dsl.hideoffnpc(ctx) == ctx end)
      assert log =~ "no npc_gid"
    end

    test "short-circuits on an already-halted ctx" do
      ctx = Ctx.halt(npc_ctx(gid_for(ToggleNpc)), :boom)

      assert Dsl.hideonnpc(ctx) == ctx
      assert Dsl.hideoffnpc(ctx) == ctx
    end
  end

  describe "cloakonnpc/1 and cloakoffnpcself/1" do
    test "cloakonnpc hides independent of enabled; cloakoffnpcself restores it" do
      gid = gid_for(ToggleNpc)
      ctx = npc_ctx(gid)

      assert Dsl.cloakonnpc(ctx) == ctx
      assert NpcSession.hidden?(gid)
      assert NpcSession.enabled?(gid)
      refute NpcSession.visible?(gid)

      assert Dsl.cloakoffnpcself(ctx) == ctx
      refute NpcSession.hidden?(gid)
      assert NpcSession.visible?(gid)
    end

    test "a nil npc_gid warns and no-ops" do
      ctx = npc_ctx(nil)

      log = capture_log(fn -> assert Dsl.cloakonnpc(ctx) == ctx end)
      assert log =~ "no npc_gid"

      log = capture_log(fn -> assert Dsl.cloakoffnpcself(ctx) == ctx end)
      assert log =~ "no npc_gid"
    end

    test "short-circuits on an already-halted ctx" do
      ctx = Ctx.halt(npc_ctx(gid_for(ToggleNpc)), :boom)

      assert Dsl.cloakonnpc(ctx) == ctx
      assert Dsl.cloakoffnpcself(ctx) == ctx
    end
  end

  describe "named-target arity: enablenpc/2, disablenpc/2, hideonnpc/2, hideoffnpc/2" do
    test "disablenpc/2 and enablenpc/2 apply to every placement sharing the name" do
      gid_a = gid_for(DupNpcA)
      gid_b = gid_for(DupNpcB)
      ctx = npc_ctx(nil)

      assert Dsl.disablenpc(ctx, "ToggleDup") == ctx
      refute NpcSession.enabled?(gid_a)
      refute NpcSession.enabled?(gid_b)

      assert Dsl.enablenpc(ctx, "ToggleDup") == ctx
      assert NpcSession.enabled?(gid_a)
      assert NpcSession.enabled?(gid_b)
    end

    test "hideonnpc/2 and hideoffnpc/2 apply to every placement sharing the name" do
      gid_a = gid_for(DupNpcA)
      gid_b = gid_for(DupNpcB)
      ctx = npc_ctx(nil)

      assert Dsl.hideonnpc(ctx, "ToggleDup") == ctx
      assert NpcSession.hidden?(gid_a)
      assert NpcSession.hidden?(gid_b)

      assert Dsl.hideoffnpc(ctx, "ToggleDup") == ctx
      refute NpcSession.hidden?(gid_a)
      refute NpcSession.hidden?(gid_b)
    end

    test "cloakonnpc/2 and cloakoffnpcself/2 apply to every placement sharing the name" do
      gid_a = gid_for(DupNpcA)
      gid_b = gid_for(DupNpcB)
      ctx = npc_ctx(nil)

      assert Dsl.cloakonnpc(ctx, "ToggleDup") == ctx
      assert NpcSession.hidden?(gid_a)
      assert NpcSession.hidden?(gid_b)

      assert Dsl.cloakoffnpcself(ctx, "ToggleDup") == ctx
      refute NpcSession.hidden?(gid_a)
      refute NpcSession.hidden?(gid_b)
    end

    test "an unknown name logs a warning and no-ops" do
      ctx = npc_ctx(nil)

      for op <- [:enablenpc, :disablenpc, :hideonnpc, :hideoffnpc, :cloakonnpc, :cloakoffnpcself] do
        log = capture_log(fn -> assert apply(Dsl, op, [ctx, "Nowhere"]) == ctx end)
        assert log =~ "unknown name"
      end
    end

    test "short-circuits on an already-halted ctx" do
      ctx = Ctx.halt(npc_ctx(nil), :boom)

      assert Dsl.enablenpc(ctx, "ToggleDup") == ctx
      assert Dsl.disablenpc(ctx, "ToggleDup") == ctx
      assert Dsl.hideonnpc(ctx, "ToggleDup") == ctx
      assert Dsl.hideoffnpc(ctx, "ToggleDup") == ctx
    end
  end

  describe "visibility matrix" do
    test "visible iff enabled and not hidden, for every combination of the two flags" do
      gid = gid_for(ToggleNpc)

      for {enabled?, hidden?, expected} <- [
            {true, false, true},
            {true, true, false},
            {false, false, false},
            {false, true, false}
          ] do
        NpcSession.set_enabled(gid, enabled?)
        NpcSession.set_hidden(gid, hidden?)

        assert NpcSession.visible?(gid) == expected,
               "expected visible?/1 == #{expected} for enabled=#{enabled?}, hidden=#{hidden?}"
      end
    end

    test "disable+hideoff stays invisible until enablenpc" do
      gid = gid_for(ToggleNpc)
      ctx = npc_ctx(gid)

      assert Dsl.disablenpc(ctx) == ctx
      assert Dsl.hideoffnpc(ctx) == ctx
      refute NpcSession.visible?(gid)

      assert Dsl.enablenpc(ctx) == ctx
      assert NpcSession.visible?(gid)
    end
  end

  describe "movement diff visibility" do
    setup do
      stub(SpatialIndex, :get_players_in_range, fn _, _, _, _ -> [] end)
      stub(SpatialIndex, :get_units_in_range, fn _, _, _, _, _ -> [] end)
      stub(SpatialIndex, :update_visibility, fn _, _, _ -> :ok end)
      stub(Broadcast, :to_players, fn _, _, _ -> :ok end)
      :ok
    end

    test "a disabled NPC is filtered out: never spawned, never left in visible_npcs" do
      gid = gid_for(ToggleNpc)
      NpcSession.set_enabled(gid, false)

      game_state = %{PlayerState.new(character(1)) | x: 300, y: 300, map_name: @map}
      UnitRegistry.register_unit(:player, 1, PlayerState, game_state, self())

      new_state = MovementHandler.handle_visibility_update(game_state)

      refute_received {:"$gen_cast", {:send_packet, %UnitSpawn{gid: ^gid}}}
      refute MapSet.member?(new_state.visible_npcs, gid)
    end

    test "a hidden NPC is filtered out the same way" do
      gid = gid_for(ToggleNpc)
      NpcSession.set_hidden(gid, true)

      game_state = %{PlayerState.new(character(1)) | x: 300, y: 300, map_name: @map}
      UnitRegistry.register_unit(:player, 1, PlayerState, game_state, self())

      new_state = MovementHandler.handle_visibility_update(game_state)

      refute_received {:"$gen_cast", {:send_packet, %UnitSpawn{gid: ^gid}}}
      refute MapSet.member?(new_state.visible_npcs, gid)
    end

    test "re-enabling makes the next diff spawn it again" do
      gid = gid_for(ToggleNpc)
      NpcSession.set_enabled(gid, false)

      game_state = %{PlayerState.new(character(1)) | x: 300, y: 300, map_name: @map}
      UnitRegistry.register_unit(:player, 1, PlayerState, game_state, self())

      disabled_state = MovementHandler.handle_visibility_update(game_state)
      refute MapSet.member?(disabled_state.visible_npcs, gid)

      NpcSession.set_enabled(gid, true)
      new_state = MovementHandler.handle_visibility_update(disabled_state)

      assert_received {:"$gen_cast", {:send_packet, %UnitSpawn{gid: ^gid}}}
      assert MapSet.member?(new_state.visible_npcs, gid)
    end
  end

  describe "immediate visibility transition broadcasts" do
    # `Npc.Session` broadcasts on its own process (started under the app's
    # long-lived `SessionDynamicSupervisor`, unrelated to this test's process
    # tree), so going through the full `ensure_started/1` + `GenServer.call`
    # round trip would run the broadcast against a *different* process's view
    # of the per-test seeded ETS tables than the one this test just set up.
    # Exercising `Session.handle_call/3` directly (same technique as
    # `MobSessionDropTest`) runs it here instead, so the real, per-test
    # `SpatialIndex`/`UnitRegistry` resolve correctly and the packet cast
    # lands for real in this test's mailbox.
    defp session_state(gid) do
      %NpcSession{gid: gid, on_fire: fn _gid, _label -> :ok end}
    end

    defp register_player(char_id, x: x, y: y) do
      game_state = %{PlayerState.new(character(char_id)) | x: x, y: y, map_name: @map}
      UnitRegistry.register_unit(:player, char_id, PlayerState, game_state, self())
      SpatialIndex.add_player(char_id, x, y, @map)
      :ok
    end

    test "disablenpc vanishes an in-range standing player immediately; enablenpc respawns it" do
      gid = gid_for(ToggleNpc)
      register_player(1, x: 302, y: 300)

      {:reply, :ok, disabled_state} =
        NpcSession.handle_call({:set_enabled, false}, {self(), make_ref()}, session_state(gid))

      assert_receive {:"$gen_cast", {:send_packet, %UnitDespawn{gid: ^gid}}}

      {:reply, :ok, _state} =
        NpcSession.handle_call({:set_enabled, true}, {self(), make_ref()}, disabled_state)

      assert_receive {:"$gen_cast", {:send_packet, %UnitSpawn{gid: ^gid, name: "Toggle"}}}
    end

    test "hideonnpc vanishes an in-range standing player immediately; hideoffnpc respawns it" do
      gid = gid_for(ToggleNpc)
      register_player(1, x: 302, y: 300)

      {:reply, :ok, hidden_state} =
        NpcSession.handle_call({:set_hidden, true}, {self(), make_ref()}, session_state(gid))

      assert_receive {:"$gen_cast", {:send_packet, %UnitDespawn{gid: ^gid}}}

      {:reply, :ok, _state} =
        NpcSession.handle_call({:set_hidden, false}, {self(), make_ref()}, hidden_state)

      assert_receive {:"$gen_cast", {:send_packet, %UnitSpawn{gid: ^gid, name: "Toggle"}}}
    end

    test "a player out of range receives nothing" do
      gid = gid_for(ToggleNpc)
      register_player(1, x: 900, y: 900)

      {:reply, :ok, _state} =
        NpcSession.handle_call({:set_enabled, false}, {self(), make_ref()}, session_state(gid))

      refute_received {:"$gen_cast", {:send_packet, %UnitDespawn{}}}
    end

    test "a flag change that doesn't flip effective visibility broadcasts nothing" do
      gid = gid_for(ToggleNpc)
      register_player(1, x: 302, y: 300)

      {:reply, :ok, disabled_state} =
        NpcSession.handle_call({:set_enabled, false}, {self(), make_ref()}, session_state(gid))

      assert_receive {:"$gen_cast", {:send_packet, %UnitDespawn{gid: ^gid}}}

      # Already invisible (disabled): hiding it too is false->false, no new broadcast.
      {:reply, :ok, _state} =
        NpcSession.handle_call({:set_hidden, true}, {self(), make_ref()}, disabled_state)

      refute_receive {:"$gen_cast", {:send_packet, _packet}}, 100
    end
  end

  describe "click gating" do
    test "clicking a disabled NPC starts no Interaction" do
      gid = gid_for(ToggleNpc)
      NpcSession.set_enabled(gid, false)

      {:noreply, new_state} = NpcInteractionHandler.handle_talk(gid, talk_state())

      assert new_state.interaction_lock == nil
      refute_receive :talked, 100
    end

    test "clicking a hidden (but enabled) NPC starts no Interaction" do
      gid = gid_for(ToggleNpc)
      NpcSession.set_hidden(gid, true)

      {:noreply, new_state} = NpcInteractionHandler.handle_talk(gid, talk_state())

      assert new_state.interaction_lock == nil
      refute_receive :talked, 100
    end

    test "clicking a visible NPC starts an Interaction as usual" do
      gid = gid_for(ToggleNpc)

      {:noreply, new_state} = NpcInteractionHandler.handle_talk(gid, talk_state())

      assert {_pid, _ref, ^gid} = new_state.interaction_lock
      assert_receive :talked, 200
    end
  end

  defp gid_for(module) do
    {^module, placement} = Enum.find(NpcRegistry.entries(), fn {mod, _} -> mod == module end)
    NpcRegistry.entity_id(placement)
  end

  defp npc_ctx(gid) do
    %Ctx{
      char_id: nil,
      account_id: nil,
      connection_pid: nil,
      game_state: nil,
      source: {:npc, :test_npc},
      npc_gid: gid
    }
  end

  defp talk_state do
    game_state = %{PlayerState.new(character(1)) | map_name: @map}
    %{game_state: game_state, connection_pid: self(), interaction_lock: nil}
  end

  defp character(char_id) do
    %Character{
      id: char_id,
      account_id: 100 + char_id,
      name: "Char#{char_id}",
      last_map: @map,
      last_x: 300,
      last_y: 300,
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
