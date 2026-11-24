defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAyothaya.Fisherman do
  @moduledoc """
  Dannai rents fishing rods and offers a chance to find the missing ring.

  ## Behavior

  - Charges bait and zeny for fishing during the search and awards a random catch.
  - Advances the search when the engagement ring is found.

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
      %{map: "ayothaya", x: 253, y: 99, dir: 3, sprite: 843, name: "Fisherman", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @monster_feed 528
  @stone 7049
  @red_potion 501
  @yellow_potion 503
  @sushi 551
  @flower_ring 2612
  @diamond_ring 2613
  @engagement_ring 7288

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :thai_find, 0) do
      1 -> offer_fishing(ctx)
      progress when progress < 1 -> introduction(ctx)
      _ -> crowded(ctx)
    end
  end

  defp offer_fishing(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Dannai]")
      |> mes("This place is known to be")
      |> mes("teeming with fish. The fish here tend to eat anything they find,")
      |> mes("so it's easy to catch them.")
      |> next()
      |> mes("[Dannai]")
      |> mes(
        "We are providing a fishing rod rental service. Every time you fish, you'll need ^3355FF 1 Monster's Feed^000000 to use as bait, and pay"
      )
      |> mes("a rod rental fee of ^3355FF50 Zeny^000000.")
      |> next()
      |> mes("[Dannai]")
      |> mes("Would you")
      |> mes("like to try?")
      |> next()
      |> select(["Yes.", "No, thanks."])

    case choice do
      1 -> fish(ctx)
      2 -> declined(ctx)
      _ -> ctx
    end
  end

  defp fish(ctx) do
    if Rathena.truthy?(count_item(ctx, @monster_feed)) and zeny(ctx) > 49 do
      ctx =
        ctx
        |> mes("^3355FFYou cast your")
        |> mes("fishing line")
        |> mes("into the water.^000000")
        |> next()
        |> mes("...")
        |> next()
        |> mes("...")
        |> mes("......")
        |> next()
        |> mes("^3355FFYou've hooked a Phen!^000000")
        |> next()
        |> delitem(@monster_feed, 1)
        |> pay_zeny(50)
        |> set_local(:randfish, Enum.random(1..100))

      case get_local(ctx, :randfish, 0) do
        roll when roll > 0 and roll < 40 -> stone(ctx)
        roll when roll < 60 and roll > 39 -> red_potion(ctx)
        roll when roll < 70 and roll > 59 -> yellow_potion(ctx)
        roll when roll < 80 and roll > 69 -> sushi(ctx)
        roll when roll < 90 and roll > 79 -> flower_ring(ctx)
        90 -> diamond_ring(ctx)
        roll when roll > 90 and roll < 101 -> engagement_ring(ctx)
        _ -> declined(ctx)
      end
    else
      insufficient_supplies(ctx)
    end
  end

  defp stone(ctx) do
    ctx
    |> mes("^3355FFWhile cooking the Phen, you")
    |> mes("find that it's swallowed a Stone.^000000")
    |> close()
    |> give_item(@stone, 1)
  end

  defp red_potion(ctx) do
    ctx
    |> mes("^3355FFInside of the Phen,")
    |> mes("you find a Red Potion.^000000")
    |> close()
    |> give_item(@red_potion, 1)
  end

  defp yellow_potion(ctx) do
    ctx
    |> mes("^3355FFInside of the Phen,")
    |> mes("you find a Yellow Potion.^000000")
    |> close()
    |> give_item(@yellow_potion, 1)
  end

  defp sushi(ctx) do
    ctx
    |> mes("^3355FFThere's nothing inside...")
    |> mes("But now you can eat Sushi!^000000")
    |> close()
    |> give_item(@sushi, 1)
  end

  defp flower_ring(ctx) do
    ctx
    |> mes("^3355FFYou find")
    |> mes("a Flower Ring")
    |> mes("inside the Phen.^000000")
    |> close()
    |> give_item(@flower_ring, 1)
  end

  defp diamond_ring(ctx) do
    ctx
    |> mes("^3355FFYou find")
    |> mes("a Diamond Ring")
    |> mes("inside the Phen.^000000")
    |> close()
    |> give_item(@diamond_ring, 1)
  end

  defp engagement_ring(ctx) do
    ctx
    |> mes("^3355FFYou find a ring")
    |> mes("with a name engraved")
    |> mes("inside the band.^000000")
    |> next()
    |> mes("^3355FFYou take the")
    |> mes("engagement ring.^000000")
    |> close()
    |> set_char_var(:thai_find, 2)
    |> changequest(12029, 12030)
    |> give_item(@engagement_ring, 1)
  end

  defp insufficient_supplies(ctx) do
    ctx
    |> mes("[Dannai]")
    |> mes(
      "Remember, you need ^3355FF1 Monster's Feed^000000 to use as bait and ^3355FF50 zeny^000000 to rend a rod."
    )
    |> close()
  end

  defp declined(ctx) do
    ctx
    |> mes("[Dannai]")
    |> mes("No problem,")
    |> mes("come back anytime you")
    |> mes("want. Fishing relaxes")
    |> mes("the mind and makes you")
    |> mes("feel at peace...")
    |> close()
  end

  defp introduction(ctx) do
    ctx
    |> mes("[Dannai]")
    |> mes("The fish here tend")
    |> mes("to eat anything they find.")
    |> mes("When you gut them, you can")
    |> mes("often find interesting things inside.")
    |> next()
    |> mes("[Dannai]")
    |> mes("So when you get a chance,")
    |> mes("why don't you sit down, relax")
    |> mes("and enjoy some quiet fishing?")
    |> close()
  end

  defp crowded(ctx) do
    ctx
    |> mes("[Dannai]")
    |> mes("Welcome, long time no see!")
    |> mes(
      "It seems people learned that you found some kind of fortune from fishing here. After word got around, I've been getting lots"
    )
    |> mes("of customers.")
    |> next()
    |> mes("[Dannai]")
    |> mes("I understand that you want")
    |> mes("fish, but right now there")
    |> mes("aren't any fishing spots")
    |> mes("for you at the moment.")
    |> next()
    |> mes("[Dannai]")
    |> mes("Please let other")
    |> mes("people have their")
    |> mes("chance to find their")
    |> mes("own fortunes.")
    |> close()
  end
end
