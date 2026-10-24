defmodule Aesir.ZoneServer.Script.DetachedCtxTest do
  @moduledoc """
  Covers `Ctx.detached/2` and `Ctx.attached?/1`, and the no-player guards Task 3
  adds to the DSL: a command that needs the attached player ends the script on a
  detached ctx (the reference's "player not attached" END), by throwing
  `{:script_end, ctx}` with `ctx.status == {:error, :no_player}`, so the rest of
  the pipe never runs. Reads end the script the same way. Commands that do not
  need a player (`sc_start`, `sc_end`) do nothing and the script goes on.

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

  defp ended(fun) do
    assert {:script_end, %Ctx{} = ctx} = catch_throw(fun.())
    ctx
  end

  defp detached, do: Ctx.detached(DetachedTestNpc, @npc_gid)

  describe "player-touching effect ops on a detached ctx" do
    test "warp/2 ends the script with :no_player without relocating anything" do
      result = ended(fn -> Dsl.warp(detached(), {"prontera", 150, 150}) end)

      assert result.status == {:error, :no_player}
      assert result.game_state == nil
    end

    test "give_item/3 ends the script with :no_player without calling any session" do
      assert ended(fn -> Dsl.give_item(detached(), 501, 1) end).status == {:error, :no_player}
    end

    test "mes/2 ends the script with :no_player without buffering the line" do
      result = ended(fn -> Dsl.mes(detached(), "hello") end)

      assert result.status == {:error, :no_player}
      assert result.page == []
    end

    test "next/1 ends the script with :no_player without flushing or blocking" do
      assert ended(fn -> Dsl.next(detached()) end).status == {:error, :no_player}
    end

    test "close/1 ends the script with :no_player without flushing" do
      assert ended(fn -> Dsl.close(detached()) end).status == {:error, :no_player}
    end

    test "select/2 ends the script with :no_player without blocking" do
      assert ended(fn -> Dsl.select(detached(), ["A", "B"]) end).status == {:error, :no_player}
    end

    test "input/2 ends the script with :no_player without blocking" do
      assert ended(fn -> Dsl.input(detached(), :int) end).status == {:error, :no_player}
    end

    test "the first ending command stops the pipe, later ops never run" do
      result =
        ended(fn ->
          detached()
          |> Dsl.mes("before")
          |> Dsl.warp({"prontera", 150, 150})
          |> Dsl.give_item(501, 1)
          |> Dsl.mes("hello")
        end)

      assert result.status == {:error, :no_player}
      assert result.page == []
    end
  end

  describe "remaining player-touching effects on a detached ctx" do
    test "heal/2 ends the script with :no_player" do
      assert ended(fn -> Dsl.heal(detached(), hp: 10) end).status == {:error, :no_player}
    end

    test "percent_heal/2 ends the script with :no_player" do
      assert ended(fn -> Dsl.percent_heal(detached(), hp: 10) end).status ==
               {:error, :no_player}
    end

    test "sc_start/4 has no unit to start the status on, does nothing and the script goes on" do
      assert Dsl.sc_start(detached(), :sc_blessing, 1_000, 1) == detached()
    end

    test "sc_end/2 and cure/2 have no unit to end the status on, do nothing and the script goes on" do
      assert Dsl.sc_end(detached(), :sc_poison) == detached()
      assert Dsl.cure(detached(), :sc_poison) == detached()
    end

    test "itemskill/3 ends the script with :no_player" do
      assert ended(fn -> Dsl.itemskill(detached(), 14, []) end).status == {:error, :no_player}
    end

    test "refine/4 returns {:error, :no_player}, its tagged-result error shape" do
      result = Dsl.refine(detached(), 0, :normal)

      assert result == {:error, :no_player}
    end
  end

  describe "player reads on a detached ctx" do
    for {name, fun} <- [
          {"zeny/1", quote(do: &Dsl.zeny/1)},
          {"base_level/1", quote(do: &Dsl.base_level/1)},
          {"position/1", quote(do: &Dsl.position/1)},
          {"checkfalcon/1", quote(do: &Dsl.checkfalcon/1)},
          {"ismounting/1", quote(do: &Dsl.ismounting/1)},
          {"upper/1", quote(do: &Dsl.upper/1)},
          {"skill_point/1", quote(do: &Dsl.skill_point/1)}
        ] do
      test "#{name} ends the script with :no_player" do
        assert ended(fn -> unquote(fun).(detached()) end).status == {:error, :no_player}
      end
    end

    test "count_item/2 ends the script with :no_player" do
      assert ended(fn -> Dsl.count_item(detached(), 501) end).status == {:error, :no_player}
    end

    test "get_char_var/3 ends the script with :no_player" do
      assert ended(fn -> Dsl.get_char_var(detached(), :some_var) end).status ==
               {:error, :no_player}
    end

    test "account variables need the attached player too" do
      assert ended(fn -> Dsl.get_account_var(detached(), "#acc") end).status ==
               {:error, :no_player}

      assert ended(fn -> Dsl.set_account_var(detached(), "#acc", 1) end).status ==
               {:error, :no_player}
    end
  end
end
