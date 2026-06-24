defmodule Aesir.ZoneServer.Script.DialogTest do
  use ExUnit.Case, async: true

  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcInteract
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @gid 0x5000_0001

  describe "mes/2" do
    test "buffers a line and returns ctx without sending" do
      ctx = Dsl.mes(build_ctx(), "hello")

      assert ctx.page == ["hello"]
      refute_received {:send, _, _}
    end

    test "accumulates lines in order" do
      ctx = build_ctx() |> Dsl.mes("a") |> Dsl.mes("b") |> Dsl.mes("c")

      assert ctx.page == ["a", "b", "c"]
    end
  end

  describe "next/1" do
    test "flushes the buffered page as a NEXT frame, blocks, then clears the buffer" do
      ctx = build_ctx() |> Dsl.mes("line 1") |> Dsl.mes("line 2")

      result = run_blocking(fn -> Dsl.next(ctx) end, {:continue, true})

      assert_received {:send, _ch, {:npc_dialog, %NpcDialog{} = dialog}}
      assert dialog.npc_id == @gid
      assert dialog.text == "line 1\nline 2"
      assert dialog.expect == :NEXT
      assert result.page == []
    end

    test "a cancel during a NEXT ends the dialog promptly (interaction exits :normal)" do
      ctx = build_ctx()
      assert_cancel_exits(fn -> Dsl.next(ctx) end)
    end
  end

  describe "select/2" do
    test "flushes a MENU frame and returns the 1-based routed choice" do
      ctx = build_ctx() |> Dsl.mes("pick one")

      {result_ctx, choice} =
        run_blocking(fn -> Dsl.select(ctx, ["A", "B"]) end, {:choice, 2})

      assert_received {:send, _ch, {:npc_dialog, %NpcDialog{expect: :MENU, options: ["A", "B"]}}}
      assert choice == 2
      assert result_ctx.page == []
    end

    test "a cancel response ends the dialog (interaction exits :normal)" do
      ctx = build_ctx()
      assert_cancel_exits(fn -> Dsl.select(ctx, ["A"]) end)
    end
  end

  describe "input/2" do
    test "INPUT_INT returns the routed number" do
      ctx = build_ctx()
      {_ctx, value} = run_blocking(fn -> Dsl.input(ctx, :int) end, {:number, -42})

      assert_received {:send, _ch, {:npc_dialog, %NpcDialog{expect: :INPUT_INT}}}
      assert value == -42
    end

    test "INPUT_STR returns the routed string" do
      ctx = build_ctx()
      {_ctx, value} = run_blocking(fn -> Dsl.input(ctx, :string) end, {:input, "ygor"})

      assert_received {:send, _ch, {:npc_dialog, %NpcDialog{expect: :INPUT_STR}}}
      assert value == "ygor"
    end

    test "a cancel during an input ends the dialog promptly (interaction exits :normal)" do
      ctx = build_ctx()
      assert_cancel_exits(fn -> Dsl.input(ctx, :int) end)
    end
  end

  describe "close/1" do
    test "flushes the remaining page as a CLOSE frame and does not block" do
      ctx = build_ctx() |> Dsl.mes("bye")

      result = Dsl.close(ctx)

      assert_received {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: "bye"}}}
      assert result.page == []
    end
  end

  describe "npc_id validation" do
    test "next/1 drops an NpcInteract whose npc_id does not match the ctx gid" do
      ctx = build_ctx()
      parent = self()

      pid =
        spawn(fn ->
          send(parent, {:done, Dsl.next(ctx)})
        end)

      # wrong npc_id -> dropped, the primitive keeps blocking
      send(pid, {:npc_interact, %NpcInteract{npc_id: 0x9999, response: {:continue, true}}})
      refute_receive {:done, _}, 100

      # right npc_id -> unblocks
      send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:continue, true}}})
      assert_receive {:done, %Ctx{}}, 500
    end
  end

  # Runs a blocking DSL primitive in a spawned process, routes a single
  # NpcInteract response to it, and returns the primitive's value. The outgoing
  # NpcDialog frame is delivered to the test process because build_ctx sets the
  # connection_pid to self().
  defp run_blocking(fun, response) do
    parent = self()

    pid =
      spawn(fn ->
        send(parent, {:result, fun.()})
      end)

    send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: response}})

    receive do
      {:result, value} -> value
    after
      1_000 -> flunk("blocking DSL primitive did not return")
    end
  end

  # Runs a blocking DSL primitive in a spawned, monitored process, routes a
  # cancel for the active gid, and asserts the process exits :normal (the dialog
  # ended) rather than returning a value or hanging to the idle timeout.
  defp assert_cancel_exits(fun) do
    {pid, ref} = spawn_monitor(fn -> fun.() end)

    send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:cancel, true}}})

    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 500
  end

  defp build_ctx do
    %Ctx{
      char_id: 1,
      account_id: 100,
      connection_pid: self(),
      game_state: %PlayerState{character_id: 1, account_id: 100},
      source: {:npc, :test_npc},
      npc_gid: @gid,
      interaction_pid: self()
    }
  end
end
