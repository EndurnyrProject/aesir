defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsAlberta.TurtleScholarAlberta do
  @moduledoc """
  Jornadan Niliria shares his research on Turtle Island.

  ## Behavior

  - Discusses the island, his past, and his search for the jewel fragment.

  ## Credits

  - Original from rAthena, authors and contributors:
    - kobra_k88
    - Lupus
    - Evera
    - DZeroX
    - L0ne_W0lf
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alberta",
        x: 246,
        y: 114,
        dir: 4,
        sprite: 121,
        name: "Turtle Island Scholar",
        unique_name: "Turtle Island Scholar",
        scope: :renewal
      },
      %{
        map: "alberta",
        x: 248,
        y: 89,
        dir: 4,
        sprite: 121,
        name: "Turtle Island Scholar",
        unique_name: "Turtle Island Scholar",
        scope: :pre_renewal
      }
    ]

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Jornadan Niliria]")
      |> mes("Every single place")
      |> mes("has its own unique")
      |> mes("smells, sights and sounds.")
      |> next()
      |> mes("[Jornadan Niliria]")
      |> mes(
        "Even the great, ever expanding sky that's shared by all the peoples of the earth looks strange when you're in a new and foreign land."
      )
      |> next()
      |> mes("[Jornandan Niliria]")
      |> mes("Heh heh...")
      |> mes("Just like my")
      |> mes("time on Turtle Island.")
      |> mes("Hah Hah Hah~")
      |> next()
      |> select(["About Turtle island", "You're Jornadan Niliria?!", "Stop talking"])

    case choice do
      1 ->
        ctx
        |> mes("[Jornadan Niliria]")
        |> mes("Turtle...")
        |> mes("Island...")
        |> next()
        |> mes("[Jornadan Niliria]")
        |> mes(
          "It's almost silly, but Turtle Island was named simply because it's shaped just like a turtle."
        )
        |> next()
        |> mes("[Jornadan Niliria]")
        |> mes(
          "Now, Turtle Island is surrounded by a dense fog. When we were first stuck in it, a lot of us believed it was the result of a curse, or some kind of magic."
        )
        |> next()
        |> mes("[Jornadan Niliria]")
        |> mes(
          "But in actuality, the fog is the result of a natural phenomenon. It's created by a waterfall inside a cave located on Turtle Island's coast."
        )
        |> next()
        |> mes("[Jornadan Niliria]")
        |> mes("Heh heh...")
        |> mes(
          "Once you attain understanding, the truth becomes so simple. I guess confusion and fear is the fog that clouds your judgment, your path on life."
        )
        |> next()
        |> mes("[Jornadan Niliria]")
        |> mes(
          "Believe it or not, I too used to fear the dangers of Turtle Island. But now that I understand most of its secrets, I look at my experiences at Turtle Island with fondness."
        )
        |> next()
        |> mes("[Jornadan Niliria]")
        |> mes(
          "Still, there is one thing I haven't yet uncovered. The ^3355FFunknown jewel fragment^000000."
        )
        |> next()
        |> mes("[Jornandan Niliria]")
        |> mes(
          "So, until I find it, I'll keep researching and learn as much as I can until I do. Ha ha ha ha~!"
        )
        |> close()

      2 ->
        ctx
        |> mes("[Jornadan Niliria]")
        |> mes("Hmm...?")
        |> mes("You've heard of me?")
        |> next()
        |> mes("[Jornadan Niliria]")
        |> mes("Ah...")
        |> mes(
          "I suppose that you know about my treasure hunting days, and probably about Turtle Island."
        )
        |> next()
        |> mes("[Jornadan Niliria]")
        |> mes(
          "Well, as you can see, I'm a little older now. These old bones aren't what they used to be."
        )
        |> next()
        |> mes("[Jornadan Niliria]")
        |> mes(
          "But perhaps, someday, if my research bears fruit, I'll venture out once more and seek the one treasure I've never found..."
        )
        |> close()

      3 ->
        ctx
        |> mes("[Jornadan Niliria]")
        |> mes(
          "When you want to discover the truth, never give in to despair. If you never give up your search, the answer will come to you."
        )
        |> next()
        |> mes("[Jornadan Niliria]")
        |> mes("...")
        |> next()
        |> mes("[Jornadan Niliria]")
        |> mes("...")
        |> mes("......")
        |> next()
        |> mes("[Jornadan Niliria]")
        |> mes(
          "By the way, I'm pretty hungry. Why doesn't Alberta have any good restaurants?! I hear they have good dimsum in Kunlun..."
        )
        |> close()

      _ ->
        ctx
    end
  end
end
