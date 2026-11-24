defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAyothaya.OldMan do
  @moduledoc """
  Tham shares village news and helps visitors trace a frightened stranger.

  ## Behavior

  - Advances the search for the stranger and otherwise offers random local conversation.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Fredzilla
    - MasterOfMuppets
    - Lupus
    - Silent
    - Evera
    - SinSloth
    - L0ne_W0lf
    - Samuray22
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ayothaya",
        x: 193,
        y: 171,
        dir: 3,
        sprite: 842,
        name: "Old Man",
        scope: :shared,
        unique_name: "Old Man#02"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :thai_find, 0) == 3 do
      stranger(ctx)
    else
      ctx = set_local(ctx, :randayo, Enum.random(1..7))

      case get_local(ctx, :randayo, 0) do
        roll when roll < 5 -> tourism(ctx)
        roll when roll < 7 -> cuisine(ctx)
        _ -> greeting(ctx)
      end
    end
  end

  defp stranger(ctx) do
    ctx
    |> mes("[Tham]")
    |> mes("Weird...")
    |> mes("Why was that guy")
    |> mes("running into the")
    |> mes("shrine like that?")
    |> mes("That really")
    |> mes("bothers me...")
    |> next()
    |> mes("[Tham]")
    |> emotion(:surprise)
    |> mes("Oh, aren't you")
    |> mes("from Midgard?")
    |> mes("Hello there~")
    |> next()
    |> mes("[Tham]")
    |> mes("Ah...")
    |> mes(
      "You heard me talking to myself? Well, I didn't see who he was but, some guy ran into the forest which leads to the shrine. He seemed really terrified of something."
    )
    |> next()
    |> mes("[Tham]")
    |> mes(
      "He came from out of nowhere, so he scared the crap out of me. Do you think he could be a criminal?"
    )
    |> next()
    |> mes("[Tham]")
    |> emotion(:aha)
    |> mes(
      "Ah! I think, in his intense fear, he was screaming something about some kind of '^FF0000Shuda^000000,' or whatever. But what could it possibly mean?"
    )
    |> next()
    |> mes("[Tham]")
    |> mes(
      "Oh well, don't worry. All of our villagers aren't like that. Anyway, I hope you enjoy your travels in Ayothaya."
    )
    |> set_char_var(:thai_find, 4)
    |> changequest(12031, 12032)
    |> close()
  end

  defp tourism(ctx) do
    ctx
    |> mes("[Tham]")
    |> mes("Oh hello~")
    |> mes("I can tell from your clothes that you must be from Midgard.")
    |> next()
    |> mes("[Tham]")
    |> mes("Recently, it seems that")
    |> mes("our village has been receiving")
    |> mes("more tourism, and I can see that")
    |> mes("our village is being influenced")
    |> mes("in a positive way.")
    |> next()
    |> mes("[Tham]")
    |> mes("Ah...")
    |> mes("While you're here,")
    |> mes("why don't you taste some")
    |> mes("authentic Ayothaya cuisine")
    |> mes("for yourself?")
    |> next()
    |> mes("[Tham]")
    |> mes("We're known for our")
    |> mes("spicy and sweet seafood,")
    |> mes("and there are some nice")
    |> mes("restaurants around here.")
    |> next()
    |> mes("[Tham]")
    |> mes(
      "Anyway, I'm sure that you'll like it. I hope that you come visit Ayothaya as often as you can~"
    )
    |> close()
  end

  defp cuisine(ctx) do
    ctx
    |> mes("[Tham]")
    |> mes("Ah~")
    |> mes("I've got this craving for Ms. Mali the Spicy's food, especially her 'Tom Yum Goong.'")
    |> next()
    |> mes("[Tham]")
    |> mes("I think it's the")
    |> mes("most delicious dish")
    |> mes("in the entire world!")
    |> close()
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Tham]")
    |> mes("Oh hello~")
    |> mes("I can tell from your clothes that you must be from Midgard.")
    |> next()
    |> mes("[Tham]")
    |> mes(
      "I hope that you enjoy your stay here, and that you come visit Ayothaya as often as you can~"
    )
    |> close()
  end
end
