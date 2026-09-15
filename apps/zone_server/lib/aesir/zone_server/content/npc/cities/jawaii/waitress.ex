defmodule Aesir.ZoneServer.Content.Npc.Cities.Jawaii.Waitress do
  @moduledoc """
  Serves married patrons and challenges unmarried visitors at the Jawaii Tavern.

  ## Behavior

  - Sells Meat or a Yellow Potion for 1,000 zeny after checking carrying capacity.
  - Directs patrons to the bar and responds differently to unmarried visitors.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - DNett123
    - L0ne_w0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "jawaii_in",
        x: 15,
        y: 104,
        dir: 0,
        sprite: 80,
        name: "Waitress",
        scope: :shared,
        unique_name: "Waitress#jawaii"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{1201, 1}]) == 0 -> inventory_full(ctx)
      Rathena.truthy?(getpartnerid(ctx)) -> serve_married_patron(ctx)
      true -> challenge_single_patron(ctx)
    end
  end

  defp inventory_full(ctx) do
    ctx
    |> mes("^3355FF * Wait a minute! *")
    |> mes(
      "You're carrying too many items with you right now. Please store some of your things into Kafra Storage and try again.^000000"
    )
    |> close()
  end

  defp serve_married_patron(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Waitress]")
      |> mes("Hello,")
      |> mes("how can I help you?")
      |> emotion(:chup)
      |> next()
      |> select(["Give me food.", "Bring me drink.", "Where's the bar?"])

    case choice do
      1 -> offer_food(ctx)
      2 -> offer_drink(ctx)
      3 -> point_to_bar(ctx)
      _ -> challenge_single_patron(ctx)
    end
  end

  defp offer_food(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Waitress]")
      |> mes("You can have")
      |> mes("1 Meat for 1,000 zeny.")
      |> mes("Would you like one?")
      |> next()
      |> select(["Yes.", "Wha--! It's too expensive!"])

    if choice == 1 do
      sell_food(ctx)
    else
      offer_more_help(ctx)
    end
  end

  defp sell_food(ctx) do
    ctx = mes(ctx, "[Waitress]")

    if zeny(ctx) > 999 do
      ctx
      |> pay_zeny(1000)
      |> give_item(517, 1)
      |> mes("There you go~")
      |> mes("Enjoy your meal~!")
      |> close()
    else
      ctx |> mes("I'm sorry but...") |> mes("This isn't enough money...") |> close()
    end
  end

  defp offer_drink(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Waitress]")
      |> mes("You can have")
      |> mes("1 Yellow Potion")
      |> mes("at 1,000 zeny.")
      |> mes("Would you like one?")
      |> next()
      |> select(["Yes.", "Wha--! It's too expensive!"])

    if choice == 1 do
      sell_drink(ctx)
    else
      offer_more_help(ctx)
    end
  end

  defp sell_drink(ctx) do
    ctx = mes(ctx, "[Waitress]")

    if zeny(ctx) > 999 do
      ctx
      |> pay_zeny(1000)
      |> give_item(503, 1)
      |> mes("There you go~")
      |> mes("Enjoy your meal~!")
      |> close()
    else
      ctx |> mes("I am sorry but you don't have enough money?!") |> close()
    end
  end

  defp offer_more_help(ctx) do
    ctx
    |> mes("[Waitress]")
    |> mes("If you")
    |> mes("need anything,")
    |> mes("please let me know.")
    |> close()
  end

  defp point_to_bar(ctx) do
    ctx
    |> mes("[Waitress]")
    |> mes("Oh, just go toward the center")
    |> mes("of the tavern. I hope you have")
    |> mes("a good time, but be careful and")
    |> mes("don't drink too much! Have fun!")
    |> close()
  end

  defp challenge_single_patron(ctx) do
    {ctx, choice} =
      ctx
      |> emotion(:huk)
      |> mes("[Waitress]")
      |> mes("Hey, hey...!")
      |> mes("I have no idea")
      |> mes("why you're here...")
      |> next()
      |> mes("[Waitress]")
      |> mes(
        "But we don't tolerate singles messing around with the happily married couples around here."
      )
      |> mes("Just have your drink")
      |> mes("and then leave!")
      |> next()
      |> select(["I'm a member of Single Army!!", "...I just wanted to congratulate them..."])

    if choice == 1 do
      rebuke_single_army(ctx)
    else
      apologize(ctx)
    end
  end

  defp rebuke_single_army(ctx) do
    ctx
    |> mes("[Employee]")
    |> mes("Yeah, right.")
    |> mes("Knock it off already.")
    |> mes("Why can't you be happy")
    |> mes("for other people?!")
    |> next()
    |> mes("[Employee]")
    |> mes("^666666*Sigh*^000000")
    |> mes("You will be welcome")
    |> mes("here when you visit")
    |> mes("with your partner, okay?")
    |> close()
  end

  defp apologize(ctx) do
    ctx
    |> mes("[Employee]")
    |> mes("Huh? Did you just")
    |> mes("say you wanted to")
    |> mes("congratulate them?")
    |> mes("Oh, you must be close")
    |> mes("friends with one")
    |> mes("of the couples...")
    |> next()
    |> mes("[Employee]")
    |> mes("I'm sorry!")
    |> mes("Let me apologize")
    |> mes("for my rudeness.")
    |> mes("I hope you have")
    |> mes("a good time.")
    |> close()
  end
end
