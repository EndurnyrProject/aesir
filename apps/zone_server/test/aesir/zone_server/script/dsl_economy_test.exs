defmodule Aesir.ZoneServer.Script.DslEconomyTest do
  @moduledoc """
  Covers the Task 6 state-mutating/reading DSL surface: the pure reads
  (`zeny/1`, `count_item/2`, `get_char_var/2,3`) over the ctx snapshot, and the
  seam-routed mutations (`pay_zeny/2`, `give_item/3`, `delitem/3`,
  `set_char_var/3`, `jobchange/2`, `openstorage/1`) which call `{:script_apply, op}` on the
  session and fold the reply into the ctx (or `Ctx.halt/2` on `{:error, _}`).
  """

  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  # A stand-in session that answers {:script_apply, op}. It does not mutate any
  # PlayerState; it just echoes a scripted reply (configured per test) and
  # forwards the op to the test process so we can assert the op routed through
  # the seam exactly once. Production behaviour of the op is covered separately
  # against the real PlayerSession handler.
  defmodule StubSession do
    use GenServer

    def start_link(reply_fun), do: GenServer.start_link(__MODULE__, reply_fun)

    @impl true
    def init(reply_fun), do: {:ok, reply_fun}

    @impl true
    def handle_call({:script_apply, op} = _msg, {from_pid, _tag}, reply_fun) do
      send(:dsl_economy_probe, {:script_apply, op})
      {:reply, reply_fun.(op, from_pid), reply_fun}
    end
  end

  setup do
    Process.register(self(), :dsl_economy_probe)
    :ok
  end

  describe "reads (pure over the ctx snapshot)" do
    test "zeny/1 reads game_state.zeny" do
      assert Dsl.zeny(build_ctx(zeny: 1_234)) == 1_234
    end

    test "count_item/2 sums the held stacks of nameid" do
      ctx = build_ctx(inventory: %{0 => item(7114, 3), 1 => item(501, 9)})

      assert Dsl.count_item(ctx, 7114) == 3
      assert Dsl.count_item(ctx, 999) == 0
    end

    test "get_char_var/3 reads a string-keyed var; unset returns the default" do
      ctx = build_ctx(vars: %{"sphmask_q" => 1})

      assert Dsl.get_char_var(ctx, :sphmask_q, 0) == 1
      assert Dsl.get_char_var(ctx, :sphmask_q) == 1
      assert Dsl.get_char_var(ctx, :missing, 0) == 0
      assert Dsl.get_char_var(ctx, :missing) == 0
    end
  end

  describe "set_char_var/3" do
    test "routes {:set_char_var, key, value} and folds the returned game_state" do
      gs = %{build_game_state() | vars: %{"k" => 1}}
      ctx = build_ctx(session: ok_session(gs))

      result = Dsl.set_char_var(ctx, :k, 1)

      assert result.status == :ok
      assert result.game_state.vars == %{"k" => 1}
      assert_received {:script_apply, {:set_char_var, :k, 1}}
    end
  end

  describe "pay_zeny/2" do
    test "folds the debited game_state on success" do
      gs = %{build_game_state() | zeny: 500}
      ctx = build_ctx(session: ok_session(gs))

      result = Dsl.pay_zeny(ctx, 500)

      assert result.status == :ok
      assert Dsl.zeny(result) == 500
      assert_received {:script_apply, {:pay_zeny, 500}}
    end

    test "halts :not_enough_zeny when the session rejects" do
      ctx = build_ctx(session: error_session(:not_enough_zeny))

      result = Dsl.pay_zeny(ctx, 1_000_000)

      assert result.status == {:error, :not_enough_zeny}
      assert_received {:script_apply, {:pay_zeny, 1_000_000}}
    end
  end

  describe "give_item/3" do
    test "routes {:give_item, id, qty} and folds the returned game_state" do
      gs = %{build_game_state() | inventory: %{0 => item(7114, 1)}}
      ctx = build_ctx(session: ok_session(gs))

      result = Dsl.give_item(ctx, 7114, 1)

      assert result.status == :ok
      assert Dsl.count_item(result, 7114) == 1
      assert_received {:script_apply, {:give_item, 7114, 1}}
    end

    test "halts :inventory_full when the session rejects" do
      ctx = build_ctx(session: error_session(:inventory_full))

      result = Dsl.give_item(ctx, 7114, 1)

      assert result.status == {:error, :inventory_full}
    end
  end

  describe "jobchange/2" do
    test "routes {:change_job, job_id} and folds the returned game_state" do
      gs = %{
        build_game_state()
        | stats: %Stats{progression: %PlayerProgression{job_id: 7}}
      }

      ctx = build_ctx(session: ok_session(gs))

      result = Dsl.jobchange(ctx, 7)

      assert result.status == :ok
      assert result.game_state.stats.progression.job_id == 7
      assert_received {:script_apply, {:change_job, 7}}
    end

    test "halts :unknown_job when the session rejects" do
      ctx = build_ctx(session: error_session(:unknown_job))

      result = Dsl.jobchange(ctx, 99_999)

      assert result.status == {:error, :unknown_job}
      assert_received {:script_apply, {:change_job, 99_999}}
    end
  end

  describe "openstorage/1" do
    test "routes {:openstorage} and folds the returned game_state" do
      gs = %{build_game_state() | storage: %{}}
      ctx = build_ctx(session: ok_session(gs))

      result = Dsl.openstorage(ctx)

      assert result.status == :ok
      assert result.game_state.storage == %{}
      assert_received {:script_apply, {:openstorage}}
    end
  end

  describe "setcart/1,2" do
    test "routes {:setcart, 1} by default and folds the returned game_state" do
      gs = build_game_state()
      ctx = build_ctx(session: ok_session(gs))

      result = Dsl.setcart(ctx)

      assert result.status == :ok
      assert_received {:script_apply, {:setcart, 1}}
    end

    test "routes {:setcart, 0} for cart removal" do
      gs = build_game_state()
      ctx = build_ctx(session: ok_session(gs))

      result = Dsl.setcart(ctx, 0)

      assert result.status == :ok
      assert_received {:script_apply, {:setcart, 0}}
    end
  end

  describe "delitem/3" do
    test "routes {:delitem, id, qty} and folds the returned game_state" do
      gs = %{build_game_state() | inventory: %{}}
      ctx = build_ctx(session: ok_session(gs), inventory: %{0 => item(7114, 1)})

      result = Dsl.delitem(ctx, 7114, 1)

      assert result.status == :ok
      assert Dsl.count_item(result, 7114) == 0
      assert_received {:script_apply, {:delitem, 7114, 1}}
    end

    test "halts :not_enough_items when the session rejects" do
      ctx = build_ctx(session: error_session(:not_enough_items))

      result = Dsl.delitem(ctx, 7114, 5)

      assert result.status == {:error, :not_enough_items}
    end
  end

  describe "short-circuit on a halted ctx" do
    test "every mutation returns a halted ctx unchanged without touching the session" do
      ctx = Ctx.halt(build_ctx(session: flunking_session()), :already_halted)

      assert Dsl.pay_zeny(ctx, 1) == ctx
      assert Dsl.give_item(ctx, 7114, 1) == ctx
      assert Dsl.delitem(ctx, 7114, 1) == ctx
      assert Dsl.set_char_var(ctx, :k, 1) == ctx
      assert Dsl.jobchange(ctx, 1) == ctx
      assert Dsl.openstorage(ctx) == ctx

      refute_received {:script_apply, _}
    end

    test "a failing op short-circuits the rest of a pipe" do
      gs = %{build_game_state() | inventory: %{0 => item(7114, 1)}}

      ctx =
        build_ctx(session: pay_fails_then_ok(gs))
        |> Dsl.pay_zeny(1_000_000)
        |> Dsl.give_item(7114, 1)
        |> Dsl.set_char_var(:k, 1)

      assert ctx.status == {:error, :not_enough_zeny}
      # give_item / set_char_var never routed through the seam after the halt.
      assert_received {:script_apply, {:pay_zeny, 1_000_000}}
      refute_received {:script_apply, {:give_item, _, _}}
      refute_received {:script_apply, {:set_char_var, _, _}}
    end
  end

  defp ok_session(game_state), do: start_stub(fn _op, _from -> {:ok, game_state} end)
  defp error_session(reason), do: start_stub(fn _op, _from -> {:error, reason} end)

  defp pay_fails_then_ok(game_state) do
    start_stub(fn
      {:pay_zeny, _}, _from -> {:error, :not_enough_zeny}
      _op, _from -> {:ok, game_state}
    end)
  end

  defp flunking_session do
    start_stub(fn _op, _from -> flunk("session must not be called on a halted ctx") end)
  end

  defp start_stub(reply_fun) do
    {:ok, pid} = StubSession.start_link(reply_fun)
    pid
  end

  defp build_ctx(opts) do
    %Ctx{
      char_id: 1,
      account_id: 100,
      connection_pid: self(),
      session_pid: Keyword.get(opts, :session, self()),
      game_state: build_game_state(opts),
      source: {:npc, :test_npc}
    }
  end

  defp build_game_state(opts \\ []) do
    %PlayerState{
      character_id: 1,
      account_id: 100,
      zeny: Keyword.get(opts, :zeny, 0),
      vars: Keyword.get(opts, :vars, %{}),
      temp_vars: %{},
      inventory: Keyword.get(opts, :inventory, %{})
    }
  end

  defp item(nameid, amount), do: %InventoryItem{nameid: nameid, amount: amount}
end
