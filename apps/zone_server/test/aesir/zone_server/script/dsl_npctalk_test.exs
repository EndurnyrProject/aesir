defmodule Aesir.ZoneServer.Script.DslNpctalkTest do
  @moduledoc """
  Covers the `npctalk` overhead chat op: it broadcasts a `ChatMessage` in view
  range of the NPC's own placement, identically on an attached or detached ctx,
  and no-ops when there is no `npc_gid` or no resolvable placement.

  The `/3` arity adds rAthena's optional tail — a `:npc` name picking a
  different speaker and a `:target` scope (`:area`/`:map`/`:all`/`:self`, or
  the raw `bc_*` integer a transpiled script passes).
  """

  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import ExUnit.CaptureLog

  alias Aesir.Commons.InterServer.PubSub
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ChatMessage
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "prontera"

  defmodule TalkerNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 150, y: 150, sprite: 58, name: "Talker"}]

    @impl true
    def on_talk(ctx), do: ctx
  end

  defmodule HeraldNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 300, y: 300, sprite: 58, name: "Herald"}]

    @impl true
    def on_talk(ctx), do: ctx
  end

  setup :setup_ets_tables

  setup do
    on_exit(fn -> :persistent_term.erase(NpcRegistry) end)
    NpcRegistry.reload([TalkerNpc, HeraldNpc])

    placement = hd(TalkerNpc.spawn())
    gid = NpcRegistry.entity_id(placement)

    {:ok, gid: gid, placement: placement}
  end

  describe "npctalk/2" do
    test "delivers a ChatMessage to a player in range from a detached ctx", %{gid: gid} do
      register_player(1, x: 152, y: 150)
      ctx = Ctx.detached(TalkerNpc, gid)

      assert Dsl.npctalk(ctx, "Buy something?") == ctx

      assert_receive {:"$gen_cast",
                      {:send_packet, %ChatMessage{gid: ^gid, message: "Talker : Buy something?"}}}
    end

    test "a player out of range receives nothing", %{gid: gid} do
      register_player(1, x: 500, y: 500)
      ctx = Ctx.detached(TalkerNpc, gid)

      assert Dsl.npctalk(ctx, "Buy something?") == ctx

      refute_received {:"$gen_cast", {:send_packet, %ChatMessage{}}}
    end

    test "an empty map is a no-op returning ctx", %{gid: gid} do
      ctx = Ctx.detached(TalkerNpc, gid)

      assert Dsl.npctalk(ctx, "Anyone there?") == ctx
      refute_received {:"$gen_cast", {:send_packet, %ChatMessage{}}}
    end

    test "works identically from an attached ctx, using the NPC's placement not the player's",
         %{gid: gid} do
      register_player(1, x: 152, y: 150)
      away_game_state = %{PlayerState.new(character(2)) | x: 900, y: 900, map_name: @map}
      ctx = attached_ctx(away_game_state, gid)

      assert Dsl.npctalk(ctx, "Hello there") == ctx

      assert_receive {:"$gen_cast",
                      {:send_packet, %ChatMessage{gid: ^gid, message: "Talker : Hello there"}}}
    end

    test "a nil npc_gid warns and no-ops" do
      ctx = Ctx.detached(TalkerNpc, 1)
      detached_ctx = %{ctx | npc_gid: nil}

      log = capture_log(fn -> assert Dsl.npctalk(detached_ctx, "Hi") == detached_ctx end)

      assert log =~ "no npc_gid"
      refute_received {:"$gen_cast", {:send_packet, %ChatMessage{}}}
    end

    test "an unresolved npc_gid warns and no-ops" do
      ctx = Ctx.detached(TalkerNpc, 999_999)

      log = capture_log(fn -> assert Dsl.npctalk(ctx, "Hi") == ctx end)

      assert log =~ "not registered"
      refute_received {:"$gen_cast", {:send_packet, %ChatMessage{}}}
    end

    test "short-circuits on an already-halted ctx", %{gid: gid} do
      register_player(1, x: 152, y: 150)
      ctx = Ctx.halt(Ctx.detached(TalkerNpc, gid), :boom)

      assert Dsl.npctalk(ctx, "Hi") == ctx
      refute_received {:"$gen_cast", {:send_packet, %ChatMessage{}}}
    end
  end

  describe "npctalk/3 targets" do
    test "target: :self reaches only the attached player, not the NPC's view range", %{
      gid: gid
    } do
      register_player(1, x: 152, y: 150)
      listener = register_player(2, x: 151, y: 150)
      ctx = attached_ctx(listener, gid)

      assert Dsl.npctalk(ctx, "Just for you", target: :self) == ctx

      assert_receive {:"$gen_cast",
                      {:send_packet, %ChatMessage{gid: ^gid, message: "Talker : Just for you"}}}

      refute_received {:"$gen_cast", {:send_packet, %ChatMessage{}}}
    end

    test "the raw bc_self flag decodes to the same self target", %{gid: gid} do
      listener = register_player(1, x: 900, y: 900)
      ctx = attached_ctx(listener, gid)

      assert Dsl.npctalk(ctx, "Out of range", target: 3) == ctx

      assert_receive {:"$gen_cast",
                      {:send_packet, %ChatMessage{gid: ^gid, message: "Talker : Out of range"}}}
    end

    test "target: :self on a detached ctx warns and no-ops", %{gid: gid} do
      register_player(1, x: 152, y: 150)
      ctx = Ctx.detached(TalkerNpc, gid)

      log = capture_log(fn -> assert Dsl.npctalk(ctx, "Hi", target: :self) == ctx end)

      assert log =~ "no attached player"
      refute_received {:"$gen_cast", {:send_packet, %ChatMessage{}}}
    end

    test "target: :map reaches a player outside view range on the same map", %{gid: gid} do
      register_player(1, x: 900, y: 900)
      ctx = Ctx.detached(TalkerNpc, gid)

      assert Dsl.npctalk(ctx, "Map wide", target: :map) == ctx

      assert_receive {:"$gen_cast",
                      {:send_packet, %ChatMessage{gid: ^gid, message: "Talker : Map wide"}}}
    end

    test "target: :all publishes to the inter-server announce fan-out", %{gid: gid} do
      :ok = PubSub.subscribe_to_announcements()
      ctx = Ctx.detached(TalkerNpc, gid)

      assert Dsl.npctalk(ctx, "Everywhere", target: :all) == ctx

      assert_receive {:announcement, %ChatMessage{gid: ^gid, message: "Talker : Everywhere"}}
    end

    test "an unknown target warns and falls back to the area default", %{gid: gid} do
      register_player(1, x: 152, y: 150)
      ctx = Ctx.detached(TalkerNpc, gid)

      log = capture_log(fn -> assert Dsl.npctalk(ctx, "Hi", target: :nope) == ctx end)

      assert log =~ "unknown target"
      assert_receive {:"$gen_cast", {:send_packet, %ChatMessage{gid: ^gid}}}
    end
  end

  describe "npctalk/3 speaker" do
    test "npc: speaks as the named placement, not ctx.npc_gid", %{gid: gid} do
      register_player(1, x: 301, y: 300)
      herald_gid = NpcRegistry.entity_id(hd(HeraldNpc.spawn()))
      ctx = Ctx.detached(TalkerNpc, gid)

      assert Dsl.npctalk(ctx, "Hear ye", npc: "Herald") == ctx

      assert_receive {:"$gen_cast",
                      {:send_packet, %ChatMessage{gid: ^herald_gid, message: "Herald : Hear ye"}}}
    end

    test "an empty npc: name keeps the attached NPC as the speaker", %{gid: gid} do
      register_player(1, x: 152, y: 150)
      ctx = Ctx.detached(TalkerNpc, gid)

      assert Dsl.npctalk(ctx, "Still me", npc: "") == ctx

      assert_receive {:"$gen_cast",
                      {:send_packet, %ChatMessage{gid: ^gid, message: "Talker : Still me"}}}
    end

    test "an unknown npc: name warns and no-ops", %{gid: gid} do
      register_player(1, x: 152, y: 150)
      ctx = Ctx.detached(TalkerNpc, gid)

      log = capture_log(fn -> assert Dsl.npctalk(ctx, "Hi", npc: "Ghost") == ctx end)

      assert log =~ "unknown name"
      refute_received {:"$gen_cast", {:send_packet, %ChatMessage{}}}
    end
  end

  defp register_player(char_id, x: x, y: y) do
    game_state = %{PlayerState.new(character(char_id)) | x: x, y: y, map_name: @map}
    UnitRegistry.register_unit(:player, char_id, PlayerState, game_state, self())
    SpatialIndex.add_player(char_id, x, y, @map)
    game_state
  end

  defp attached_ctx(game_state, gid) do
    %Ctx{
      char_id: game_state.character_id,
      account_id: game_state.account_id,
      connection_pid: self(),
      game_state: game_state,
      source: {:npc, TalkerNpc.npc_id()},
      session_pid: self(),
      npc_gid: gid
    }
  end

  defp character(char_id) do
    %Character{
      id: char_id,
      account_id: 100 + char_id,
      name: "Char#{char_id}",
      last_map: @map,
      last_x: 150,
      last_y: 150,
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
