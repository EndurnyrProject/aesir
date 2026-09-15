defmodule Aesir.ZoneServer.Content.Npc.Airports.Airships.AirshipStaff do
  @moduledoc """
  Provides travel information aboard the domestic airship.

  ## Behavior

  - Answers a Hugel quest inquiry about a passenger named Thierry.
  - Explains how to disembark and describes the cabin and passenger facilities.

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
        map: "airplane",
        x: 250,
        y: 58,
        dir: 2,
        sprite: 67,
        name: "Airship Staff",
        scope: :shared,
        unique_name: "Airship Staff#airplane"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :hg_ma1, 0) == 3 do
      answer_thierry_inquiry(ctx)
    else
      offer_travel_information(ctx)
    end
  end

  defp answer_thierry_inquiry(ctx) do
    {ctx, _choice} =
      ctx
      |> mes("[Airship Staff]")
      |> mes("Welcome")
      |> mes("to the Airship.")
      |> mes("How may I help you?")
      |> next()
      |> select(["Do you have a passenger named Thierry?"])

    ctx
    |> mes("[Airship Staff]")
    |> mes("I am sorry, but I do not think that we have a passenger by that name.")
    |> close()
  end

  defp offer_travel_information(ctx) do
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
