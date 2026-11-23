defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAlberta.Knight do
  @moduledoc """
  Passats discusses the scattered Alberta Security Knights.

  ## Behavior

  - Discusses the mission and heals low-level adventurers on one dialogue path.

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
        map: "tur_dun01",
        x: 190,
        y: 115,
        dir: 4,
        sprite: 105,
        name: "Knight",
        scope: :shared,
        unique_name: "Knight#tur"
      }
    ]

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[?]")
      |> mes("Where are they?")
      |> mes("Oh hey! You're an adventurer, aren't you? Do you know where my comrades are?")
      |> next()
      |> select([
        "Who are you?",
        "Sorry, I don't.",
        "Why did you come here?",
        "How did you get here?"
      ])

    case choice do
      1 ->
        ctx
        |> mes("[Passats]")
        |> mes(
          "My name is Passats, a proud Security Knight of Alberta. We've obtained some information that some people came here to seek treasure."
        )
        |> next()
        |> mes("[Passats]")
        |> mes(
          "Our task here is to save people, but when we arrived on Turtle Island, we were attacked by a mob of monsters! So we all got scattered."
        )
        |> next()
        |> mes("[Passats]")
        |> mes("Now I'm all alone. If you find anyone else in my unit, would you let them know?")
        |> close()

      2 ->
        ctx =
          ctx
          |> mes("[Passats]")
          |> mes("Ah well...")
          |> mes(
            "Well, if you happen to find anyone else in my unit, would you let them know where I am?"
          )
          |> next()
          |> mes("[Passat]")
          |> mes(
            "Oh, and if you find our leader, kick his butt, will you? It's so fat, there's no way you can miss."
          )
          |> next()

        ctx =
          if base_level(ctx) <= 10 do
            percent_heal(ctx, hp: 40, sp: 0)
          else
            ctx
          end

        ctx
        |> mes("[Passats]")
        |> mes("Oh...")
        |> mes("And, um...")
        |> mes("Cheer up!")
        |> close()

      3 ->
        ctx
        |> mes("[Passats]")
        |> mes(
          "There are a lot of stories about the amazing wealth that can be found on this island. However, everyone assumed that it was impossible to find Turtle Island."
        )
        |> next()
        |> mes("[Passats]")
        |> mes(
          "But then, the problem began when some navigator actually knew the way to Turtle Island. I think he'll take just about anybody for 10,000 zeny!"
        )
        |> next()
        |> mes("[Passats]")
        |> mes(
          "So anyway, some of the people of Alberta have been foolishly coming here, hoping to find treasure. But of course, they can't fight monsters."
        )
        |> next()
        |> mes("[Passats]")
        |> mes(
          "So now we're here in order to seek out towners in trouble, and send them safely back home. Of course, now it seems that we also need rescuing..."
        )
        |> close()

      4 ->
        {ctx, _} =
          ctx
          |> mes("[Passats]")
          |> mes("Hmmm...")
          |> next()
          |> mes("[Passats]")
          |> mes("No clue.")
          |> next()
          |> select(["How can that be?!"])

        ctx
        |> mes("[Passats]")
        |> mes(
          "Oh, don't be angry. I just drank too much vodka! Before we arrived I was still unconscious and when I finally sobered up, I was here. I'm so embarrassed~"
        )
        |> next()
        |> mes("[Passats]")
        |> mes("I...")
        |> mes("I'm a victim too~")
        |> close()

      _ ->
        ctx
    end
  end
end
