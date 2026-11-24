defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsComodo.Traveler do
  @moduledoc """
  Isac Mari crafts special headgear for travelers.

  ## Behavior

  - Explains the ingredients for four hats and crafts them when supplied.

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
        x: 273,
        y: 137,
        dir: 4,
        sprite: 702,
        name: "Traveler",
        scope: :shared,
        unique_name: "Traveler#head"
      }
    ]

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Isac Mari]")
      |> mes(
        "I travel around the world, and collect many interesting stories from people. Sometimes they teach me how to make special items."
      )
      |> next()
      |> mes("[Isac Mari]")
      |> mes(
        "I know how to make all sorts of worldly hats. But right now, I can't make these since I don't have the right items."
      )
      |> next()
      |> select(["Mine Helmet", "Parcel Hat", "Grief for Greed", "Opera Phantom Mask"])

    case choice do
      1 -> mine_helmet(ctx)
      2 -> parcel_hat(ctx)
      3 -> grief_for_greed(ctx)
      4 -> opera_phantom_mask(ctx)
      _ -> ctx
    end
  end

  defp mine_helmet(ctx) do
    if count_item(ctx, 5009) > 0 and count_item(ctx, 5028) > 0 and count_item(ctx, 999) > 24 and
         count_item(ctx, 747) > 0 do
      {ctx, choice} =
        ctx
        |> mes("[Isac Mari]")
        |> mes(
          "Mine Helmet was designed for the miners in the coal mines to have light in the dark. If you brought all the required items, I will go ahead and make it for you~"
        )
        |> next()
        |> mes("[Isac Mari]")
        |> mes(
          "But can you check that the items in your inventory aren't upgraded or have cards compounded into them? If any of the required items have forged upgrades or cards, those will be lost once I create the Mine Hat."
        )
        |> next()
        |> mes("[Isac Mari]")
        |> mes(
          "It's better to keep only the items used to make the Mine Hat in your inventory. Did you check? If so, let's get started."
        )
        |> next()
        |> select(["Give me a minute~!", "Let's make the Mine Hat."])

      case choice do
        1 ->
          ctx
          |> mes("[Isac Mari]")
          |> mes(
            "Alright. Please check your items again. It's much better to be safe than sorry."
          )
          |> close()

        2 ->
          ctx
          |> mes("^3355FF*Thook Thook*")
          |> mes("*Pop!*^000000")
          |> next()
          |> mes("[Isac Mari]")
          |> mes("Whew! This is pretty hard!")
          |> next()
          |> delitem(5009, 1)
          |> delitem(5028, 1)
          |> delitem(747, 1)
          |> delitem(999, 25)
          |> mes("[Isac Mari]")
          |> mes("I'm not quite sure if this is the right one, but it looks about right. Ha ha~")
          |> give_item(5031, 1)
          |> close()

        _ ->
          ctx
      end
    else
      ctx
      |> mes("[Isac Mari]")
      |> mes(
        "I hear Mine Helmets are used in the mines near Geffen. As you know, it's not possible to work without light, even though it attracts monsters in the caves."
      )
      |> next()
      |> mes("[Isac Mari]")
      |> mes(
        "One day, a miner remodeled his own Safety Helmet so that he could work with both hands. Since then, it's been called the Mine Helm."
      )
      |> next()
      |> mes("[Isac Mari]")
      |> mes("If you want to make Mine Helmet,")
      |> mes("^3355FF1 Safety Helmet^000000")
      |> mes("^3355FF1 Candle^000000 ")
      |> mes("^3355FF1 Crystal Mirror^000000")
      |> mes("^3355FF25 Steel^000000")
      |> mes("is needed to create it.")
      |> next()
      |> mes("[Isac Mari]")
      |> mes("If you bring all the items then I will make it for you right away. See you later~")
      |> close()
    end
  end

  defp parcel_hat(ctx) do
    if count_item(ctx, 1059) > 149 and count_item(ctx, 907) > 99 and count_item(ctx, 978) > 0 do
      {ctx, choice} =
        ctx
        |> mes("[Isac Mari]")
        |> mes(
          "Parcel Hat seems to be useful for business people to carry around their products. If you brought everything I need, I will make it for you."
        )
        |> mes("If you brought all the required items, I will make it for you~")
        |> next()
        |> mes("[Isac Mari]")
        |> mes(
          "But can you check that the items in your inventory aren't upgraded or have cards compounded into them? If any of the required items have forged upgrades or cards, those will be lost once I create the Parcel Hat."
        )
        |> next()
        |> mes("[Isac Mari]")
        |> mes(
          "It's better to keep only the items used to make the Parcel Hat in your inventory. Did you check? If so, let's get started."
        )
        |> next()
        |> select(["Give me a minute~!", "Let's make the Parcel Hat."])

      case choice do
        1 ->
          ctx
          |> mes("[Isac Mari]")
          |> mes(
            "Alright. Please check your items again. It's much better to be safe than sorry."
          )
          |> close()

        2 ->
          ctx
          |> mes("^3355FF*Thook Thook*")
          |> mes("*Pop!*^000000")
          |> next()
          |> mes("[Isac Mari]")
          |> mes("Oh...")
          |> mes("I think I messed up!")
          |> mes("No, wait, I think I can fix this...")
          |> next()
          |> delitem(1059, 150)
          |> delitem(907, 100)
          |> delitem(978, 1)
          |> mes("[Isac Mari]")
          |> mes("Well...")
          |> mes("Um, it looks like a Parcel Hat. So that's good enough for me! Ha ha~")
          |> give_item(5023, 1)
          |> close()

        _ ->
          ctx
      end
    else
      ctx
      |> mes("[Isac Mari]")
      |> mes(
        "I heard that around Alberta, Merchants are always selling goods from their carts in the middle of the streets."
      )
      |> next()
      |> mes("[Isac Mari]")
      |> mes("But in the East side of the country, they use a different way to transfer goods.")
      |> next()
      |> mes("[Isac Mari]")
      |> mes(
        "Goods would be packed into a bundle and placed on top of the head so you wouldn't need to carry things by hand. But it's hard to keep your balance."
      )
      |> next()
      |> mes("[Isac Mari]")
      |> mes("I'll need...")
      |> mes("^3355FF150 Fabric^000000")
      |> mes("^3355FF100 Resin^000000 and")
      |> mes("^3355FF1 Cobaltblue Dyestuffs^000000")
      |> mes("to make a Parcel Hat.")
      |> next()
      |> mes("[Isac Mari]")
      |> mes("If you bring all the items then I will make it for you right away. See you later~!")
      |> close()
    end
  end

  defp grief_for_greed(ctx) do
    if count_item(ctx, 2233) > 0 and count_item(ctx, 969) > 0 and count_item(ctx, 949) > 79 and
         count_item(ctx, 999) > 19 and count_item(ctx, 938) > 799 do
      {ctx, choice} =
        ctx
        |> mes("[Isac Mari]")
        |> mes("Grief for Greed...")
        |> mes("If you brought all the required items, I'll go ahead and make it for you~")
        |> next()
        |> mes("[Isac Mari]")
        |> mes(
          "But can you check that the items in your inventory aren't upgraded or have cards compounded into them? If any of the required items have forged upgrades or cards, those will be lost once I create the Money Loser's Grief."
        )
        |> next()
        |> mes("[Isac Mari]")
        |> mes(
          "It's better to keep only the items used to make the Grief for Greed in your inventory. Did you check? If so, let's get started."
        )
        |> next()
        |> select(["Give me a minute~!", "Let's make the Grief for Greed."])

      case choice do
        1 ->
          ctx
          |> mes("[Isac Mari]")
          |> mes(
            "Alright. Please check your items again. It's much better to be safe than sorry."
          )
          |> close()

        2 ->
          ctx
          |> mes("^3355FF*Thook Thook*")
          |> mes("*Pop!*^000000")
          |> next()
          |> mes("[Isac Mari]")
          |> mes("Whew! This is pretty hard!")
          |> next()
          |> delitem(2233, 1)
          |> delitem(969, 1)
          |> delitem(949, 80)
          |> delitem(999, 20)
          |> delitem(938, 800)
          |> mes("[Isac Mari]")
          |> mes(
            "I might have made a few mistakes, but it looks good enough. Here you go, your own Grief for Greed hat!"
          )
          |> give_item(5021, 1)
          |> close()

        _ ->
          ctx
      end
    else
      ctx
      |> mes("[Isac Mari]")
      |> mes("Grief for Greed...")
      |> mes(
        "There's a tale of an honest Merchant that lived in Morocc long ago who had a quarrel with a bad guild."
      )
      |> next()
      |> mes("[Isac Mari]")
      |> mes(
        "Because the honest Merchant was not cheating people by his prices, his street stall was attacked by the bad guild and all his goods were taken."
      )
      |> next()
      |> mes("[Isac Mari]")
      |> mes(
        "So, the honest Merchant lost everything except some broken items. To express his sadness, he took these broken items and created this magnificent hat, the Grief for Greed."
      )
      |> next()
      |> mes("[Isac Mari]")
      |> mes(
        "This special hat appeals to people's sympathies, making them buy more goods to support the inner goodness of honest Merchants."
      )
      |> next()
      |> mes("[Isac Mari]")
      |> mes("For this hat, I'll need...")
      |> mes("^3355FF1 Slotted Circlet^000000")
      |> mes("^3355FF1 Gold^000000")
      |> mes("^3355FF20 Steel^000000")
      |> mes("^3355FF80 Feather^000000")
      |> mes("^3355FF800 Sticky Mucus^000000")
      |> next()
      |> mes("[Isac Mari]")
      |> mes("If you bring all the items then I will make it for you right away. See you later~")
      |> close()
    end
  end

  defp opera_phantom_mask(ctx) do
    if count_item(ctx, 2281) > 0 and count_item(ctx, 1048) > 49 do
      {ctx, choice} =
        ctx
        |> mes("[Isac Mari]")
        |> mes("Opera Phantom Mask...")
        |> mes(
          "Frightening, but also tragic and romantic. If you brought all the required items, I will make it for you~"
        )
        |> next()
        |> mes("[Isac Mari]")
        |> mes(
          "But can you check that the items in your inventory aren't upgraded or have cards compounded into them? If any of the required items have forged upgrades or cards, those will be lost once I create the Opera Masque."
        )
        |> next()
        |> mes("[Isac Mari]")
        |> mes(
          "It's better to keep only the items used to make the Opera Mask in your inventory. Did you check? If so, let's get started."
        )
        |> next()
        |> select(["Give me a minute~!", "Let's make the Opera Masque."])

      case choice do
        1 ->
          ctx
          |> mes("[Isac Mari]")
          |> mes(
            "Alright. Please check your items again. It's much better to be safe than sorry."
          )
          |> close()

        2 ->
          ctx
          |> mes("^3355FF*Thook Thook*")
          |> mes("*Pop!*^000000")
          |> next()
          |> mes("[Isac Mari]")
          |> mes("Whew! This is pretty hard!")
          |> next()
          |> delitem(2281, 1)
          |> delitem(1048, 50)
          |> mes("[Isac Mari]")
          |> mes("I'm not quite sure if this is the right one.")
          |> mes("But it looks fine. Ha ha")
          |> give_item(5043, 1)
          |> close()

        _ ->
          ctx
      end
    else
      ctx
      |> mes("[Isac Mari]")
      |> mes("Opera Phantom Mask...")
      |> mes("Behind this mask is a story about a man's love and personal tragedy.")
      |> next()
      |> mes("[Isac Mari]")
      |> mes(
        "You may know him as the Phantom of the Opera. He was a musical genius that brought terror to the stage, because his scarred face forced him to live outside of society."
      )
      |> next()
      |> mes("[Isac Mari]")
      |> mes(
        "However, he fell in love with a beautiful singer and used his talents to propel her to new heights of fame. He finally revealed himself to her."
      )
      |> next()
      |> mes("[Isac Mari]")
      |> mes("In the end...")
      |> mes(
        "She deeply cared for him, but was in love with another singer. The Phantom disappeared, perhaps to haunt some other place, and all that was left of him was his mask..."
      )
      |> next()
      |> mes("[Isac Mari]")
      |> mes(
        "The mask that he was wearing is differently shaped that other opera masks, and was made to cover his particular facial scarring."
      )
      |> next()
      |> mes("[Isac Mari]")
      |> mes("If you want to make Phantom of Opera. You will need:")
      |> mes("^3355FF1 Opera Masque^000000")
      |> mes("^3355FF50 Horrendous Hair^000000")
      |> next()
      |> mes("[Isac Mari]")
      |> mes("If you bring all the items then I will make it for you right away. See you later~")
      |> close()
    end
  end
end
