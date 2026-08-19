defmodule Aesir.ZoneServer.Gm.DispatcherTest do
  use Aesir.DataCase, async: true
  use Mimic

  alias Aesir.Commons.Models.Account
  alias Aesir.Net.ChatMessage
  alias Aesir.ZoneServer.Gm.Dispatcher
  alias Aesir.ZoneServer.Mmo.Woe.Server
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!
  setup :set_mimic_private

  defmodule StubCommand do
    @behaviour Aesir.ZoneServer.Gm.Command

    @impl true
    def name, do: "stub"

    @impl true
    def required_level, do: 60

    @impl true
    def execute(args, _ctx), do: {:ok, "ran #{Enum.join(args, ",")}"}
  end

  defmodule FailingStubCommand do
    @behaviour Aesir.ZoneServer.Gm.Command

    @impl true
    def name, do: "fail"

    @impl true
    def required_level, do: 0

    @impl true
    def execute(_args, _ctx), do: {:error, "boom"}
  end

  defmodule ExplodingCommand do
    @behaviour Aesir.ZoneServer.Gm.Command

    @impl true
    def name, do: "boom"

    @impl true
    def required_level, do: 60

    @impl true
    def execute(_args, _ctx), do: raise("execute should not be called")
  end

  defp seed_account(gm_level) do
    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "gm#{System.unique_integer([:positive])}",
        userid: "gm#{System.unique_integer([:positive])}",
        user_pass: "password",
        email: "gm@test.com",
        gm_level: gm_level
      })
      |> Repo.insert()

    account
  end

  defp ctx_for(account) do
    %{
      game_state: %PlayerState{account_id: account.id, character_id: 1000},
      connection_pid: self()
    }
  end

  defp receive_chat_message(timeout \\ 1000) do
    receive do
      {:send, _channel, {_tag, %ChatMessage{} = message}} -> message
    after
      timeout -> flunk("Expected a ChatMessage within #{timeout}ms")
    end
  end

  test "replies 'Unknown command' for an unregistered token" do
    ctx = ctx_for(seed_account(99))

    Dispatcher.dispatch("@nope 1 2", ctx, %{})

    assert %ChatMessage{gid: 1000, message: "Unknown command"} = receive_chat_message()
  end

  test "denies a caller below required_level and does not call execute" do
    ctx = ctx_for(seed_account(10))

    Dispatcher.dispatch("@boom", ctx, %{"boom" => ExplodingCommand})

    assert %ChatMessage{gid: 1000, message: "Insufficient permission"} = receive_chat_message()
  end

  test "runs the command and replies with its {:ok, msg} when gm_level is sufficient" do
    ctx = ctx_for(seed_account(60))

    Dispatcher.dispatch("@stub 501 10", ctx, %{"stub" => StubCommand})

    assert %ChatMessage{gid: 1000, message: "ran 501,10"} = receive_chat_message()
  end

  test "replies with the command's {:error, msg}" do
    ctx = ctx_for(seed_account(0))

    Dispatcher.dispatch("@fail", ctx, %{"fail" => FailingStubCommand})

    assert %ChatMessage{gid: 1000, message: "boom"} = receive_chat_message()
  end

  test "routes @agitstart to AgitStart, which starts WoE and replies" do
    ctx = ctx_for(seed_account(99))
    expect(Server, :start, fn -> :ok end)

    Dispatcher.dispatch("@agitstart", ctx)

    assert %ChatMessage{gid: 1000, message: "WoE started."} = receive_chat_message()
  end

  test "routes @agitend to AgitEnd, which stops WoE and replies" do
    ctx = ctx_for(seed_account(99))
    expect(Server, :stop, fn -> :ok end)

    Dispatcher.dispatch("@agitend", ctx)

    assert %ChatMessage{gid: 1000, message: "WoE ended."} = receive_chat_message()
  end

  test "denies @agitstart below GM level 99 without invoking Woe.Server" do
    ctx = ctx_for(seed_account(10))
    reject(&Server.start/0)

    Dispatcher.dispatch("@agitstart", ctx)

    assert %ChatMessage{gid: 1000, message: "Insufficient permission"} = receive_chat_message()
  end

  test "routes @PVPON case-insensitively to PvpOn; a bogus arg yields the usage reply" do
    ctx = ctx_for(seed_account(99))

    Dispatcher.dispatch("@PVPON bogus", ctx)

    assert %ChatMessage{gid: 1000, message: "Usage: @pvpon [noparty] [noguild]"} =
             receive_chat_message()
  end

  test "denies @pvpon below GM level 99 without invoking PvpOn" do
    ctx = ctx_for(seed_account(10))

    Dispatcher.dispatch("@pvpon noparty", ctx)

    assert %ChatMessage{gid: 1000, message: "Insufficient permission"} = receive_chat_message()
  end

  test "denies @pvpoff below GM level 99 without invoking PvpOff" do
    ctx = ctx_for(seed_account(10))

    Dispatcher.dispatch("@pvpoff", ctx)

    assert %ChatMessage{gid: 1000, message: "Insufficient permission"} = receive_chat_message()
  end
end
