defmodule Aesir.ZoneServer.Content.Npc.Functions.Guard131 do
  @moduledoc """
  Guardian of the Lighthalzen dimensional gate, who measures a player's standing in the
  three kingdoms before letting them through.

  ## Behavior

  - Sends a player past step 19 back to the Time-Gap of Dimension instead of opening the
    gate.
  - Waves in a player past step 8 who comes to register with the three kingdoms.
  - Refuses everyone else, walking them to the gate's destination only when the caller
    passes a truthy `touch` argument.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @destination "lhz_in01"

  @doc """
  Callable rAthena global function `Guard_13_1(touch, x, y)`; throws `{:script_end, ctx}`
  once the guard's dialog ends the calling script.
  """
  @spec call(Ctx.t(), [integer()]) :: no_return()
  def call(ctx, args) do
    ctx = mes(ctx, "[Guard]")
    progress = get_char_var(ctx, :ep13_ryu, 0)

    cond do
      progress > 19 -> turn_away(ctx, args)
      progress > 8 -> admit(ctx)
      true -> refuse(ctx, args)
    end
  end

  defp turn_away(ctx, args) do
    ctx
    |> mes("You're not allowed to enter.")
    |> mes("All of you are instructed to go to the Time-Gap of Dimension on Rune-Midgarts!")
    |> next()
    |> mes("[Guard]")
    |> mes("Just go there.")
    |> mes("This is a restricted area.")
    |> close()
    |> warp_to(args)
    |> halt()
  end

  defp admit(ctx) do
    ctx
    |> mes("You've come here")
    |> mes("to register as a member of the three kingdoms?")
    |> next()
    |> mes("[Guard]")
    |> mes("Enter.")
    |> close()
    |> halt()
  end

  defp refuse(ctx, args) do
    ctx = ctx |> mes("You are not allowed") |> mes("to enter.")

    if Rathena.truthy?(Enum.at(args, 0, 0)) do
      ctx |> close() |> warp_to(args) |> halt()
    else
      ctx |> close() |> halt()
    end
  end

  defp warp_to(ctx, args) do
    warp(ctx, @destination, Enum.at(args, 1, 0), Enum.at(args, 2, 0))
  end

  defp halt(ctx), do: throw({:script_end, ctx})
end
