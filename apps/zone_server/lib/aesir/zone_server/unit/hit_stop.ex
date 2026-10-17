defmodule Aesir.ZoneServer.Unit.HitStop do
  @moduledoc """
  How a damaging hit stops a walking unit.

  A delivered hit marked `:walk_delay?` (`DamageShared.walk_delay?/2`, and no
  endure time running as it was dealt) stops a living, walking unit that does
  not otherwise endure it (`Endure.holds?/4`, full form).
  The unit stops on the nearest cell: when at most half of the step it is taking
  is left, it finishes that step and its walk ends there; otherwise it stays on
  its cell. Nothing else is delayed: the unit may walk again at once.

  Each walking unit records its pending step (`t:step/0`) when it schedules it,
  so the stop knows how far the step got. The step's timer delivers
  `{:timeout, timer, message}`, and the owner takes a step only when `current?/2`
  says it is the one recorded: every stop clears the record, so a stopped walk's
  timer never drives the unit's next walk.
  """

  @typedoc """
  A scheduled step: when it lands and how long it takes (monotonic
  milliseconds), and the timer that will take it; nil when none is known.
  """
  @type step :: {integer(), non_neg_integer(), reference()} | nil

  @doc "Whether a delivery's metadata asks the target to stop walking."
  @spec stops_walk?(map()) :: boolean()
  def stops_walk?(metadata), do: Map.get(metadata, :walk_delay?, false) == true

  @doc """
  Where the stop leaves a walking unit whose pending step is `step` at `now`:
  `:finish_step` when at most half of the step is left, else `:stay`.
  """
  @spec plan(step(), integer()) :: :finish_step | :stay
  def plan({due_at, duration, _timer}, now) when due_at - now <= div(duration, 2),
    do: :finish_step

  def plan(_step, _now), do: :stay

  @doc """
  Sends `{:timeout, timer, message}` to the calling process after `duration`
  milliseconds and returns the step record for it.
  """
  @spec schedule(term(), non_neg_integer()) :: step()
  def schedule(message, duration) do
    now = now()
    {now + duration, duration, :erlang.start_timer(duration, self(), message)}
  end

  @doc "Whether `timer` belongs to the recorded pending `step`."
  @spec current?(step(), reference()) :: boolean()
  def current?({_due_at, _duration, timer}, timer), do: true
  def current?(_step, _timer), do: false

  @doc "Cancels a pending step's timer."
  @spec cancel(step()) :: :ok
  def cancel({_due_at, _duration, timer}) do
    Process.cancel_timer(timer)
    :ok
  end

  def cancel(nil), do: :ok

  @doc "The clock steps are recorded on."
  @spec now() :: integer()
  def now, do: System.monotonic_time(:millisecond)
end
