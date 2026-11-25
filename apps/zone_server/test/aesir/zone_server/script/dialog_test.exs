defmodule Aesir.ZoneServer.Script.DialogTest do
  use ExUnit.Case, async: true

  import Aesir.ZoneServer.Factory

  alias Aesir.Net.Cutin
  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcInteract
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl

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
      ctx = build_ctx() |> Dsl.mes("line")
      assert_cancel_exits(fn -> Dsl.next(ctx) end)
    end

    @tag :capture_log
    test "with no mes box open it fails and the script goes on without a frame" do
      assert %{failures: [next: :no_mes], page: []} = Dsl.next(build_ctx())
      refute_received {:send, _ch, {:npc_dialog, _dialog}}
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
      assert result_ctx.game_state.temp_vars["menu"] == 2
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
    test "after a mes, flushes the page as a CLOSE frame and waits for the player to close it" do
      ctx = build_ctx() |> Dsl.mes("bye")

      result = assert_waits_for_close(fn -> Dsl.close(ctx) end)

      assert_received {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: "bye"}}}
      assert %{page: [], mes_active: false} = result
    end

    test "with no mes box open, sends the CLOSE frame and goes on without waiting" do
      result = Dsl.close(build_ctx())

      assert_received {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE}}}
      assert result.page == []
    end
  end

  describe "close2/1" do
    test "waits for the player to close the window even with no mes box open" do
      ctx = build_ctx()

      result = assert_waits_for_close(fn -> Dsl.close2(ctx) end)

      assert_received {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE}}}
      assert result.mes_active == false
    end
  end

  describe "cancel" do
    test "clears any displayed cutin before the dialog ends" do
      ctx = build_ctx()
      assert_cancel_exits(fn -> Dsl.select(ctx, ["A"]) end)

      assert_received {:send, _ch, {:cutin, %Cutin{image: "", type: 255}}}
    end
  end

  describe "npc_id validation" do
    test "next/1 drops an NpcInteract whose npc_id does not match the ctx gid" do
      ctx = %{build_ctx() | mes_active: true}
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

    case response do
      {:choice, choice} ->
        assert_receive {:"$gen_call", from,
                        {:npc, {:script_apply, {:set_temp_var, :menu, ^choice}}}}

        game_state = %{build_ctx().game_state | temp_vars: %{"menu" => choice}}
        GenServer.reply(from, {:ok, game_state})

      _other ->
        :ok
    end

    receive do
      {:result, value} -> value
    after
      1_000 -> flunk("blocking DSL primitive did not return")
    end
  end

  # Runs a closing DSL primitive in a spawned process, checks it has not
  # returned before the player closes the window, then routes the close.
  defp assert_waits_for_close(fun) do
    parent = self()
    pid = spawn(fn -> send(parent, {:result, fun.()}) end)

    refute_receive {:result, _ctx}, 100

    send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:close, true}}})
    assert_receive {:result, result}, 500
    result
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
    build(:script_ctx, npc_gid: @gid, session_pid: self(), interaction_pid: self())
  end
end
