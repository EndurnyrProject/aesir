defmodule Aesir.ZoneServer.Script.DslSkillGrantTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  defmodule Session do
    use GenServer

    def start_link(reply_fun), do: GenServer.start_link(__MODULE__, reply_fun)

    @impl true
    def init(reply_fun), do: {:ok, reply_fun}

    @impl true
    def handle_call({:npc, {:script_apply, op}}, _from, reply_fun),
      do: {:reply, reply_fun.(op), reply_fun}
  end

  defp ctx(opts \\ []) do
    game_state = %PlayerState{character_id: 1}

    %Ctx{
      char_id: 1,
      account_id: 100,
      connection_pid: self(),
      session_pid: Keyword.get(opts, :session_pid),
      game_state: game_state,
      source: {:npc, :test_npc}
    }
  end

  defp start_session(reply_fun) do
    test_pid = self()

    {:ok, session} =
      Session.start_link(fn op ->
        send(test_pid, {:script_apply, op})
        reply_fun.(op)
      end)

    session
  end

  describe "skill/4" do
    test "routes id-based grants as a :grant_skill op and folds the refreshed game state" do
      refreshed = %PlayerState{character_id: 1}
      session = start_session(fn {:grant_skill, 9001, 3} -> {:ok, refreshed} end)

      result = Dsl.skill(ctx(session_pid: session), 9001, 3, 0)

      assert result.status == :ok
      assert result.game_state == refreshed
      assert_received {:script_apply, {:grant_skill, 9001, 3}}
    end

    test "routes name-based grants unchanged and ignores the flag argument" do
      refreshed = %PlayerState{character_id: 1}
      session = start_session(fn {:grant_skill, :ht_phantasmic, 1} -> {:ok, refreshed} end)

      result = Dsl.skill(ctx(session_pid: session), :ht_phantasmic, 1, 12_345)

      assert result.status == :ok
      assert result.game_state == refreshed
      assert_received {:script_apply, {:grant_skill, :ht_phantasmic, 1}}
    end

    test "halts with the handler failure and leaves the snapshot untouched" do
      session = start_session(fn {:grant_skill, 9001, 1} -> {:error, :not_grantable} end)

      result = Dsl.skill(ctx(session_pid: session), 9001, 1, 0)

      assert result.status == {:error, :not_grantable}
      assert result.game_state == %PlayerState{character_id: 1}
      assert_received {:script_apply, {:grant_skill, 9001, 1}}
    end

    test "halts :no_player without calling the session on a detached ctx" do
      detached = %{ctx() | game_state: nil}

      assert Dsl.skill(detached, 9001, 1, 0) == Ctx.halt(detached, :no_player)
    end

    test "short-circuits an already-errored ctx without calling the session" do
      errored = Ctx.halt(ctx(), :previous_error)

      assert Dsl.skill(errored, 9001, 1, 0) == errored
    end
  end
end
