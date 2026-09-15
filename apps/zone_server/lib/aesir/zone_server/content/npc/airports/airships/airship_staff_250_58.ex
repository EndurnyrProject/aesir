defmodule Aesir.ZoneServer.Content.Npc.Airports.Airships.AirshipStaff25058 do
  @moduledoc """
  Provides travel information aboard the international airship.

  ## Behavior

  - Explains how to disembark at a destination.
  - Describes the captain's cabin and passenger facilities.

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
        map: "airplane_01",
        x: 250,
        y: 58,
        dir: 2,
        sprite: 67,
        name: "Airship Staff",
        scope: :shared,
        unique_name: "Airship Staff#airplane01"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Airship Staff]")
      |> mes("Welcome")
      |> mes("to the Airship.")
      |> mes("How may I help you?")
      |> next()
      |> select(["Using the Airship", "Captain's Cabin", "Facilities", "Cancel"])

    respond(ctx, choice)
  end

  defp respond(ctx, 1) do
    ctx
    |> mes("[Airship Staff]")
    |> mes("When you see a broadcast")
    |> mes("announcing that we have")
    |> mes("arrived at your destination,")
    |> mes("please use one of the exits")
    |> mes("located at the north and")
    |> mes("south ends of the Airship.")
    |> next()
    |> mes("[Airship Staff]")
    |> mes("If you happen to miss")
    |> mes("your stop, don't worry.")
    |> mes("The Airship is constantly")
    |> mes("en route and you'll get")
    |> mes("another chance to arrive")
    |> mes("to your intended destination.")
    |> close()
  end

  defp respond(ctx, 2) do
    ctx
    |> mes("[Airship Staff]")
    |> mes("The Captain's Cabin")
    |> mes("is located at the front")
    |> mes("of the Airship. There, you")
    |> mes("can meet the captain and")
    |> mes("the pilot of the Airship.")
    |> close()
  end

  defp respond(ctx, 3) do
    ctx
    |> mes("[Airship Staff]")
    |> mes("The Airship provides")
    |> mes("various Mini Games for")
    |> mes("the entertainment of all")
    |> mes("our passengers. We invite")
    |> mes("you to try your luck and skills")
    |> mes("in the Airship's Mini Games~")
    |> close()
  end

  defp respond(ctx, 4) do
    ctx
    |> mes("[Airship Staff]")
    |> mes("Well, I hope you")
    |> mes("your flight aboard")
    |> mes("our Airships. Thank")
    |> mes("you and have a good day.")
    |> close()
  end

  defp respond(ctx, _choice), do: ctx
end
