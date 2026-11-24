defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.UweKleine do
  @moduledoc """
  Uwe Kleine, Einbroch's flamboyant smith and chef, shares cooking advice for Large Jellopy.

  ## Behavior

  - Introduces himself on a first visit and talks about Einbroch's history.
  - Asks for 6 Large Jellopy as cooking tuition, paying 1 Coal and beginner advice.
  - Recognizes odd-progress (former Blacksmith) characters as transcended returners.
  - Gives Blacksmiths and Whitesmiths their own storyline: welcome gifts, hammer lessons, a
    Jubilee for Coal trade and Mini Furnace rewards.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - MasterOfMuppets
    - Lupus
    - KarLaeda
    - SinSloth
    - L0ne_W0lf
    - Yommy
    - Paradox924X
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  - Fixes the rAthena Blacksmith gate, `BaseClass == Job_Blacksmith`, which can never be
    true because `BaseClass` is the first class (Merchant), to `BaseJob` so Blacksmiths and
    the Whitesmiths the branch already handles reach it
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "einbroch",
        x: 215,
        y: 180,
        dir: 6,
        sprite: 85,
        name: "Uwe Kleine",
        scope: :shared,
        unique_name: "Uwe Kleine#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @giggles ["...Ho ho~", "...*Tee Hee~*", "...Behbie~"]
  @chuckles ["Hohohohoho.", "Umhohohoho.*", "Umho."]

  @impl true
  def on_talk(ctx) do
    cook = get_char_var(ctx, :ein_cook, 0)

    if Rathena.job_id(base_job(ctx)) == Rathena.job_id(:blacksmith) do
      blacksmith(ctx, cook)
    else
      visitor(ctx, cook)
    end
  end

  defp blacksmith(ctx, cook) do
    cond do
      cook > 1199 -> furnace_gift(ctx)
      cook > 1099 -> jellopy_favor(ctx)
      cook == 0 -> smith_welcome(ctx)
      cook < 10 -> novice_smith_menu(ctx, cook)
      cook < 20 or cook == 219 -> smith_menu(ctx)
      cook > 299 -> transcended_smith(ctx)
      true -> ctx
    end
  end

  defp visitor(ctx, cook) do
    cond do
      rem(cook, 2) == 1 -> former_smith(ctx, cook)
      cook > 999 -> apprentice(ctx, cook - 1000)
      cook == 0 -> first_visit(ctx)
      true -> ctx
    end
  end

  defp furnace_gift(ctx) do
    {ctx, choice} =
      ctx
      |> long_time_no_see()
      |> select(["So... You're a chef.", "Yes, I tried my best."])

    case choice do
      1 ->
        ctx
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("So...")
        |> mes("You're a chef.")
        |> next()
        |> mes("[Uwe]")
        |> mes("That's right, it's")
        |> mes("what I do for business.")
        |> mes("Now, as for what I do for")
        |> mes("^EEA9B8pleasure^000000, well, please don't")
        |> mes("hesitate to ask, sugar honey~ ")
        |> next()
        |> hand_over_furnaces()

      2 ->
        ctx
        |> mes("[Uwe]")
        |> mes(
          "Only continuous effort will lead you to success. I guess that means you've learned your lesson, sugar honey~"
        )
        |> next()
        |> hand_over_furnaces()

      _ ->
        ctx
    end
  end

  defp hand_over_furnaces(ctx) do
    if overweight?(ctx, 908, 200) do
      too_heavy(ctx)
    else
      ctx
      |> set_char_var(:ein_cook, 219)
      |> give_item(612, 10)
      |> mes("[Uwe]")
      |> mes("I had these lying")
      |> mes("around, so why don't")
      |> mes("you take them, sugar")
      |> mes("honey? They're not very")
      |> mes("pricey, but they're useful")
      |> mes("in doing some smithing.")
      |> next()
      |> mes("[Uwe]")
      |> mes("Alright then~")
      |> mes("Hope you enjoy")
      |> mes("your Mini Furances")
      |> laugh_and_close(@giggles)
    end
  end

  defp jellopy_favor(ctx) do
    {ctx, choice} =
      ctx
      |> jellopy_reminder()
      |> select(["There you go.", "I want to quit.", "Can I do it later?"])

    case choice do
      1 -> hand_in_jellopy(ctx)
      2 -> quit_favor(ctx)
      3 -> late_for_favor(ctx)
      _ -> ctx
    end
  end

  defp hand_in_jellopy(ctx) do
    jellopy = count_item(ctx, 7126)

    cond do
      jellopy > 5 and overweight?(ctx, 908, 199) ->
        too_heavy(ctx)

      jellopy > 5 ->
        ctx
        |> trade_jellopy_for_coal()
        |> next()
        |> mes("[Uwe]")
        |> mes("I hope you enjoy!")
        |> mes("Personally, I think the")
        |> mes("best part of smithing")
        |> mes("is standing over the flaming")
        |> mes("heat and getting all ^EEA9B8hot and")
        |> mes("sweaty^000000. Ooh, how exciting~!")
        |> close()

      jellopy > 0 ->
        hand_in_some_jellopy(ctx)

      true ->
        no_jellopy(ctx)
    end
  end

  defp hand_in_some_jellopy(ctx) do
    {ctx, choice} =
      ctx
      |> missing_jellopy("...you")
      |> select(["Give him all.", "Cancel."])

    case choice do
      1 ->
        if overweight?(ctx, 1201, 1), do: too_heavy(ctx), else: give_him_all(ctx)

      2 ->
        if overweight?(ctx, 1201, 1) do
          too_heavy(ctx)
        else
          ctx
          |> mes("[Uwe]")
          |> mes("Well... Then... Anyway,")
          |> mes("Congratulation to became")
          |> mes(if whitesmith?(ctx), do: "a Master Smith!!", else: "a Black Smith!!")
          |> mes("This is my present for it.")
          |> naughty("...you")
          |> consolation_furnaces()
        end

      _ ->
        ctx
    end
  end

  defp give_him_all(ctx) do
    ctx = just_kidding(ctx)
    if overweight?(ctx, 908, 220), do: too_heavy(ctx), else: extra_furnaces(ctx)
  end

  defp consolation_furnaces(ctx) do
    if overweight?(ctx, 908, 100) do
      ctx
      |> next()
      |> too_heavy_lines()
      |> close()
    else
      ctx
      |> set_char_var(:ein_cook, 219)
      |> give_item(612, 5)
      |> next()
      |> not_extravagant()
    end
  end

  defp quit_favor(ctx) do
    if overweight?(ctx, 908, 200) do
      too_heavy(ctx)
    else
      ctx
      |> mes("[Uwe]")
      |> mes("Quit...?")
      |> mes(
        "Oh well, at least you're honest. But let me give you a little something, since we're both fellow smiths."
      )
      |> next()
      |> mes("[Uwe]")
      |> mes("Still...")
      |> mes("That doesn't change")
      |> mes("the fact that you've")
      |> mes("been very, very bad.")
      |> naughty("...You")
      |> set_char_var(:ein_cook, 219)
      |> give_item(612, 10)
      |> next()
      |> not_extravagant()
    end
  end

  defp late_for_favor(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Uwe]")
      |> mes(
        "Oooh, you came back later than I thought, so I don't need really need them anymore. Then again, just holding onto them doesn't sound right either..."
      )
      |> next()
      |> select(["Here you go~", "I want to quit."])

    case choice do
      1 -> if overweight?(ctx, 908, 199), do: too_heavy(ctx), else: late_hand_in(ctx)
      2 -> if overweight?(ctx, 908, 200), do: too_heavy(ctx), else: late_quit(ctx)
      _ -> ctx
    end
  end

  defp late_hand_in(ctx) do
    jellopy = count_item(ctx, 7126)

    cond do
      jellopy > 5 -> ctx |> trade_jellopy_for_coal() |> close()
      jellopy > 0 -> late_hand_in_some(ctx)
      true -> no_jellopy(ctx)
    end
  end

  defp late_hand_in_some(ctx) do
    {ctx, choice} =
      ctx
      |> missing_jellopy("...You")
      |> select(["Give them all.", "Cancel."])

    case choice do
      1 ->
        if overweight?(ctx, 908, 220) do
          too_heavy(ctx)
        else
          ctx |> just_kidding() |> extra_furnaces()
        end

      2 ->
        if overweight?(ctx, 908, 200) do
          too_heavy(ctx)
        else
          ctx
          |> mes("[Uwe]")
          |> mes("Okay.")
          |> mes("Anyway~!")
          |> mes("When you do get all")
          |> mes("that Large Jellopy,")
          |> mes("just come back to me.")
          |> naughty("...you")
          |> set_char_var(:ein_cook, 219)
          |> give_item(612, 10)
          |> next()
          |> mes("[Uwe]")
          |> mes("This Portable Furnace is not expensive")
          |> mes("but very important item for smiths, right?")
          |> mes("Use it!")
          |> mes("And visit me someday again. Huhuhu..")
          |> close()
        end

      _ ->
        ctx
    end
  end

  defp late_quit(ctx) do
    ctx =
      ctx
      |> mes("[Uwe]")
      |> mes("Well... Then... Anyway,")
      |> mes("Congratulation to became")

    ctx =
      if whitesmith?(ctx) do
        ctx
        |> mes("a Master Smith!!")
        |> mes("This is my present for it. Huhuhu.")
      else
        ctx
        |> mes("a Black Smith!!")
        |> mes("This is my present for it. Huhuhu.")
        |> naughty("...You")
      end

    ctx
    |> set_char_var(:ein_cook, 219)
    |> give_item(612, 10)
    |> next()
    |> not_extravagant()
  end

  defp trade_jellopy_for_coal(ctx) do
    ctx
    |> mes("[Uwe]")
    |> mes("Thank you ^EEA9B8so^000000 much!")
    |> mes("Here's the Coal I promised~")
    |> mes(
      "Oh, and take these Mini Furnaces. They were just lying around, so you know, I thought, well, why don't you take them? *Tee hee hee~*"
    )
    |> delitem(7126, 6)
    |> set_char_var(:ein_cook, 219)
    |> give_item(1003, 1)
    |> give_item(612, 10)
  end

  defp missing_jellopy(ctx, you) do
    ctx
    |> mes("[Uwe]")
    |> mes("Ooh, you're missing")
    |> mes("some. I guess you can")
    |> mes("still give them to me, but")
    |> mes("you'd get less of a reward")
    |> naughty(you)
  end

  defp just_kidding(ctx) do
    ctx
    |> mes("[Uwe]")
    |> mes("Just kidding~")
    |> mes(
      "Don't be so nervous, I don't really need those anymore. But since I know you're hard working, I'll throw in a little something extra..."
    )
    |> next()
  end

  defp extra_furnaces(ctx) do
    smiths = if whitesmith?(ctx), do: "MasterSmiths", else: "Blacksmiths"

    ctx
    |> mes("[Uwe]")
    |> mes(
      "I usually give you cutie #{smiths} 10 Mini Furnaces, but you can have ^EEA9B811^000000. There's the little something extra I was talking about."
    )
    |> set_char_var(:ein_cook, 219)
    |> give_item(612, 11)
    |> next()
    |> not_extravagant()
  end

  defp no_jellopy(ctx) do
    ctx
    |> mes("[Uwe]")
    |> mes("^666666You didn't bring")
    |> mes("any Large Jellopy...?^000000.")
    |> set_char_var(:ein_cook, 219)
    |> next()
    |> mes("[Uwe]")
    |> mes(
      "It's fine! It's not like I feel ^EEA9B8betrayed^000000 or anything, but I don't need them anymore! Since we're both in the business of smithing, I just hope that you remember to follow through on your favors, 'kay? Buhbye~"
    )
    |> close()
  end

  defp not_extravagant(ctx) do
    ctx
    |> mes("[Uwe]")
    |> mes(
      "I know it's not very extravagant, but these will come in handy next time you're smithing. So make the best use of them, 'kay?"
    )
    |> close()
  end

  defp smith_welcome(ctx) do
    {ctx, choice} =
      ctx
      |> cooking_is_a_joy()
      |> select(["Um, isn't this a forge?", "Ignore him."])

    case choice do
      1 ->
        ctx
        |> mes("[Uwe]")
        |> forge_introduction()
        |> key_to_cooking()

      2 ->
        ctx
        |> mes("[Uwe]")
        |> mes("Hmmm...?")
        |> mes("Why don't you stay and chat?")
        |> mes("Oh, you adventurers are always")
        |> mes("so busy with your things to do")
        |> mes("and people to see. Ah well~")
        |> close()

      _ ->
        ctx
    end
  end

  defp key_to_cooking(ctx) do
    address =
      if sex(ctx) == 1,
        do: "you ^EEA9B8naughty little man^000000?",
        else: "you ^EEA9B8naughty, naughty girl^000000?"

    {ctx, choice} =
      ctx
      |> mes("[Uwe]")
      |> mes("Cooking is probably one")
      |> mes("of the greatest pleasures")
      |> mes("a craftsman can enjoy. Ooh,")
      |> mes("what do you think is the most")
      |> mes("important factor in cooking,")
      |> mes(address)
      |> next()
      |> select(["Heart.", "Ingredients.", "Skills.", "Tools."])

    case choice do
      1 -> ctx |> answer_heart() |> come_see_me()
      2 -> ctx |> answer_ingredients() |> come_see_me()
      3 -> ctx |> answer_skills() |> come_see_me()
      4 -> ctx |> answer_tools() |> come_see_me()
      _ -> ctx
    end
  end

  defp answer_heart(ctx) do
    ctx
    |> repeat_answer("Heart")
    |> mes("[Uwe]")
    |> mes("Na-na-na-na-noooo~")
    |> mes("If a heart was all you")
    |> mes("needed to cook or forge,")
    |> mes("then anyone can make and")
    |> mes("upgrade a Claymore, right?")
    |> next()
    |> mes("[Uwe]")
    |> mes("What you really need")
    |> mes("when cooking and forging")
    |> mes("is ^EEA9B8desire^000000. The burning desire")
    |> mes("and passion to make something")
    |> mes("great! If that was what you meant, then you are absolutely right!")
    |> next()
    |> mes("[Uwe]")
    |> mes("But any other meaning")
    |> mes("to that answer would have")
    |> mes("been absolutely wrooooong.")
    |> next()
    |> emveretarcon_gift(1)
  end

  defp answer_ingredients(ctx) do
    ctx
    |> repeat_answer("Ingredients")
    |> mes("[Uwe]")
    |> mes("Na-na-na-na-noooo~")
    |> mes("People always blame their")
    |> mes("ingredients when something")
    |> mes("goes wrong! It's those people")
    |> mes("who just embarrass themselves~ ")
    |> next()
    |> mes("[Uwe]")
    |> mes(
      "Now, if you have the pride to only use the very best ingredients you can find, then that's fine. But the quality of whatever you make can't depend on the ingredients alone."
    )
    |> next()
    |> mes("[Uwe]")
    |> mes("Speaking of ingredients,")
    |> mes("someone just gave me some")
    |> mes("Steel. Why don't you have 2 of")
    |> mes("them as my little way of saying, ''Welcome to Einbroch, cutie~!''")
    |> set_char_var(:ein_cook, 3)
    |> give_item(998, 2)
  end

  defp answer_skills(ctx) do
    ctx
    |> repeat_answer("Skills")
    |> mes("[Uwe]")
    |> mes("Well, skill alone isn't")
    |> mes("enough to make something")
    |> mes("great. You also need to put in")
    |> mes("the effort. You can't complain")
    |> mes("about not having enough skill")
    |> mes("when you slack off, right?")
    |> next()
    |> mes("[Uwe]")
    |> mes("You always need to invest")
    |> mes("time and effort to make your")
    |> mes("crafts stand out. Now, if you")
    |> mes("meet someone whose skill")
    |> mes("makes yours seem pathetic, driving you to improve yourself...")
    |> next()
    |> mes("[Uwe]")
    |> mes("Then by all means,")
    |> mes("feel free to follow")
    |> mes("your drive and improve")
    |> mes("your skills! Just don't")
    |> mes("fall back on your lack")
    |> mes("of skills as any excuse.")
    |> next()
    |> emveretarcon_gift(5)
  end

  defp answer_tools(ctx) do
    ctx
    |> repeat_answer("Tools")
    |> mes("[Uwe]")
    |> mes("Well, not just anyone can")
    |> mes("bake delicious cakes, even")
    |> mes("if they had the best oven in")
    |> mes("in the Schwarzwald Republic.")
    |> mes("And a child with all the tools")
    |> mes("couldn't put a sword together.")
    |> next()
    |> mes("[Uwe]")
    |> mes("Tools are helpful, but")
    |> mes("master craftsmen never blame")
    |> mes("their tools for their mistakes.")
    |> next()
    |> mes("[Uwe]")
    |> mes("Oh, and speaking of")
    |> mes("tools, I just received")
    |> mes("some new hammers today.")
    |> mes("Why don't you have one as")
    |> mes("my way of saying ''Welcome")
    |> mes("to Einbroch, sugar honey~''")
    |> set_char_var(:ein_cook, 7)
    |> give_item(613, 1)
  end

  defp repeat_answer(ctx, answer) do
    ctx
    |> mes("[Uwe]")
    |> mes("...")
    |> mes("......")
    |> mes("......#{answer}?")
    |> next()
  end

  defp emveretarcon_gift(ctx, cook) do
    ctx
    |> mes("[Uwe]")
    |> mes("Oooh, I just received")
    |> mes("some Emvertarcons today,")
    |> mes("so please have one, 'kay?")
    |> mes("Welcome to Einbroch, cutie~")
    |> set_char_var(:ein_cook, cook)
    |> give_item(1011, 1)
  end

  defp come_see_me(ctx) do
    ctx
    |> next()
    |> mes("[Uwe]")
    |> mes("Oh...")
    |> mes("And feel free to")
    |> mes("come and see me")
    |> mes("anytime, alright?")
    |> mes("So don't be shy")
    |> laugh_and_close(@giggles)
  end

  defp novice_smith_menu(ctx, cook) do
    {ctx, choice} =
      ctx
      |> mes("[Uwe]")
      |> mes("Oh! Hello again,")
      |> mes("you cutie adventurer.")
      |> mes("So tell me, what brings")
      |> mes("you here, #{char_name(ctx, 0)}?")
      |> next()
      |> select(["Ask about Cooking.", "Ask about Einbroch.", "Cancel."])

    case choice do
      1 -> novice_lesson(ctx, cook)
      2 -> einbroch_novice_smith(ctx)
      3 -> feel_free_to_visit(ctx)
      _ -> ctx
    end
  end

  defp novice_lesson(ctx, 1) do
    {ctx, choice} =
      ctx
      |> cooking_prompt()
      |> select(["Ingredients", "Skills", "Tools", "Cancel"])

    case choice do
      1 -> ingredients_talk(ctx)
      2 -> skills_talk(ctx, @chuckles)
      3 -> ctx |> tools_lesson() |> offer_hammers(11, false)
      4 -> feel_free_to_visit(ctx)
      _ -> ctx
    end
  end

  defp novice_lesson(ctx, 3) do
    {ctx, choice} =
      ctx
      |> cooking_prompt()
      |> select(["Heart", "Skills", "Tools", "Cancel."])

    case choice do
      1 -> heart_talk(ctx)
      2 -> skills_talk(ctx, @chuckles)
      3 -> ctx |> tools_lesson() |> offer_hammers(13, false)
      4 -> feel_free_to_visit(ctx)
      _ -> ctx
    end
  end

  defp novice_lesson(ctx, 5) do
    {ctx, choice} =
      ctx
      |> cooking_prompt()
      |> select(["Heart", "Ingredients", "Tools", "Cancel"])

    case choice do
      1 -> heart_talk(ctx)
      2 -> ingredients_talk(ctx)
      3 -> ctx |> tools_lesson() |> offer_hammers(15, true)
      4 -> feel_free_to_visit(ctx)
      _ -> ctx
    end
  end

  defp novice_lesson(ctx, 7) do
    {ctx, choice} =
      ctx
      |> cooking_prompt()
      |> select(["Heart", "Ingredients", "Skills", "Cancel."])

    case choice do
      1 ->
        heart_talk(ctx)

      2 ->
        ctx
        |> ingredients_lesson()
        |> set_char_var(:ein_cook, 17)
        |> next()
        |> fun_talk()
        |> laugh_and_close(@giggles)

      3 ->
        practice_talk(ctx)

      4 ->
        feel_free_to_visit(ctx)

      _ ->
        ctx
    end
  end

  defp novice_lesson(ctx, 9) do
    {ctx, choice} =
      ctx
      |> cooking_prompt()
      |> select(["Heart", "Ingredients", "Skills", "Tools", "Cancel."])

    case choice do
      1 -> heart_talk(ctx)
      2 -> ingredients_talk(ctx)
      3 -> skills_talk(ctx, @chuckles)
      4 -> ctx |> tools_lesson() |> offer_hammers(19, true)
      5 -> feel_free_to_visit(ctx)
      _ -> ctx
    end
  end

  # An even or negative ein_cook matches no lesson and falls through into the Einbroch talk.
  defp novice_lesson(ctx, _cook), do: einbroch_novice_smith(ctx)

  defp practice_talk(ctx) do
    ctx
    |> mes("[Uwe]")
    |> mes("'I couldn't do it cuz")
    |> mes("I'm not skillful with it.'")
    |> mes("It's the most foolish words in the world.")
    |> mes("There's only way for cooking.")
    |> mes("Practice, practice and try!.")
    |> next()
    |> mes("[Uwe]")
    |> mes("I know it's the easiest")
    |> mes("lame excuse for a person")
    |> mes("who never try hard anything.")
    |> next()
    |> mes("[Uwe]")
    |> mes("It's very same for a smith job.")
    |> mes("If you don't try to")
    |> mes("upgrade your skill,")
    |> mes("your works will be poor")
    |> mes("forever..")
    |> next()
    |> mes("[Uwe]")
    |> mes("But there's different way")
    |> mes("to blaim on your skill.")
    |> mes("When you face the higher wall,")
    |> mes("you can feel that you're not enough yet.")
    |> mes("Then you can reproch yourself and your skills.")
    |> mes("It's natural.")
    |> next()
    |> mes("[Uwe]")
    |> mes("After that ordeal, if you try harder")
    |> mes("and make your goal higher,")
    |> mes("every people around you will")
    |> mes("look up to you.")
    |> next()
    |> mes("[Uwe]")
    |> mes("Well, I hope")
    |> mes("you like them~")
    |> laugh_and_close(@giggles)
  end

  defp offer_hammers(ctx, next_cook, pause?) do
    ctx =
      ctx
      |> mes("[Uwe]")
      |> mes("Oh, while we're on")
      |> mes("the subject of tools,")
      |> mes("I just received some")
      |> mes("new hammers today.")
      |> mes("Would you like a couple?")
      |> next()

    if overweight?(ctx, 908, 50) do
      ctx
      |> mes("[Uwe]")
      |> mes("Mmmm...?")
      |> mes("You're holding too many")
      |> mes("things. I can't give you any")
      |> mes("hammers if you don't have")
      |> mes("room. Hurry, put your extra")
      |> mes("stuff in your Kafra Storage~")
      |> close()
    else
      ctx =
        ctx
        |> set_char_var(:ein_cook, next_cook)
        |> give_item(614, 1)
        |> give_item(613, 1)

      ctx = if pause?, do: next(ctx), else: ctx

      ctx
      |> mes("[Uwe]")
      |> mes("Well, I hope")
      |> mes("you like them~")
      |> laugh_and_close(@giggles)
    end
  end

  defp smith_menu(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Uwe]")
      |> mes("Oh, welcome back.")
      |> mes("So how's the weapon")
      |> mes("forging coming along?")
      |> next()
      |> select([
        "Talk about Cooking",
        "Talk about Einbroch",
        "Talk about Cooking Utensils",
        "Cancel"
      ])

    case choice do
      1 -> cooking_topics(ctx)
      2 -> einbroch_smith(ctx)
      3 -> jubilee_trade(ctx)
      4 -> feel_free_to_visit(ctx)
      _ -> ctx
    end
  end

  defp jubilee_trade(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Uwe]")
      |> mes("Cooking utensils?")
      |> mes("Well, they're usually")
      |> mes("made out of ^0000FFJubilee^000000,")
      |> mes("a crystallization dropped")
      |> mes("from mineral monsters.")
      |> next()
      |> mes("[Uwe]")
      |> mes("Jubilee is too soft")
      |> mes("to make weapons, but")
      |> mes("it conducts heat very well")
      |> mes("so it's perfect for making")
      |> mes("cooking utensils! *Tee hee~*")
      |> next()
      |> mes("[Uwe]")
      |> mes("That reminds me...")
      |> mes(
        "I need to make some new cooking utensils soon. Would you do me a favor and let me have some of your materials? Pretty pleeeeeease~"
      )
      |> next()
      |> mes("[Uwe]")
      |> mes("If you don't mind,")
      |> mes("would you please give me")
      |> mes("30 ^0000FFJubilee^000000 and 4 ^0000FFLarge Jellopy^000000.")
      |> mes("Then, I'll trade you 1 Coal for all of those. How does it sound?")
      |> next()
      |> select(["Sure.", "No, thanks."])

    case choice do
      1 ->
        if count_item(ctx, 7312) > 29 and count_item(ctx, 7126) > 3 do
          ctx
          |> delitem(7312, 30)
          |> delitem(7126, 4)
          |> give_item(1003, 1)
          |> mes("[Uwe]")
          |> mes("Hooray!")
          |> mes("Thank you")
          |> mes("^EEA9B8soooo^000000 much!")
          |> close()
        else
          ctx
          |> mes("[Uwe]")
          |> mes("Hmmm...?")
          |> mes("You don't have")
          |> mes("enough of them?")
          |> next()
          |> mes("[Uwe]")
          |> mes("Oh well, don't")
          |> mes("worry. You can take")
          |> mes("your time and bring")
          |> mes("that stuff whenever")
          |> mes(" you can, 'kay?")
          |> close()
        end

      2 ->
        ctx
        |> mes("[Uwe]")
        |> mes("I understand.")
        |> mes("You might not have all")
        |> mes("that Jubilee and Large Jellopy")
        |> mes("I'm asking for at the moment,")
        |> mes("anyway. But if you do get them, would visit me again, cutie?")
        |> close()

      _ ->
        ctx
    end
  end

  defp transcended_smith(ctx) do
    if whitesmith?(ctx) do
      ctx
      |> mes("[Uwe]")
      |> mes("Oooh...!")
      |> mes("Congratulations!")
      |> mes("You finally became")
      |> mes("a cutie MasterSmith!")
      |> next()
      |> mes("[Uwe]")
      |> mes("Mmmm...")
      |> mes("I know!")
      |> mes("Let's celebrate!")
      |> mes("Here sugar honey,")
      |> mes("have some of these")
      |> mes("cookies I just baked~")
      |> next()
      |> set_char_var(:ein_cook, 9)
      |> give_item(538, 5)
      |> mes("[Uwe]")
      |> mes("Okay, enjoy!")
      |> mes("I hope you have")
      |> mes("a good time smithing!")
      |> close()
    else
      ctx
      |> mes("[Uwe]")
      |> mes("Hmmm?")
      |> mes("Oh, it's you~")
      |> mes("I'm sorry, I was")
      |> mes("just thinking about")
      |> mes("something but now I just")
      |> mes("lost my train of thought.")
      |> set_char_var(:ein_cook, 219)
      |> next()
      |> mes("[Uwe]")
      |> mes("What was I going")
      |> mes("to say? Hmm, I can't")
      |> mes("quite remember. Oh well,")
      |> mes("I'll see you later, cutie~")
      |> close()
    end
  end

  defp former_smith(ctx, cook) do
    ctx =
      cond do
        cook > 299 -> hello_again(ctx)
        cook > 199 -> recognize_transcended(ctx, 100)
        cook > 99 -> recognize_transcended(ctx, 0)
        true -> recognize_transcended(ctx, 300)
      end

    {ctx, choice} = select(ctx, ["Ask about Einbroch.", "Ask about Cooking.", "Cancel."])

    case choice do
      1 -> einbroch_visitor(ctx)
      2 -> cooking_topics(ctx)
      3 -> feel_free_to_visit(ctx)
      _ -> ctx
    end
  end

  defp recognize_transcended(ctx, cook_bonus) do
    ctx =
      ctx
      |> mes("[Uwe]")
      |> mes("Hm...?")
      |> mes("I never forget a face,")
      |> mes("but somehow I feel like")
      |> mes("we've met somewhere before...")
      |> next()

    ctx = if cook_bonus > 0, do: advance_cook(ctx, cook_bonus), else: ctx
    gender = if sex(ctx) == 1, do: "boy", else: "girl"

    ctx
    |> mes("[Uwe]")
    |> mes("Ah...!")
    |> mes("I have it!")
    |> mes("#{char_name(ctx, 0)}!")
    |> mes("Yes, now I remember you.")
    |> mes("Decided to transcend, eh?")
    |> next()
    |> mes("[Uwe]")
    |> mes("What brings to")
    |> mes("me, you ^EEA9B8naughty #{gender}^000000?")
    |> next()
  end

  defp apprentice(ctx, favor) do
    cond do
      favor > 199 -> finished_apprentice(ctx)
      favor > 99 -> jellopy_apprentice(ctx)
      true -> ctx |> hello_cutie() |> stranger_menu(&bye_cutie/1)
    end
  end

  defp finished_apprentice(ctx) do
    {ctx, choice} =
      ctx
      |> hello_again()
      |> select([
        "Talk about Einbroch.",
        "Ask him to forge a Weapon.",
        "Talk about Cooking.",
        "Cancel."
      ])

    case choice do
      1 -> einbroch_visitor(ctx)
      2 -> refuse_forging(ctx)
      3 -> cooking_topics(ctx)
      4 -> take_care_sugar(ctx)
      _ -> ctx
    end
  end

  defp jellopy_apprentice(ctx) do
    {ctx, choice} =
      ctx
      |> jellopy_reminder()
      |> select([
        "Talk about Einbroch.",
        "Ask him to forge a Weapon.",
        "Give him the Materials.",
        "Cancel."
      ])

    case choice do
      1 -> einbroch_visitor(ctx)
      2 -> refuse_forging(ctx)
      3 -> bring_jellopy(ctx)
      4 -> take_care_sugar(ctx)
      _ -> ctx
    end
  end

  defp bring_jellopy(ctx) do
    jellopy = count_item(ctx, 7126)

    if jellopy > 5 do
      ctx
      |> mes("[Uwe]")
      |> mes("Thank you ^EEA9B8so^000000 much!")
      |> mes("Here's the Coal I promised~")
      |> delitem(7126, 6)
      |> advance_cook(100)
      |> give_item(1003, 1)
      |> next()
      |> beginner_advice()
    else
      ctx = ctx |> mes("[Uwe]") |> mes("Huh...?")

      ctx =
        if jellopy == 0 do
          ctx |> mes("You brought") |> mes("none at all...?")
        else
          ctx |> mes("This isn't enough") |> mes("Large Jellopy...!")
        end

      ctx
      |> mes("Next time, be sure")
      |> mes("to bring 6 Large Jellopy,")
      |> mes("okay? Don't forget, cutie~")
      |> close()
    end
  end

  defp beginner_advice(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Uwe]")
      |> mes(
        "Now, I can't teach you everything about cooking, but I will give you some good advice for beginners."
      )
      |> mes("I hope you pay attention, sugar")
      |> mes("honey. Now what would you like")
      |> mes("to hear more about? Hmm...?")
      |> next()
      |> select(["Heart", "Materials", "Skills", "Tools", "Cancel."])

    case choice do
      1 -> heart_talk(ctx)
      2 -> ingredients_talk(ctx)
      3 -> skills_talk(ctx, @chuckles)
      4 -> tools_talk(ctx)
      5 -> take_care_sugar(ctx)
      _ -> ctx
    end
  end

  defp first_visit(ctx) do
    {ctx, choice} =
      ctx
      |> cooking_is_a_joy()
      |> select(["Um, isn't this a forge?", "Ignore him."])

    case choice do
      1 ->
        ctx
        |> mes("[Uwe]")
        |> set_char_var(:ein_cook, 1000)
        |> forge_introduction()
        |> mes("[Uwe]")
        |> mes("So, how can")
        |> mes("I help you, you")
        |> mes("adooooooooorable")
        |> mes(if sex(ctx) == 1, do: "hunk of a man?", else: "womanly woman?")
        |> next()
        |> stranger_menu(&bye_sugar/1)

      2 ->
        ctx
        |> mes("[Uwe]")
        |> mes("Cooking begins with")
        |> mes("fire and ends with fire.")
        |> mes("There's a certain art to")
        |> mes("creating fine, delicious")
        |> mes("foods to delight the palate~")
        |> close()

      _ ->
        ctx
    end
  end

  defp stranger_menu(ctx, farewell) do
    {ctx, choice} =
      select(ctx, [
        "Talk about Einbroch.",
        "Ask him to forge a Weapon.",
        "Master, I want to learn cooking.",
        "Cancel."
      ])

    case choice do
      1 -> einbroch_visitor(ctx)
      2 -> refuse_forging(ctx)
      3 -> cooking_tuition(ctx)
      4 -> farewell.(ctx)
      _ -> ctx
    end
  end

  defp cooking_tuition(ctx) do
    ctx
    |> mes("[Uwe]")
    |> mes("Mm...?")
    |> mes("Did you just")
    |> mes("say that you")
    |> mes("want to learn")
    |> mes("the art of cooking?")
    |> next()
    |> mes("[Uwe]")
    |> mes("I'm sorry, but I can't")
    |> mes("really give culinary")
    |> mes("lessons. But I will")
    |> mes("give good advice for")
    |> mes("hopeful beginners.")
    |> next()
    |> mes("[Uwe]")
    |> mes("Now...")
    |> mes("For your tuition")
    |> mes("I'll need-- Gosh,")
    |> mes("there's just so many")
    |> mes("things. Get some paper,")
    |> mes("and a pen for this list...")
    |> next()
    |> advance_cook(100)
    |> mes("[Uwe]")
    |> mes("Just kidding!")
    |> mes("^333333*Titter~*^000000 I don't need")
    |> mes("much to make some")
    |> mes("cooking utensils. Bring")
    |> mes("6 ^0000FFLarge Jellopy^000000. That's it!")
    |> next()
    |> mes("[Uwe]")
    |> mes("In return, I will give you")
    |> mes("1 Coal and some useful")
    |> mes("cooking advice for novices.")
    |> mes("I give this advice for free to")
    |> mes("my smithing colleages, though...")
    |> next()
    |> mes("[Uwe]")
    |> mes("Why ^EEA9B8don't^000000 you")
    |> mes("become a Blacksmith?")
    |> mes("I'm much more confident")
    |> mes("in that field. ^333333*Tee hee~*^000000")
    |> next()
    |> mes("[Uwe]")
    |> mes("Well, I'll be")
    |> mes("waiting right")
    |> mes("here until you")
    |> mes("come back.")
    |> laugh_and_close(@giggles)
  end

  defp refuse_forging(ctx) do
    ctx
    |> mes("[Uwe]")
    |> mes("Well...")
    |> mes("I actually just")
    |> mes("do smithing work")
    |> mes("to create my own")
    |> mes("cooking tools.")
    |> next()
    |> mes("[Uwe]")
    |> mes("Oh, I understand")
    |> mes("that somebody needs")
    |> mes("to fight the monsters,")
    |> mes("but I'm the wrong person")
    |> mes("to ask for forging weapons.")
    |> mes("I... am a strict pacifist~")
    |> next()
    |> mes("[Uwe]")
    |> mes("Just go look")
    |> mes("around for a little")
    |> mes("bit, I'm sure you'll")
    |> mes("find a Blacksmith")
    |> mes("who's willing to forge")
    |> mes("you a good weapon~")
    |> close()
  end

  defp cooking_topics(ctx) do
    {ctx, choice} =
      ctx
      |> cooking_prompt()
      |> select(["Heart", "Ingredients", "Skills", "Tools", "Cancel."])

    case choice do
      1 -> heart_talk(ctx)
      2 -> ingredients_talk(ctx)
      3 -> skills_talk(ctx, @giggles)
      4 -> tools_talk(ctx)
      5 -> feel_free_to_visit(ctx)
      _ -> ctx
    end
  end

  defp cooking_prompt(ctx) do
    ctx
    |> mes("[Uwe]")
    |> mes("Ooh, cooking!")
    |> mes("So what did you")
    |> mes("want to ask me...?")
    |> next()
  end

  defp heart_talk(ctx) do
    ctx
    |> mes("[Uwe]")
    |> mes("Ah, heart. Just like forging,")
    |> mes("you need passion and desire")
    |> mes("to create something special.")
    |> mes("Every smith and cook knows that")
    |> mes("you can do anything if you have")
    |> mes("the will and the commitment.")
    |> next()
    |> mes("[Uwe]")
    |> mes("Well, that's all")
    |> mes("I really have to")
    |> mes("say about that. But")
    |> mes("come back and chat")
    |> mes("whenever you please.")
    |> laugh_and_close(@giggles)
  end

  defp ingredients_talk(ctx) do
    ctx
    |> ingredients_lesson()
    |> next()
    |> fun_talk()
    |> laugh_and_close(@giggles)
  end

  defp ingredients_lesson(ctx) do
    ctx
    |> mes("[Uwe]")
    |> mes("Now for beginners,")
    |> mes("learning to select")
    |> mes("and use ingredients")
    |> mes("is one of the most")
    |> mes("important fundamentals.")
    |> next()
    |> mes("[Uwe]")
    |> mes("Cooking is like forging")
    |> mes("since specific ingredients")
    |> mes("are needed to make specialty")
    |> mes("items or dishes. You can't just")
    |> mes("skip them if you really need")
    |> mes("them, right? Right!")
    |> next()
    |> mes("[Uwe]")
    |> mes("Once you make up your")
    |> mes("mind to do something,")
    |> mes("focus on finishing it, 'kay?")
    |> mes("Never cut corners and always")
    |> mes("dedicate yourself to make the")
    |> mes("very best finished product~")
  end

  defp skills_talk(ctx, laughs) do
    ctx
    |> mes("[Uwe]")
    |> mes("When you're beginning to learn")
    |> mes("skills, you can't let yourself be discouraged! Practice makes")
    |> mes("perfect, you know? But never")
    |> mes("use your lack of skills as an")
    |> mes("excuse if you happen to fail...")
    |> next()
    |> mes("[Uwe]")
    |> mes("Effort is also an essential")
    |> mes("in forging and cooking! Now,")
    |> mes("on the other hand, if you put")
    |> mes(
      "in all the effort but didn't learn any of the skills, you'll still get nowhere fast, right? Right!"
    )
    |> next()
    |> mes("[Uwe]")
    |> mes("The key is to always")
    |> mes("give 100% effort and work")
    |> mes("on improving your skills.")
    |> mes("Before you know it, you'll")
    |> mes("be a respected master!")
    |> next()
    |> fun_talk()
    |> laugh_and_close(laughs)
  end

  defp tools_talk(ctx) do
    ctx
    |> tools_lesson()
    |> fun_talk()
    |> laugh_and_close(@giggles)
  end

  defp tools_lesson(ctx) do
    ctx
    |> mes("[Uwe]")
    |> mes("Cooking is a little")
    |> mes("easier if you have")
    |> mes("nicer tools to use,")
    |> mes("but that's it. Tools by")
    |> mes("themselves can't make")
    |> mes("just anybody a master.")
    |> next()
    |> mes("[Uwe]")
    |> mes("In the end, the best")
    |> mes("tools are the ones you're")
    |> mes("most comfortable with using.")
    |> mes("In fact, I still use the old knife I used back when I was just")
    |> mes("a little novice chef~")
    |> next()
  end

  defp fun_talk(ctx) do
    ctx
    |> mes("[Uwe]")
    |> mes("Well, that was")
    |> mes("a fun talk. Come")
    |> mes("back and visit, 'kay?")
    |> mes("I'll miss you until")
    |> mes("the next time~")
  end

  defp einbroch_novice_smith(ctx) do
    {ctx, choice} =
      ctx
      |> einbroch_history()
      |> select(["Then why are you here?", "But I like the city life~"])

    case choice do
      1 ->
        ctx
        |> mes("[Uwe]")
        |> mes("Well, sugar honey,")
        |> mes("I've been waiting for")
        |> mes("someone. But... It looks")
        |> mes("like that person won't be")
        |> mes("coming back anyway.")
        |> next()
        |> mes("[Uwe]")
        |> mes("Oooh, but let's not talk")
        |> mes("about that. Next time you")
        |> mes("drop by, we'll talk about")
        |> mes("something more fun, 'kay?")
        |> close()

      2 ->
        ctx
        |> mes("[Uwe]")
        |> mes("Big cities can be nice,")
        |> mes("but you never get to enjoy")
        |> mes("the sensation of stepping")
        |> mes("barefoot through the grass,")
        |> mes("or the magnificent sight of")
        |> mes("the shining stars at night.")
        |> next()
        |> mes("[Uwe]")
        |> mes("And the people who live")
        |> mes("in the cities can be so")
        |> mes("uptight! I've known more")
        |> mes("than a few who look down")
        |> mes("on people from smaller towns.")
        |> next()
        |> mes("[Uwe]")
        |> mes("It's sad to see some")
        |> mes("people will always be")
        |> mes("that ignorant. I... I just")
        |> mes("can't believe those people")
        |> mes("can be sooo close minded!")
        |> next()
        |> mes("[Uwe]")
        |> mes("Oh...!")
        |> mes("I'm sorry, I guess")
        |> mes("I went a little overboard.")
        |> mes("^666666*Titter*^000000 Next time you drop")
        |> mes("by, we'll talk about something")
        |> mes("more fun, 'kay? Buhbye~")
        |> close()

      _ ->
        ctx
    end
  end

  defp einbroch_smith(ctx) do
    {ctx, choice} =
      ctx
      |> einbroch_history()
      |> select(["Then why are you here?", "But I like the city life~"])

    case choice do
      1 ->
        ctx
        |> mes("[Uwe]")
        |> mes("Well, sugar honey,")
        |> mes(
          "I've been waiting for someone. But... It looks like that person won't be coming back anyway."
        )
        |> next()
        |> mes("[Uwe]")
        |> mes(
          "Oooh, but let's not talk about that. Next time you drop by, we'll talk about something more fun, 'kay? Buhbye~"
        )
        |> close()

      2 ->
        ctx
        |> mes("[Uwe]")
        |> mes(
          "Well, big cities are nice, but you never get to enjoy the sensation of stepping barefoot through the grass, or the clear sight of the stars at night."
        )
        |> next()
        |> mes("[Uwe]")
        |> mes(
          "And the people who live in cities can be so uptight! I've known more than a few who look down on people who live in smaller towns."
        )
        |> next()
        |> mes("[Uwe]")
        |> mes(
          "It's sad to see some people will always be that ignorant. I... I just can't believe people can be sooo close minded!"
        )
        |> next()
        |> mes("[Uwe]")
        |> mes("Oh...!")
        |> mes(
          "I'm sorry, I guess I went a little overboard. ^666666*Titter*^000000 Next time you drop by, we'll talk about something more fun, 'kay? Buhbye~"
        )
        |> close()

      _ ->
        ctx
    end
  end

  defp einbroch_visitor(ctx) do
    {ctx, choice} =
      ctx
      |> einbroch_history()
      |> select(["Then why are you here?", "I won't. Thanks for the advice."])

    case choice do
      1 ->
        ctx
        |> mes("[Uwe]")
        |> mes("Well, I have some")
        |> mes("precious memories of")
        |> mes("this place. Once, there was")
        |> mes("a man who lived here who")
        |> mes("was just like a father to me.")
        |> next()
        |> mes("[Uwe]")
        |> mes("Oh, but I'm sure that")
        |> mes("you don't want to hear")
        |> mes("about that. Next time you")
        |> mes("drop by, we'll talk about")
        |> mes("something more fun, 'kay?")
        |> mes("Buhbye for now, cutie~")
        |> close()

      2 ->
        ctx
        |> mes("[Uwe]")
        |> mes("Oh, that is such")
        |> mes("a good decision,")
        |> mes("sugar honey! Oh, you")
        |> mes("cutie adventurers are")
        |> mes("so precious, so lovable.")
        |> mes("^333333*Tee hee hee~*^000000")
        |> next()
        |> fun_talk()
        |> close()

      _ ->
        ctx
    end
  end

  defp einbroch_history(ctx) do
    ctx
    |> mes("[Uwe]")
    |> mes("Einbroch was originally")
    |> mes("built to support Einbech's")
    |> mes("mining efforts. Because it's")
    |> mes("small and crowded with people,")
    |> mes("there's no room to build the ore refining factories over there.")
    |> next()
    |> mes("[Uwe]")
    |> mes("Since Einbroch used to be")
    |> mes("an empty lot, it was perfect")
    |> mes("for building factories. That's")
    |> mes("what my grandfather told me a")
    |> mes("long time ago. Anyway, Einbroch quickly grew into a major city.")
    |> next()
    |> mes("[Uwe]")
    |> mes("Now people think that this")
    |> mes("city was never planned to be")
    |> mes("just an extension of Einbech.")
    |> mes("See that rampart over there?")
    |> mes("It doesn't connect to Einbech at all! No protection for them...")
    |> next()
    |> mes("[Uwe]")
    |> mes("It's like the government")
    |> mes("lost all interest in Einbech.")
    |> mes("Even the miners there have")
    |> mes("been moving here to work in ")
    |> mes("the factories. But more people hasn't made this city more lively.")
    |> next()
    |> mes("[Uwe]")
    |> mes("Einbroch may look modern")
    |> mes("and exciting now, but soon")
    |> mes("you'll see that there's no sign")
    |> mes("of warmth or life. So... Just don't live here in your old age.")
    |> next()
  end

  defp cooking_is_a_joy(ctx) do
    ctx
    |> mes("[Uwe]")
    |> mes("Cooking is such a joy~!")
    |> mes("The scents, the flavors, the sensation of sheer ^EEA9B8satiation^000000...")
    |> next()
  end

  defp forge_introduction(ctx) do
    ctx
    |> mes("Is this a forge?")
    |> mes("Oh, sugar honey,")
    |> mes("you haven't been here")
    |> mes("before, haven't you?")
    |> next()
    |> mes("[Uwe]")
    |> mes("My name is Uwe Kleine")
    |> mes("and this is my forge~! I am")
    |> mes("the most elegant Blacksmith")
    |> mes("and the best chef here in the")
    |> mes("Schwarzwald Republic~")
    |> next()
  end

  defp long_time_no_see(ctx) do
    ctx
    |> mes("[Uwe]")
    |> mes("Oh hello hello~")
    |> mes("It's been a long")
    |> mes("time since we've talked,")
    |> mes("you cutie adventurer~")
    |> next()
  end

  defp jellopy_reminder(ctx) do
    ctx
    |> long_time_no_see()
    |> mes("[Uwe]")
    |> mes("So, sugar honey,")
    |> mes("how is it going with")
    |> mes("the little favor I asked")
    |> mes("you about last time?")
    |> mes("Did you already forget")
    |> mes("the 6 Large Jellopy?")
    |> next()
  end

  defp hello_again(ctx) do
    ctx
    |> mes("[Uwe]")
    |> mes("Ah, hello again,")
    |> mes("cutie adventurer.")
    |> mes("How can I help you?")
    |> next()
  end

  defp hello_cutie(ctx) do
    ctx
    |> mes("[Uwe]")
    |> mes("Hello, cutie~")
    |> mes("How can I help you?")
    |> next()
  end

  defp feel_free_to_visit(ctx) do
    ctx
    |> mes("[Uwe]")
    |> mes("Oh...?")
    |> mes("Well, feel")
    |> mes("free to visit")
    |> mes("me whenever")
    |> mes("you want, 'kay?")
    |> close()
  end

  defp take_care_sugar(ctx) do
    ctx
    |> mes("[Uwe]")
    |> mes("Alright then,")
    |> mes("sugar honey.")
    |> mes("Take care~")
    |> mes("Hohohohoho~")
    |> close()
  end

  defp bye_cutie(ctx) do
    ctx
    |> mes("[Uwe]")
    |> mes("Take care,")
    |> mes("cutie adventurer!")
    |> mes("Hohoho!")
    |> close()
  end

  defp bye_sugar(ctx) do
    ctx
    |> mes("[Uwe]")
    |> mes("Take care,")
    |> mes("sugar honey~")
    |> mes("Ho ho ho!")
    |> close()
  end

  defp too_heavy(ctx) do
    ctx
    |> mes("[Uwe]")
    |> too_heavy_lines()
    |> close()
  end

  defp too_heavy_lines(ctx) do
    ctx
    |> mes("Oh, I was going to give")
    |> mes("you a little something,")
    |> mes("but you've carrying too")
    |> mes("many things. Why don't")
    |> mes("you put some of it away")
    |> mes("in your Kafra Storage?")
  end

  defp naughty(ctx, you) do
    gender = if sex(ctx) == 1, do: "boy", else: "girl"
    mes(ctx, "#{you} ^EEA9B8naughty #{gender}^000000.")
  end

  defp laugh_and_close(ctx, laughs), do: ctx |> mes(Enum.random(laughs)) |> close()

  defp advance_cook(ctx, amount),
    do: set_char_var(ctx, :ein_cook, get_char_var(ctx, :ein_cook, 0) + amount)

  defp overweight?(ctx, item_id, amount), do: checkweight(ctx, [{item_id, amount}]) == 0

  defp whitesmith?(ctx), do: Rathena.job_id(class(ctx)) == Rathena.job_id(:whitesmith)
end
