defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAlberta.Knight189126 do
  @moduledoc """
  Jayprocat describes the Security Knights’ failed mission.

  ## Behavior

  - Explains the rescue mission or discusses the monsters on the island.

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
        x: 189,
        y: 126,
        dir: 4,
        sprite: 105,
        name: "Knight",
        scope: :shared,
        unique_name: "Knight#tur2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Jayprocat]")
      |> mes(
        "Oh? Are you a civilian? Nice to meet you. I'm a mighty Security Knight of Alberta, Jayprocat."
      )
      |> next()
      |> select(["What is that, exactly?", "I'm not impressed."])

    if choice == 1 do
      ctx
      |> mes("[Jayprocat]")
      |> mes("Well...")
      |> mes(
        "We're supposed to protect the people of Alberta. That's our job as proud Security Knights."
      )
      |> next()
      |> mes("[Jayprocat]")
      |> mes(
        "So when a bunch of them caught treasure fever and started coming here, we came to rescue them. Anyway, that was the plan."
      )
      |> next()
      |> mes("[Jayprocat]")
      |> mes(
        "It turns out that by some joke by fate, our leader is this pudgy guy who attracted a mob on monsters to us by noisily digging up treasure, instead of doing what we were supposed to do."
      )
      |> next()
      |> mes("[Jayprocat]")
      |> mes("*Sigh...*")
      |> mes(
        "Why wasn't Mudasamu in charge? With him as leader, I would've been home for dinner..."
      )
      |> close()
    else
      {ctx, follow_up} =
        ctx
        |> mes("[Jayprocat]")
        |> mes("Well...")
        |> mes(
          "It's true that we pretty much messed up our current mission to save anyone here seeking for treasure, since we need rescuing now as well."
        )
        |> next()
        |> mes("[Jayprocat]")
        |> mes("*Sniff*")
        |> mes(
          "Why did we have to be attacked by so many monsters on my first mission? I'm... I'm just a new recruit..."
        )
        |> next()
        |> select(["Why did you run away?", "I don't care."])

      if follow_up == 1 do
        ctx
        |> mes("[Jayprocat]")
        |> mes(
          "No, I didn't just run away! The monsters were too stong and there were so many of them! Plus, it's our damn leader's fault."
        )
        |> next()
        |> mes("[Jayprocat]")
        |> mes(
          "The monsters are all highly evolved turtles. And this island even looks like a turtle! But I guess you knew that already."
        )
        |> next()
        |> mes("[Jayprocat]")
        |> mes(
          "I had no idea that this island's monsters were so much stronger than the ones that live near Alberta."
        )
        |> next()
        |> mes("[Jayprocat]")
        |> mes(
          "Their shells are so tough, and we can't seem to find any sort of weak point! I have no idea how to fight these turtles!"
        )
        |> close()
      else
        ctx
        |> mes("[Jayprocat]")
        |> mes("You're so mean...")
        |> mes("I mean, I'm really new at this!")
        |> close()
      end
    end
  end
end
