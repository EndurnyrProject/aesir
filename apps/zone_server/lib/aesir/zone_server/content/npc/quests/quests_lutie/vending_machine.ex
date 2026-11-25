defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLutie.VendingMachine do
  @moduledoc """
  Titicupe's snowman vending machine, which turns piles of materials into headgear.

  ## Behavior

  - Explains that refines and cards on inserted items are lost.
  - Exchanges materials for a Raccoon Hat, Spore Hat, Wonder Nutshell, Rainbow Eggshell, Blush,
    Chef Hat, Candle or Cake Hat.
  - Rejects the exchange when any required material is missing.

  ## Credits

  - Original from rAthena, authors and Contributors
    - TonyMan
    - Samuray22
    - Lupus
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "xmas", x: 115, y: 297, dir: 4, sprite: 111, name: "Vending Machine", scope: :shared}
    ]

  @insert_message "^3355FFYou gingerly place the items into the snowman's mouth.^000000"

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Audi]")
      |> mes(
        "^555555Exciting item vending machine. Invented by great Titicupe. Select the desired item and place required items into snowmouth receptacle.^000000"
      )
      |> next()
      |> select([
        "^FF3355Notice (Must Read)^000000",
        "Raccoon Hat",
        "Spore Hat",
        "Wonder Nutshell",
        "Rainbow Eggshell",
        "Blush",
        "Chef Hat",
        "Candle",
        "Cake Hat",
        "Cancel"
      ])

    case choice do
      1 -> notice(ctx)
      2 -> raccoon_hat(ctx)
      3 -> spore_hat(ctx)
      4 -> wonder_nutshell(ctx)
      5 -> rainbow_eggshell(ctx)
      6 -> blush(ctx)
      7 -> chef_hat(ctx)
      8 -> candle(ctx)
      9 -> cake_hat(ctx)
      10 -> cancel(ctx)
      _ -> ctx
    end
  end

  defp notice(ctx) do
    ctx
    |> mes("[Audi]")
    |> mes("Hi~ !")
    |> mes(
      "I need to tell you one important thing. This vending machine is not equipped to differentiate between special items and ordinary items."
    )
    |> next()
    |> mes("[Audi]")
    |> mes(
      "So if you use an item that has been ^FF3355upgraded, or has a card compounded to it^000000, any cards or upgrades will be lost in creating the new item."
    )
    |> next()
    |> mes("[Audi]")
    |> mes(
      "So when you try to exchange and generate items, please put all the valuable items you won't be using into the Kafra Storage."
    )
    |> next()
    |> mes("[Audi]")
    |> mes(
      "Please keep this in mind because this Vending Machine does not provide any returns, refunds or exchanges."
    )
    |> next()
    |> mes("[Audi]")
    |> mes("Have a great time!")
    |> mes("Thank you!")
    |> close()
  end

  defp raccoon_hat(ctx) do
    exchange(ctx, [{2213, 1}, {1036, 20}, {7012, 200}, {7065, 300}], fn ctx ->
      ctx
      |> emotion(:o)
      |> machine_noise(["*Kapang!*^000000"])
      |> give_item(5033, 1)
      |> next()
      |> mes("[Audi]")
      |> thank_you()
      |> close()
    end)
  end

  defp spore_hat(ctx) do
    exchange(ctx, [{7033, 850}, {7068, 300}, {1015, 1}], fn ctx ->
      ctx
      |> emotion(:o)
      |> machine_noise(["*Kapang!*", "*Wek Wek*^000000"])
      |> give_item(5029, 1)
      |> next()
      |> thank_you()
      |> close()
    end)
  end

  defp wonder_nutshell(ctx) do
    exchange(ctx, [{5037, 1}, {7064, 500}], fn ctx ->
      ctx
      |> machine_noise(["*Kapang!*", "*BeepBoopBeepBoop*", "*Beeeeeeoop*^000000"])
      |> emotion(:o)
      |> give_item(5050, 1)
      |> next()
      |> mes("[Audi]")
      |> thank_you()
      |> close()
    end)
  end

  defp rainbow_eggshell(ctx) do
    exchange(ctx, [{5015, 1}, {978, 1}, {7030, 50}], fn ctx ->
      ctx
      |> emotion(:o)
      |> machine_noise(["*OoooEeeeeeee~*^000000"])
      |> give_item(5039, 1)
      |> next()
      |> mes("[Audi]")
      |> thank_you()
      |> close()
    end)
  end

  defp blush(ctx) do
    exchange(
      ctx,
      [{7047, 100}],
      fn ctx ->
        ctx
        |> emotion(:o)
        |> machine_noise(["*Kapang!*", "*ChoopChoop*", "*Chaaawah!*^000000"])
        |> give_item(5040, 1)
        |> mes("[Audi]")
        |> thank_you()
        |> next()
        |> mes("[Titicupe]")
        |> mes(
          "You got Blush?! Huh. I guess you really like looking glamourous~! I bet you really appreciate my genius now, huh?"
        )
        |> close()
      end,
      "^3355FFYou gingerly place all 100 Aprons into the snowman's mouth.^000000"
    )
  end

  defp chef_hat(ctx) do
    exchange(ctx, [{539, 120}, {982, 1}, {949, 330}, {1036, 450}], fn ctx ->
      ctx
      |> emotion(:o)
      |> machine_noise(["*Kapang!*", "*Muuuuuuugeeee*^000000"])
      |> give_item(5026, 1)
      |> next()
      |> mes("[Audi]")
      |> thank_you()
      |> close()
    end)
  end

  defp candle(ctx) do
    exchange(ctx, [{2279, 1}, {7035, 50}, {526, 100}], fn ctx ->
      ctx
      |> emotion(:o)
      |> machine_noise(["*Kapang!*^000000"])
      |> give_item(5028, 1)
      |> next()
      |> mes("[Audi]")
      |> thank_you()
      |> close()
    end)
  end

  defp cake_hat(ctx) do
    exchange(ctx, [{529, 10}, {530, 5}, {538, 15}, {539, 20}, {999, 10}], fn ctx ->
      ctx
      |> emotion(:o)
      |> machine_noise(["*Kapang!*^000000"])
      |> give_item(5024, 1)
      |> next()
      |> mes("[Audi]")
      |> thank_you()
      |> close()
    end)
  end

  defp cancel(ctx) do
    ctx
    |> mes("[Audi]")
    |> mes("^555555Please...")
    |> mes("Insert...")
    |> mes("Items.^000000")
    |> close()
  end

  defp exchange(ctx, materials, dispense, message \\ @insert_message) do
    if Enum.all?(materials, fn {item, amount} -> count_item(ctx, item) >= amount end) do
      ctx
      |> mes(message)
      |> next()
      |> remove_materials(materials)
      |> dispense.()
    else
      incorrect_items(ctx)
    end
  end

  defp remove_materials(ctx, materials) do
    Enum.reduce(materials, ctx, fn {item, amount}, ctx -> delitem(ctx, item, amount) end)
  end

  defp machine_noise(ctx, finish) do
    ["^3355FF*Vroooooom~~*", "*Bzzzzzt*", "*choogachooga*" | finish]
    |> Enum.reduce(ctx, &mes(&2, &1))
  end

  defp thank_you(ctx) do
    ctx
    |> mes("^555555Thank you for coming by.")
    |> mes("Please come again!")
    |> mes("Oh, and tell a friend!^000000")
  end

  defp incorrect_items(ctx) do
    ctx
    |> emotion(:x)
    |> mes("[Audi]")
    |> mes("^555555Error Error!")
    |> mes("Incorrect items!^000000")
    |> next()
    |> mes("[Titicupe]")
    |> mes("I...")
    |> mes("I guess a lot of people would do anything to get their hands on some Blush.")
    |> close()
  end
end
