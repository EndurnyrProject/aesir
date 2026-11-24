defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.Recluse do
  @moduledoc """
  Jasi guards the Brasilis water lilies and remembers Jasira.

  ## Behavior

  - Shares his story and lets adventurers admire the lilies.
  - Accepts coconuts in exchange for permission to pick a flower.
  - Warps monsters that wander into his area back to 67,215 (`OnTouchNPC`).

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - og2
    - Euphy
    - Capuche
    - Daegaladh

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "bra_dun02",
        x: 67,
        y: 205,
        dir: 5,
        sprite: 475,
        name: "Recluse",
        scope: :shared,
        unique_name: "Recluse#bra",
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnTouchNPC", ctx) do
    {ctx, _result} = unitwarp(ctx, 0, "this", 67, 215)
    ctx
  end

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :brazil_regia, 0) do
      3 ->
        meet_jasi(ctx)

      4 ->
        ctx |> mes("[Jasi]") |> mes("Did you enjoy the water lily?") |> close()

      5 ->
        fruit_reminder(ctx)

      6 ->
        offer_coconuts(ctx)

      _ ->
        ctx
        |> mes("[Jasi]")
        |> mes("The flowers blooming from the Water lily today is wonderful.")
        |> close()
    end
  end

  defp meet_jasi(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Recluse]")
      |> mes("Oh, I haven't seen another person in such a long time.")
      |> next()
      |> select(["Keep going.", "Are you the moon?"])

    if choice == 1 do
      ctx |> mes("[Recluse]") |> mes("You don't have specific business with me.") |> close()
    else
      discuss_jasira(ctx)
    end
  end

  defp discuss_jasira(ctx) do
    ctx =
      ctx
      |> mes("[Recluse]")
      |> mes("Moon?")
      |> mes("My name is Jasi.")
      |> mes("My family has worked to take care of the water lily from generation to generation.")
      |> next()
      |> mes("[Jasi]")
      |> mes(
        "Basically the Brasilis water lily is too shy to appear in front of people so, they only bloom in rare places. I guess they like it here, though, that's why I've been staying here for such a long time."
      )
      |> next()
      |> mes("[Jasi]")
      |> mes(
        "My family has taken care of the water lily calmly to prevent harm from people's hand or monsters."
      )
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Do you remember a girl named Jasi.")
      |> next()
      |> mes("[Jasi]")
      |> mes("Ja...si..........")
      |> mes("Ah!! a hurry scurry girl. ")
      |> mes("Gosh.. I was in trouble due to that girl.")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Trouble?")
      |> next()
      |> mes("[Jasi]")
      |> mes(
        "One day a young lady appeared with lots of scars so I helped her. Then suddenly she tried to pick up the water lily and asked me to accept her as my wife or make her into a water lily what a nutcase!"
      )
      |> next()
      |> mes("[Jasi]")
      |> mes("I was barely able to calm down and send her to the village.")
      |> mes("My life is that water lily so I didn't want anything embarrassing to happen.")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("This is a gift from Jasira to say sorry for that time.")
      |> mes("She is really sad that can't come here by herself due to private difficulties.")
      |> next()

    if count_item(ctx, 513) < 10 do
      ctx
      |> mes("[Jasi]")
      |> mes("What are you saying?")
      |> next()
      |> mes("- Oh yeah, I forgot to bring 10 Bananas -")
      |> close()
    else
      appreciate_lilies(ctx)
    end
  end

  defp appreciate_lilies(ctx) do
    ctx =
      ctx
      |> mes("[Jasi]")
      |> mes("Ah! Bananas! Wow it's been a long time. She's pretty considerate isn't she?")
      |> next()
      |> mes("[Jasi]")
      |> mes("Anyway is that all the business you have with me?")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes(
      "Umm honestly I was wondering to find water lily and met you by coincidence. Jasira told me her sad story so that's what led me here."
    )
    |> next()
    |> mes("[Jasi]")
    |> mes("I got it.")
    |> mes("As you can see, there are lots of Brasilis water lily around here.")
    |> mes("If you make sure that you won't destroy them you can appreciate them as you wish.")
    |> set_char_var(:brazil_regia, 4)
    |> changequest(2202, 2203)
    |> close()
  end

  defp fruit_reminder(ctx) do
    ctx |> mes("[Jasi]") |> mes("I forgot what the name of that fruit was...") |> close()
  end

  defp offer_coconuts(ctx) do
    if count_item(ctx, 11_515) < 5 do
      fruit_reminder(ctx)
    else
      ctx =
        ctx
        |> mes("[Jasi]")
        |> mes("Did you find the fruit?")
        |> mes("Oh right this is....?")
        |> next()

      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("It's called a 'coconut'.")
      |> next()
      |> mes("[Jasi]")
      |> mes("Ahah! COCONUT!!")
      |> mes(
        "Now I remember thank you very much. I can't remember the last time I had this fruit."
      )
      |> next()
      |> mes("[Jasi]")
      |> mes("I guess I should keep my promise.")
      |> mes("You can take one Water lily.")
      |> next()
      |> mes("[Jasi]")
      |> mes("I hope the Brasilis water lily will understand me.")
      |> mes("You better grab the flower while you have a chance~")
      |> next()
      |> mes("[Jasi]")
      |> mes("Oh, can you tell that girl Jasira something for me?")
      |> mes(
        "Tell her that I am not the moon from the story, but I want to become the moon to shine only for her."
      )
      |> delitem(11_515, 5)
      |> set_char_var(:brazil_regia, 7)
      |> changequest(2205, 2206)
      |> close()
    end
  end
end
