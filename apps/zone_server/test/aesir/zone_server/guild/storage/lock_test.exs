defmodule Aesir.ZoneServer.Guild.Storage.LockTest do
  use ExUnit.Case, async: true

  import Aesir.TestWait

  alias Aesir.ZoneServer.Guild.Storage.Lock

  setup do
    %{guild_id: System.unique_integer([:positive])}
  end

  test "claim is exclusive and a losing claim returns immediately", %{guild_id: guild_id} do
    holder_pid = anchor()
    other_pid = anchor()

    assert :ok = Lock.claim(guild_id, 10, holder_pid)

    # A losing claim must be a definitive answer, not a race to wait out. The
    # budget sits below the 250ms a five-attempt, 50ms-apart retry would take,
    # so reintroducing one fails here. The real path is sub-millisecond -
    # raising this number to chase a flake would make the check vacuous.
    claim = Task.async(fn -> Lock.claim(guild_id, 20, other_pid) end)
    assert {:ok, {:error, :in_use}} = Task.yield(claim, 200)
  end

  test "holder reports the claiming character and session", %{guild_id: guild_id} do
    holder_pid = anchor()

    assert :error = Lock.holder(guild_id)
    assert :ok = Lock.claim(guild_id, 30, holder_pid)
    assert {:ok, %{char_id: 30, session_pid: ^holder_pid}} = Lock.holder(guild_id)
  end

  test "held_by? only recognizes the current session", %{guild_id: guild_id} do
    holder_pid = anchor()
    other_pid = anchor()

    refute Lock.held_by?(guild_id, holder_pid)
    assert :ok = Lock.claim(guild_id, 40, holder_pid)
    assert Lock.held_by?(guild_id, holder_pid)
    refute Lock.held_by?(guild_id, other_pid)
  end

  test "a non-holder cannot release another session's claim", %{guild_id: guild_id} do
    holder_pid = anchor()
    other_pid = anchor()

    assert :ok = Lock.claim(guild_id, 50, holder_pid)
    assert :ok = Lock.release(guild_id, other_pid)
    refute_eventually(fn -> Lock.holder(guild_id) == :error end)
    assert {:ok, %{char_id: 50, session_pid: ^holder_pid}} = Lock.holder(guild_id)
    assert {:error, :in_use} = Lock.claim(guild_id, 60, other_pid)
  end

  test "the holder can release its claim", %{guild_id: guild_id} do
    holder_pid = anchor()
    next_holder_pid = anchor()

    assert :ok = Lock.claim(guild_id, 70, holder_pid)
    assert :ok = Lock.release(guild_id, holder_pid)
    assert_eventually(fn -> Lock.claim(guild_id, 80, next_holder_pid) == :ok end)
    assert {:ok, %{char_id: 80, session_pid: ^next_holder_pid}} = Lock.holder(guild_id)
  end

  test "stop unconditionally drops a claim and is idempotent", %{guild_id: guild_id} do
    holder_pid = anchor()

    assert :ok = Lock.stop(guild_id)
    assert :ok = Lock.claim(guild_id, 90, holder_pid)
    assert :ok = Lock.stop(guild_id)
    assert_eventually(fn -> Lock.holder(guild_id) == :error end)
    assert :ok = Lock.stop(guild_id)
  end

  test "an anchor exit frees the guild for another session", %{guild_id: guild_id} do
    holder_pid = anchor()
    next_holder_pid = anchor()

    assert :ok = Lock.claim(guild_id, 100, holder_pid)
    Process.exit(holder_pid, :kill)

    assert_eventually(fn -> Lock.claim(guild_id, 110, next_holder_pid) == :ok end)
    assert {:ok, %{char_id: 110, session_pid: ^next_holder_pid}} = Lock.holder(guild_id)
  end

  defp anchor do
    pid = spawn(fn -> receive do: (:stop -> :ok) end)
    on_exit(fn -> if Process.alive?(pid), do: Process.exit(pid, :kill) end)
    pid
  end
end
