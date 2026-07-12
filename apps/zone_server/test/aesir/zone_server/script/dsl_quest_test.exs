defmodule Aesir.ZoneServer.Script.DslQuestTest do
  @moduledoc """
  Covers the Task 7 quest DSL surface: the seam-routed mutations
  (`setquest/2`, `erasequest/2`, `completequest/2`, `changequest/3`) which call
  `{:script_apply, op}` on the session and fold the reply into the ctx (or
  `Ctx.halt/2` on `{:error, _}`), and the pure reads (`checkquest/2,3`,
  `questprogress/2,3`, `isbegin_quest/2`) over `ctx.game_state.quest_log`.
  """

  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.QuestManagement.QuestDefinition
  alias Aesir.ZoneServer.Mmo.QuestManagement.Quests
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.QuestLog.Entry

  @hunt %QuestDefinition{
    id: 7393,
    title: "Shiny Silver Blade",
    targets: [%{mob_id: 2314, count: 10}]
  }

  # A stand-in session that answers {:script_apply, op}. It does not mutate any
  # PlayerState; it just echoes a scripted reply (configured per test) and
  # forwards the op to the test process so we can assert the op routed through
  # the seam exactly once. Production behaviour of the op is covered against
  # the real `ScriptEffectHandler`.
  defmodule StubSession do
    use GenServer

    def start_link(reply_fun), do: GenServer.start_link(__MODULE__, reply_fun)

    @impl true
    def init(reply_fun), do: {:ok, reply_fun}

    @impl true
    def handle_call({:script_apply, op} = _msg, {from_pid, _tag}, reply_fun) do
      send(:dsl_quest_probe, {:script_apply, op})
      {:reply, reply_fun.(op, from_pid), reply_fun}
    end
  end

  setup do
    Process.register(self(), :dsl_quest_probe)

    defs = [@hunt]
    index = %{all: defs, by_id: Map.new(defs, &{&1.id, &1})}
    :persistent_term.put(Quests, index)
    on_exit(fn -> :persistent_term.erase(Quests) end)

    :ok
  end

  describe "setquest/2" do
    test "routes {:setquest, id} and folds the returned game_state" do
      gs = %{build_game_state() | quest_log: %{7393 => entry(:active, [0])}}
      ctx = build_ctx(session: ok_session(gs))

      result = Dsl.setquest(ctx, 7393)

      assert result.status == :ok
      assert result.game_state.quest_log[7393].state == :active
      assert_received {:script_apply, {:setquest, 7393}}
    end

    test "halts :already_started when the session rejects" do
      ctx = build_ctx(session: error_session(:already_started))

      result = Dsl.setquest(ctx, 7393)

      assert result.status == {:error, :already_started}
      assert_received {:script_apply, {:setquest, 7393}}
    end
  end

  describe "erasequest/2" do
    test "routes {:erasequest, id} and folds the returned game_state" do
      gs = %{build_game_state() | quest_log: %{}}
      ctx = build_ctx(session: ok_session(gs), quest_log: %{7393 => entry(:active, [0])})

      result = Dsl.erasequest(ctx, 7393)

      assert result.status == :ok
      assert result.game_state.quest_log == %{}
      assert_received {:script_apply, {:erasequest, 7393}}
    end

    test "halts :not_started when the session rejects" do
      ctx = build_ctx(session: error_session(:not_started))

      result = Dsl.erasequest(ctx, 7393)

      assert result.status == {:error, :not_started}
    end
  end

  describe "completequest/2" do
    test "routes {:completequest, id} and folds the returned game_state" do
      gs = %{build_game_state() | quest_log: %{7393 => entry(:complete, [10])}}
      ctx = build_ctx(session: ok_session(gs))

      result = Dsl.completequest(ctx, 7393)

      assert result.status == :ok
      assert result.game_state.quest_log[7393].state == :complete
      assert_received {:script_apply, {:completequest, 7393}}
    end

    test "halts :not_started when the session rejects" do
      ctx = build_ctx(session: error_session(:not_started))

      result = Dsl.completequest(ctx, 7393)

      assert result.status == {:error, :not_started}
    end
  end

  describe "changequest/3" do
    test "routes {:changequest, old, new} and folds the returned game_state" do
      gs = %{build_game_state() | quest_log: %{7394 => entry(:active, [0])}}
      ctx = build_ctx(session: ok_session(gs))

      result = Dsl.changequest(ctx, 7393, 7394)

      assert result.status == :ok
      assert result.game_state.quest_log[7394].state == :active
      assert_received {:script_apply, {:changequest, 7393, 7394}}
    end

    test "halts :not_started when the session rejects" do
      ctx = build_ctx(session: error_session(:not_started))

      result = Dsl.changequest(ctx, 7393, 7394)

      assert result.status == {:error, :not_started}
    end
  end

  describe "getexp/3" do
    test "routes {:getexp, base, job} and folds the returned game_state" do
      ctx = build_ctx(session: ok_session(build_game_state()))

      result = Dsl.getexp(ctx, 300_000, 100_000)

      assert result.status == :ok
      assert_received {:script_apply, {:getexp, 300_000, 100_000}}
    end
  end

  describe "short-circuit on a halted ctx" do
    test "every quest mutation returns a halted ctx unchanged without touching the session" do
      ctx = Ctx.halt(build_ctx(session: flunking_session()), :already_halted)

      assert Dsl.setquest(ctx, 7393) == ctx
      assert Dsl.erasequest(ctx, 7393) == ctx
      assert Dsl.completequest(ctx, 7393) == ctx
      assert Dsl.changequest(ctx, 7393, 7394) == ctx
      assert Dsl.getexp(ctx, 300_000, 100_000) == ctx

      refute_received {:script_apply, _}
    end
  end

  describe "checkquest/2,3 (pure read over the ctx snapshot)" do
    test "checkquest/2 defaults to :havequest" do
      ctx = build_ctx(quest_log: %{7393 => entry(:active, [0])})

      assert Dsl.checkquest(ctx, 7393) == 1
    end

    test "checkquest/3 accepts :playtime and :hunting" do
      ctx = build_ctx(quest_log: %{7393 => entry(:active, [10])})

      assert Dsl.checkquest(ctx, 7393, :playtime) == 0
      assert Dsl.checkquest(ctx, 7393, :hunting) == 2
    end

    test "returns -1 for a never-started quest (a read, not an error)" do
      ctx = build_ctx(quest_log: %{})

      assert Dsl.checkquest(ctx, 7393) == -1
      assert Dsl.checkquest(ctx, 7393, :playtime) == -1
      assert Dsl.checkquest(ctx, 7393, :hunting) == -1
    end
  end

  describe "questprogress/2,3 (alias of checkquest, same core)" do
    test "questprogress/2 defaults to :havequest" do
      ctx = build_ctx(quest_log: %{7393 => entry(:complete, [10])})

      assert Dsl.questprogress(ctx, 7393) == 2
    end

    test "questprogress/3 accepts :hunting" do
      ctx = build_ctx(quest_log: %{7393 => entry(:active, [3])})

      assert Dsl.questprogress(ctx, 7393, :hunting) == 0
    end

    test "returns -1 for a never-started quest" do
      ctx = build_ctx(quest_log: %{})

      assert Dsl.questprogress(ctx, 7393) == -1
    end
  end

  describe "isbegin_quest/2 (pure read over the ctx snapshot)" do
    test "0 for a never-started quest" do
      ctx = build_ctx(quest_log: %{})

      assert Dsl.isbegin_quest(ctx, 7393) == 0
    end

    test "1 for an inactive or active quest" do
      ctx = build_ctx(quest_log: %{7393 => entry(:inactive, [0])})

      assert Dsl.isbegin_quest(ctx, 7393) == 1
    end

    test "2 for a complete quest" do
      ctx = build_ctx(quest_log: %{7393 => entry(:complete, [10])})

      assert Dsl.isbegin_quest(ctx, 7393) == 2
    end
  end

  defp entry(state, counts), do: %Entry{state: state, counts: counts, deadline: nil}

  defp ok_session(game_state), do: start_stub(fn _op, _from -> {:ok, game_state} end)
  defp error_session(reason), do: start_stub(fn _op, _from -> {:error, reason} end)

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
      zeny: 0,
      vars: %{},
      temp_vars: %{},
      inventory: %{},
      quest_log: Keyword.get(opts, :quest_log, %{})
    }
  end
end
