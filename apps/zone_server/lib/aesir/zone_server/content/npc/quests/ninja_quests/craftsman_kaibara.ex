defmodule Aesir.ZoneServer.Content.Npc.Quests.NinjaQuests.CraftsmanKaibara do
  @moduledoc """
  Kaibara, the last craftsman who forges ninja swords out of a Black Dragon's scales.

  ## Behavior

  - Turns any non-Ninja away.
  - Offers five swords, each paid up front with the listed materials and Zeny:
    Gokurin, Jitte, Ashura[3], Murasame and Hakujin.
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
    spawn: [
      %{
        map: "que_ng",
        x: 72,
        y: 34,
        dir: 3,
        sprite: 847,
        name: "Craftsman Kaibara",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @confirm ["No thanks. It's too expensive.", "Yes! I want one!"]

  # Each shortage entry is `{cause, lines}`: the line explaining the shortfall
  # followed by the requirement page the reference prints with it.
  @gokurin %{
    costs: [{:delitem, 1036, 400}, {:delitem, 984, 5}, {:delitem, 7123, 30}, {:zeny, 200_000}],
    reward: 13006,
    missing:
      {"It looks like there are not enough ingredients for me to make you a Gokurin.",
       [
         "In order to make the Gokurin,",
         "I require ^ff0000 400 Dragon's Scale,^000000",
         "^ff00005 Oridecons^000000, ^ff000030 Dragon Skins^000000",
         "and ^ff0000200000 Zeny^000000.",
         "Make sure you have those items when you return to me."
       ]},
    short_zeny:
      {"Hmm, it looks like you have enough materials, but you're short on Zeny.",
       [
         "In order to make the Gokurin,",
         "I require ^ff0000 400 Dragon Scales,^000000",
         "^ff00005 Oridecons^000000, ^ff000030 Dragon Skins^000000",
         "and ^ff0000200,000 Zeny^000000.",
         "Make sure you have those items when you return to me."
       ]},
    completed: [
      "Hmm, looks good.",
      "I've checked your ingredients and fees.",
      "Here is your completed Gokurin."
    ]
  }

  @jitte %{
    costs: [{:delitem, 999, 30}, {:delitem, 7022, 1}, {:zeny, 20_000}],
    reward: 13007,
    missing:
      {"It looks like you need more materials before I can make you a Jitte.",
       [
         "In order to create a Jitte, I require",
         "^ff000030 Steel^000000, ",
         "^f00001 Old Hilt^000000,",
         "and ^ff000020,000 Zeny^000000.",
         "Remember these needed materials, and come back after you're positive you have them all."
       ]},
    short_zeny:
      {"Hmm.. You brought plenty of materials, but you're short on zeny.",
       [
         "In order to create the Jitte, I require",
         "^ff000030 Steel,^000000",
         "^f00001 Old Hilt^000000,",
         "and ^ff000020,000 Zeny^000000.",
         "Remember these needed materials, and come back after you're positive you have them all."
       ]},
    completed: [
      "Hmm, very well.",
      "I've checked your ingredients and fees.",
      "Here is your completed Jitte."
    ]
  }

  @ashura %{
    costs: [{:delitem, 999, 25}, {:delitem, 7099, 5}, {:zeny, 32_000}],
    reward: 13011,
    missing:
      {"It looks like you don't have all the materials I need to create an Ashura[3] for you.",
       [
         "I require ^ff000025 Steel,^000000",
         "^ff0000Five Worn-out Magic Scrolls,^000000",
         "and ^ff0000 32,000 Zeny^000000 in order to create an Ashura[3].",
         "Remember these needed materials, and come back after you're positive you have them all."
       ]},
    short_zeny:
      {"Hmm.. You brought plenty of materials, but you're short on zeny.",
       [
         "In order to create an Ashura[3], I require the following materials - ",
         "^ff000025 Steel,^000000",
         "^ff00005 Worn-out Magic Scrolls^000000,",
         "and ^ff0000 32,000 Zeny^000000",
         "Remember these needed materials, and come back after you're positive you have them all."
       ]},
    completed: [
      "Hmm, very well.",
      "I've checked your ingredients and fees.",
      "Here is your completed Ashura[3]."
    ]
  }

  @murasame %{
    costs: [{:delitem, 999, 30}, {:delitem, 720, 10}, {:zeny, 48_000}],
    reward: 13012,
    missing:
      {"It looks like your short on materials for me to create you a Murasame.",
       [
         "I require ^ff000030 Steel^000000, ",
         "^ff000010 Aquamarines^000000,",
         "and ^ff000048,000 Zeny^000000",
         "in order to create a Murasame.",
         "Remember these needed materials, and come back after you're positive you have them all."
       ]},
    short_zeny:
      {"Hmm.. You brought plenty of materials, but you're short on zeny.",
       [
         "In order to create a Murasame, I require..",
         "^ff000030 Steel^000000, ",
         "^ff000010 Aquamarines^000000,",
         "and ^ff000048,000 Zeny^000000.",
         "Remember these needed materials, and come back after you're positive you have them all."
       ]},
    completed: [
      "Hmm, very well.",
      "I've checked your ingredients and fees.",
      "Here is your completed Murasame."
    ]
  }

  @hakujin %{
    costs: [{:delitem, 932, 500}, {:delitem, 12001, 10}, {:delitem, 722, 5}, {:zeny, 120_000}],
    reward: 13014,
    missing:
      {"It looks like you're short on raw materials for me to be able to make you a Hakujin.",
       [
         "In order to create a Hakujin, I require...",
         "500 Skel-Bones, 5 Pearls",
         "10 Level 3 Heal Scrolls",
         "and 120,000 Zeny.",
         "Remember these needed materials, and come back after you're positive you have them all."
       ]},
    short_zeny:
      {"Hmm.. You brought plenty of materials, but you're short on zeny.",
       [
         "In order to create a Hakujin, I require...",
         "500 Skel-Bones, 5 Pearls",
         "10 Level 3 Heal Scrolls",
         "and 120,000 Zeny.",
         "Remember these needed materials, and come back after you're positive you have them all."
       ]},
    completed: [
      "Hmm, very well.",
      "I've double checked the materials and Zeny you've brought.",
      "Here is your completed Hakujin."
    ]
  }

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if Rathena.job_id(base_class(ctx)) == Rathena.job_id(:ninja) do
      choose_weapon(ctx)
    else
      turn_away(ctx)
    end
  end

  defp turn_away(ctx) do
    ctx
    |> mes("[Kaibara]")
    |> mes("I am a Craftsman called Kaibara")
    |> mes("I create weapons for Ninjas.")
    |> mes("However, It doesn't look like you are a ninja.")
    |> next()
    |> mes("[Kaibara]")
    |> mes(
      "Even if I created a sword for you, I doubt you would be able to appreciate it. What a shame..."
    )
    |> close()
  end

  defp choose_weapon(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Kaibara]")
      |> mes(
        "I am the last Craftsman who knows how to make a sword out of a Black Dragon's scales. They call me Kaibara."
      )
      |> mes("You look like a Ninja.")
      |> mes("If you're interested, take a look at my goods while you decide what you want.")
      |> next()
      |> select(["Gokurin", "Jitte", "Ashura[3]", "Murasame", "Hakujin", "Cancel"])

    case choice do
      1 -> gokurin(ctx)
      2 -> jitte(ctx)
      3 -> ashura(ctx)
      4 -> murasame(ctx)
      5 -> hakujin(ctx)
      _ -> dismiss(ctx)
    end
  end

  defp gokurin(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Kaibara]")
      |> mes("Hmm~ I see you've picked the Gokurin.")
      |> mes("Gokurin is made with various materials, one of them being Dragon's Scale.")
      |> next()
      |> mes("[Kaibara]")
      |> mes("The required material for this sword is 400 Dragon Scales,")
      |> mes("5 Oridecons, and 30 Dragon Skins.")
      |> mes("and 200,000 Zeny.")
      |> mes("Do you want me to create this item for you?")
      |> next()
      |> select(@confirm)

    forge(ctx, choice, @gokurin)
  end

  defp jitte(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Kaibara]")
      |> mes("Hmm~ You've picked the ^ff0000Jitte^000000.")
      |> mes(
        "This sword has a legend that the more enemies you slay with it, the stronger it gets."
      )
      |> next()
      |> mes("[Kaibara]")
      |> mes("The required materials are 30 Steel, one Old Hilt")
      |> mes("and 20,000 Zeny.")
      |> mes("Do you want me to create this item for you?")
      |> next()
      |> select(@confirm)

    forge(ctx, choice, @jitte)
  end

  defp ashura(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Kaibara]")
      |> mes("Hmm~ You've chose the ^ff0000Ashura[3]^000000.")
      |> mes("In order to create an Ashura[3], I require ")
      |> mes("25 Steel, 5 Worn-out Magic Scrolls")
      |> mes("And 32,000 Zeny.")
      |> mes("Do you want me to create this item for you?")
      |> next()
      |> select(@confirm)

    forge(ctx, choice, @ashura)
  end

  defp murasame(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Kaibara]")
      |> mes("Hmm~ You've chose the ^ff0000Murasame^000000.")
      |> mes("To create the Murasame, I require")
      |> mes("30 Steel, 10 Aquamarines")
      |> mes("And 48,000 Zeny.")
      |> mes("Do you want me to create this item for you?")
      |> next()
      |> select(@confirm)

    forge(ctx, choice, @murasame)
  end

  defp hakujin(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Kaibara]")
      |> mes("Hmm~ You've chose the ^ff0000Hakujin^000000.")
      |> mes("In order to create a Hakujin, I require...")
      |> mes("500 Skel-Bones, 5 Pearls")
      |> mes("10 Level 3 Heal Scrolls")
      |> mes("and 120,000 Zeny.")
      |> mes("Do you want me to create this item for you?")
      |> next()
      |> select(@confirm)

    forge(ctx, choice, @hakujin)
  end

  defp forge(ctx, choice, weapon) do
    if choice == 1, do: decline(ctx), else: check(ctx, weapon)
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
    |> mes("[Kaibara]")
    |> mes(cause)
    |> next()
    |> mes("[Kaibara]")
    |> say(lines)
    |> close()
  end

  defp trade(ctx, weapon) do
    ctx
    |> charge(weapon.costs)
    |> give_item(weapon.reward, 1)
    |> mes("[Kaibara]")
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

  defp decline(ctx) do
    ctx
    |> mes("[Kaibara]")
    |> mes("Hrm. I understand. These are materials that are difficult to attain...")
    |> mes("If you ever happen to gather all these materials one day, feel free to come back.")
    |> close()
  end

  defp dismiss(ctx) do
    ctx
    |> mes("[Kaibara]")
    |> mes("Hmm, Very well.")
    |> mes("Come and look for me again.")
    |> close()
  end
end
