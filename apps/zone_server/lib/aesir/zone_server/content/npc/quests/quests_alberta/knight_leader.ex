defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAlberta.KnightLeader do
  @moduledoc """
  Takuyaka leads the scattered Alberta Security Knights on Turtle Island.

  ## Behavior

  - Describes the scattered mission through four dialogue choices.
  - Calls out to Mudasamu when approached.

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
        map: "tur_dun03",
        x: 105,
        y: 76,
        dir: 4,
        sprite: 110,
        name: "Knight Leader",
        scope: :shared,
        unique_name: "Knight Leader#tur",
        trigger: {5, 5}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTouch_", ctx) do
    ctx
    |> mes("[Scared Voice]")
    |> mes("Wh-wh-whaat?!")
    |> next()
    |> mes("[Terrified Voice]")
    |> mes("What's that noise?!")
    |> mes("M-M-Mudasamu!")
    |> mes("Protect me!")
    |> next()
    |> mes("[Mudasamu]")
    |> mes("No.")
    |> mes("And shut up.")
    |> close()
  end

  @impl true
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Takuyaka]")
      |> mes("Where did all my men go?!")
      |> mes("This is horrible~!")
      |> next()
      |> mes("[Takuyaka]")
      |> mes("Oh...")
      |> mes("*Whew!*")
      |> mes("Finally, another person.")
      |> mes("Tell me who you are!")
      |> next()

    {ctx, choice} =
      select(
        ctx,
        String.split(
          Rathena.concat(
            Rathena.concat("Who are you to ask?:", char_name(ctx, 0)),
            "!:What are you doing here?:First, tell me who you are."
          ),
          ":"
        )
      )

    case choice do
      1 ->
        ctx
        |> mes("[Takuyaka]")
        |> mes(
          "How dare you speak to me in that tone! Don't you know who I am?! I'm Takuyaka, leader of the Security Knights of Alberta! Kobolds and Porings quiver in fear when they hear my name..."
        )
        |> next()
        |> mes("[Takuyaka]")
        |> mes(
          "So tell me the truth! You came here for treasure, didn't you?! You want it all for yourself! You bastard! Now get off this island! Go, shoo!"
        )
        |> close()

      2 ->
        ctx = mes(ctx, "[Takuyaka]")

        ctx
        |> mes(Rathena.concat(Rathena.concat("", char_name(ctx, 0)), "?"))
        |> mes(
          "Well, your name sounds better than mine. And you have more hair on your head as well. Hmmm..."
        )
        |> next()
        |> mes("[Takuyaka]")
        |> mes(
          "Do you have anything to give me? You know, some food or zeny? It's not like I really need it, it's just... Oh bother. Never mind. Perhaps we'll meet later."
        )
        |> close()

      3 ->
        ctx
        |> mes("[Takuyaka]")
        |> mes(
          "I've heard that many treasures can be found on Turtle Island. If I can take enough home, I'll be rich! Well, we're supposed to rescue lost adventurers too, but whatever. As leader, I can do whatever I want!"
        )
        |> next()
        |> mes("[Takuyaka]")
        |> mes(
          "However, we're totally lost. Meaning we can't find any treasure or even rescue any people. Grrr...! Where are my useless soldiers! I've probably spoiled them with too much food!"
        )
        |> next()
        |> mes("[Takuyaka]")
        |> mes("If you see any of them, tell them they must assemble here! Alright?!")
        |> close()

      4 ->
        ctx
        |> mes("[Takuyaka]")
        |> mes(
          "Me? I'm Takuyaka. A tall, dark, handsome, and dashing leader, as well as a fearsome knight! I have come to save the foolish people of Alberta that have come seeking treasure on Turtle Island."
        )
        |> next()
        |> mes("[Mudasamu]")
        |> mes("Really, now?")
        |> next()
        |> mes("[Takuyaka]")
        |> mes("Quiet!")
        |> next()
        |> mes("[Takuyaka]")
        |> mes(
          "Anyway, we came here with the purest of intents. But right when we arrived, we were attacked by monsters! Because of the confusion from all the fighting, my soldiers were scattered."
        )
        |> next()
        |> mes("[Takuyaka]")
        |> mes("Mudasamu!")
        |> mes("Why is this")
        |> mes("happening to me!!!!")
        |> next()
        |> mes("[Mudasamu]")
        |> mes("Huh...!")
        |> mes("Why should you")
        |> mes("be surprised,")
        |> mes("you chubby dwarf?")
        |> close()

      _ ->
        ctx
    end
  end
end
