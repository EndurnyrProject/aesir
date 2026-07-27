defmodule Aesir.TestWait do
  @moduledoc """
  Polling helpers for tests that drive real processes.

  Anything that goes through a session, a manager tick or a PubSub broadcast
  lands a few milliseconds after the call that triggered it, so a single read
  right after the trigger is a race. These poll until the condition holds or the
  budget runs out, and return as soon as it does - a passing test pays only the
  time it actually waited.

      assert eventually(fn -> StatusStorage.has_status?(:player, id, :sc_bless) end)
      assert_eventually(fn -> Storage.get(group_id) == nil end)
      refute_eventually(fn -> StatusStorage.has_status?(:mob, id, :sc_freeze) end)

  The budget is a timeout in milliseconds, not an attempt count, so changing the
  poll interval cannot silently change how long a test waits. The default is
  deliberately generous: the cost only shows up on a failing assertion, while too
  tight a budget shows up as a flake under full-suite load.

  `refute_eventually/3` always burns its whole window (that is what it is
  asserting), so it defaults to a much shorter one.
  """

  import ExUnit.Assertions

  @default_timeout 4_000
  @default_interval 25
  @default_refute_window 500

  @typedoc "A zero-arity check, run repeatedly until it returns a truthy value."
  @type check :: (-> as_boolean(term()))

  @doc """
  Returns `true` as soon as `check` holds, or `false` once `timeout` has passed.
  """
  @spec eventually(check(), timeout(), pos_integer()) :: boolean()
  def eventually(check, timeout \\ @default_timeout, interval \\ @default_interval)
      when is_function(check, 0) do
    poll(check, System.monotonic_time(:millisecond) + timeout, interval)
  end

  @doc """
  Like `eventually/3`, but fails the test when `check` never holds.
  """
  @spec assert_eventually(check(), timeout(), pos_integer()) :: true
  def assert_eventually(check, timeout \\ @default_timeout, interval \\ @default_interval) do
    assert eventually(check, timeout, interval),
           "condition never became true within #{timeout}ms"
  end

  @doc """
  Fails the test if `check` ever holds within `window`.
  """
  @spec refute_eventually(check(), timeout(), pos_integer()) :: false
  def refute_eventually(check, window \\ @default_refute_window, interval \\ @default_interval) do
    refute eventually(check, window, interval),
           "condition became true within #{window}ms"
  end

  defp poll(check, deadline, interval) do
    cond do
      check.() ->
        true

      System.monotonic_time(:millisecond) >= deadline ->
        false

      true ->
        Process.sleep(interval)
        poll(check, deadline, interval)
    end
  end
end
