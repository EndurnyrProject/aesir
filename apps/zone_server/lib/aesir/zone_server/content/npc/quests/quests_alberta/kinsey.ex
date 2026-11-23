defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAlberta.Kinsey do
  @moduledoc """
  Kinsey points curious adventurers toward Grandpa Turtle.

  ## Behavior

  - Tells interested players where to find the old man and his letter.

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
        x: 91,
        y: 70,
        dir: 4,
        sprite: 89,
        name: "Kinsey",
        scope: :shared,
        unique_name: "Kinsey#tur"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Kinsey]")
      |> mes(
        "What does a man have to do to get a stiff drink around here? I mean, there are absolutely no good bars in Alberta!"
      )
      |> next()
      |> mes("[Kinsey]")
      |> mes(
        "Well, the alcohol in the pub here is second rate, but I gotta admit, it's got a great atmosphere."
      )
      |> next()
      |> mes("[Kinsey]")
      |> mes(
        "In fact, this old man is always there, telling stories about Turtle Island! But we're not sure if he's been there, or if he's just that drunk."
      )
      |> next()
      |> select(["^3333FF*ting!*^000000", "Sounds fun~"])

    if choice == 1 do
      ctx =
        ctx
        |> mes("[Kinsey]")
        |> mes("Whoa...")
        |> mes(
          "Hey, your eyes just lit up right when I said 'Turtle Island!' Hmm, let me try that again."
        )
        |> next()
        |> mes("[Kinsey]")
        |> mes("*Ahem*")
        |> mes("'Tur-tle")
        |> mes("Is-land.'")
        |> next()

      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("^3333FF*ting!*^000000")
      |> next()
      |> mes("[Kinsey]")
      |> mes("Ah...")
      |> mes(
        "You must be an adventurer. It seems like you really wanna learn more about that place, huh?"
      )
      |> next()
      |> mes("[Kinsey]")
      |> mes(
        "Why don't you look around near the pub, and look for that old man? He's usually pretty drunk, and speaks nonsense, but he might have something to say to you."
      )
      |> next()
      |> mes("[Kinsey]")
      |> mes(
        "Oh, and um, I've been in his room before. He leaves some sort of letter lying around the table that has something to do with his Turtle Island stories."
      )
      |> next()
      |> mes("[Kinsey]")
      |> mes(
        "But if he asks for you to buy him a drink, I wouldn't do it. He's got like, three extra livers or something, so he'll drink you to bankruptcy."
      )
      |> close()
    else
      ctx
      |> mes("[Kinsey]")
      |> mes(
        "Yeah, I guess it's pretty cool listening to his stories. But it would be even cooler if I could hear them in a better drinking establishment."
      )
      |> next()
      |> mes("[Kinsey]")
      |> mes(
        "I mean, they don't even serve a 'Boogieman,' much less a 'Cobo.' It's getting harder and harder to find those fine, fine specialty drinks."
      )
      |> close()
    end
  end
end
