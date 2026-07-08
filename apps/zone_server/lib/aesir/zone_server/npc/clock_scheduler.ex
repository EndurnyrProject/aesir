defmodule Aesir.ZoneServer.Npc.ClockScheduler do
  @moduledoc """
  Single process per zone node that fires rAthena's clock-style NPC labels:

  - `OnClock<HHMM>` — once a day, at that exact time (e.g. `OnClock2359`).
  - `OnHour<HH>` — once an hour, at minute `00` (e.g. `OnHour03` = 03:00).
  - `OnMinute<MM>` — once an hour, at minute `MM` (e.g. `OnMinute30`).
  - `On<Ddd><HHMM>` — once a week, `Ddd` in `Sun`/`Mon`/`Tue`/`Wed`/`Thu`/
    `Fri`/`Sat` (e.g. `OnSun2359`).

  Time is server local time (`NaiveDateTime.local_now/0` by default,
  injectable via the `:now_fun` option for tests), matching rAthena's
  wall-clock semantics.

  The wake-up is armed to the next minute boundary (`ms_until_next_minute/1`)
  rather than a fixed interval, so ticks land on `:00` of every minute
  without drift. Each tick re-reads `Npc.Registry.labels/0` rather than
  caching the label set at init: a registry reload (`@reloadscript`) can add
  or remove clock labels, and with the corpus's label count the per-minute
  cost of re-scanning is nil.

  Matching (`matching_labels/2`) and arming (`ms_until_next_minute/1`) are
  pure functions, independently testable against fixed `NaiveDateTime`s with
  no process machinery.
  """

  use GenServer
  use TypedStruct

  alias Aesir.ZoneServer.Npc.Events
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry

  @weekdays {"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"}

  @clock_pattern ~r/^OnClock(\d{2})(\d{2})$/
  @hour_pattern ~r/^OnHour(\d{2})$/
  @minute_pattern ~r/^OnMinute(\d{2})$/
  @weekday_pattern ~r/^On(Sun|Mon|Tue|Wed|Thu|Fri|Sat)(\d{2})(\d{2})$/

  typedstruct do
    field :now_fun, (-> NaiveDateTime.t()), enforce: true
  end

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Returns the subset of `labels` that match the given `datetime`, in
  rAthena's clock semantics. Non-clock labels (`OnInit`, `OnTouch`,
  `OnTimer<ms>`, ...) never match.
  """
  @spec matching_labels([String.t()], NaiveDateTime.t()) :: [String.t()]
  def matching_labels(labels, %NaiveDateTime{} = datetime) do
    Enum.filter(labels, &matches?(&1, datetime))
  end

  @doc """
  Milliseconds until the next minute boundary (`:00` seconds), given `now`.
  Returns the full `60_000` when `now` already sits exactly on a boundary,
  never `0`.
  """
  @spec ms_until_next_minute(NaiveDateTime.t()) :: pos_integer()
  def ms_until_next_minute(%NaiveDateTime{} = now) do
    {microsecond, _precision} = now.microsecond
    ms_into_minute = now.second * 1_000 + div(microsecond, 1_000)
    60_000 - ms_into_minute
  end

  @impl true
  def init(opts) do
    now_fun = Keyword.get(opts, :now_fun, &NaiveDateTime.local_now/0)
    state = %__MODULE__{now_fun: now_fun}
    arm_next_tick(state)
    {:ok, state}
  end

  @impl true
  def handle_info(:tick, state) do
    now = state.now_fun.()

    NpcRegistry.labels()
    |> matching_labels(now)
    |> Enum.each(&Events.trigger_all/1)

    arm_next_tick(state)
    {:noreply, state}
  end

  @spec arm_next_tick(t()) :: reference()
  defp arm_next_tick(state) do
    Process.send_after(self(), :tick, ms_until_next_minute(state.now_fun.()))
  end

  @spec matches?(String.t(), NaiveDateTime.t()) :: boolean()
  defp matches?(label, datetime) do
    clock_matches?(label, datetime) or hour_matches?(label, datetime) or
      minute_matches?(label, datetime) or weekday_matches?(label, datetime)
  end

  @spec clock_matches?(String.t(), NaiveDateTime.t()) :: boolean()
  defp clock_matches?(label, datetime) do
    case Regex.run(@clock_pattern, label) do
      [_, hour, minute] ->
        datetime.hour == String.to_integer(hour) and
          datetime.minute == String.to_integer(minute)

      nil ->
        false
    end
  end

  @spec hour_matches?(String.t(), NaiveDateTime.t()) :: boolean()
  defp hour_matches?(label, datetime) do
    case Regex.run(@hour_pattern, label) do
      [_, hour] -> datetime.hour == String.to_integer(hour) and datetime.minute == 0
      nil -> false
    end
  end

  @spec minute_matches?(String.t(), NaiveDateTime.t()) :: boolean()
  defp minute_matches?(label, datetime) do
    case Regex.run(@minute_pattern, label) do
      [_, minute] -> datetime.minute == String.to_integer(minute)
      nil -> false
    end
  end

  @spec weekday_matches?(String.t(), NaiveDateTime.t()) :: boolean()
  defp weekday_matches?(label, datetime) do
    case Regex.run(@weekday_pattern, label) do
      [_, ddd, hour, minute] ->
        weekday(datetime) == ddd and datetime.hour == String.to_integer(hour) and
          datetime.minute == String.to_integer(minute)

      nil ->
        false
    end
  end

  @spec weekday(NaiveDateTime.t()) :: String.t()
  defp weekday(datetime) do
    day_index = datetime |> NaiveDateTime.to_date() |> Date.day_of_week()
    elem(@weekdays, day_index - 1)
  end
end
