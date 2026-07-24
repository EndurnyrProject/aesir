defmodule Aesir.ZoneServer.Script.DslFalconTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @falcon_bit Option.id(:falcon)

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
    game_state = %PlayerState{character_id: 1, option: Keyword.get(opts, :option, 0)}

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

  describe "checkfalcon/1" do
    test "returns 1 only when the attached snapshot has the Falcon bit" do
      assert Dsl.checkfalcon(ctx(option: @falcon_bit)) == 1
      assert Dsl.checkfalcon(ctx()) == 0
    end

    test "returns 0 without an attached player" do
      assert Dsl.checkfalcon(%{ctx() | game_state: nil}) == 0
    end
  end

  describe "setfalcon/2" do
    test "normalizes non-zero flags and folds the session's refreshed game state into ctx" do
      refreshed = %PlayerState{character_id: 1, option: @falcon_bit}
      session = start_session(fn {:set_falcon, true} -> {:ok, refreshed} end)

      result = Dsl.setfalcon(%{ctx(session_pid: session) | game_state: %PlayerState{}}, -1)

      assert result.status == :ok
      assert result.game_state == refreshed
      assert_received {:script_apply, {:set_falcon, true}}
    end

    test "normalizes zero to dismissal and halts with the handler failure" do
      session = start_session(fn {:set_falcon, false} -> {:error, :falcon_skill_not_learned} end)

      result = Dsl.setfalcon(ctx(session_pid: session), 0)

      assert result.status == {:error, :falcon_skill_not_learned}
      assert_received {:script_apply, {:set_falcon, false}}
    end

    test "halts detached contexts without mutating their snapshots" do
      detached = %{ctx() | game_state: nil}

      assert Dsl.setfalcon(detached, 1) == Ctx.halt(detached, :no_player)
    end
  end
end
