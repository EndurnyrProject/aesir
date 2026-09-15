defmodule Aesir.ZoneServer.Content.Npc.Cities.Aldebaran.KafraEmployee do
  @moduledoc """
  Exchanges Special Reserve Points for supplies or lottery prizes.

  ## Behavior

  - Requires sufficient inventory capacity before offering rewards.
  - Exchanges 100 to 2,800 points for Potatoes or Red Potions.
  - Runs one of two lotteries for 1,000 or 3,000 points and awards a random prize.

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
        x: 79,
        y: 161,
        dir: 7,
        sprite: 115,
        name: "Kafra Employee",
        scope: :shared,
        unique_name: "Kafra Employee#reserve1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if checkweight(ctx, [{1201, 1}]) == 0 do
      inventory_full(ctx)
    else
      begin_exchange(ctx)
    end
  end

  defp begin_exchange(ctx) do
    ctx =
      ctx
      |> mes("[Kafra Employee]")
      |> mes("Welcome, #{char_name(ctx, 0)}~")
      |> mes("Here, you can exchange")
      |> mes("the Special Reserve Points")
      |> mes("you've earned by using the")
      |> mes("Kafra Services for some")
      |> mes("neat and useful prizes~")
      |> next()
      |> mes("[Kafra Employee]")
      |> mes(
        "Please remember that each window has a different amount of special reserve points you can Use"
      )
      |> mes("You can use ^7D0781from 100p to 3000p^000000 in here.")
      |> next()
      |> mes("[Kafra Employee]")

    if get_char_var(ctx, :MaxWeight, 0) - weight(ctx) < 11_000 do
      insufficient_free_weight(ctx)
    else
      choose_reward(ctx)
    end
  end

  defp choose_reward(ctx) do
    total = get_char_var(ctx, :RESRVPTS, 0)

    reward_table = [
      516,
      100,
      7,
      200,
      15,
      300,
      25,
      400,
      35,
      500,
      50,
      600,
      60,
      700,
      75,
      800,
      85,
      900,
      100,
      1000
    ]

    {ctx, choice} =
      ctx
      |> mes("Let's see...")
      |> mes("#{char_name(ctx, 0)}...")
      |> mes("Ah, you have a total of")
      |> mes("#{total} Special Reserve Points.")
      |> mes("Now what you would like")
      |> mes("to exchange them for?")
      |> next()
      |> select([
        "100 = Potato 7 ea",
        "200 = Potato 15 ea",
        "300 = Potato 25 ea",
        "400 = Potato 35 ea",
        "500 = Potato 50 ea",
        "600 = Potato 60 ea",
        "700 = Potato 75 ea",
        "800 = Potato 85 ea",
        "900 = Potato 100 ea",
        "1000 = 1st Lottery Chance!",
        "Next Articles",
        "Cancel"
      ])

    if choice == 11 do
      choose_second_page(ctx, total)
    else
      redeem_or_finish(ctx, total, reward_table, choice, false)
    end
  end

  defp choose_second_page(ctx, total) do
    reward_table = [
      501,
      1100,
      7,
      1300,
      15,
      1500,
      25,
      1700,
      35,
      1900,
      50,
      2100,
      60,
      2300,
      75,
      2500,
      85,
      2800,
      100,
      3000
    ]

    {ctx, choice} =
      select(
        ctx,
        String.split(
          "1100 = Red Potion 7 ea:1300 = Red Potion 15 ea:1500 = Red Potion 25 ea:1700 = Red Potion 35 ea:1900 = Red Potion 50 ea:2100 = Red Potion 60 ea:2300 = Red Potion 75 ea:2500 = Red Potion 85 ea:2800 = Red Potion 100 ea:3000 = 2nd Lotery Chance!::Cancel",
          ":"
        )
      )

    redeem_or_finish(ctx, total, reward_table, choice, true)
  end

  defp redeem_or_finish(ctx, _total, _reward_table, 12, _second_page), do: finish(ctx)

  defp redeem_or_finish(ctx, total, reward_table, choice, second_page) do
    point_cost = Enum.at(reward_table, choice * 2 - 1, 0)
    quantity = Enum.at(reward_table, choice * 2, 0)

    if total < point_cost do
      insufficient_points(ctx, point_cost - total)
    else
      remaining = total - point_cost

      {ctx, confirmation} =
        ctx
        |> mes("[Kafra Employee]")
        |> mes("After receiving this")
        |> mes("reward, you'll have")
        |> mes("^AC0000#{remaining}^000000 Special Reserve")
        |> mes("Points left. Would you")
        |> mes("like to redeem your")
        |> mes("points for this reward?")
        |> next()
        |> select(["Exchange.", "Cancel"])

      if confirmation == 1 do
        ctx
        |> set_char_var(:RESRVPTS, remaining)
        |> grant_reward(reward_table, quantity, choice, second_page)
        |> next()
        |> finish()
      else
        finish(ctx)
      end
    end
  end

  defp grant_reward(ctx, reward_table, quantity, choice, _second_page) when choice < 10 do
    give_item(ctx, Enum.at(reward_table, 0, 0), quantity)
  end

  defp grant_reward(ctx, _reward_table, _quantity, _choice, second_page) do
    ctx =
      ctx
      |> mes("[Kafra Employee]")
      |> announce_lottery(second_page)
      |> next()
      |> mes("[Kafra Employee]")
      |> mes("How many times")
      |> mes("would you like to spin")
      |> mes("the lottery machine?")
      |> mes("You can spin it 1 to 5 times.")
      |> next()

    {ctx, spins} = ask_spin_count(ctx)
    prize = Enum.random(1..20)

    ctx
    |> play_machine(spins)
    |> reveal_prize(second_page, prize)
  end

  defp announce_lottery(ctx, false) do
    ctx
    |> mes("^0000FF1st Lottery Chance!!^000000")
    |> mes("It's time to test out")
    |> mes("your luck. Get ready!")
  end

  defp announce_lottery(ctx, true) do
    ctx
    |> mes("Uh oh...")
    |> mes("It's that time again~")
    |> mes("It's Kafra Lottery Time!")
    |> mes("Let's see how good your")
    |> mes("luck is today. Ready?")
  end

  defp ask_spin_count(ctx) do
    {ctx, input} = input(ctx, :int)
    {invalid, spins} = Rathena.input_int(input, 1, 5)

    if invalid != 0 do
      ctx
      |> mes("[Kafra Employee]")
      |> mes("Excuse me...?")
      |> mes("Please choose")
      |> mes("a number from 1 to 5.")
      |> next()
      |> ask_spin_count()
    else
      {ctx, spins}
    end
  end

  defp play_machine(ctx, spins) do
    Enum.reduce(1..spins, ctx, fn _, ctx ->
      ctx
      |> machine_sound(Enum.random(1..3))
      |> next()
    end)
  end

  defp machine_sound(ctx, 1),
    do: ctx |> mes("^3355FFDrrrrrrrrrrrrrrrrrr...") |> mes("Tuum tuum tuum!^000000")

  defp machine_sound(ctx, 2),
    do: ctx |> mes("^3355FFChika chika chika") |> mes("Shooooooooooom~^000000")

  defp machine_sound(ctx, 3),
    do: ctx |> mes("^3355FFTuk tuk tuk tuk") |> mes("Flaaaaaavaaaaah~^000000")

  defp reveal_prize(ctx, false, prize) do
    ctx =
      ctx
      |> mes("[Kafra Employee]")
      |> mes("Ooh, something")
      |> mes("came out! Let's see")
      |> mes("what you've won~")
      |> mes("Oh goodness, it's...!")
      |> next()
      |> mes("[Kafra Employee]")

    cond do
      prize <= 10 ->
        ctx
        |> give_item(516, 100)
        |> mes("Hm? F-fourth prize?")
        |> mes("You got the 4th prize!!")
        |> mes("Well, that's not too bad.")
        |> mes("That's 100 Potatoes!")
        |> mes("When they're sliced, then fried, they make a great snack when")
        |> mes("drinking with your friends~")

      prize <= 15 ->
        ctx
        |> give_item(602, 4)
        |> mes("It's Third Prize!")
        |> mes("4 Butterfly Wings~")
        |> mes("When you're in trouble,")
        |> mes("just wave one of these")
        |> mes("to take you away...")
        |> mes("To your safe place.")

      prize <= 19 ->
        ctx
        |> give_item(2403, 1)
        |> mes("Second Prize!")
        |> mes("A brand new shiny pair")
        |> mes("of Shoes! Its elegant design")
        |> mes("and durability comes with our")
        |> mes("highest recommendation. We")
        |> mes("hope you enjoy your new shoes~")

      prize == 20 ->
        ctx
        |> give_item(2328, 1)
        |> mes("Whoa...!")
        |> mes("First Prize!")
        |> mes("Your very own")
        |> next()
        |> mes("set of Wooden Mail!")
        |> mes("Today must be your")
        |> mes("lucky day, adventurer!")

      true ->
        ctx
    end
  end

  defp reveal_prize(ctx, true, prize) do
    ctx =
      ctx
      |> mes("[Kafra Employee]")
      |> mes("It looks like")
      |> mes("something came")
      |> mes("out! What could it be?")
      |> mes("Ooh, you just won...")
      |> next()
      |> mes("[Kafra Employee]")

    cond do
      prize <= 10 ->
        ctx
        |> give_item(501, 100)
        |> mes("F-fourth prize...?!")
        |> mes("Boooo! 100 Red Potions.")
        |> mes("Wait.. That's actually pretty")
        |> mes("good! Yaaaaaay~ Now you")
        |> mes("can look like a high roller by")
        |> mes("sharing them with your friends!")

      prize <= 16 ->
        ctx
        |> give_item(2201, 1)
        |> mes("Third Prize!")
        |> mes("Your very own pair")
        |> mes("of suave Sunglasses!")
        |> mes("It'll give you an edge in")
        |> mes("the war of looking cool,")
        |> mes("or when playing poker~")

      prize <= 19 ->
        ctx
        |> give_item(2226, 1)
        |> mes("Second Prize!")
        |> mes("A... Cap? Hmmm,")
        |> mes("these have pretty good")
        |> mes("Defense, but I'm not so")
        |> mes("sure of how fashionable")
        |> mes("this hat is. Oh well...")

      prize == 20 ->
        ctx
        |> give_item(505, 3)
        |> mes("Oh wow...!")
        |> mes("First Prize!")
        |> mes("3 Blue Potions~")
        |> mes("With enough of these,")
        |> mes("you can use your skills")
        |> mes("with a bit more impunity~")

      true ->
        ctx
    end
  end

  defp insufficient_points(ctx, points) do
    ctx
    |> mes("[Kafra Employee]")
    |> mes("I'm sorry, but you don't")
    |> mes("enough Special Reserve")
    |> mes("Points to exchange for this")
    |> mes("reward. You need at least")
    |> mes("^0000FF#{points}^000000 more points.")
    |> close()
  end

  defp inventory_full(ctx) do
    ctx
    |> mes("^3355FFWait a minute! Right now,")
    |> mes("you're carrying too many items")
    |> mes("in your inventory. Please come")
    |> mes("back after storing some of")
    |> mes("your things in Kafra Storage.")
    |> close()
  end

  defp insufficient_free_weight(ctx) do
    ctx
    |> mes("Um, but I don't think")
    |> mes("you're able to carry")
    |> mes("very much right now.")
    |> mes("It looks like you have")
    |> mes("too much stuff inside")
    |> mes("your inventory.")
    |> next()
    |> mes("[Kafra Employee]")
    |> mes("Please put some of")
    |> mes("your things into Kafra")
    |> mes("Storage. To use this")
    |> mes("service, we ask that you")
    |> mes("have about ^FF00001,100^000000 free units")
    |> mes("of weight in your inventory.")
    |> close()
  end

  defp finish(ctx) do
    ctx
    |> mes("[Kafra Employee]")
    |> mes("Alright then. Please")
    |> mes("use our services to")
    |> mes("collect more and more")
    |> mes("Special Reserve Points")
    |> mes("for even better rewards.")
    |> mes("Thank you for your patronage.")
    |> close()
  end
end
