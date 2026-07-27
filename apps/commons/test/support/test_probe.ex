defmodule Aesir.TestProbe do
  @moduledoc """
  Registers the running test process under a fixed name, tolerating the
  previous test's not-yet-reaped process.

  ExUnit's runner stops waiting for a test process as soon as that process
  reports its result: `receive_test_reply/4` demonitors on `:test_finished`,
  and the test process only calls `exit(:shutdown)` afterwards. The next test's
  `setup` can therefore run while the previous test process is still alive and
  still holding its registered name, and a bare `Process.register/2` blows up
  with "the name is already taken". Waiting for the name to be released instead
  keeps the probe pattern deterministic.
  """

  @doc """
  Registers `self()` as `name`, waiting up to `timeout` ms for a previous
  holder to go away first.
  """
  @spec register!(atom(), timeout()) :: :ok
  def register!(name, timeout \\ 1_000) when is_atom(name) do
    await_free(name, timeout)
    Process.register(self(), name)
    :ok
  end

  defp await_free(name, timeout) do
    case Process.whereis(name) do
      nil ->
        :ok

      pid ->
        ref = Process.monitor(pid)

        receive do
          {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
        after
          timeout ->
            Process.demonitor(ref, [:flush])
            :ok
        end
    end
  end
end
