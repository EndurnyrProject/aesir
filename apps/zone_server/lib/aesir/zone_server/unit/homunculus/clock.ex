defmodule Aesir.ZoneServer.Unit.Homunculus.Clock do
  @moduledoc """
  Monotonic active-session and skill-cooldown clock helpers.

  Durable clocks are non-negative remaining milliseconds. While the owner is
  online, active time is held as `Runtime.active_deadline_ms` and cooldown map
  values are monotonic deadlines. `pause_cooldowns/2` converts deadlines back
  to durable remainders; `resume_cooldowns/2` performs the inverse conversion.
  """

  alias Aesir.ZoneServer.Unit.Homunculus.Runtime

  @active_duration_ms 1_800_000

  @type milliseconds :: non_neg_integer()
  @type deadline_ms :: integer()
  @type cooldowns :: %{optional(term()) => integer()}
  @type timer_start :: (milliseconds(), term() -> reference())
  @type timer_cancel :: (reference() -> term())
  @type timer_opts :: [timer_start: timer_start(), timer_cancel: timer_cancel()]

  @doc "Returns monotonic time in milliseconds."
  @spec now_ms() :: integer()
  def now_ms, do: System.monotonic_time(:millisecond)

  @doc "Returns the deadline for a fresh thirty-minute active session."
  @spec fresh_active_deadline(integer()) :: integer()
  def fresh_active_deadline(now_ms), do: now_ms + @active_duration_ms

  @doc "Converts a deadline to a non-negative paused remainder."
  @spec pause_remaining(integer(), integer()) :: non_neg_integer()
  def pause_remaining(deadline_ms, now_ms), do: max(deadline_ms - now_ms, 0)

  @doc "Converts a paused remainder to a monotonic deadline."
  @spec resume_deadline(non_neg_integer(), integer()) :: integer()
  def resume_deadline(remaining_ms, now_ms), do: now_ms + remaining_ms

  @doc "Converts every paused cooldown remainder to an online monotonic deadline."
  @spec resume_cooldowns(cooldowns(), integer()) :: cooldowns()
  def resume_cooldowns(cooldowns, now_ms) do
    Map.new(cooldowns, fn {skill_id, remaining_ms} ->
      {skill_id, resume_deadline(remaining_ms, now_ms)}
    end)
  end

  @doc "Converts every online cooldown deadline to a paused durable remainder."
  @spec pause_cooldowns(cooldowns(), integer()) :: cooldowns()
  def pause_cooldowns(cooldowns, now_ms) do
    Map.new(cooldowns, fn {skill_id, deadline_ms} ->
      {skill_id, pause_remaining(deadline_ms, now_ms)}
    end)
  end

  @doc "Returns the nearest cooldown deadline, or `nil` for an empty map."
  @spec nearest_cooldown(cooldowns()) :: integer() | nil
  def nearest_cooldown(cooldowns) do
    cooldowns
    |> Map.values()
    |> Enum.min(fn -> nil end)
  end

  @doc "Removes cooldowns whose online deadline is due."
  @spec remove_due_cooldowns(cooldowns(), integer()) :: cooldowns()
  def remove_due_cooldowns(cooldowns, now_ms) do
    Map.reject(cooldowns, fn {_skill_id, deadline_ms} -> deadline_ms <= now_ms end)
  end

  @doc """
  Snapshots online deadlines as durable non-negative remainders without touching timers.

  Task 8 uses this seam for checkpoints and graceful termination so it never
  persists the stale active-session seed or process-local monotonic deadlines.
  """
  @spec durable_snapshot(atom(), integer() | nil, cooldowns(), integer()) ::
          {:ok, %{active_remaining_ms: non_neg_integer(), cooldowns: cooldowns()}}
          | {:error, :invalid_clock_state}
  def durable_snapshot(lifecycle, active_deadline_ms, cooldowns, now_ms)
      when lifecycle in [:active, :rested, :dead] and is_map(cooldowns) and is_integer(now_ms) do
    with {:ok, active_remaining_ms} <- snapshot_active(lifecycle, active_deadline_ms),
         true <- Enum.all?(cooldowns, fn {_skill_id, deadline_ms} -> is_integer(deadline_ms) end) do
      {:ok,
       %{
         active_remaining_ms:
           if(lifecycle == :active, do: pause_remaining(active_remaining_ms, now_ms), else: 0),
         cooldowns: pause_cooldowns(cooldowns, now_ms)
       }}
    else
      _invalid -> {:error, :invalid_clock_state}
    end
  end

  def durable_snapshot(_lifecycle, _active_deadline_ms, _cooldowns, _now_ms),
    do: {:error, :invalid_clock_state}

  @doc """
  Arms an active-expiry timer for a deadline.

  The default OTP timer delivers `{:timeout, ref, {:homunculus, :active_expired}}`.
  """
  @spec arm_active(integer(), integer(), timer_opts()) :: reference()
  def arm_active(deadline_ms, now_ms, opts \\ []) do
    start_timer(max(deadline_ms - now_ms, 0), :active_expired, opts)
  end

  @doc "Arms one timer for the nearest cooldown, or returns `nil` when none exist."
  @spec arm_nearest_cooldown(cooldowns(), integer(), timer_opts()) :: reference() | nil
  def arm_nearest_cooldown(cooldowns, now_ms, opts \\ []) do
    case nearest_cooldown(cooldowns) do
      nil -> nil
      deadline_ms -> start_timer(max(deadline_ms - now_ms, 0), :cooldowns_expired, opts)
    end
  end

  @doc """
  Arms one Homunculus timer.

  The default OTP timer delivers `{:timeout, ref, {:homunculus, event}}`.
  """
  @spec arm(milliseconds(), term(), timer_opts()) :: reference()
  def arm(delay_ms, event, opts \\ []), do: start_timer(delay_ms, event, opts)

  @doc "Cancels the timer stored in one `Runtime` field and clears the field."
  @spec cancel_field(Runtime.t(), atom(), timer_opts()) :: Runtime.t()
  def cancel_field(%Runtime{} = runtime, field, opts \\ []) do
    runtime |> Map.fetch!(field) |> cancel(opts)
    Map.put(runtime, field, nil)
  end

  @doc "Cancels every timer-reference field of the `Runtime` and clears them all."
  @spec cancel_all(Runtime.t(), timer_opts()) :: Runtime.t()
  def cancel_all(%Runtime{} = runtime, opts \\ []) do
    Enum.reduce(Runtime.timer_fields(), runtime, &cancel_field(&2, &1, opts))
  end

  @doc "Cancels a stored OTP timer reference."
  @spec cancel(reference() | nil, timer_opts()) :: :ok
  def cancel(timer_ref, opts \\ [])
  def cancel(nil, _opts), do: :ok

  def cancel(timer_ref, opts) when is_reference(timer_ref) do
    cancel_timer = Keyword.get(opts, :timer_cancel, &Process.cancel_timer/1)
    cancel_timer.(timer_ref)
    :ok
  end

  @doc "Checks received timer identity against the currently stored reference."
  @spec current_timer?(reference() | nil, reference() | nil) :: boolean()
  def current_timer?(stored_ref, received_ref)
      when is_reference(stored_ref) and is_reference(received_ref),
      do: stored_ref == received_ref

  def current_timer?(_stored_ref, _received_ref), do: false

  defp snapshot_active(:active, active_deadline_ms) when is_integer(active_deadline_ms),
    do: {:ok, active_deadline_ms}

  defp snapshot_active(lifecycle, nil) when lifecycle in [:rested, :dead], do: {:ok, 0}
  defp snapshot_active(_lifecycle, _active_deadline_ms), do: :error

  defp start_timer(delay_ms, event, opts) do
    timer_start = Keyword.get(opts, :timer_start, &default_start_timer/2)
    timer_start.(delay_ms, event)
  end

  defp default_start_timer(delay_ms, event) do
    :erlang.start_timer(delay_ms, self(), {:homunculus, event})
  end
end
