defmodule Aesir.ZoneServer.Content.Npc.Quests.NinjaQuests.Tetsu do
  @moduledoc """
  Murata Tetsu, weapon craftsman of the Fuuma ninja, trades weapons for materials and Zeny.

  ## Behavior

  - Turns any non-Ninja away.
  - Offers four weapons, all of them paid up front with the listed materials and
    Zeny: Fuuma Shuriken Beneki, Daisharin, the slotted Daisharin[4] (which also
    consumes a Daisharin) and Rekka.
  - Names the missing materials or the shortfall in Zeny and ends the
    conversation without charging anything.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Playtester
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/ninja_quests.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "que_ng", x: 22, y: 62, dir: 3, sprite: 709, name: "Tetsu", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @remember "Remember these needed materials, and come back after you're positive you have them all."

  # Each shortage entry is `{cause, lines}`: the line explaining the shortfall
  # followed by the requirement page the reference prints with it.
  #
  # The costs keep the reference's order with it: the Daisharin[4] trade pays the
  # fee before handing over the Fuuma Shuriken Daisharin it is slotted from.
  @beneki %{
    costs: [{:delitem, 999, 50}, {:delitem, 7115, 20}, {:delitem, 984, 5}, {:zeny, 90_000}],
    reward: 13300,
    missing:
      {"It looks like you haven't brought me enough materials to make you a Fuuma Shuriken Beneki.",
       [
         "In order to create a Fuuma shuriken Beneki, I require...",
         "^ff000050 Steel,^000000",
         "^ff000020 Harpy Feathers^000000,",
         "^ff00005 Oridecons^000000,",
         "and ^ff000090,000 Zeny^000000.",
         @remember
       ]},
    short_zeny:
      {"Hmm.. You brought plenty of materials, but you're short on zeny.",
       [
         "In order to create a Fuuma Shuriken Beneki, I require...",
         "^ff000050 Steel,^000000",
         "^ff000020 Harpy Feathers^000000,",
         "^ff00005 Oridecons^000000,",
         "and ^ff000090,000 Zeny^000000.",
         @remember
       ]},
    completed: [
      "Hmm, very well.",
      "Looks like you've brought me the correct amount of materials and Zeny",
      "Here is your completed Fuuma Shuriken Beneki"
    ]
  }

  @daisharin %{
    costs: [{:delitem, 999, 30}, {:delitem, 7301, 100}, {:delitem, 984, 2}, {:zeny, 40_000}],
    reward: 13301,
    missing:
      {"It looks like you haven't brought me enough materials to make you a Fuuma Shuriken Daisharin.",
       [
         "Fuuma Shuriken Daisharin, I require...",
         "^ff000030 Steel^000000, ",
         "^ff0000100 Tassels^000000,",
         "^ff00002 Oridecons^000000,",
         "and ^ff000040,000 Zeny^000000.",
         @remember
       ]},
    short_zeny:
      {"Hmm.. You brought plenty of materials, but you're short on zeny.",
       [
         "Fuuma Shuriken Daisharin, I require...",
         "^ff000030 Steel^000000, ",
         "^ff0000100 Tassels^000000,",
         "^ff00002 Oridecons^000000,",
         "and ^ff000040,000 Zeny^000000.",
         @remember
       ]},
    completed: [
      "Hmm, very well.",
      "Looks like you've brought me the correct amount of materials and Zeny",
      "Here is your completed Fuuma Shuriken Daisharin"
    ]
  }

  @daisharin4 %{
    costs: [
      {:delitem, 733, 20},
      {:delitem, 984, 3},
      {:zeny, 40_000},
      {:delitem, 13301, 1}
    ],
    reward: 13302,
    missing:
      {"It looks like you haven't brought me enough materials to make you a Fuuma Shuriken Daisharin[4].",
       [
         "In order to create a Fuuma Shuriken Daisharin[4], I require...",
         "^ff000020 Cracked Diamonds^000000,",
         "^ff00003 Oridecons^000000,",
         "1 Fuuma Shuriken Daisharin, and",
         "^ff000040,000 Zeny^000000.",
         @remember
       ]},
    short_zeny:
      {"Hmm.. You brought plenty of materials, but you're short on zeny.",
       [
         "In order to create a Fuuma Shuriken Daisharin[4], I require...",
         "^ff000020 Cracked Diamonds^000000,",
         "^ff00003 Oridecons^000000,",
         "1 Fuuma Shuriken Daisharin, and",
         "^ff000040,000 Zeny^000000.",
         @remember
       ]},
    completed: [
      "Hmm, very well.",
      "Looks like you've brought me the correct amount of materials and Zeny",
      "Here is your completed Fuuma Shuriken Daisharin[4]."
    ]
  }

  @rekka %{
    costs: [
      {:delitem, 999, 50},
      {:delitem, 7098, 100},
      {:delitem, 7097, 100},
      {:delitem, 7521, 50},
      {:zeny, 78_000}
    ],
    reward: 13303,
    missing:
      {"It looks like you haven't brought me enough materials to make you a Fuuma Shuriken Rekka.",
       [
         "In order to create a Fuuma Shuriken Rekka, I require...",
         "^ff000050 Steel^000000,^ff000050 Burning Stones^000000,",
         "^ff0000100 Burning Hearts^000000,^ff0000100 Live Coal^000000,",
         "and ^ff000078,000 Zeny^000000",
         @remember
       ]},
    short_zeny:
      {"Hmm.. You brought plenty of materials, but you're short on zeny.",
       [
         "In order to create a Fuuma Shuriken Rekka, I require...",
         "^ff000050 Steel^000000,^ff000050 Burning Stones^000000,",
         "^ff0000100 Burning Hearts^000000,^ff0000100 Live Coal^000000,",
         "and ^ff000078,000 Zeny^000000",
         @remember
       ]},
    completed: [
      "Hmm, very well.",
      "Looks like you've brought me the correct amount of materials and Zeny",
      "Here is your completed Fuuma Shuriken Rekka."
    ]
  }

  @weapon_menu [
    "Fuuma Shuriken Beneki",
    "Fuuma Shuriken Daisharin",
    "Fuuma Shuriken Daisharin[4]",
    "Fuuma Shuriken Rekka",
    "Cancel"
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Tetsu]")

    if Rathena.job_id(base_class(ctx)) == Rathena.job_id(:ninja) do
      choose_weapon(ctx)
    else
      turn_away(ctx)
    end
  end

  defp turn_away(ctx) do
    ctx
    |> mes("I'm The Craftman of Fuuma Ninjas called Tetsu.")
    |> next()
    |> mes("[Tetsu]")
    |> mes(
      "My living is getting tough because of my gambling, so I've started to make weapons part time."
    )
    |> next()
    |> mes("[Tetsu]")
    |> mes("However, it looks like you're not a ninja.")
    |> mes("There's no point of me explaining any further then.")
    |> next()
    |> mes("[Tetsu]")
    |> mes("Perhaps when I have some money to spare, we could play a game of Mah-jong together.")
    |> close()
  end

  defp choose_weapon(ctx) do
    {ctx, choice} =
      ctx
      |> mes("I am the Craftman of the Fuuma Ninja. I am called Tetsu.")
      |> next()
      |> mes("[Tetsu]")
      |> mes(
        "Things have become tough for me due to my habit of gambling... So, here I am making weapons again, at long last."
      )
      |> next()
      |> mes("[Tetsu]")
      |> mes(
        "I may not look it, but if it's about any items related to Fuuma, there's none who come close to my craftsmenship."
      )
      |> mes("Well, look around, look around.")
      |> next()
      |> select(@weapon_menu)

    case choice do
      1 -> beneki(ctx)
      2 -> daisharin(ctx)
      3 -> daisharin4(ctx)
      4 -> rekka(ctx)
      5 -> cancel(ctx)
      _ -> ctx
    end
  end

  defp beneki(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Tetsu]")
      |> mes("Hmm~ You've chose the ^ff0000Fuuma Beneki^000000.")
      |> mes("In order to make the Fuuma Beneki, I need")
      |> mes("50 Steel, 20 Harpy Feather")
      |> mes("5 Oridecon, and 90,000 Zeny.")
      |> mes("Do you want me to create this item for you?")
      |> next()
      |> select(["Well .. erm .. it's kind of pricey.", "Yes! Make it for me!"])

    accept(ctx, choice, @beneki)
  end

  defp daisharin(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Tetsu]")
      |> mes("Hmm~ I see you've chose the ^ff0000Fuuma Shuriken Daisharin^000000.")
      |> mes("Fuuma Shuriken Daisharin In order to create Fuuma Shuriken Daisharin, I require...")
      |> mes("30 Steel, 100 Tassels")
      |> mes("2 Oridecons, and 40,000 Zeny.")
      |> mes("Do you want me to create this item for you?")
      |> next()
      |> select(["Well .. erm .. it's kind of pricey.", "Yes! Make it for me!"])

    accept(ctx, choice, @daisharin)
  end

  defp daisharin4(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Tetsu]")
      |> mes("Hmm~ I see you've chose the ^ff0000Fuuma Shuriken Daisharin[4]^000000.")
      |> mes("In order to create Fuuma Shuriken Daisharin[4], I require...")
      |> mes("20 Cracked Diamonds, 1 Fuuma Shuriken Daisharin")
      |> mes("3 Oridecons, and 40,000 Zeny.")
      |> mes("Do you want me to create this item for you?")
      |> next()
      |> mes("[Tetsu]")
      |> mes("And in case you don't know...")
      |> mes(
        "In the process of slotting a weapon, your weapon will lose any refine points and slotted cards, if any."
      )
      |> mes(
        "Think this over with caution, and then decide if you really want to do this or not."
      )
      |> next()
      |> select(["No thanks.. It's a little pricey..", "Yes! Make it for me!"])

    accept(ctx, choice, @daisharin4)
  end

  defp rekka(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Tetsu]")
      |> mes("Hmm~ I see you've chose the ^ff0000Fuuma Shuriken Rekka^000000.")
      |> mes("In order to create a Fuuma Shuriken Rekka, I require")
      |> mes("50 Steel, 100 Live Coal")
      |> mes("100 Burning Hearts, 50 Burning Stones")
      |> mes("and 78,000 Zeny.")
      |> mes("Do you want me to create this item for you?")
      |> next()
      |> select(["Well .. erm .. it's kind of pricey", "Yes! Make it for me!"])

    accept(ctx, choice, @rekka)
  end

  # The first option of every crafting menu jumps to the shared refusal label.
  defp accept(ctx, choice, weapon) do
    case choice do
      1 -> nope(ctx)
      2 -> check(ctx, weapon)
      _ -> ctx
    end
  end

  defp nope(ctx) do
    ctx
    |> mes("[Tetsu]")
    |> mes("Hmm. The cost to create this item is kind of expensive...")
    |> mes(
      "All right. If you do gather all the required materials one day, come back and see me."
    )
    |> close()
  end

  defp cancel(ctx) do
    ctx
    |> mes("[Tetsu]")
    |> mes("What a shame.")
    |> mes("I wanted to show you the weapons I put my heart and soul into making them.")
    |> mes("If you ever have second thoughts, it's never too late to come back and ask.")
    |> close()
  end

  defp check(ctx, weapon) do
    cond do
      not holds_materials?(ctx, weapon) -> shortage(ctx, weapon.missing)
      not holds_fee?(ctx, weapon) -> shortage(ctx, weapon.short_zeny)
      true -> trade(ctx, weapon)
    end
  end

  defp holds_materials?(ctx, weapon) do
    weapon.costs
    |> Enum.filter(&match?({:delitem, _, _}, &1))
    |> Enum.all?(fn {:delitem, item, quantity} -> count_item(ctx, item) >= quantity end)
  end

  defp holds_fee?(ctx, weapon) do
    Enum.all?(weapon.costs, fn
      {:zeny, fee} -> zeny(ctx) >= fee
      _cost -> true
    end)
  end

  defp shortage(ctx, {cause, lines}) do
    ctx
    |> mes("[Tetsu]")
    |> mes(cause)
    |> next()
    |> mes("[Tetsu]")
    |> say(lines)
    |> close()
  end

  defp trade(ctx, weapon) do
    ctx
    |> charge(weapon.costs)
    |> give_item(weapon.reward, 1)
    |> mes("[Tetsu]")
    |> say(weapon.completed)
    |> close()
  end

  defp charge(ctx, costs) do
    Enum.reduce(costs, ctx, fn
      {:delitem, item, quantity}, ctx -> delitem(ctx, item, quantity)
      {:zeny, fee}, ctx -> pay_zeny(ctx, fee)
    end)
  end

  defp say(ctx, lines), do: Enum.reduce(lines, ctx, fn line, ctx -> mes(ctx, line) end)
end
