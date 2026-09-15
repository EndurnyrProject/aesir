defmodule Aesir.ZoneServer.Content.Npc.Airports.Airships.AppleMerchant do
  @moduledoc """
  Runs Fruitz's apple and apple juice shop aboard the domestic airship.

  ## Behavior

  - Sells up to 500 Apples at 15 zeny each after checking funds and carrying capacity.
  - Converts three Apples and one Empty Bottle into one Apple Juice.
  - Recounts how Fruitz won enough Apples to establish his airship business.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "airplane",
        x: 50,
        y: 66,
        dir: 5,
        sprite: 86,
        name: "Apple Merchant",
        scope: :shared,
        unique_name: "Apple Merchant#airplane"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Fruitz]")
      |> mes("Welcome to Fruitz's")
      |> mes("Shop where you can")
      |> mes("purchase Apples or grind")
      |> mes("them to make Apple Juice.")
      |> next()
      |> select(["Buy Apples.", "Make Apple Juice.", "Why are you here?", "Cancel."])

    case choice do
      1 -> buy_apples(ctx)
      2 -> make_apple_juice(ctx)
      3 -> tell_story(ctx)
      4 -> close_shop(ctx)
      _ -> ctx
    end
  end

  defp buy_apples(ctx) do
    ctx =
      ctx
      |> mes("[Fruitz]")
      |> mes("Please enter the amount")
      |> mes("of Apples that you wish to")
      |> mes("buy. Each Apple is 15 zeny")
      |> mes("and you can buy a maximum")
      |> mes("of 500 at a time. Please enter")
      |> mes(" '0' to cancel your order.")
      |> next()

    case ask_purchase_amount(ctx) do
      {:cancel, ctx} ->
        ctx

      {:order, ctx, amount, price} ->
        complete_purchase(ctx, amount, price)
    end
  end

  defp ask_purchase_amount(ctx) do
    {ctx, amount} = input(ctx, :int)

    cond do
      amount == 0 ->
        {:cancel, farewell(ctx)}

      amount < 1 or amount > 500 ->
        ctx =
          ctx
          |> mes("[Fruitz]")
          |> mes("You've entered a number")
          |> mes("higher than the maximum")
          |> mes("value of 500. Please enter")
          |> mes("the number of Apples you")
          |> mes("wish to purchase again.")
          |> next()

        ask_purchase_amount(ctx)

      true ->
        confirm_purchase(ctx, amount)
    end
  end

  defp confirm_purchase(ctx, amount) do
    price = amount * 15

    {ctx, choice} =
      ctx
      |> mes("[Fruitz]")
      |> mes("A total of ^FF0000#{amount}^000000 Apples")
      |> mes("will cost you ^FF0000#{price}^000000 zeny.")
      |> mes("Would you like to continue?")
      |> next()
      |> select(["Yes", "No"])

    if choice == 2 do
      {:cancel, farewell(ctx)}
    else
      {:order, ctx, amount, price}
    end
  end

  defp complete_purchase(ctx, amount, price) do
    cond do
      zeny(ctx) < price ->
        ctx
        |> mes("[Fruitz]")
        |> mes("I'm sorry, but you don't")
        |> mes("have enough money to")
        |> mes("purchase that many Apples.")
        |> mes("Please check your zeny or")
        |> mes("purchase fewer Apples.")
        |> close()

      checkweight(ctx, [{512, amount}]) == 0 ->
        ctx
        |> mes("[Fruitz]")
        |> mes("Hmmm, I don't think")
        |> mes("you've got enough room in")
        |> mes("your inventory to carry this")
        |> mes("many Apples. Why don't you free up some of your inventory space?")
        |> close()

      true ->
        ctx
        |> pay_zeny(price)
        |> give_item(512, amount)
        |> mes("[Fruitz]")
        |> mes("Thanks for stopping by")
        |> mes("my shop. I hope you enjoy")
        |> mes("the flavor of these Apples~!")
        |> close()
    end
  end

  defp make_apple_juice(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Fruitz]")
      |> mes("Okay, I'll need")
      |> mes("^FF00003 Apples and 1 Empty Bottle^000000")
      |> mes("to make 1 Apple Juice for you.")
      |> mes("Would you like to proceed?")
      |> next()
      |> select(["Yes", "No"])

    if choice == 1 do
      craft_apple_juice(ctx)
    else
      farewell(ctx)
    end
  end

  defp craft_apple_juice(ctx) do
    if count_item(ctx, 512) < 3 or count_item(ctx, 713) < 1 do
      ctx
      |> mes("[Fruitz]")
      |> mes("I'm sorry, but you don't")
      |> mes("have enough materials to")
      |> mes("create a bottle of Apple Juice.")
      |> mes("Remember, I need 3 Apples")
      |> mes("and 1 Empty Bottle to do it.")
      |> close()
    else
      ctx
      |> mes("[Fruitz]")
      |> mes("Thank you,")
      |> mes("please wait")
      |> mes("just a moment.")
      |> next()
      |> mes("^3355FF*Grind grind*")
      |> mes("*Grind grind*")
      |> mes("*Clang...!*^000000")
      |> next()
      |> delitem(512, 3)
      |> delitem(713, 1)
      |> give_item(531, 1)
      |> mes("[Fruitz]")
      |> mes("There you go~")
      |> mes("I hope you enjoy!")
      |> mes("Please feel free to")
      |> mes("stop by for your Apple")
      |> mes("and Apple Juice needs")
      |> mes("at anytime, adventurer~")
      |> close()
    end
  end

  defp tell_story(ctx) do
    ctx
    |> mes("[Fruitz]")
    |> mes("I used to be a wandering")
    |> mes("vagabond when, one day,")
    |> mes("I took a nap and something")
    |> mes("struck my head and awoke")
    |> mes("me from my restful slumber.")
    |> next()
    |> mes("[Fruitz]")
    |> mes("It turns out that I was")
    |> mes("sleeping beneath an apple")
    |> mes("tree and that an apple fell")
    |> mes("and hit me on the head.")
    |> mes("I was dying of hunger and")
    |> mes("was about to eat that Apple...")
    |> next()
    |> mes("[Fruitz]")
    |> mes("But suddenly, Kain, my old")
    |> mes("friend from the mining days,")
    |> mes("asked me to help him around")
    |> mes("on the Airship. So I did, and")
    |> mes("it was there where I found some")
    |> mes("people playing the Dice game.")
    |> next()
    |> mes("[Fruitz]")
    |> mes("I was bored and curious")
    |> mes("and ended up wagering that")
    |> mes("single Apple in a game of")
    |> mes("dice. But for some reason,")
    |> mes("I had this incredible lucky")
    |> mes("streak. One apple became two... ")
    |> next()
    |> mes("[Fruitz]")
    |> mes("Two became four and")
    |> mes("before I knew it, I had")
    |> mes("cornered the Apple market!")
    |> mes("I won so many Apples, I just")
    |> mes("started my own business here")
    |> mes("on the Airship. Weird, huh?")
    |> next()
    |> mes("[Fruitz]")
    |> mes("So Apples are good")
    |> mes("for you. They were")
    |> mes("certainly very good")
    |> mes("to me. Hahahahaah~!")
    |> close()
  end

  defp farewell(ctx) do
    ctx
    |> mes("[Fruitz]")
    |> mes("Thanks for stopping")
    |> mes("by my shop. Farewell!")
    |> mes("Come by anytime when")
    |> mes("you feel like having an")
    |> mes("Apple to snack on~")
    |> close()
  end

  defp close_shop(ctx) do
    ctx
    |> mes("[Fruitz]")
    |> mes("Thank you for")
    |> mes("using my shop.")
    |> mes("Farewell~")
    |> close()
  end
end
