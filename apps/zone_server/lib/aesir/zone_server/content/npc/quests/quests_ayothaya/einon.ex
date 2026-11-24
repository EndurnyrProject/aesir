defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAyothaya.Einon do
  @moduledoc """
  Einon introduces adventurers to Ayothaya’s Tom Yum Goong.

  ## Behavior

  - Offers the Tom Yum Goong quest and directs interested adventurers to Mali.
  - Gives directions or talks about Ayothaya as the quest progresses.

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
        x: 196,
        y: 265,
        dir: 3,
        sprite: 842,
        name: "Einon",
        scope: :shared,
        unique_name: "Einon#ayo"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :tomyumgoong, 0) do
      0 -> introduce(ctx)
      1 -> directions(ctx)
      _ -> village(ctx)
    end
  end

  defp introduce(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Einon]")
      |> mes("Do you know what the")
      |> mes("most popular cuisine")
      |> mes("of this village is?")
      |> next()
      |> mes("[Einon]")
      |> mes("Ayothaya is world famous")
      |> mes("for its regional cuisine, but")
      |> mes("out of all Ayothayan dishes,")
      |> mes("'^3131FFTom Yum Goong^000000' is the best.")
      |> next()
      |> mes("[Einon]")
      |> mes("Tom Yum Goong is a type")
      |> mes(
        "of soup that is very spicy. Try it once, and you will be amazed by its profound taste. Try it twice, and you will be enraptured by its tantalizing aroma."
      )
      |> next()
      |> mes("[Einon]")
      |> mes("It's really one of the most delicious foods in the world!")
      |> mes("Everyone in the world would")
      |> mes("want to try this at least once in his lifetime. So, would you like")
      |> mes("to try some?")
      |> next()
      |> select(["Sure thing.", "No, thanks. I hate spicy food."])

    if choice == 1, do: recommend(ctx), else: decline(ctx)
  end

  defp recommend(ctx) do
    ctx
    |> mes("[Einon]")
    |> mes("Okay...!")
    |> mes("Now who would be")
    |> mes("best for preparing")
    |> mes("Tom Yum Goong for you?")
    |> mes("Hmmmmm...")
    |> next()
    |> mes("[Einon]")
    |> mes("Everyone in the village")
    |> mes("knows how to make it, but")
    |> mes("I recommend that you go")
    |> mes("visit ^3131FFMali the Spicy^000000.")
    |> next()
    |> emotion(:best)
    |> set_char_var(:tomyumgoong, 1)
    |> setquest(8123)
    |> mes("[Einon]")
    |> mes("She is the best cook when it")
    |> mes("comes to Tom Yum Goong!")
    |> mes("Why don't you ask her")
    |> mes("to cook you some?")
    |> close()
  end

  defp decline(ctx) do
    ctx
    |> mes("[Einon]")
    |> mes("Oh I see...")
    |> mes("However, when you")
    |> mes("change your mind,")
    |> mes("please come back.")
    |> close()
  end

  defp directions(ctx) do
    ctx
    |> mes("[Einon]")
    |> mes("Ah, you wanna know")
    |> mes("where ^3131FFMali the Spicy^000000 is?")
    |> mes("Well, there's not too many places")
    |> mes("a cook would stay other than in")
    |> mes("a restaurant, right? Hahaha~")
    |> close()
  end

  defp village(ctx) do
    ctx
    |> mes("[Einon]")
    |> mes("Golden Ayothaya...")
    |> mes("Although I've grown")
    |> mes("up in this village,")
    |> mes("I still think my village")
    |> mes("is magnificient and beautiful.")
    |> next()
    |> mes("[Einon]")
    |> mes("What do you think?")
    |> mes("Wouldn't you agree with me?")
    |> close()
  end
end
