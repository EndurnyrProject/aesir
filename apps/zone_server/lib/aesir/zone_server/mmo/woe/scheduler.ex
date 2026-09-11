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

  Each tick also runs the daily castle guard: maturation applies on the
  first tick at or after 00:01 whose date differs from the last matured
  date (catch-up safe if a tick is missed), and treasure spawns only on
  the tick that lands exactly at 00:01.
  """

  use GenServer

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Woe.Economy
  alias Aesir.ZoneServer.Mmo.Woe.Server
  alias Aesir.ZoneServer.Mmo.Woe.Treasure
  alias Aesir.ZoneServer.Npc.ClockScheduler

  @type window :: {1..7, {0..23, 0..59}, {0..23, 0..59}}

  @day_minutes 1440
  @week_minutes 10_080

  @enforce_keys [:now_fun]
  defstruct now_fun: nil, last_matured_on: nil

  @type t() :: %__MODULE__{
          now_fun: (-> NaiveDateTime.t()),
          last_matured_on: Date.t() | nil
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

  @doc """
  Whether `state` should run daily maturation and/or spawn treasure at `now`.

  Maturation runs on the first tick at or after 00:01 whose date differs
  from `state.last_matured_on` (catch-up safe if a tick was missed);
  treasure spawns only on the tick landing exactly at 00:01.
  """
  @spec daily_actions(t(), NaiveDateTime.t()) ::
          {mature? :: boolean(), spawn_treasure? :: boolean()}
  def daily_actions(%__MODULE__{last_matured_on: last_matured_on}, %NaiveDateTime{} = now) do
    past_0001? = now.hour > 0 or now.minute >= 1
    mature? = past_0001? and NaiveDateTime.to_date(now) != last_matured_on
    spawn? = now.hour == 0 and now.minute == 1

    {mature?, spawn?}
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

    case {desired_state(Config.woe_schedule(), now), Server.active?()} do
      {:active, false} -> Server.start()
      {:inactive, true} -> Server.stop()
      _ -> :ok
    end

    {mature?, spawn_treasure?} = daily_actions(state, now)

    state =
      if mature? do
        Economy.mature_all()
        %{state | last_matured_on: NaiveDateTime.to_date(now)}
      else
        state
      end

    if spawn_treasure?, do: Treasure.spawn_all()

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
