defmodule Aesir.ZoneServer.Content.Npc.Cities.Aldebaran.KafraEmployee88161 do
  @moduledoc """
  Runs high-value lotteries using Special Reserve Points.

  ## Behavior

  - Offers lottery entries costing 5,000, 7,000, or 10,000 points.
  - Deducts the selected entry cost before drawing one of four prize tiers.
  - Requires sufficient free carrying capacity before accepting an entry.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
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
        x: 88,
        y: 161,
        dir: 3,
        sprite: 115,
        name: "Kafra Employee",
        scope: :shared,
        unique_name: "Kafra Employee#reserve2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Kafra Employee]")
      |> mes("Welcome~ #{char_name(ctx, 0)}.")
      |> mes("Currently, we, Kafra Center is having a special event for our customers.")
      |> next()
      |> mes("[Kafra Employee]")
      |> mes(
        "You can get free gifts by using special reserve points with ^FF0000Special Kafra ^529DFFGift Event!^000000"
      )
      |> mes("Kafra Corporation added new gifts in this event.")
      |> next()
      |> mes("[Kafra Employee]")
      |> mes("Do you want to use your points?")
      |> next()
      |> select(["Yes, I do", "Maybe in next time"])

    if choice == 1 do
      offer_lotteries(ctx)
    else
      finish(ctx)
    end
  end

  defp offer_lotteries(ctx) do
    ctx = mes(ctx, "[Kafra Employee]")

    if get_char_var(ctx, :MaxWeight, 0) - weight(ctx) < 11_000 do
      insufficient_free_weight(ctx)
    else
      choose_lottery(ctx)
    end
  end

  defp choose_lottery(ctx) do
    points = get_char_var(ctx, :RESRVPTS, 0)
    costs = [0, 5000, 7000, 10_000]

    {ctx, choice} =
      ctx
      |> mes("Your special reserve points are ^FF0000#{points}^000000~")
      |> mes("Choose a category to test your luck.")
      |> next()
      |> select([
        "5000p = 1st Lottery Chance!",
        "7000p = 2nd Lottery Chance!",
        "10000p = 3rd Lottery Chance!",
        "Cancel"
      ])

    if choice == 4 do
      finish(ctx)
    else
      enter_lottery(ctx, points, Enum.at(costs, choice, 0), choice)
    end
  end

  defp enter_lottery(ctx, points, cost, choice) do
    ctx = mes(ctx, "[Kafra Employee]")

    if points < cost do
      ctx
      |> mes("I'm sorry~ dear~")
      |> mes(
        "You can't choose the selected chance because you do not have enough special reserve points."
      )
      |> mes("Please check your special reserve points and choose another one~")
      |> close()
    else
      draw_lottery(ctx, points - cost, choice)
    end
  end

  defp draw_lottery(ctx, remaining_points, choice) do
    ctx =
      ctx
      |> set_char_var(:RESRVPTS, remaining_points)
      |> mes("^0000FF#{num_suffix(ctx, choice)} Lottery Chance!!^000000")
      |> next()
      |> mes("[Kafra Employee]")
      |> mes("It's time to try your luck.")
      |> next()
      |> mes("[Kafra Employee]")
      |> mes("Let's see how lucky you are. Now! Get ready!")
      |> next()

    sound = Enum.random(1..3)

    ctx =
      ctx
      |> lottery_sound(sound)
      |> next()
      |> mes("[Kafra Employee]")
      |> mes("Something has come out~ Let's see what you got~")
      |> mes("G~ U~ E~ S~ S~ W~ H~ A~ T~")
      |> next()
      |> mes("[Kafra Employee]")
      |> mes("^FF0000Oh, my goodness! It's!!^000000")
      |> next()
      |> mes("[Kafra Employee]")

    prize = Enum.random(1..20)

    ctx
    |> award_prize(choice, prize)
    |> mes("Congratulations~~")
    |> close()
  end

  defp lottery_sound(ctx, 1), do: mes(ctx, "'Drrrrrr~ Drrrrrr~'")
  defp lottery_sound(ctx, 2), do: mes(ctx, "'Rrrrrrr...'")
  defp lottery_sound(ctx, 3), do: mes(ctx, "'Boing.. Boing.. Clink!'")

  defp award_prize(ctx, 1, prize) do
    cond do
      prize < 15 ->
        ctx
        |> give_item(501, 150)
        |> mes("What a pity!")
        |> mes("You got the 4th prize!!")
        |> mes("The prize is ^00FF00150 Red Potions~^000000")
        |> next()
        |> mes("[Kafra Employee]")
        |> mes("Whoa~ 150 potions! It is enough to share with your friends~")

      prize < 18 ->
        ctx
        |> give_item(645, 15)
        |> mes("The 3rd~~")
        |> mes("The 3rd prize!")
        |> mes("The prize is ^00FF0015 Concentration Potion~^000000")
        |> next()
        |> mes("[Kafra Employee]")
        |> mes("We always use this when we need to concentrate on something.")
        |> mes("However, overdose is not good for your body~")

      prize < 20 ->
        ctx
        |> give_item(505, 3)
        |> mes("The 2nd~~")
        |> mes("The 3rd prize~~")
        |> mes("The prize is ^00FF003 Blue Potions~^000000")
        |> next()
        |> mes("[Kafra Employee]")
        |> mes("Try these when your spiritual power is low~")

      prize == 20 ->
        ctx
        |> give_item(608, 1)
        |> mes("Whoa~!! The first... The First!!!")
        |> mes("Congratulations~~ You got the 1st prize~")
        |> mes("The prize is ^00FF001 Yggdrasil Seed~^000000")
        |> next()
        |> mes("[Kafra Employee]")
        |> mes("I guess you spent entire luck for this lottery chance~")

      true ->
        ctx
    end
  end

  defp award_prize(ctx, 2, prize) do
    cond do
      prize < 15 ->
        ctx
        |> give_item(504, 10)
        |> mes("What a pity!")
        |> mes("You got the 4th prize!!")
        |> mes("The prize is ^00FF0010 White Potions~^000000")
        |> next()
        |> mes("[Kafra Employee]")
        |> mes("The greatest among potions! Use it before you fall into faint~")

      prize < 18 ->
        ctx
        |> give_item(656, 15)
        |> mes("The 3rd~~")
        |> mes("The 3rd prize!")
        |> mes("The prize is ^00FF0015 Awakening Potions~^000000")
        |> next()
        |> mes("[Kafra Employee]")
        |> mes("An awakening potion is better than a concentration potion!")
        |> mes("Overdose is not good for your body~")

      prize < 20 ->
        ctx
        |> give_item(657, 10)
        |> mes("The 2nd~~")
        |> mes("The 3rd prize~~")
        |> mes("The prize is ^00FF0010 Berserk Potions~^000000")
        |> next()
        |> mes("[Kafra Employee]")
        |> mes("Overdose may cause madness~")

      prize == 20 ->
        ctx
        |> give_item(608, 1)
        |> give_item(607, 1)
        |> mes("Whoa~!! The first... The First!!!")
        |> mes("Congratulations~~ You got the 1st prize~")
        |> mes("The prize is ^00FF001 Yggdrasilberry~^000000")
        |> mes("The prize is ^00FF001 Yggdrasil Seed~^000000")
        |> next()
        |> mes("[Kafra Employee]")
        |> mes("I guess you spent entire luck for this lottery chance~")

      true ->
        ctx
    end
  end

  defp award_prize(ctx, 3, prize) do
    cond do
      prize < 15 ->
        ctx
        |> give_item(504, 30)
        |> mes("What a pity!")
        |> mes("You got the 4th prize!!")
        |> mes("The prize is ^00FF0030 White Potions~^000000")
        |> next()
        |> mes("[Kafra Employee]")
        |> mes("The greatest among potions! Use it before you fall into faint~")

      prize < 18 ->
        ctx
        |> give_item(505, 10)
        |> mes("The 3rd~~")
        |> mes("The 3rd prize!")
        |> mes("The prize is ^00FF0010 Blue Potions~^000000")
        |> next()
        |> mes("[Kafra Employee]")
        |> mes("Try these when your spiritual power is low~")

      prize < 20 ->
        ctx
        |> give_item(608, 1)
        |> give_item(526, 10)
        |> mes("The 2nd~~")
        |> mes("The 3rd prize~~")
        |> mes("The prize is ^00FF001 Yggdrasil Seed~^000000")
        |> mes("The prize is ^00FF0010 Royal Jellies~^000000")
        |> next()
        |> mes("[Kafra Employee]")
        |> mes("What a gift set~")
        |> mes("These are very healthy food so ~")

      prize == 20 ->
        ctx
        |> give_item(607, 3)
        |> give_item(608, 2)
        |> mes("Whoa~!! The first... The First!!!")
        |> mes("Congratulations~~ You got the 1st prize~")
        |> mes("The prize is ^00FF003 Yggdrasilberries~^000000")
        |> mes("The prize is ^00FF002 Yggdrasil Seeds~^000000")
        |> next()
        |> mes("[Kafra Employee]")
        |> mes("I guess you spent entire luck for this lottery chance~")

      true ->
        ctx
    end
  end

  defp award_prize(ctx, _choice, _prize), do: ctx

  defp insufficient_free_weight(ctx) do
    ctx
    |> mes("....Oh dear... What are you carrying so many things...?")
    |> mes("I don't think you can keep the received items~")
    |> next()
    |> mes("[Kafra Employee]")
    |> mes("I'm sorry~ but~")
    |> mes(
      "Please, visit Kafra warehouse and store your items until you have free space of ^0000FF1100^000000 and come back."
    )
    |> mes("I apologize for inconvenience~")
    |> close()
  end

  defp finish(ctx) do
    ctx
    |> mes("[Kafra Employee]")
    |> mes("No Problem~")
    |> mes("Collect more~ and more~ special reserve points~")
    |> mes("Thank you for using Kafra Corporation's services~~")
    |> close()
  end
end
