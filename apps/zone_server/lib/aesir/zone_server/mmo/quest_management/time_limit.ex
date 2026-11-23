defmodule Aesir.ZoneServer.Mmo.QuestManagement.TimeLimit do
  @moduledoc """
  Parses a quest `TimeLimit` and turns it into an expiry timestamp, ported from
  rAthena (`quest.cpp` `split_exact_quest_time` and `quest_time`, `timer.cpp`
  `solve_time`). Pure: the caller supplies the clock.

    * `:none` - the quest never expires on its own.
    * `{:relative, seconds}` - a string with a `+` (`+3h`, `+1h30mn`, `+1d`),
      units `s`, `n`/`mn`, `h`, `d`/`j`, expiring that long after the clock.
    * `{:at, time, week}` - a time of day (`4h`, `7d 4h`, `Monday 4h`).
      `time` is rAthena's `quest->time`: seconds of day, plus whole days
      unless a weekday other than Sunday is given. `week` is `0` (Sunday)
      to `6`, or `-1` for none.

  Relative months and years (`m`, `y`, `a`) are rejected: rAthena resolves them
  against the calendar, which a fixed number of seconds cannot hold, and no
  shipped quest uses them.
  """

  @type t :: :none | {:relative, pos_integer()} | {:at, non_neg_integer(), -1..6}

  @weekdays [
    {"sunday", 0},
    {"monday", 1},
    {"tuesday", 2},
    {"wednesday", 3},
    {"thursday", 4},
    {"friday", 5},
    {"saturday", 6}
  ]

  @spec parse(String.t() | nil) :: {:ok, t()} | {:error, String.t()}
  def parse(nil), do: {:ok, :none}
  def parse(""), do: {:ok, :none}

  def parse(string) when is_binary(string) do
    if String.contains?(string, "+"), do: parse_relative(string), else: parse_at(string)
  end

  @spec parse!(String.t() | nil) :: t()
  def parse!(string) do
    case parse(string) do
      {:ok, limit} -> limit
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @doc """
  The Unix time the limit expires for a quest started at `now_unix`, which is
  `local_now` on the server clock. `0` means it never expires. A time of day
  equal to the current one rolls to the next day, as in rAthena.
  """
  @spec deadline(t(), integer(), NaiveDateTime.t()) :: non_neg_integer()
  def deadline(:none, _now_unix, _local_now), do: 0
  def deadline({:relative, seconds}, now_unix, _local_now), do: now_unix + seconds

  def deadline({:at, time, week}, now_unix, local_now) do
    time_today = local_now.hour * 3600 + local_now.minute * 60 + local_now.second
    wday = local_now |> NaiveDateTime.to_date() |> Date.day_of_week() |> rem(7)
    day_shift = if time_today >= rem(time, 86_400), do: 1, else: 0

    day_shift =
      cond do
        week < 0 -> day_shift
        week < wday + day_shift -> week + 7 - wday
        true -> week - wday
      end

    now_unix + day_shift * 86_400 + time - time_today
  end

  defp parse_relative(string) do
    case scan_relative(string, 0) do
      {:ok, seconds} when seconds > 0 ->
        {:ok, {:relative, seconds}}

      {:ok, _seconds} ->
        {:error, "Incorrect TimeLimit format #{inspect(string)} given"}

      :unsupported ->
        {:error, "TimeLimit #{inspect(string)} uses months or years, which are not supported"}
    end
  end

  defp scan_relative("", seconds), do: {:ok, seconds}

  defp scan_relative(<<_, tail::binary>> = rest, seconds) do
    case number(rest) do
      {0, _after_number} -> scan_relative(tail, seconds)
      {value, rest} -> scan_relative_unit(rest, value, seconds)
    end
  end

  defp scan_relative_unit("s" <> rest, value, seconds), do: scan_relative(rest, seconds + value)

  defp scan_relative_unit("n" <> rest, value, seconds),
    do: scan_relative(rest, seconds + value * 60)

  defp scan_relative_unit("mn" <> rest, value, seconds),
    do: scan_relative(rest, seconds + value * 60)

  defp scan_relative_unit("h" <> rest, value, seconds),
    do: scan_relative(rest, seconds + value * 3600)

  defp scan_relative_unit(<<c, rest::binary>>, value, seconds) when c in ~c"dj",
    do: scan_relative(rest, seconds + value * 86_400)

  defp scan_relative_unit(<<c, _::binary>>, _value, _seconds) when c in ~c"may", do: :unsupported
  defp scan_relative_unit(<<_, rest::binary>>, _value, seconds), do: scan_relative(rest, seconds)
  defp scan_relative_unit("", _value, seconds), do: {:ok, seconds}

  defp parse_at(string) do
    fields = scan_at(string, %{week: -1, day: -1, hour: -1, minute: -1, second: -1})

    if fields.hour in 0..23 and fields.minute <= 59 and fields.second <= 59 do
      time =
        fields.hour * 3600 + max(0, fields.minute) * 60 + max(0, fields.second) +
          if(fields.week > 0, do: 0, else: max(0, fields.day) * 86_400)

      {:ok, {:at, time, fields.week}}
    else
      {:error, "Incorrect TimeLimit format #{inspect(string)} given"}
    end
  end

  defp scan_at("", fields), do: fields

  defp scan_at(rest, fields) do
    {value, rest} = number(rest)

    case weekday(rest) do
      {week, size} ->
        scan_at(binary_part(rest, size, byte_size(rest) - size), %{fields | week: week})

      nil ->
        scan_at_unit(rest, value, fields)
    end
  end

  defp scan_at_unit("s" <> rest, value, fields), do: scan_at(rest, %{fields | second: value})
  defp scan_at_unit("mn" <> rest, value, fields), do: scan_at(rest, %{fields | minute: value})
  defp scan_at_unit("h" <> rest, value, fields), do: scan_at(rest, %{fields | hour: value})

  defp scan_at_unit(<<c, rest::binary>>, value, fields) when c in ~c"dj",
    do: scan_at(rest, %{fields | day: value})

  defp scan_at_unit(<<_, rest::binary>>, _value, fields), do: scan_at(rest, fields)
  defp scan_at_unit("", _value, fields), do: fields

  defp weekday(rest) do
    down = String.downcase(rest, :ascii)

    Enum.find_value(@weekdays, fn {name, week} ->
      String.starts_with?(down, name) && {week, byte_size(name)}
    end)
  end

  # C `atoi` reads past leading whitespace, but the scan pointer only moves over
  # the sign and digits, so "4 h" reads the `h` as 0 hours.
  defp number(rest) do
    value =
      case Integer.parse(String.trim_leading(rest)) do
        {value, _} -> value
        :error -> 0
      end

    {value, skip_digits(skip_sign(rest))}
  end

  defp skip_sign(<<sign, rest::binary>>) when sign in ~c"+-", do: rest
  defp skip_sign(rest), do: rest

  defp skip_digits(<<digit, rest::binary>>) when digit in ?0..?9, do: skip_digits(rest)
  defp skip_digits(rest), do: rest
end
