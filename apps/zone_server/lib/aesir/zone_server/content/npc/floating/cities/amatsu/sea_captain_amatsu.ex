defmodule Aesir.ZoneServer.Content.Npc.Floating.Cities.Amatsu.SeaCaptainAmatsu do
  @moduledoc """
  Sir Walter Moers, the captain who opened the sealane and now sells the trip to
  Amatsu.

  ## Behavior

  - Tells the story of how Amatsu was discovered and of the king's reward, or
    offers the crossing.
  - The crossing costs 10,000 zeny: boarding charges the fare and warps to
    Amatsu, and a player short of it is sent away without being charged.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script cities/amatsu.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alberta",
        x: 246,
        y: 74,
        dir: 3,
        sprite: 709,
        name: "Sea Captain",
        scope: :renewal,
        unique_name: "Sea Captain#ama1"
      },
      %{
        map: "alberta",
        x: 245,
        y: 93,
        dir: 3,
        sprite: 709,
        name: "Sea Captain",
        scope: :pre_renewal,
        unique_name: "Sea Captain#ama1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Walter Moers]")
      |> mes("Hey, there.")
      |> mes("Have you ever heard that there")
      |> mes("are totally different countries")
      |> mes("than the Rune-Midgarts Kingdom?")
      |> next()
      |> select(["About Amatsu...", "Go to Amatsu", "Cancel"])

    case choice do
      1 -> tell_the_story(ctx)
      2 -> offer_the_crossing(ctx)
      3 -> suggest_a_trip(ctx)
      _ -> ctx
    end
  end

  defp tell_the_story(ctx) do
    ctx
    |> mes("[Walter Moers]")
    |> mes("I heard that a drifting ship")
    |> mes("accidentally discovered it...")
    |> mes("The ship was totally destroyed")
    |> mes("by a raging storm in heavy fog.")
    |> mes(" ")
    |> next()
    |> mes("[Walter Moers]")
    |> mes("Anyway, the ship was wrecked")
    |> mes("on the beach. It was there")
    |> mes("he arrived at a town called Amatsu.")
    |> next()
    |> mes("[Walter Moers]")
    |> mes("The towners took pity on him")
    |> mes("and took care of his wounds.")
    |> mes("He lived there until he finished making a map.")
    |> next()
    |> mes("[Walter Moers]")
    |> mes("He passed away when he returned")
    |> mes("to Rune-Midgarts. Fortunately,")
    |> mes("the map was given to our king, Tristan III.")
    |> next()
    |> mes("[Walter Moers]")
    |> mes("King Tristan III announced")
    |> mes("that he would reward any")
    |> mes("person brave enough to venture to Amatsu, and spread copies of this map.")
    |> next()
    |> mes("[Walter Moers]")
    |> mes("Many brave and adventurous")
    |> mes("sea captains took the")
    |> mes("challenge. Great fortune could")
    |> mes("be made in trade with Amatsu, as well as the rewards from King Tristan III...")
    |> next()
    |> mes("[Walter Moers]")
    |> mes("However, they all failed!")
    |> mes("To overcome various currents")
    |> mes("and bad weather, lots of")
    |> mes("experience is required. But they were all blinded by their greed...")
    |> next()
    |> mes("[Walter Moers]")
    |> mes("Finally, a great man discovered")
    |> mes("the perfect sealane to Amatsu...")
    |> mes("Right! That is me. Sir Walter")
    |> mes("Moers. I started the trade with Amatsu! Hahaha! Well, that's all about Amatsu.")
    |> next()
    |> mes("[Walter Moers]")
    |> mes("I made good money from trades")
    |> mes("for years, and now I'm interested")
    |> mes("in tourism. If you want to go to Amatsu, let me know~!")
    |> close()
  end

  defp offer_the_crossing(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Walter Moers]")
      |> mes("Oh yeah? It's a long way to")
      |> mes("Amatsu. That's why we are")
      |> mes(
        "charging a fare. You don't think that crossing oceans and currents is easy, do you?"
      )
      |> next()
      |> mes("[Walter Moers]")
      |> mes("10,000 zeny for a round-trip! I've")
      |> mes("got a stately room in a sturdy and")
      |> mes("safe trade ship for you. It is a ")
      |> mes("reasonable fare when you consider")
      |> mes("that this isn't a one way trip.")
      |> next()
      |> mes("[Walter Moers]")
      |> mes("Shall we go now? You didn't forget")
      |> mes("the fare, right? Let's go.")
      |> next()
      |> select(["All Aboard!", "Cancel"])

    if answer == 1 do
      board(ctx)
    else
      ctx
      |> mes("[Walter Moers]")
      |> mes("If you are an adventurer,")
      |> mes("this is a great chance")
      |> mes("to experience a different culture...Well, it is up to you.")
      |> close()
    end
  end

  defp board(ctx) do
    if zeny(ctx) > 9_999 do
      ctx
      |> mes("[Walter Moers]")
      |> mes("Alright, I will start the engine!")
      |> close()
      |> pay_zeny(10_000)
      |> warp("amatsu", 197, 83)
    else
      ctx
      |> mes("[Walter Moers]")
      |> mes("Were you even listening to me?")
      |> mes("10,000 zeny. If you got")
      |> mes("nothing, find some treasure")
      |> mes("somewhere, like in a wrecked ship...Show me the money!")
      |> close()
    end
  end

  defp suggest_a_trip(ctx) do
    ctx
    |> mes("[Walter Moers]")
    |> mes("If you are tired of your daily")
    |> mes("life, take a trip to a distant")
    |> mes("country across the ocean.")
    |> mes("Someplace like, oh I don't know, Amatsu~")
    |> close()
  end
end
