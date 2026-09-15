defmodule Aesir.ZoneServer.Content.Npc.Cities.Amatsu.SeaCaptain do
  @moduledoc """
  Offers travelers passage from Amatsu back to Alberta.

  ## Behavior

  - Returns consenting travelers to Alberta without charging a fare.
  - Uses the destination coordinates for the active game mode.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "amatsu",
        x: 194,
        y: 79,
        dir: 5,
        sprite: 709,
        name: "Sea Captain",
        scope: :shared,
        unique_name: "Sea Captain#ama2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Walter Moers]")
      |> mes("You came... Did you enjoy")
      |> mes("your trip to Amatsu...?")
      |> mes("Alright, I will take you")
      |> mes("back to Alberta.")
      |> next()
      |> select(["Back to Alberta", "Cancel"])

    if choice == 1 do
      return_to_alberta(ctx)
    else
      ctx
      |> mes("[Walter Moers]")
      |> mes("Well, take your time.")
      |> mes("The ship to Alberta is")
      |> mes("always ready to depart...")
      |> close()
    end
  end

  defp return_to_alberta(ctx) do
    ctx =
      ctx
      |> mes("[Walter Moers]")
      |> mes("Let's go then. You must have")
      |> mes("so many things to talk about,")
      |> mes("right? All aboard now.")
      |> close()

    if Rathena.truthy?(checkre(ctx, 0)) do
      warp(ctx, "alberta", 245, 87)
    else
      warp(ctx, "alberta", 243, 91)
    end
  end
end
