defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsComodo.HairOrnamentGirl do
  @moduledoc """
  The Hair Ornament Girl crafts hairbands from supplied materials.

  ## Behavior

  - Offers four headgear recipes and crafts the chosen item after confirmation.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Evera
    - Samuray22
    - Brainstorm

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "comodo",
        x: 228,
        y: 159,
        dir: 3,
        sprite: 700,
        name: "Hair Ornament Girl",
        scope: :shared
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx = mes(ctx, "[Hair Ornament Girl]")

    ctx =
      if sex(ctx) == 1 do
        ctx
        |> mes("Oh, hello!")
        |> mes(
          "Would you like to order a hairband? They're great presents to give to your girlfriend, and show that you're thinking of her."
        )
      else
        ctx
        |> mes("Hello~!")
        |> mes(
          "I think one of these will suit a pretty girl like you very well. Would you like to order a hairband?"
        )
      end

    {ctx, selection} =
      ctx
      |> next()
      |> mes("[Hair Ornament Girl]")
      |> mes(
        "If you give me a few simple items then I can make a gorgeous Hair Band. If you have any questions, go ahead and have a look."
      )
      |> next()
      |> select(["Cross Hat", "Bulb Band", "Stripe Hairband", "Blue Hairband"])

    craft_selection(ctx, selection)
  end

  defp craft_selection(ctx, 1) do
    if count_item(ctx, 2608) > 0 and count_item(ctx, 7069) > 499 do
      {ctx, confirmation} =
        ctx
        |> mes("[Hair Ornament Girl]")
        |> mes("You've chosen the Cross Hat?")
        |> mes("If you brought all the required items, I will make it for you~")
        |> next()
        |> mes("[Hair Ornament Girl]")
        |> mes("But before I can make it, can you check that the items are right?")
        |> mes(
          "If it is a forged, upgraded item or has monster cards in it, then those cards and upgrades will be lost."
        )
        |> next()
        |> mes("[Hair Ornament Girl]")
        |> mes(
          "It's better to bring just to keep the requested items in your inventory. Did you check? Then let's make it, okay?"
        )
        |> next()
        |> select(["No.", "Yes."])

      case confirmation do
        1 ->
          ctx
          |> mes("[Hair Ornament Girl]")
          |> mes(
            "Ah, alright. I guess you should put all your other things into Kafra Storage first. Okay then, see you soon."
          )
          |> mes("See you soon~")
          |> close()

        2 ->
          ctx
          |> mes("^3355FFSwish swish snip snip^000000")
          |> next()
          |> delitem(2608, 1)
          |> delitem(7069, 500)
          |> mes("[Hair Ornament Girl]")
          |> mes("Look at this! Well done~")
          |> mes("Please come again~ hoooo!")
          |> give_item(5036, 1)
          |> close()

        _ ->
          ctx
      end
    else
      ctx
      |> mes("[Hair Ornament Girl]")
      |> mes("Oh, you've chosen Cross Hat?")
      |> mes("There are some items needed to make this headband.")
      |> next()
      |> mes("[Hair Ornament Girl]")
      |> mes("I'll need...")
      |> mes("^3355FF1 Rosary^000000")
      |> mes("^3355FF500 Destroyed Armor^000000")
      |> next()
      |> mes("[Hair Ornament Girl]")
      |> mes("If you bring all the items then I will make it for you right away.")
      |> mes("See you then~")
      |> close()
    end
  end

  defp craft_selection(ctx, 2) do
    if count_item(ctx, 2233) > 0 and count_item(ctx, 746) > 19 do
      {ctx, confirmation} =
        ctx
        |> mes("[Hair Ornament Girl]")
        |> mes("You've chosen Bulb band?")
        |> mes("If you brought all the required items, I will make it for you~")
        |> next()
        |> mes("[Hair Ornament Girl]")
        |> mes("But before I can make it, can you check that the items are right?")
        |> mes(
          "If it is a forged, upgraded item or has monster cards in it, then those cards and upgrades will be lost."
        )
        |> next()
        |> mes("[Hair Ornament Girl]")
        |> mes(
          "It's better to bring just to keep the requested items in your inventory. Did you check? Then let's make it, okay?"
        )
        |> next()
        |> select(["No.", "Yes."])

      case confirmation do
        1 ->
          ctx
          |> mes("[Hair Ornament Girl]")
          |> mes(
            "Ah, alright. I guess you should put all your other things into Kafra Storage first. Okay then, see you soon."
          )
          |> close()

        2 ->
          ctx
          |> mes("^3355FFSwish swish snip snip^000000")
          |> next()
          |> delitem(2233, 1)
          |> delitem(746, 20)
          |> mes("[Hair Ornament Girl]")
          |> mes("Look at this! Well done~")
          |> mes("Please come again~ hoooo!")
          |> give_item(5034, 1)
          |> close()

        _ ->
          ctx
      end
    else
      ctx
      |> mes("[Hair Ornament Girl]")
      |> mes("Oh, you've chosen Bulb Band?")
      |> mes("There are some required items needed to make this headband.")
      |> next()
      |> mes("[Hair Ornament Girl]")
      |> mes("I'll need...")
      |> mes("^3355FF1 Slotted Circlet^000000")
      |> mes("^3355FF20 Glass Bead^000000")
      |> next()
      |> mes("[Hair Ornament Girl]")
      |> mes("If you bring all the items then I will make it for you right away.")
      |> mes("See you then~")
      |> close()
    end
  end

  defp craft_selection(ctx, 3) do
    if count_item(ctx, 1099) > 1499 do
      {ctx, confirmation} =
        ctx
        |> mes("[Hair Ornament Girl]")
        |> mes("You've chosen Stripe band?")
        |> mes("If you brought all the required items, I will make it for you~")
        |> next()
        |> mes("[Hair Ornament Girl]")
        |> mes("You want me to make it now?")
        |> next()
        |> select(["No.", "Yes."])

      case confirmation do
        1 ->
          ctx |> mes("[Hair Ornament Girl]") |> mes("See you later then~") |> close()

        2 ->
          ctx
          |> mes("^3355FFSwish swish snip snip^000000")
          |> next()
          |> delitem(1099, 1500)
          |> mes("[Hair Ornament Girl]")
          |> mes("Look at this! Well done~")
          |> mes("Please come again~")
          |> give_item(5049, 1)
          |> close()

        _ ->
          ctx
      end
    else
      ctx
      |> mes("[Hair Ornament Girl]")
      |> mes(
        "Oh, you've chosen the Stripe band? There are some required items needed to make this headband."
      )
      |> next()
      |> mes("[Hair Ornament Girl]")
      |> mes("I'll need...")
      |> mes("^3355FF1500 Worn-out Prison Uniform^000000")
      |> next()
      |> mes("[Hair Ornament Girl]")
      |> mes("If you bring all the items then I will make it for you right away.")
      |> mes("See you then~")
      |> close()
    end
  end

  defp craft_selection(ctx, 4) do
    if count_item(ctx, 2211) > 0 and count_item(ctx, 978) > 0 and count_item(ctx, 7003) > 299 do
      {ctx, confirmation} =
        ctx
        |> mes("[Hair Ornament Girl]")
        |> mes("You've chosen Blue Hairband?")
        |> mes("If you brought all the required items, I will make it for you~")
        |> next()
        |> mes("[Hair Ornament Girl]")
        |> mes("But before I can make it, can you check that the items are right?")
        |> mes(
          "If it is a forged, upgraded item or has monster cards in it, then those cards and upgrades will be lost."
        )
        |> next()
        |> mes("[Hair Ornament Girl]")
        |> mes(
          "It's better to bring just to keep the requested items in your inventory. Did you check? Then let's make it, okay?"
        )
        |> next()
        |> select(["No.", "Yes."])

      case confirmation do
        1 ->
          ctx
          |> mes("[Hair Ornament Girl]")
          |> mes(
            "Ah, alright. I guess you should put all your other things into Kafra Storage first. Okay then, see you soon."
          )
          |> close()

        2 ->
          ctx
          |> mes("^3355FFSwish swish snip snip^000000")
          |> next()
          |> delitem(2211, 1)
          |> delitem(978, 1)
          |> delitem(7003, 300)
          |> mes("[Hair Ornament Girl]")
          |> mes("Look, at this! Well done!")
          |> mes("Please come again~ ")
          |> give_item(5052, 1)
          |> close()

        _ ->
          ctx
      end
    else
      ctx
      |> mes("[Hair Ornament Girl]")
      |> mes("Oh, you've chosen Blue Hairband?")
      |> mes("There are some required items needed to make this headband.")
      |> next()
      |> mes("[Hair Ornament Girl]")
      |> mes("I'll need...")
      |> mes("^3355FF1 Bandana^000000")
      |> mes("^3355FF1 Cobaltblue Dyestuffs^000000")
      |> mes("^3355FF300 Anolian Skin^000000")
      |> next()
      |> mes("[Hair Ornament Girl]")
      |> mes("If you bring all the items then I will make it for you right away.")
      |> mes("See you then~")
      |> close()
    end
  end

  defp craft_selection(ctx, _), do: ctx
end
