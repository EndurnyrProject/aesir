defmodule Aesir.ZoneServer.Content.Npc.Cities.Moscovia.MoscoviaPROfficer do
  @moduledoc """
  Offers travelers passage from Moscovia back to Alberta.

  ## Behavior

  - Lets the player return to Alberta or remain in Moscovia.
  - Uses mode-specific arrival coordinates in Alberta.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moscovia",
        x: 166,
        y: 53,
        dir: 4,
        sprite: 960,
        name: "Moscovia P.R. Officer",
        scope: :shared,
        unique_name: "Moscovia P.R. Officer#2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Moscovia P.R. Officer]")
      |> mes("How was your trip?")
      |> mes("Do you have good memories from Moscovia?")
      |> mes("A ship is now leaving")
      |> mes("for Rune-Midgarts.")
      |> next()
      |> select(["Return to Alberta", "Cancel"])

    if choice == 2 do
      ctx
      |> mes("[Moscovia P.R. Officer]")
      |> mes("If you want to see more")
      |> mes("please take your time.")
      |> close()
    else
      return_to_alberta(ctx)
    end
  end

  defp return_to_alberta(ctx) do
    ctx =
      ctx
      |> mes("[Moscovia P.R. Officer]")
      |> mes("Please come and visit soon.")
      |> mes("Ok then, Let's get going.")
      |> close()

    if Rathena.truthy?(checkre(ctx, 0)) do
      warp(ctx, "alberta", 244, 86)
    else
      warp(ctx, "alberta", 243, 67)
    end
  end
end
