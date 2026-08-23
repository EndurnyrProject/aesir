defmodule Aesir.ZoneServer.Guild.Storage.LockTest do
  use ExUnit.Case, async: false

  import Aesir.TestWait

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.ZoneServer.Guild.Storage.Lock

  setup do
    ClusterTestHelper.clear_all()
    on_exit(&ClusterTestHelper.clear_all/0)
    :ok
  end

  test "claim is exclusive and a losing claim returns immediately" do
    holder_pid = anchor()
    other_pid = anchor()

    assert :ok = Lock.claim(1, 10, holder_pid)

    # A losing claim must be a definitive answer, not a race to wait out. The
    # budget sits below the 250ms a five-attempt, 50ms-apart retry would take,
    # so reintroducing one fails here. The real path is sub-millisecond -
    # raising this number to chase a flake would make the check vacuous.
    claim = Task.async(fn -> Lock.claim(1, 20, other_pid) end)
    assert {:ok, {:error, :in_use}} = Task.yield(claim, 200)
  end

  test "holder reports the claiming character and session" do
    holder_pid = anchor()

    assert :error = Lock.holder(2)
    assert :ok = Lock.claim(2, 30, holder_pid)
    assert {:ok, %{char_id: 30, session_pid: ^holder_pid}} = Lock.holder(2)
  end

  test "held_by? only recognizes the current session" do
    holder_pid = anchor()
    other_pid = anchor()

    refute Lock.held_by?(3, holder_pid)
    assert :ok = Lock.claim(3, 40, holder_pid)
    assert Lock.held_by?(3, holder_pid)
    refute Lock.held_by?(3, other_pid)
  end

  test "a non-holder cannot release another session's claim" do
    holder_pid = anchor()
    other_pid = anchor()

    assert :ok = Lock.claim(4, 50, holder_pid)
    assert :ok = Lock.release(4, other_pid)
    refute_eventually(fn -> Lock.holder(4) == :error end)
    assert {:ok, %{char_id: 50, session_pid: ^holder_pid}} = Lock.holder(4)
    assert {:error, :in_use} = Lock.claim(4, 60, other_pid)
  end

  test "the holder can release its claim" do
    holder_pid = anchor()
    next_holder_pid = anchor()

    assert :ok = Lock.claim(5, 70, holder_pid)
    assert :ok = Lock.release(5, holder_pid)
    assert_eventually(fn -> Lock.claim(5, 80, next_holder_pid) == :ok end)
    assert {:ok, %{char_id: 80, session_pid: ^next_holder_pid}} = Lock.holder(5)
  end

  test "stop unconditionally drops a claim and is idempotent" do
    holder_pid = anchor()

    assert :ok = Lock.stop(6)
    assert :ok = Lock.claim(6, 90, holder_pid)
    assert :ok = Lock.stop(6)
    assert_eventually(fn -> Lock.holder(6) == :error end)
    assert :ok = Lock.stop(6)
  end

  test "an anchor exit frees the guild for another session" do
    holder_pid = anchor()
    next_holder_pid = anchor()

    assert :ok = Lock.claim(7, 100, holder_pid)
    Process.exit(holder_pid, :kill)

    assert_eventually(fn -> Lock.claim(7, 110, next_holder_pid) == :ok end)
    assert {:ok, %{char_id: 110, session_pid: ^next_holder_pid}} = Lock.holder(7)
  end

  defp anchor do
    pid = spawn(fn -> receive do: (:stop -> :ok) end)
    on_exit(fn -> if Process.alive?(pid), do: Process.exit(pid, :kill) end)
    pid
  end
end
