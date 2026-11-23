defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAlberta.Knight67130 do
  @moduledoc """
  Nysurea advises stranded adventurers and can send eligible players back to Alberta.

  ## Behavior

  - Offers free transport to low-level adventurers with at most 3,000 zeny.

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
        x: 67,
        y: 130,
        dir: 4,
        sprite: 105,
        name: "Knight",
        scope: :shared,
        unique_name: "Knight#tur4"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Nysurea]")
      |> mes("Hm? I'm surprised that someone around here is still alive.")
      |> next()
      |> mes("[Nysurea]")
      |> mes("I'm beginning to think all my comrades have been killed by the monsters here...")
      |> next()

    if base_level(ctx) <= 40 do
      ctx = ctx |> mes("[Nysurea]") |> mes("Having a") |> mes("tough time?") |> next()

      if zeny(ctx) <= 3000 do
        {ctx, choice} =
          ctx
          |> mes("[Nysurea]")
          |> mes(
            "Even though you're pretty strong, sooner or later you might need a reprieve. I can send you back to Alberta right now if you want."
          )
          |> next()
          |> select(["Yes, Help me.", "No, thanks."])

        if choice == 1 do
          ctx
          |> mes("[Nysurea]")
          |> mes(
            "Okay then, let me activate this teleport thingee donated to us by Kafra Corporation..."
          )
          |> close()
          |> warp("alberta", 241, 115)
        else
          ctx
          |> mes("[Nysurea]")
          |> mes(
            "Ah, that's the spirit! You should be careful though. And if you see any other of my comrades, let them know I'm here, would you?"
          )
          |> next()
          |> mes("[Nysurea]")
          |> mes("Well, good luck!")
          |> close()
        end
      else
        ctx
        |> mes("[Nysurea]")
        |> mes(
          "You look lost! If you stick around here, well, the monsters will probably get the best of you sooner or later."
        )
        |> next()
        |> mes("[Nyusurea]")
        |> mes("Anyway...")
        |> mes("Good luck!")
        |> mes("You'll need it!")
        |> close()
      end
    else
      ctx
      |> mes("[Nysurea]")
      |> mes("Huh...")
      |> mes(
        "You look calm and collected. If all our soldiers were as strong as you, we probably would not have been scattered."
      )
      |> next()
      |> mes("[Nysurea]")
      |> mes(
        "I have dreams of becoming a great knight, but since our 'leader' is all plump and no brains, we're stuck in this predicament."
      )
      |> next()
      |> mes("[Nysurea]")
      |> mes(
        "Anyway, be careful in this third level of Turtle Island. A lot of our men were annihilated when they went to explore the East and North sides, so be careful!"
      )
      |> close()
    end
  end
end
