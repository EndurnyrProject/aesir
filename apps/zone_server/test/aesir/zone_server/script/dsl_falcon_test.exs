defmodule Aesir.ZoneServer.Script.DslFalconTest do
  use ExUnit.Case, async: true

  import Bitwise

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

    test "ends the script without an attached player" do
      assert {:script_end, %{status: {:error, :no_player}}} =
               catch_throw(Dsl.checkfalcon(%{ctx() | game_state: nil}))
    end
  end

  describe "checkoption/2" do
    test "tests requested option bits against the player snapshot" do
      wug = Option.id(:wug)
      rider = Option.id(:wugrider)
      player = ctx(option: wug ||| @falcon_bit)

      assert Dsl.checkoption(player, wug) == 1
      assert Dsl.checkoption(player, rider) == 0
      assert Dsl.checkoption(player, wug ||| rider) == 1
      assert Dsl.checkoption(ctx(), wug) == 0
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

    test "normalizes zero to dismissal and fails the command on a handler failure" do
      session = start_session(fn {:set_falcon, false} -> {:error, :falcon_skill_not_learned} end)

      result = Dsl.setfalcon(ctx(session_pid: session), 0)

      assert result.status == :ok
      assert result.failures == [{:set_falcon, :falcon_skill_not_learned}]
      assert_received {:script_apply, {:set_falcon, false}}
    end

    test "ends the script on detached contexts without mutating their snapshots" do
      detached = %{ctx() | game_state: nil}

      assert {:script_end, ended} = catch_throw(Dsl.setfalcon(detached, 1))
      assert ended == %{detached | status: {:error, :no_player}}
    end
  end
end
