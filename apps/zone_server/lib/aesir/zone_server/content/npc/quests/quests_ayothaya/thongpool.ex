defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAyothaya.Thongpool do
  @moduledoc """
  Thongpool sells shrimp for the Tom Yum Goong quest.

  ## Behavior

  - Offers discounted shrimp during the quest and repeat purchases afterwards.
  - Checks carrying capacity and zeny before selling.

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
        x: 153,
        y: 86,
        dir: 5,
        sprite: 843,
        name: "Thongpool",
        scope: :shared,
        unique_name: "Thongpool#ayo"
      }
    ]

  @shrimp 567
  @knife 1201

  @impl true
  def on_talk(ctx) do
    cond do
      max_weight(ctx) - weight(ctx) < 2000 or checkweight(ctx, [{@knife, 1}]) == 0 ->
        initial_overweight(ctx)

      get_char_var(ctx, :tomyumgoong, 0) == 2 ->
        first_offer(ctx)

      get_char_var(ctx, :tomyumgoong, 0) == 3 ->
        repeat_offer(ctx)

      true ->
        greeting(ctx)
    end
  end

  defp first_offer(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Thongpool]")
      |> mes("Come adventurers,")
      |> mes("take a look! I have")
      |> mes("plenty of Shrimp!")
      |> next()
      |> mes("[Thongpool]")
      |> mes("You're looking for Shrimp,")
      |> mes("aren't you? How many Shrimp")
      |> mes("do you need? Twenty? Forty?")
      |> next()
      |> select(["I need Shrimp for Tom Yum Goong.", "Err, they look expensive."])

    if choice == 1, do: bulk_offer(ctx), else: expensive(ctx)
  end

  defp bulk_offer(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Thongpool]")
      |> mes("Ah! I guess Ms. Mali the Spicy recommended me to you. I guess")
      |> mes("that also means you want to buy them in bulk?")
      |> next()
      |> mes("[Thongpool]")
      |> mes("After all,")
      |> mes("you'll need a larger")
      |> mes("amount of Shrimp to")
      |> mes("cook Tom Yum Goong.")
      |> next()
      |> mes("[Thongpool]")
      |> mes("Oh yes, you will need 20 Shrimps for Ms. Mali's Tom Yum Goong.")
      |> mes("I'll even give you a discount:")
      |> mes("11,000 zeny for 20 shrimps.")
      |> mes("What do you say?")
      |> next()
      |> select(["I will take them.", "I could get 100 Jellopies for that much!"])

    if choice == 1, do: buy(ctx, :first), else: jellopies(ctx)
  end

  defp repeat_offer(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Thongpool]")
      |> mes("Mmm...?")
      |> mes("Did you need")
      |> mes("more Shrimps?")
      |> mes("Would you like")
      |> mes("to buy more?")
      |> next()
      |> select(["Yes!", "No, thanks."])

    if choice == 1, do: buy(ctx, :repeat), else: reminder(ctx)
  end

  defp buy(ctx, purchase) do
    cond do
      zeny(ctx) <= 10_999 -> insufficient_money(ctx)
      max_weight(ctx) - weight(ctx) <= 3999 -> overweight(ctx)
      purchase == :first -> first_purchase(ctx)
      true -> repeat_purchase(ctx)
    end
  end

  defp initial_overweight(ctx) do
    ctx
    |> mes("- Wait a minute! -")
    |> mes("- Currently you're carrying -")
    |> mes("- too many items with you. -")
    |> mes("- Please enlighten your weight -")
    |> mes("- and try again. -")
    |> close()
  end

  defp first_purchase(ctx) do
    ctx
    |> pay_zeny(11_000)
    |> set_char_var(:tomyumgoong, 3)
    |> give_item(@shrimp, 20)
    |> emotion(:best)
    |> mes("[Thongpool]")
    |> mes("Good, now you have the")
    |> mes(
      "freshest Shrimp in this village! It's time for you to go back and ask Ms. Mali to cook them for you."
    )
    |> close()
  end

  defp repeat_purchase(ctx) do
    ctx
    |> pay_zeny(11_000)
    |> give_item(@shrimp, 20)
    |> mes("[Thongpool]")
    |> mes("There you go~")
    |> mes("The freshest Shrimp you can ever get in this village, and maybe even the world!")
    |> close()
  end

  defp overweight(ctx) do
    ctx
    |> mes("[Thongpool]")
    |> mes("Awww...")
    |> mes(
      "You're carrying too much stuff with you. I don't think you can carry more than what you have right now."
    )
    |> close()
  end

  defp insufficient_money(ctx) do
    ctx
    |> mes("[Thongpool]")
    |> mes("Awww...")
    |> mes("You don't have")
    |> mes("enough money.")
    |> close()
  end

  defp jellopies(ctx) do
    ctx
    |> mes("[Thongpool]")
    |> mes("Well well well...")
    |> mes(
      "You might fill your hungry stomach with that many Jellopies but they wouldn't taste as good as my Shrimp!"
    )
    |> close()
  end

  defp expensive(ctx) do
    ctx
    |> mes("[Thongpool]")
    |> mes("What...?")
    |> mes("Do you think")
    |> mes("it's expensive?")
    |> mes("But the fantastic taste")
    |> mes("of Tom Yum Goong")
    |> mes("is priceless!")
    |> close()
  end

  defp reminder(ctx) do
    ctx
    |> mes("[Thongpool]")
    |> mes("Good, now you have gotten the freshest shrimps in this village!")
    |> mes("It's time for you to go back and ask Ms. Mali to cook for you.")
    |> close()
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Thongpool]")
    |> mes("Welcome, welcome!")
    |> mes("I've got the best Shrimp caught in the cleanest waters in the world~!")
    |> close()
  end
end
