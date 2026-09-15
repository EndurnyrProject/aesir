defmodule Aesir.ZoneServer.Content.Npc.Cities.Payon.ArcherJoe do
  @moduledoc """
  Enthuses about Payon and answers questions about the town.

  ## Behavior

  - Responds to whether the visitor knows Payon.
  - Discusses local clothing, the Central Palace, or the town drunkard with interested visitors.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad Dib
    - Darkchild
    - DracoRPG
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "pay_arche",
        x: 77,
        y: 131,
        dir: 2,
        sprite: 88,
        name: "Archer Joe",
        scope: :shared,
        unique_name: "Archer Joe#payon"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Archer Joe]")
      |> mes("Payon!")
      |> mes("Such a wonderful")
      |> mes("place! Superb Bows")
      |> mes("and skillful Archers!")
      |> next()
      |> mes("[Archer Joe]")
      |> mes("Hey you~!")
      |> mes("Have you heard")
      |> mes("of famous Payon?")
      |> next()
      |> select(["Yeah, of course~! ", "Pay...on?", "..."])

    case choice do
      1 -> praise_payon(ctx)
      2 -> explain_payon(ctx) |> close()
      3 -> question_silence(ctx) |> close()
      _ -> close(ctx)
    end
  end

  defp praise_payon(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Archer Joe]")
      |> mes("Oh! You the man!")
      |> mes("You know the Archers of Payon!")
      |> mes("We never miss our target! Even from a distance, the hearts of our foes are unsafe!")
      |> next()
      |> select(["So, you like this place, huh? ", "Hahahaha~"])

    if choice == 1 do
      discuss_payon(ctx)
    else
      close(ctx)
    end
  end

  defp discuss_payon(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Archer Joe]")
      |> mes("Yes! I love this place!")
      |> mes("I love this city so much,")
      |> mes(
        "I've even been doing research on it! If there's anything you wanna know about Payon, please ask me!"
      )
      |> next()
      |> select([
        "The people wear unique clothing here.",
        "What's the building in the middle of town?",
        "Who's that guy drinking over there? ",
        "Talk to you later."
      ])

    ctx
    |> answer_payon_topic(choice)
    |> close()
  end

  defp answer_payon_topic(ctx, 1) do
    ctx
    |> mes("[Archer Joe]")
    |> mes("Yes, I agree.")
    |> mes(
      "You must know this place used to be isolated because of the thick forests and the mountainous area."
    )
    |> next()
    |> mes("[Archer Joe]")
    |> mes(
      "Because of that, the Payon developed a culture of its own, which is quite different than that of the rest of Rune-Midgarts."
    )
    |> next()
    |> mes("[Archer Joe]")
    |> mes(
      "This garment is traditional Payon clothing! Why don't you try wearing one? It's very comfortable~"
    )
  end

  defp answer_payon_topic(ctx, 2) do
    ctx
    |> mes("[Archer Joe]")
    |> mes(
      "You mean the Central Palace? Strangers aren't allowed to enter that place. People say the royal family and their friends from outside gather there."
    )
    |> next()
    |> mes("[Archer Joe]")
    |> mes("I'd like to go there sometime, and see what it's like on the inside!")
  end

  defp answer_payon_topic(ctx, 3) do
    ctx
    |> mes("[Archer Joe]")
    |> mes("Oh! That guy's notorious!")
    |> mes("Whatever you do, don't treat")
    |> mes("him to any drinks!")
    |> mes("You'll regret it!")
  end

  defp answer_payon_topic(ctx, 4) do
    ctx
    |> mes("[Archer Joe]")
    |> mes("Okay!")
    |> mes("See ya!")
    |> mes("Catch you later!")
  end

  defp answer_payon_topic(ctx, _choice), do: ctx

  defp explain_payon(ctx) do
    ctx
    |> mes("[Archer Joe]")
    |> mes("What a shame...")
    |> mes("How have you not")
    |> mes("heard of the Payon Archers?")
    |> next()
    |> mes("[Archer Joe]")
    |> mes("Well, when you ")
    |> mes("learn more about us,")
    |> mes("let's talk again and I can tell you why the Payon Archers are")
    |> mes("so great!")
  end

  defp question_silence(ctx) do
    ctx
    |> mes("[Archer Joe]")
    |> mes("Why are")
    |> mes("you so quiet?")
    |> mes("You're not shy, are you?")
    |> mes("Come on, there's no reason")
    |> mes("to be bashful around me~")
  end
end
