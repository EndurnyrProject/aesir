defmodule Aesir.ZoneServer.Content.Npc.Functions.Time2str do
  @moduledoc """
  Formats the time left until a Unix timestamp.

  ## Behavior

  The remaining seconds are split into days, hours, minutes and seconds, and every non-zero unit is
  written out with its singular or plural noun. A remaining time of zero still reports
  `0 seconds`; a timestamp in the past reports nothing.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script other/Global_Functions.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Script.Ctx

  @seconds_per_day 86_400
  @seconds_per_hour 3600
  @seconds_per_minute 60

  @doc """
  Callable rAthena global function `Time2Str(tick)`; returns the remaining time in words.
  """
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), String.t()}
  def call(ctx, args) do
    remaining = Enum.at(args, 0, 0) - gettimetick(ctx, 2)

    days = div(remaining, @seconds_per_day)
    remaining = remaining - days * @seconds_per_day

    hours = div(remaining, @seconds_per_hour)
    remaining = remaining - hours * @seconds_per_hour

    minutes = div(remaining, @seconds_per_minute)
    remaining = remaining - minutes * @seconds_per_minute

    text =
      amount(days, "day") <>
        amount(hours, "hour") <> amount(minutes, "minute") <> seconds(remaining)

    {ctx, text}
  end

  defp amount(1, unit), do: "1 " <> unit <> ", "
  defp amount(value, unit) when value > 1, do: "#{value} #{unit}s, "
  defp amount(_value, _unit), do: ""

  defp seconds(0), do: "0 seconds"
  defp seconds(1), do: "1 second"
  defp seconds(value) when value > 1, do: "#{value} seconds"
  defp seconds(_past), do: ""
end
