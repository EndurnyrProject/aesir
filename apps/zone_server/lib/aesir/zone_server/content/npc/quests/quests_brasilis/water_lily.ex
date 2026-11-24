defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.WaterLily do
  @moduledoc """
  The water lily is the object of Jasi's quest.

  ## Behavior

  - Offers Jasi bananas and learns which fruit he wants in exchange for a flower.
  - Allows the adventurer to pick a flower after Jasi agrees.

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
        x: 71,
        y: 200,
        dir: 3,
        sprite: 111,
        name: "Water lily",
        scope: :shared,
        unique_name: "Water lily#bra"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :brazil_regia, 0) do
      4 -> approach_lily(ctx)
      5 -> fruit_reminder(ctx)
      7 -> pick_lily(ctx)
      _ -> ctx
    end
  end

  defp approach_lily(ctx) do
    {ctx, choice} =
      ctx
      |> mes(
        "An unusual Water lily is blooming here. You can't stop staring at it, knowing that few people have seen this flower bloom."
      )
      |> next()
      |> select(["Pick up the flower.", "Keep gazing."])

    if choice == 2 do
      ctx |> mes("- You can't avoid staring at it's beauty. -") |> close()
    else
      offer_bananas(ctx)
    end
  end

  defp offer_bananas(ctx) do
    ctx = ctx |> mes("[Jasi]") |> mes("Uh! What are you doing??!!") |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("There is a person who really needs this flower, can I just take one of 'em?")
      |> next()
      |> mes("[Jasi]")
      |> mes("As I said earlier, I am the guardian of this water lily.")
      |> mes("I can't just stand by here and watch you pluck even a single flower from it.")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes(
        "Hey man~ I brought these delicious fruits for you... try it! They are really well matured and fresh bananas."
      )
      |> next()

    if count_item(ctx, 513) < 10 do
      ctx
      |> mes("[Jasi]")
      |> mes("What are you saying?")
      |> next()
      |> mes("- Oh yeah, I forgot to bring 10 Bananas -")
      |> close()
    else
      ask_for_flower(ctx)
    end
  end

  defp ask_for_flower(ctx) do
    ctx =
      ctx
      |> mes("[Jasi]")
      |> mes("Hmm... It's been so long since I've had this fruit.")
      |> next()
      |> mes("[Jasi]")
      |> mes("I will just try one. That's all.")
      |> next()
      |> mes("- munch -")
      |> mes("- mumble mumble mumble -")
      |> specialeffect(:potion7, :area, "Recluse#bra")
      |> next()
      |> mes("[Jasi]")
      |> mes("Uh, this taste... is!")
      |> mes("I remember my mom baking these into a tasty bread!")
      |> next()
      |> mes("[Jasi]")
      |> mes("It makes me miss my childhood.")
      |> next()

    ctx =
      ctx
      |> emotion(:huk, getnpcid(ctx, "Recluse#bra"))
      |> mes("[Jasi]")
      |> mes("Hoho!!!!")
      |> mes("I've been here for as long as I can remember...")
      |> mes("I don't have enough time to even do simple things like eat delicious fruit.")
      |> next()
      |> mes("[Jasi]")
      |> mes("It was a really delicious banana.")
      |> mes("But rules are rules!")
      |> mes("I must do my duty.")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Please! I just need one flower~ What can I do to convince you?")
      |> next()
      |> mes("[Jasi]")
      |> mes("Rules are rules, what do you want from me?")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Didn't that banana remind you of your childhood? What can I get for you?")
      |> next()
      |> mes("[Jasi]")
      |> mes("Now that you mention it, there is one fruit that I really miss.")
      |> mes("It was my favorite when I was young but I don't remember what it was called.")
      |> next()
      |> mes("[Jasi]")
      |> mes(
        "It's brown and has a hard shell around it. It has juice inside and you can use it as a cup when you're done eating the fruit."
      )
      |> mes("Do you know what it is?")
      |> next()
      |> mes("[Jasi]")
      |> mes("If you bring 5 of those things, I will reconsider your suggestion.")
      |> delitem(513, 10)
      |> set_char_var(:brazil_regia, 5)
      |> changequest(2203, 2204)
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Ok so I have to bring 5 fruits with hard shells.")
    |> mes("Hmm what is it?")
    |> close()
  end

  defp fruit_reminder(ctx) do
    ctx
    |> mes("[Jasi]")
    |> mes("It was my favorite when I was young but I don't remember what it was called.")
    |> next()
    |> mes("[Jasi]")
    |> mes(
      "It's brown and has a hard shell around it. It has juice inside and you can use it as a cup when you're done eating the fruit."
    )
    |> mes("Do you know what it is?")
    |> close()
  end

  defp pick_lily(ctx) do
    if not Rathena.truthy?(checkweight(ctx, [{1201, 1}])) do
      ctx
      |> mes("- wait a second!! -")
      |> mes("- you have too many items -")
      |> mes("- so you can't get any more items. -")
      |> mes("- make your body lighter -")
      |> mes("- then try again. -")
      |> close()
    else
      ctx
      |> mes("- You take a beautiful water lily carefully in your hands. -")
      |> set_char_var(:brazil_regia, 8)
      |> give_item(7553, 1)
      |> close()
    end
  end
end
