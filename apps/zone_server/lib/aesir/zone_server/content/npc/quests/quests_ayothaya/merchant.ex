defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAyothaya.Merchant do
  @moduledoc """
  Merchant Thongdum sells ingredients for Tom Yum Goong.

  ## Behavior

  - Sells a quest ingredient and offers repeat purchases after the first sale.

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
        x: 213,
        y: 94,
        dir: 7,
        sprite: 841,
        name: "Merchant",
        scope: :shared,
        unique_name: "Merchant#ayo"
      }
    ]

  @chili 7286

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :tomyumgoong, 0) do
      6 -> first_offer(ctx)
      7 -> repeat_offer(ctx)
      _ -> greeting(ctx)
    end
  end

  defp first_offer(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Merchant Thongdum]")
      |> mes("Hello, there~")
      |> mes("Are you looking for")
      |> mes("ingredients to make")
      |> mes("Tom Yum Goong?")
      |> next()
      |> mes("[Merchant Thongdum]")
      |> mes("Let's see...")
      |> mes("I'm selling chiles,")
      |> mes("fish sauce, and some")
      |> mes("spices and flavorings")
      |> mes("you'll need. I'll sell")
      |> mes("it all to you for 2,000 zeny.")
      |> next()
      |> select(["Thanks, I'll take it.", "It's a rip-off, man!"])

    if choice == 1 do
      ctx |> emotion(:thanks) |> buy(:first)
    else
      declined(ctx)
    end
  end

  defp repeat_offer(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Merchant Thongdum]")
      |> mes("I thought I provided you")
      |> mes("with enough ingredients, but")
      |> mes("now that I think about it, I don't")
      |> mes("know how much Tom Yum Goong")
      |> mes("you're making.")
      |> next()
      |> mes("[Merchant Thongdum]")
      |> mes("Would you like to")
      |> mes("buy some more Chilis?")
      |> next()
      |> select(["No, thanks.", "Yes, please."])

    if choice == 1 do
      ctx |> mes("[Merchant Thongdum]") |> mes("Fare well~") |> close()
    else
      buy(ctx, :repeat)
    end
  end

  defp buy(ctx, purchase) do
    cond do
      zeny(ctx) <= 1999 -> insufficient_money(ctx)
      max_weight(ctx) - weight(ctx) <= 1199 -> overweight(ctx)
      purchase == :first -> first_purchase(ctx)
      true -> repeat_purchase(ctx)
    end
  end

  defp first_purchase(ctx) do
    ctx
    |> pay_zeny(2000)
    |> set_char_var(:tomyumgoong, 7)
    |> give_item(@chili, 30)
    |> mes("[Merchant Thongdum]")
    |> mes("Thank you.")
    |> mes("I hope you will enjoy")
    |> mes("your Tom Yum Goong~")
    |> close()
  end

  defp repeat_purchase(ctx) do
    ctx
    |> pay_zeny(2000)
    |> give_item(@chili, 30)
    |> mes("[Merchant Thongdum]")
    |> mes("Thank you,")
    |> mes("come again!")
    |> close()
  end

  defp overweight(ctx) do
    ctx
    |> mes("[Merchant Thongdum]")
    |> mes("Uh oh...")
    |> mes("It looks like")
    |> mes("you're carrying")
    |> mes("too much stuff")
    |> mes("right now.")
    |> next()
    |> mes("[Merchant Thongdum]")
    |> mes("I can't give you")
    |> mes("anything if you don't")
    |> mes("have the room to hold it!")
    |> close()
  end

  defp insufficient_money(ctx) do
    ctx
    |> mes("[Merchant Thongdum]")
    |> mes("Hmm...?")
    |> mes("Right now, it looks")
    |> mes("like you don't have the")
    |> mes("money to buy what you")
    |> mes("need from me.")
    |> close()
  end

  defp declined(ctx) do
    ctx
    |> emotion(:stare_about)
    |> mes("[Merchant Thongdum]")
    |> mes("Don't say that.")
    |> mes("My prices are always")
    |> mes("reasonable. I want you to know")
    |> mes("that I'm a respectable Merchant.")
    |> close()
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Merchant Thongdum]")
    |> mes("Hello there!")
    |> mes("Ever try a Chili before?")
    |> next()
    |> mes("[Merchant Thongdom]")
    |> mes("Despite its tiny appearance,")
    |> mes(
      "it has a very strong flavor. It's also hot and spicy, so you should be careful when you eat one."
    )
    |> next()
    |> mes("[Merchant Thongdum]")
    |> mes(
      "The people of Ayothaya enjoy sensational food with distinct, spicy flavors. In Ayothayan cuisine, we use things like Chilis, garlic, ginger and cilantro."
    )
    |> next()
    |> mes("[Merchant Thongdum]")
    |> mes("I'm selling Chilis,")
    |> mes("so if you need any,")
    |> mes("please come to me~")
    |> close()
  end
end
