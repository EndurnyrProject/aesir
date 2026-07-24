defmodule Aesir.ZoneServer.Script.DetachedCtxTest do
  @moduledoc """
  Covers `Ctx.detached/2` and `Ctx.attached?/1`, and the no-player guards Task 3
  adds to the DSL: player-touching effects each independently re-check
  `game_state: nil` and halt `{:error, :no_player}` on a detached ctx (they do
  not rely on a prior op's `status`), so every op in a pipe halts on its own;
  once any op halts, later ops in the same pipe additionally short-circuit via
  the pre-existing `%Ctx{status: {:error, _}}` clause without re-checking
  `game_state`. Player reads raise instead, since they have no `status` to
  carry an error.

  `summon_mob/2` and `summon_random_mob/2` are the exception: Task 11 makes
  them detached-capable off the calling NPC's own placement, so their
  detached-ctx coverage (including the still-halting unresolvable-gid case)
  lives in `Aesir.ZoneServer.Integration.OnMyMobDeadTest` instead, alongside the rest
  of the OnMyMobDead owner-event feature.
  """

  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  defmodule DetachedTestNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 100, y: 100, dir: 0, sprite: 58, name: "Detached Test"}]

    @impl true
    def on_talk(ctx), do: ctx
  end

  @npc_gid 0x5000_1234

  describe "Ctx.detached/2" do
    test "builds a ctx with no player attached, carrying the NPC identity" do
      ctx = Ctx.detached(DetachedTestNpc, @npc_gid)

      assert ctx.char_id == nil
      assert ctx.account_id == nil
      assert ctx.connection_pid == nil
      assert ctx.game_state == nil
      assert ctx.session_pid == nil
      assert ctx.npc_gid == @npc_gid
      assert ctx.source == {:npc, DetachedTestNpc.npc_id()}
      assert ctx.status == :ok
    end
  end

  describe "Ctx.attached?/1" do
    test "false for a detached ctx" do
      refute Ctx.attached?(Ctx.detached(DetachedTestNpc, @npc_gid))
    end

    test "true for a ctx built from a player session" do
      ps = %PlayerState{character_id: 1, account_id: 1}
      ctx = Ctx.from_session(%{game_state: ps, connection_pid: self()}, {:item, 501})

      assert Ctx.attached?(ctx)
    end
  end

  describe "player-touching effect ops on a detached ctx" do
    test "warp/2 halts :no_player without relocating anything" do
      result = Dsl.warp(Ctx.detached(DetachedTestNpc, @npc_gid), {"prontera", 150, 150})

      assert result.status == {:error, :no_player}
      assert result.game_state == nil
    end

    test "give_item/3 halts :no_player without calling any session" do
      result = Dsl.give_item(Ctx.detached(DetachedTestNpc, @npc_gid), 501, 1)

      assert result.status == {:error, :no_player}
    end

    test "mes/2 halts :no_player without buffering the line" do
      result = Dsl.mes(Ctx.detached(DetachedTestNpc, @npc_gid), "hello")

      assert result.status == {:error, :no_player}
      assert result.page == []
    end

    test "next/1 halts :no_player without flushing or blocking" do
      result = Dsl.next(Ctx.detached(DetachedTestNpc, @npc_gid))

      assert result.status == {:error, :no_player}
    end

    test "close/1 halts :no_player without flushing" do
      result = Dsl.close(Ctx.detached(DetachedTestNpc, @npc_gid))

      assert result.status == {:error, :no_player}
    end

    test "select/2 halts :no_player and returns a nil choice without blocking" do
      {result, choice} = Dsl.select(Ctx.detached(DetachedTestNpc, @npc_gid), ["A", "B"])

      assert result.status == {:error, :no_player}
      assert choice == nil
    end

    test "input/2 halts :no_player and returns a nil value without blocking" do
      {result, value} = Dsl.input(Ctx.detached(DetachedTestNpc, @npc_gid), :int)

      assert result.status == {:error, :no_player}
      assert value == nil
    end

    test "subsequent ops after the first halt short-circuit via the existing status clause" do
      ctx =
        Ctx.detached(DetachedTestNpc, @npc_gid)
        |> Dsl.warp({"prontera", 150, 150})
        |> Dsl.give_item(501, 1)
        |> Dsl.mes("hello")

      assert ctx.status == {:error, :no_player}
      assert ctx.page == []
    end
  end

  describe "remaining player-touching effects on a detached ctx" do
    test "heal/2 halts :no_player" do
      result = Dsl.heal(Ctx.detached(DetachedTestNpc, @npc_gid), hp: 10)

      assert result.status == {:error, :no_player}
    end

    test "percent_heal/2 halts :no_player" do
      result = Dsl.percent_heal(Ctx.detached(DetachedTestNpc, @npc_gid), hp: 10)

      assert result.status == {:error, :no_player}
    end

    test "sc_start/4 halts :no_player" do
      result = Dsl.sc_start(Ctx.detached(DetachedTestNpc, @npc_gid), :sc_blessing, 1_000, 1)

      assert result.status == {:error, :no_player}
    end

    test "sc_end/2 halts :no_player instead of silently succeeding" do
      result = Dsl.sc_end(Ctx.detached(DetachedTestNpc, @npc_gid), :sc_poison)

      assert result.status == {:error, :no_player}
    end

    test "cure/2 halts :no_player (delegates to sc_end/2)" do
      result = Dsl.cure(Ctx.detached(DetachedTestNpc, @npc_gid), :sc_poison)

      assert result.status == {:error, :no_player}
    end

    test "itemskill/3 halts :no_player" do
      result = Dsl.itemskill(Ctx.detached(DetachedTestNpc, @npc_gid), 14, [])

      assert result.status == {:error, :no_player}
    end

    test "refine/4 returns {:error, :no_player}, its tagged-result error shape" do
      result = Dsl.refine(Ctx.detached(DetachedTestNpc, @npc_gid), 0, :normal)

      assert result == {:error, :no_player}
    end
  end

  describe "player reads on a detached ctx" do
    test "zeny/1 raises ArgumentError naming the op" do
      assert_raise ArgumentError, ~r/zeny\/1/, fn ->
        Dsl.zeny(Ctx.detached(DetachedTestNpc, @npc_gid))
      end
    end

    test "base_level/1 raises ArgumentError naming the op" do
      assert_raise ArgumentError, ~r/base_level\/1/, fn ->
        Dsl.base_level(Ctx.detached(DetachedTestNpc, @npc_gid))
      end
    end

    test "count_item/2 raises ArgumentError naming the op" do
      assert_raise ArgumentError, ~r/count_item\/2/, fn ->
        Dsl.count_item(Ctx.detached(DetachedTestNpc, @npc_gid), 501)
      end
    end

    test "position/1 raises ArgumentError naming the op" do
      assert_raise ArgumentError, ~r/position\/1/, fn ->
        Dsl.position(Ctx.detached(DetachedTestNpc, @npc_gid))
      end
    end

    test "get_char_var/3 raises ArgumentError naming the op" do
      assert_raise ArgumentError, ~r/get_char_var\/3/, fn ->
        Dsl.get_char_var(Ctx.detached(DetachedTestNpc, @npc_gid), :some_var)
      end
    end
  end
end
