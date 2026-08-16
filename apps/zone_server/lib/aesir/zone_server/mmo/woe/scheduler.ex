defmodule Aesir.ZoneServer.Mmo.Woe.Scheduler do
  @moduledoc """
  Config-driven auto start/stop of WoE on a minute tick.

  Arms to the next minute boundary (`Npc.ClockScheduler.ms_until_next_minute/1`)
  and on each tick compares the wall-clock `desired_state/2` (over
  `Config.woe_schedule/0`) with `Woe.Server.active?/0`, calling `start/0` or
  `stop/0` only when the state must change. Because both are idempotent, a
  missed edge self-heals on the next tick — e.g. a restart mid-WoE sees
  `desired_state == :active` against an inactive server and re-arms via
  `start/0`.

  Time is server local time (`NaiveDateTime.local_now/0` by default, injectable
  via the `:now_fun` option for tests).
  """

  use GenServer

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Woe.Server
  alias Aesir.ZoneServer.Npc.ClockScheduler

  @type window :: {1..7, {0..23, 0..59}, {0..23, 0..59}}

  @day_minutes 1440
  @week_minutes 10_080

  @enforce_keys [:now_fun]
  defstruct [:now_fun]

  @type t() :: %__MODULE__{
          now_fun: (-> NaiveDateTime.t())
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Whether WoE should be active at `datetime`, given the weekly `windows` of
  `{day, {h, m}, {h, m}}` tuples (`day` is the ISO weekday, 1 = Monday).

  A window covers its start time (inclusive) up to its stop time (exclusive);
  a stop at or before the start wraps past midnight (equal times span a full
  day).
  """
  @spec desired_state([window()], NaiveDateTime.t()) :: :active | :inactive
  def desired_state(windows, %NaiveDateTime{} = datetime) do
    if Enum.any?(windows, &in_window?(&1, datetime)), do: :active, else: :inactive
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
    case {desired_state(Config.woe_schedule(), state.now_fun.()), Server.active?()} do
      {:active, false} -> Server.start()
      {:inactive, true} -> Server.stop()
      _ -> :ok
    end

    arm_next_tick(state)
    {:noreply, state}
  end

  @spec arm_next_tick(t()) :: reference()
  defp arm_next_tick(state) do
    Process.send_after(self(), :tick, ClockScheduler.ms_until_next_minute(state.now_fun.()))
  end

  @spec in_window?(window(), NaiveDateTime.t()) :: boolean()
  defp in_window?({day, start, stop}, datetime) do
    start_minute = minute_of_week(day, start)
    end_minute = minute_of_week(day, stop)
    end_minute = if end_minute > start_minute, do: end_minute, else: end_minute + @day_minutes
    minute = minute_of_week(datetime)

    if end_minute <= @week_minutes do
      minute >= start_minute and minute < end_minute
    else
      minute >= start_minute or minute < end_minute - @week_minutes
    end
  end

  @spec minute_of_week(1..7, {0..23, 0..59}) :: non_neg_integer()
  defp minute_of_week(day, {hour, minute}) do
    (day - 1) * 24 * 60 + hour * 60 + minute
  end

  @spec minute_of_week(NaiveDateTime.t()) :: non_neg_integer()
  defp minute_of_week(datetime) do
    day = datetime |> NaiveDateTime.to_date() |> Date.day_of_week()
    minute_of_week(day, {datetime.hour, datetime.minute})
  end
end
