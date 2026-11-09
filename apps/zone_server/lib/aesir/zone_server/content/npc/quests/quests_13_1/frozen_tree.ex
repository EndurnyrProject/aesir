defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.FrozenTree do
  @moduledoc """
  The tree Rumis Block climbed in the Manuk field to study Hillsrions up close.

  ## Behavior

  - Talks Rumis down through the first meeting, sets `ep13_animal` to 12 and advances
    quest 2154 to 2155.
  - Asks for 5 Hillsrion Horns while `ep13_animal` is 12 and the player carries fewer.
  - Takes the 5 horns, sets `ep13_animal` to 13 and advances quest 2155 to 2156, then walks
    back to the camp with the player.
  - Says nothing outside those two steps.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "man_fild01",
        x: 92,
        y: 230,
        dir: 3,
        sprite: 111,
        name: "Frozen Tree",
        scope: :shared,
        unique_name: "Frozen Tree#evt_lumis",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @hillsrion_horn 6032
  @horns_needed 5

  @awaiting_horns 12
  @first_meeting 11

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :ep13_animal, 0) do
      @first_meeting -> first_meeting(ctx)
      @awaiting_horns -> turn_in_horns(ctx)
      _step -> ctx
    end
  end

  defp first_meeting(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Knock, knock. Are you here?")
    |> next()
    |> mes("- Something is making loud noise near the top of the tree. -")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("...Oh, yes. Yes!")
    |> mes("Monsters were looking at me, so I climbed up this tree without even thinking!")
    |> mes("How can I get down now?")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("Oh wait, I can see everything so clearly from here.")
    |> mes("I guess staying here will be much safer and easier for studying monsters.")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("...I'm looking at Hillsrion, the creature that people are talking about.")
    |> mes("It's covered with soft fur that reminds me of soft ice flakes floating in the air.")
    |> mes("...Oh, sorry.. I was just talking to myself.")
    |> next()
    |> mes("[Rumis Block]")
    |> mes(
      "I'll be watching the Hillsrions from this tree. #{char_name(ctx, 0)}, can you please go collect ^3131FFHillsrion Horns^000000 for me?"
    )
    |> next()
    |> mes("[Rumis Block]")
    |> mes(
      "Their horns might possess a special power. And I want to have them for further research."
    )
    |> mes("...5 horns will be enough.")
    |> set_char_var(:ep13_animal, @awaiting_horns)
    |> changequest(2154, 2155)
    |> close()
  end

  defp turn_in_horns(ctx) do
    if count_item(ctx, @hillsrion_horn) < @horns_needed do
      ctx
      |> mes("[Rumis Block]")
      |> mes("I'd like to study Hillsrion's Horns. Please bring 5 of them for me, okay.")
      |> close()
    else
      collected_horns(ctx)
    end
  end

  defp collected_horns(ctx) do
    ctx =
      ctx
      |> mes("[Rumis Block]")
      |> mes("...*Shiver*...")
      |> next()
      |> mes("[Rumis Block]")
      |> mes("...*Shiver*...")
      |> mes("...*Shiver*...")
      |> next()
      |> mes("[Rumis Block]")
      |> mes("...*Shiver*...")
      |> mes("...*Shiver*...")
      |> mes("...*Shiver*...")
      |> next()
      |> mes("[Rumis Block]")
      |> mes("Ah! You're back!")
      |> mes("Phew...")
      |> next()
      |> mes("[Rumis Block]")
      |> mes("Are you okay? Their fangs look so sharp and shiny...")
      |> mes(
        "Oh right, you're an expert when it comes to this kind of job. Hahaha, I don't have to worry about you anymore."
      )
      |> next()
      |> mes("[Rumis Block]")
      |> mes("Have you brought Hillsrion's Horns?")
      |> mes("Those are the horns in your hands?")
      |> next()
      |> mes("[Rumis Block]")
      |> mes("Oh...")
      |> next()
      |> mes("[Rumis Block]")
      |> mes("Ho...")
      |> next()

    ctx
    |> mes("[Rumis Block]")
    |> mes("Well, they appear to be ordinary horns with a spiral pattern.")
    |> mes("Monsters with such horns are a dime a dozen in Midgard.")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("I, however, still have no idea how Hillsrions use their horns.")
    |> next()
    |> mes("[Rumis Block]")
    |> mes(
      "If they have bad vision, they could use the horns as feelers, or... I know you don't want to hear me ramble on with my conjecture. Sorry."
    )
    |> next()
    |> mes("[Rumis Block]")
    |> mes(
      "We can call it a day for today. Thanks to you, I now feel confident enough to at least come to this tree by myself next time."
    )
    |> next()
    |> mes("[Rumis Block]")
    |> mes("Let's go back to the camp. Shall we? I have something to discuss with you.")
    |> set_char_var(:ep13_animal, 13)
    |> delitem(@hillsrion_horn, @horns_needed)
    |> changequest(2155, 2156)
    |> close()
  end
end
