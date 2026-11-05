defmodule Aesir.ZoneServer.Content.Npc.Quests.JuiceMaker.MarxHansen do
  @moduledoc """
  Marx Hansen, the Payon merchant who blends fruit, an Empty Bottle and a small fee into fruit
  juice for players who have heard of his trade.

  ## Behavior

  - Players carrying too much weight are turned away before anything else.
  - Until the juice quest is learned he only talks about the history of fruit processing.
  - Afterwards he explains the trade, or blends fruit into Apple, Banana, Carrot and Grape
    Juice for 3 zeny and an Empty Bottle each, either as many as the player can afford or a
    chosen amount of up to 100 bottles.
  - A shortfall of fruit, Empty Bottles or zeny ends the trade with nothing spent.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "payon_in03",
        x: 188,
        y: 146,
        dir: 5,
        sprite: 86,
        name: "Marx Hansen",
        scope: :shared,
        unique_name: "Marx Hansen#juice"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @speaker "[Merchant Marx Hansen]"
  @empty_bottle 713
  @zeny_per_bottle 3

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{1201, 1}]) == 0 -> encumbered(ctx)
      Rathena.truthy?(:erlang.band(get_char_var(ctx, :MISC_QUEST, 0), 1)) -> processing_menu(ctx)
      true -> first_visit_menu(ctx)
    end
  end

  defp encumbered(ctx) do
    ctx
    |> mes("- Wait a moment! -")
    |> mes("- Currently you're carrying -")
    |> mes("- too many items with you. -")
    |> mes("- Please come back later -")
    |> mes("- after you put some items into kafra storage. -")
    |> close()
  end

  defp processing_menu(ctx) do
    {ctx, choice} =
      ctx
      |> mes(@speaker)
      |> mes("Welcome.")
      |> mes("Did you come to")
      |> mes("process fruits as well?")
      |> next()
      |> select([
        "Make Juice.",
        "Talk and get information about fruit processing.",
        "Cancel."
      ])

    case choice do
      1 -> choose_fruit(ctx)
      2 -> explain_processing(ctx)
      3 -> send_off(ctx, "visit")
      _ -> ctx
    end
  end

  defp choose_fruit(ctx) do
    {ctx, choice} =
      ctx
      |> mes(@speaker)
      |> mes("What kind of fruit juice would you like to make?")
      |> next()
      |> select(["Apple Juice", "Banana Juice", "Carrot Juice", "Grape Juice", "Cancel"])

    case choice do
      1 -> take_order(ctx, 512, 531)
      2 -> take_order(ctx, 513, 532)
      3 -> take_order(ctx, 515, 534)
      4 -> take_order(ctx, 514, 533)
      5 -> say_goodbye(ctx, "See you next time.")
      _ -> ctx
    end
  end

  defp take_order(ctx, fruit, juice) do
    ctx
    |> set_local(:fruit, fruit)
    |> set_local(:juice, juice)
    |> check_materials()
  end

  defp check_materials(ctx) do
    fruit = get_local(ctx, :fruit, 0)

    if count_item(ctx, fruit) == 0 or count_item(ctx, @empty_bottle) == 0 or
         zeny(ctx) < @zeny_per_bottle do
      missing_materials(ctx)
    else
      ask_quantity(ctx)
    end
  end

  defp missing_materials(ctx) do
    fruit = get_local(ctx, :fruit, 0)
    juice = get_local(ctx, :juice, 0)

    ctx
    |> mes(@speaker)
    |> mes("Oh no...")
    |> mes(
      "You don't have all the necessary materials. To make #{Rathena.getitemname(juice)}, I need 1 #{Rathena.getitemname(fruit)} and 1 Empty Bottle. I will also need a 3 zeny fee."
    )
    |> next()
    |> mes(@speaker)
    |> mes(
      "When you have prepared everything, I will blend the fruit to give you delicious juice."
    )
    |> close()
  end

  defp ask_quantity(ctx) do
    {ctx, choice} =
      ctx
      |> mes(@speaker)
      |> mes("How many would you like?")
      |> next()
      |> select(["As many as I can.", "I want a certain amount.", "Cancel."])

    case choice do
      1 -> take_everything(ctx)
      2 -> ask_amount(ctx)
      3 -> say_goodbye(ctx, "Come again.")
      _ -> ctx
    end
  end

  defp take_everything(ctx) do
    fruit = get_local(ctx, :fruit, 0)

    make =
      Enum.min([
        count_item(ctx, fruit),
        count_item(ctx, @empty_bottle),
        div(zeny(ctx), @zeny_per_bottle)
      ])

    ctx
    |> set_local(:make, make)
    |> blend()
  end

  defp ask_amount(ctx) do
    ctx
    |> mes(@speaker)
    |> mes(
      "Choose a number less than 100. If you don't want to, put '0'. You can make up to #{count_item(ctx, get_local(ctx, :fruit, 0))} bottles of juice."
    )
    |> next()
    |> enter_amount()
  end

  defp enter_amount(ctx) do
    {ctx, amount} = input(ctx, :int)

    cond do
      amount == 0 -> say_goodbye(ctx, "Come again.")
      amount > 100 -> retry_amount(ctx)
      true -> ctx |> set_local(:make, amount) |> blend()
    end
  end

  defp retry_amount(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("More than 100 bottles is impossible. Choose a different amount.")
    |> next()
    |> enter_amount()
  end

  defp blend(ctx) do
    fruit = get_local(ctx, :fruit, 0)
    make = get_local(ctx, :make, 0)
    total_zeny = @zeny_per_bottle * make

    if count_item(ctx, fruit) < make or count_item(ctx, @empty_bottle) < make or
         zeny(ctx) < total_zeny do
      cannot_help(ctx)
    else
      sell_juice(ctx, fruit, make, total_zeny)
    end
  end

  defp cannot_help(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("Oh no...")
    |> mes(
      "You don't have all the necessary materials. I can't help a situation like this. I guess you collect what you need."
    )
    |> close()
  end

  defp sell_juice(ctx, fruit, make, total_zeny) do
    juice = get_local(ctx, :juice, 0)

    ctx
    |> delitem(fruit, make)
    |> delitem(@empty_bottle, make)
    |> pay_zeny(total_zeny)
    |> give_item(juice, make)
    |> mes(@speaker)
    |> mes(
      "Here you go! Fresh and delicious juice as promised. It should be very refreshing and palatable."
    )
    |> next()
    |> mes(@speaker)
    |> mes("Well then...")
    |> mes("Come again.")
    |> close()
  end

  defp explain_processing(ctx) do
    ctx
    |> processing_history()
    |> next()
    |> mes("# Fruit Juice Information #")
    |> mes("^CC4E5C- Apple Juice -^000000")
    |> mes("Apple x 1 ea, Empty Bottle x 1 ea, 3 zeny.")
    |> mes("^E3CF57- Banana Juice -^000000")
    |> mes("Banana x 1 ea, Empty Bottle x 1 ea, 3 zeny.")
    |> mes("^ED9121- Carrot Juice -^000000")
    |> mes("Carrot x 1 ea, Empty Bottle x 1 ea, 3 zeny.")
    |> mes("^CC00FF- Grape Juice -^000000")
    |> mes("Grape x 1 ea, Empty Bottle x 1 ea, 3 zeny.")
    |> close()
  end

  defp processing_history(ctx) do
    ctx
    |> mes(@speaker)
    |> mes(
      "Before humans were able to develop such vast societies, they gathered fruit from trees to survive. Fruits may have been nature's blessing that allowed us to exist in the world."
    )
    |> next()
    |> mes(@speaker)
    |> mes(
      "Since life became so prosperous, the younger generation seems not to eat fruit any more. So, I started thinking of ways to make fruit easier to eat."
    )
    |> next()
    |> mes(@speaker)
    |> mes(
      "I realized that when you make fruit juice, it's more convenient to eat and has a much better taste."
    )
  end

  defp first_visit_menu(ctx) do
    {ctx, choice} =
      ctx
      |> mes(@speaker)
      |> mes("Welcome.")
      |> mes("How may I help you?")
      |> next()
      |> select(["Talk", "Cancel"])

    if choice == 1 do
      ctx |> processing_history() |> close()
    else
      send_off(ctx, "vist")
    end
  end

  defp say_goodbye(ctx, farewell) do
    ctx
    |> mes(@speaker)
    |> mes("Well then...")
    |> mes(farewell)
    |> close()
  end

  # The reference script misspells "visit" in the page shown to players who have not
  # learned the trade yet; both spellings keep their own branch.
  defp send_off(ctx, verb) do
    ctx
    |> mes(@speaker)
    |> mes("Hey!")
    |> mes("If you #{verb}")
    |> mes("somebody, talk to them!")
    |> close()
  end
end
