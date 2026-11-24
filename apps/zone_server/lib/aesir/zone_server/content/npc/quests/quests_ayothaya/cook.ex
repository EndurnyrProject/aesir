defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAyothaya.Cook do
  @moduledoc """
  Mali the Spicy prepares Tom Yum Goong for adventurers who gather her ingredients.

  ## Behavior

  - Guides adventurers through collecting shrimp, lemons and chiles.
  - Accepts the ingredients in stages and rewards ten portions after cooking.

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
        map: "ayo_in01",
        x: 145,
        y: 163,
        dir: 3,
        sprite: 839,
        name: "Cook",
        scope: :shared,
        unique_name: "Cook#ayo"
      }
    ]

  @shrimp 567
  @lemon 568
  @chile 7286
  @tom_yum_goong 566

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :tomyumgoong, 0)

    cond do
      stage < 2 -> introduction(ctx, stage)
      stage == 2 and count_item(ctx, @shrimp) > 19 -> bad_shrimp(ctx)
      stage == 2 -> shrimp_reminder(ctx)
      stage == 3 and count_item(ctx, @shrimp) > 19 -> fresh_shrimp(ctx)
      stage == 3 -> missing_shrimp(ctx)
      stage == 4 and count_item(ctx, @lemon) > 9 -> bad_lemons(ctx)
      stage == 4 -> lemon_reminder(ctx)
      stage == 5 and count_item(ctx, @lemon) > 9 -> fresh_lemons(ctx)
      stage == 5 -> missing_lemons(ctx)
      stage == 6 and count_item(ctx, @chile) > 29 -> bad_chiles(ctx)
      stage == 6 -> market_reminder(ctx)
      stage == 7 -> finish_quest(ctx)
      true -> busy(ctx)
    end
  end

  defp introduction(ctx, stage) do
    ctx =
      ctx
      |> mes("[Mali the Spicy]")
      |> mes("Hello, there!")
      |> mes("I am called Mali the Spicy.")
      |> mes("All of my dishes always amaze")
      |> mes("my customers with their tempting scents and deep flavors.")
      |> next()
      |> mes("[Mali the Spicy]")
      |> mes("I am especially proud of my")
      |> mes("^3131FFTom Yum Goong^000000, which is the")
      |> mes("best in the village. I suppose")
      |> mes("it's my fate to cook the greatest Tom Yum Goong ever.")

    if stage == 0, do: close(ctx), else: request_help(ctx)
  end

  defp request_help(ctx) do
    {ctx, choice} =
      ctx
      |> next()
      |> mes("[Mali the Spicy]")
      |> mes("Oh I see...")
      |> mes("You want me to cook")
      |> mes("Tom Yum Goong for you,")
      |> mes("don't you?")
      |> next()
      |> mes("[Mali the Spicy]")
      |> mes("Honestly, I've been really")
      |> mes(
        "busy ever since I opened this restaurant. If you really wish to taste my Tom Yum Goong, would"
      )
      |> mes("you do something for me?")
      |> next()
      |> select(["Sure!", "Eh... I dunno."])

    if choice == 1, do: explain_ingredients(ctx), else: decline(ctx)
  end

  defp explain_ingredients(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Mali the Spicy]")
      |> mes("First, would you get")
      |> mes("the ingredients to make")
      |> mes(
        "Tom Yum Goong for me? I'll need some ^CE0000Shrimps^000000, ^CE0000Chiles^000000 and ^CE0000Lemons^000000."
      )
      |> next()
      |> mes("[Mali the Spicy]")
      |> mes(
        "Remember, Shrimp is the main ingredient of this dish. So, the fresher the Shrimp, the tastier your food will be."
      )
      |> next()
      |> select(["Where can I find them?"])

    ctx
    |> mes("[Mali the Spicy]")
    |> mes("I expected you")
    |> mes("to ask me that.")
    |> mes("For Shrimps, look around")
    |> mes("the beach. You should see")
    |> mes("a lot of them there.")
    |> next()
    |> mes("[Mali the Spicy]")
    |> mes(
      "However, you might have a hard time finding them since you haven't done that before. So just buy some Shrimp from the guy who sells"
    )
    |> mes("the freshest Shrimp around.")
    |> next()
    |> mes("[Mali the Spicy]")
    |> mes("Hmmm...")
    |> mes("If you mention")
    |> mes("my name, that guy")
    |> mes("might give you a discount.")
    |> set_char_var(:tomyumgoong, 2)
    |> changequest(8123, 8124)
    |> next()
    |> mes("[Mali the Spicy]")
    |> mes("His name is ^3131FFThongpool^000000.")
    |> mes(
      "He will be somewhere around the village selling Shrimps. Go and ask him to give you 20 Shrimps to cook Tom Yum Goong."
    )
    |> close()
  end

  defp decline(ctx) do
    ctx
    |> mes("[Mali the Spicy]")
    |> mes("I understand this might be difficult to do, but it's worth")
    |> mes("a try if you really want to taste the best Tom Yum Goong.")
    |> close()
  end

  defp bad_shrimp(ctx) do
    ctx
    |> mes("[Mali the Spicy]")
    |> mes("Errr...")
    |> mes("What's wrong with these Shrimp?")
    |> mes(
      "They all have these scratches and rips in them! I can't believe Thongpool sold such bad Shrimp"
    )
    |> mes("to his customers!")
    |> next()
    |> mes("[Mali the Spicy]")
    |> mes("I'm so sorry, but")
    |> mes("I can't cook the best")
    |> mes("Tom Yum Goong with")
    |> mes("these Shrimp.")
    |> next()
    |> mes("[Mali the Spicy]")
    |> mes("I know it's an inconvenience, but would you go back to Thongpool")
    |> mes("and ask him to give you the freshest Shrimp to cook the best")
    |> mes("Tom Yum Goong?")
    |> close()
  end

  defp shrimp_reminder(ctx) do
    ctx
    |> mes("[Mali the Spicy]")
    |> mes("Make sure you ask")
    |> mes("Mr. Thongpool to give")
    |> mes("you 20 Shrimps.")
    |> mes("Now hurry~")
    |> close()
  end

  defp fresh_shrimp(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Mali the Spicy]")
      |> mes("Ah, you came back!")
      |> mes("Now, let me see what")
      |> mes("you've brought. Hmm...")
      |> mes("These are...")
      |> next()
      |> emotion(:best)
      |> mes("[Mali the Spicy]")
      |> mes("The freshest Shrimp that")
      |> mes("I've been looking for! Well done~")
      |> mes("With these big and fresh Shrimp,")
      |> mes("I can cook the best Tom Yum Goong for you! Thank you so much!")
      |> delitem(@shrimp, 20)
      |> next()
      |> mes("[Mali the Spicy]")
      |> mes(
        "It will be a perfect food with the natural sweetness of the Shrimp, the sourness of Lemons and a little bit of fish sauce!"
      )
      |> next()
      |> mes("[Mali the Spicy]")
      |> mes("Oh... Right.")
      |> mes("But we only have Shrimp.")
      |> mes("Now, I want you to bring")
      |> mes("me some ^CE0000Lemons^000000.")
      |> next()
      |> select([
        "Where can I find Lemons?",
        "I hate sour food. I'd better quit!"
      ])

    if choice == 1, do: lemon_directions(ctx), else: quit(ctx)
  end

  defp lemon_directions(ctx) do
    ctx
    |> set_char_var(:tomyumgoong, 4)
    |> changequest(8124, 8125)
    |> mes("[Mali the Spicy]")
    |> mes("A few days ago, I saw a good")
    |> mes("Lemon tree while taking a walk.")
    |> mes("But this tree belongs to an ordinary man who's not a Fruit Merchant.")
    |> next()
    |> mes("[Mali the Spicy]")
    |> mes("I'm not sure whether")
    |> mes("or not he'd sell Lemons")
    |> mes("to you, but you can try,")
    |> mes("I guess.")
    |> close()
  end

  defp quit(ctx) do
    ctx
    |> emotion(:anger)
    |> mes("[Mali the Spicy]")
    |> mes("What a stupid...!")
    |> mes(
      "If you quit just because you really hate sour flavors, you must not be that eager to have my Tom Yum Goong!"
    )
    |> next()
    |> mes("[Mali the Spicy]")
    |> mes("Once you taste my")
    |> mes("Tom Yum Goong, you'll")
    |> mes("regret what you just said!")
    |> close()
  end

  defp missing_shrimp(ctx) do
    ctx
    |> mes("[Mali the Spicy]")
    |> mes("Huh...?")
    |> mes("What did you do")
    |> mes("with the Shrimps?")
    |> mes("You didn't eat them")
    |> mes("on the way here, did you?")
    |> close()
  end

  defp bad_lemons(ctx) do
    ctx
    |> mes("[Mali the Spicy]")
    |> mes("You think these are")
    |> mes("the best quality Lemons?")
    |> mes("Take a closer look!")
    |> next()
    |> mes("[Mali the Spicy]")
    |> mes("The skin of these")
    |> mes("Lemons lack luster")
    |> mes("and they don't even smell")
    |> mes("fresh! They're just")
    |> mes("common Lemons!")
    |> close()
  end

  defp lemon_reminder(ctx) do
    ctx
    |> mes("[Mali the Spicy]")
    |> mes("Alright...")
    |> mes("I'm counting on you")
    |> mes("to get the best Lemons")
    |> mes("from the guy that owns that tree.")
    |> next()
    |> mes("[Mali the Spicy]")
    |> mes("Somehow, you've got")
    |> mes("to get those high quality")
    |> mes("Lemons so that I can make")
    |> mes("some Tom Yum Goong!")
    |> close()
  end

  defp fresh_lemons(ctx) do
    {ctx, choice} =
      ctx
      |> emotion(:surprise)
      |> mes("[Mali the Spicy]")
      |> mes("Welcome back!")
      |> mes("Wow, you came back")
      |> mes("really fast! Okay, let me")
      |> mes("see the Lemons")
      |> mes("you brought?")
      |> next()
      |> mes("[Mali the Spicy]")
      |> mes("Wow, great!")
      |> mes("These are really fresh Lemons!")
      |> mes("How could you bring all of these by yourself? Thanks for your trouble~")
      |> next()
      |> mes("[Mali the Spicy]")
      |> mes("Now, you should go buy")
      |> mes("some ^CE0000Chiles^000000 and some")
      |> mes("other materials in the Market.")
      |> next()
      |> mes("[Mali the Spicy]")
      |> mes("When you talk")
      |> mes("to the Merchants")
      |> mes("in the Market, they")
      |> mes("will know what you want.")
      |> next()
      |> select([
        "Okay, I'll be right back.",
        "Ah, I'm tired now. Let me take a rest first..."
      ])

    if choice == 1, do: accept_lemons(ctx), else: rest(ctx)
  end

  defp accept_lemons(ctx) do
    ctx
    |> delitem(@lemon, 10)
    |> set_char_var(:tomyumgoong, 6)
    |> changequest(8125, 8126)
    |> mes("[Mali the Spicy]")
    |> mes("See you in a bit~")
    |> close()
  end

  defp rest(ctx) do
    ctx
    |> mes("[Mali the Spicy]")
    |> mes("It's your call.")
    |> mes("But remember...")
    |> mes("The Shrimps might go bad")
    |> mes("while you're taking a rest.")
    |> close()
  end

  defp missing_lemons(ctx) do
    ctx
    |> mes("[Mali the Spicy]")
    |> mes("Huh...?")
    |> mes("What did you")
    |> mes("do with Lemons?")
    |> mes("You didn't eat them")
    |> mes("all on the way here, did you?")
    |> close()
  end

  defp bad_chiles(ctx) do
    ctx
    |> mes("[Mali the Spicy]")
    |> mes("I don't understand...")
    |> mes("Where did you get these")
    |> mes("bad ingredients?! Didn't")
    |> mes("I tell you that my")
    |> mes("Tom Yum Goong")
    |> mes("requires the best?!")
    |> close()
  end

  defp market_reminder(ctx) do
    ctx
    |> mes("[Mali the Spicy]")
    |> mes(
      "I know you've been working hard to do me this favor. I hope you'll put forth that last little bit of effort to finish this."
    )
    |> next()
    |> mes("[Malli the Spicy]")
    |> mes(
      "Please go take a look in the Market. I don't doubt that it will be a good experience. After all, my fantastic Tom Yum Goong is waiting for you!"
    )
    |> close()
  end

  defp finish_quest(ctx) do
    cond do
      max_weight(ctx) - weight(ctx) <= 1499 -> overweight(ctx)
      count_item(ctx, @chile) > 29 -> cook(ctx)
      true -> missing_chiles(ctx)
    end
  end

  defp cook(ctx) do
    ctx
    |> delitem(@chile, 30)
    |> emotion(:surprise)
    |> mes("[Mali the Spicy]")
    |> mes("Now...")
    |> mes("Everything is all set!")
    |> mes("Before we start, let me")
    |> mes("check the materials.")
    |> next()
    |> mes("[Mali the Spicy]")
    |> mes("^CE0000Shrimp^000000, ^CE0000Chiles^000000, ^CE0000Lemons^000000...")
    |> mes("Fish sauce and other little things...")
    |> next()
    |> mes("[Mali the Spicy]")
    |> mes("Perfect!")
    |> mes("Shall we begin?")
    |> next()
    |> mes("^FF0000*Tuk*^000000")
    |> mes("^9C009C*Tup*^000000")
    |> mes("^009C00*Puk*^000000")
    |> specialeffect(:enchantpoison)
    |> next()
    |> mes("^FF0031*Chop chop*^000000")
    |> mes("^FF9C00*Tup tup tup*^000000")
    |> mes("^639CFF*Pu pu^000000 -")
    |> specialeffect(:venomdust)
    |> next()
    |> mes("[Mali the Spicy]")
    |> mes("- ^9C6300Tup tup^000000 ^006363chook^000000")
    |> mes("^316363Chop chop^000000")
    |> mes("^FF0000Tup tup tup^000000 ^009C00Pu pu^000000 -")
    |> specialeffect(:stonecurse)
    |> specialeffect(:hasteup)
    |> specialeffect(:beginspell)
    |> next()
    |> mes("[Mali the Spicy]")
    |> mes("Wah^00009Cah^0000FFahhhh^0063FFaaaahhh^000000!")
    |> emotion(:huk)
    |> specialeffect(:flasher)
    |> specialeffect(:lord)
    |> next()
    |> mes("[Mali the Spicy]")
    |> mes(" ...")
    |> mes(" ......")
    |> mes(" .........")
    |> next()
    |> set_char_var(:tomyumgoong, 8)
    |> completequest(8126)
    |> give_item(@tom_yum_goong, 10)
    |> emotion(:best)
    |> mes("[Mali the Spicy]")
    |> mes("Here's your")
    |> mes("Tom Yum Goong!")
    |> mes("Ah~ This taste,")
    |> mes("this scent... Yeah.")
    |> mes("I know I did a good job.")
    |> next()
    |> mes("[Mali the Spicy]")
    |> mes(
      "Do you know what is the secret of Tom Yum Goong? It isn't simply just food. This has the power to heal you, and help you get into better shape."
    )
    |> next()
    |> mes("[Mali the Spicy]")
    |> mes("Because...")
    |> mes("It contains the")
    |> mes("power of God.")
    |> next()
    |> mes("[Mali the Spicy]")
    |> mes("Okay...!")
    |> mes("I'm giving you")
    |> mes("10 Tom Yum Goong")
    |> mes("free of charge~")
    |> next()
    |> mes("[Mali the Spicy]")
    |> mes(
      "Thank you for all the trouble that you have been though to get these ingredients. It would make me happy if you shared Tom Yum Goong with your friends."
    )
    |> next()
    |> mes("[Mali the Spicy]")
    |> mes(
      "Share the flavor of Ayothaya, and let them know how beautiful our land is. It was good to see you, take care now~"
    )
    |> close()
  end

  defp missing_chiles(ctx) do
    ctx
    |> mes("[Mali the Spicy]")
    |> mes(
      "Huh? What did you do with the Chiles? You didn't eat them all on the way here, did you?"
    )
    |> close()
  end

  defp overweight(ctx) do
    ctx
    |> mes("[Mali the Spicy]")
    |> mes("Hmm...")
    |> mes(
      "You seem to be carrying too many things. Why don't you free up some space in your inventory first, and then come back?"
    )
    |> close()
  end

  defp busy(ctx) do
    ctx
    |> emotion(:kek)
    |> mes("[Mali the Spicy]")
    |> mes("Ah...!")
    |> mes("So busy, so busy!")
    |> mes("My customers never get tired of")
    |> mes("the taste of my Tom Yum Goong!")
    |> mes("Heh heh heh~!")
    |> close()
  end
end
