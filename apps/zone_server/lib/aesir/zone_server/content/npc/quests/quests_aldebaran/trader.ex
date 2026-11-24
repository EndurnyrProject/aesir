defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAldebaran.Trader do
  @moduledoc """
  Trades collected materials and zeny for one of four headgears.

  ## Behavior

  - Doctor Band: 1 Red Bandana, 50 Iron, 1 Cracked Diamond and 3,500 zeny.
  - Feather Bonnet: 1 Romantic Gent, 300 Feather of Birds and 500 zeny.
  - Phantom of Opera: 20 Iron, 1 Singing Plant and 5,000 zeny.
  - Sakkat: 120 Trunks and 10,000 zeny.
  - Missing any requirement ends the dialogue without taking anything.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - Lupus
    - Silent
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "aldeba_in",
        x: 152,
        y: 166,
        dir: 4,
        sprite: 86,
        name: "Trader",
        scope: :shared,
        unique_name: "Trader#01"
      }
    ]

  @doctor_band_cost {[{2275, 1}, {998, 50}, {733, 1}], 3500}
  @feather_bonnet_cost {[{2247, 1}, {916, 300}], 500}
  @phantom_of_opera_cost {[{998, 20}, {707, 1}], 5000}
  @sakkat_cost {[{1019, 120}], 10_000}

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Trader]")
      |> mes("Who is this mysterious man?")
      |> mes("I, the enigmatic and debonair 'Trader?'")
      |> next()
      |> mes("[Trader]")
      |> mes(
        "Traveling about the Midgard Continent, with all of his wonderful hats? Nobody knows..."
      )
      |> next()
      |> mes("[Trader]")
      |> mes(
        "For what purpose do I collect and trade these hats from all around the world? Choose a hat, get closer to unraveling the mystery..."
      )
      |> next()
      |> mes(" (1) ^3355FFDoctor Band^000000:")
      |> mes("1 Red Bandana + 50 Irons + 1 Cracked Diamond + 3500 Zeny")
      |> mes(" (2)^3355FFFeather Bonnet^000000:")
      |> mes("1 Romantic Gent + 300 Feather of Birds + 500 Zeny")
      |> mes(" (3) ^3355FFPhantom of Opera^000000:")
      |> mes("20 Iron + 1 Singing Plant + 5000 Zeny ")
      |> mes(" (4) ^3355FFSakkat^000000:")
      |> mes("120 Trunks + 10000 Zeny ")
      |> next()
      |> select([" Doctor Band ", " Feather Bonnet ", " Phantom of Opera ", " Sakkat "])

    trade(ctx, choice)
  end

  defp trade(ctx, 1) do
    if affordable?(ctx, @doctor_band_cost) do
      ctx
      |> pay(@doctor_band_cost)
      |> mes("[Trader]")
      |> mes(
        "Hm! You don't have a medical license, do you? It's alright, I've heard about a rogue, unlicensed physician who performed medical miracles! But... That might have been a comic book."
      )
      |> next()
      |> mes("[Trader]")
      |> mes("Oh whatever. Just don't get caught.")
      |> give_item(2273, 1)
      |> close()
    else
      ctx
      |> mes("[Trader]")
      |> mes("You guy~")
      |> mes("Check the requirements again.")
      |> mes("You don't look like an idiot though. So c'mon man, get real.")
      |> close()
    end
  end

  defp trade(ctx, 2) do
    if affordable?(ctx, @feather_bonnet_cost) do
      ctx
      |> pay(@feather_bonnet_cost)
      |> mes("[Trader]")
      |> mes(
        "Ooh~! You have good fashion sense. I know you've had a hard time collecting this stuff, but this hat is worth it. Take it. All you need now is a fur coat and a cane!"
      )
      |> give_item(5018, 1)
      |> close()
    else
      ctx
      |> mes("[Trader]")
      |> mes("You guy~")
      |> mes(
        "Go check my requirements again. You don't look like an idiot though. C'mon man, get real."
      )
      |> close()
    end
  end

  defp trade(ctx, 3) do
    if affordable?(ctx, @phantom_of_opera_cost) do
      ctx
      |> pay(@phantom_of_opera_cost)
      |> mes("[Trader]")
      |> mes(
        "This one? It's a little bit scary, though it has some sort of romantic quality. What do you think? You like it? Alright, take it, it's yours!"
      )
      |> give_item(2281, 1)
      |> close()
    else
      ctx
      |> mes("[Trader]")
      |> mes(
        "Buffoon. Go check the requirements again. ^3355FFPhantom of Opera^000000 isn't easy to come by. So c'mon man, get real."
      )
      |> close()
    end
  end

  defp trade(ctx, 4) do
    if affordable?(ctx, @sakkat_cost) do
      ctx
      |> pay(@sakkat_cost)
      |> mes("[Trader]")
      |> mes(
        "If you have a chance to visit the Uplander Village, Payon, please go and meet the Sakkat Craftsman."
      )
      |> next()
      |> mes("[Trader]")
      |> mes(
        "He's never sold Sakkat to Traders other than me, since only I can recognize its quality. Due to its rarity, Sakkat has become a very unique and exceptional product. Okay! Take it, it's yours!"
      )
      |> give_item(2280, 1)
      |> close()
    else
      ctx
      |> mes("[Trader]")
      |> mes(
        "MORON~ Check my requirements again. C'mon man, you don't look like an idiot, so get real~"
      )
      |> close()
    end
  end

  defp trade(ctx, _choice), do: ctx

  defp affordable?(ctx, {items, price}) do
    Enum.all?(items, fn {item_id, amount} -> count_item(ctx, item_id) >= amount end) and
      zeny(ctx) >= price
  end

  defp pay(ctx, {items, price}) do
    items
    |> Enum.reduce(ctx, fn {item_id, amount}, ctx -> delitem(ctx, item_id, amount) end)
    |> pay_zeny(price)
  end
end
