defmodule Aesir.ZoneServer.Content.Npc.Airports.Airships.AppleMerchant5066 do
  @moduledoc """
  Runs Meltz's apple and apple juice shop aboard the international airship.

  ## Behavior

  - Sells up to 500 Apples at 15 zeny each after checking funds and carrying capacity.
  - Converts three Apples and one Empty Bottle into one Apple Juice.
  - Refuses service when the player's inventory is already too heavy.

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
        map: "airplane_01",
        x: 50,
        y: 66,
        dir: 5,
        sprite: 86,
        name: "Apple Merchant",
        scope: :shared,
        unique_name: "Apple Merchant#air01"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if checkweight(ctx, [{1201, 1}]) == 0 do
      inventory_full(ctx)
    else
      offer_services(ctx)
    end
  end

  defp offer_services(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Meltz]")
      |> mes("Welcome to Meltz's")
      |> mes("Shop where you can")
      |> mes("purchase Apples or grind")
      |> mes("them to make Apple Juice.")
      |> next()
      |> select(["Buy Apples.", "Make Apple Juice.", "Cancel."])

    case choice do
      1 -> buy_apples(ctx)
      2 -> make_apple_juice(ctx)
      _ -> farewell(ctx)
    end
  end

  defp buy_apples(ctx) do
    ctx =
      ctx
      |> mes("[Meltz]")
      |> mes("Please enter the amount")
      |> mes("of Apples that you wish to")
      |> mes("buy. Each Apple is 15 zeny")
      |> mes("and you can buy a maximum")
      |> mes("of 500 at a time. Please enter")
      |> mes("'0' to cancel your order.")
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
          |> mes("[Meltz]")
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
      |> mes("[Meltz]")
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
        |> mes("[Meltz]")
        |> mes("I'm sorry, you don't have")
        |> mes("enough money with you.")
        |> mes("Please check your funds or")
        |> mes("purchase less Apples.")
        |> close()

      checkweight(ctx, [{512, amount}]) == 0 ->
        ctx
        |> mes("[Meltz]")
        |> mes("Hmm, I don't think you've")
        |> mes("got enough room to carry")
        |> mes("this many Apples. You might")
        |> mes("want to free up your inventory")
        |> mes("space.")
        |> close()

      true ->
        ctx
        |> pay_zeny(price)
        |> give_item(512, amount)
        |> mes("[Meltz]")
        |> mes("Thanks for stopping by")
        |> mes("my shop. I hope you enjoy")
        |> mes("the flavor of these Apples~!")
        |> close()
    end
  end

  defp make_apple_juice(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Meltz]")
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
      |> mes("[Meltz]")
      |> mes("I'm sorry, but you don't")
      |> mes("have enough materials to")
      |> mes("create a bottle of Apple Juice.")
      |> mes("Remember, I need 3 Apples")
      |> mes("and 1 Empty Bottle to do it.")
      |> close()
    else
      ctx
      |> mes("[Meltz]")
      |> mes("Thank you, please wait.")
      |> next()
      |> mes("^3355FF*Grind* *Grind*")
      |> mes("*Grind* *Grind*")
      |> mes("*Clang...!*^000000")
      |> next()
      |> delitem(512, 3)
      |> delitem(713, 1)
      |> give_item(531, 1)
      |> mes("[Meltz]")
      |> mes("There you go~")
      |> mes("Please come again.")
      |> close()
    end
  end

  defp inventory_full(ctx) do
    ctx
    |> mes("- Wait a minute !! -")
    |> mes("- Currently you're carrying -")
    |> mes("- too many items with you. -")
    |> mes("- Please try again -")
    |> mes("- after you lose some weight. -")
    |> close()
  end

  defp farewell(ctx) do
    ctx
    |> mes("[Meltz]")
    |> mes("Thanks for stopping")
    |> mes("by my shop. Farewell!")
    |> mes("Come by anytime when")
    |> mes("you feel like having an")
    |> mes("Apple to snack on~")
    |> close()
  end
end
