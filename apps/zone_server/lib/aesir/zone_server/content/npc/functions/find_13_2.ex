defmodule Aesir.ZoneServer.Content.Npc.Functions.Find132 do
  @moduledoc """
  Runs the mineral detector dialogue for the daily quest.

  ## Behavior

  - Checks quest progress, detector possession, and mineral count.
  - Offers a location check and optionally returns to the calling script.

  ## Credits

  - Original from rAthena, authors and contributors:
    - L0ne_W0lf
    - Gepard
    - Masao
    - Euphy
    - Joseph
    - Jeybla
    - Mazvi

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  import Aesir.ZoneServer.Script.Dsl, warn: false
  alias Aesir.ZoneServer.Script.Rathena

  @doc "Callable rAthena global function; returns `{ctx, return_value}`."
  def call(ctx, args) do
    ctx =
      case Enum.at(args, 0, 0) do
        0 -> ctx |> set_local(:Check, [2, 10]) |> set_local(:"str$", "Mt. Mjolnir")
        1 -> ctx |> set_local(:Check, [3, 5]) |> set_local(:"str$", "Abyss Lake")
        2 -> ctx |> set_local(:Check, [4, 5]) |> set_local(:"str$", "Thor Volcano")
        _ -> ctx
      end

    if get_char_var(ctx, :ep13_2_tre, 0) != Enum.at(get_local(ctx, :Check, []), 0, 0) or
         count_item(ctx, 6076) != 1 or
         count_item(ctx, 6077) >= Enum.at(get_local(ctx, :Check, []), 1, 0) do
      throw({:script_end, ctx})
    else
      check_location(ctx, args)
    end
  end

  defp check_location(ctx, args) do
    {ctx, choice} =
      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat("- Just arrived at ", get_local(ctx, :"str$", "")),
          ". I think I can find the mineral by using the Mineral Detector in the Portable Toolbox. -"
        )
      )
      |> next()
      |> select(["Check current location.", "Do nothing."])

    case choice do
      1 ->
        ctx =
          ctx
          |> mes("- You pressed the button of the detector. -")
          |> next()
          |> mes("[Mineral Detector]")
          |> mes("Bee beep -")

        if Rathena.truthy?(Enum.at(args, 1, 0)) do
          {ctx, nil}
        else
          ctx = ctx |> next() |> mes("- Nothing's found. -") |> close()
          throw({:script_end, ctx})
        end

      2 ->
        ctx = ctx |> mes("- You decide to do nothing. -") |> close()
        throw({:script_end, ctx})

      _ ->
        throw({:script_end, ctx})
    end
  end
end
