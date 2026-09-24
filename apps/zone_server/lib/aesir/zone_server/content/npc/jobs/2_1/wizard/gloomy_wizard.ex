defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Wizard.GloomyWizard do
  @moduledoc """
  Raulel Asparagus runs the written test and sends candidates to the battle test of the
  Wizard job change quest.

  ## Behavior

  - Turns away non-Mages; sends Novices back to Geffen.
  - Gives Mages who passed the item test a random ten-question written test on magic,
    monsters, or Mages; 80 points or more on a retake, or 90 or more on the first try, passes.
  - Explains the elemental room battle test, sets the Geffen save point, and warps
    candidates into the arena.
  - Makes repeat battle test candidates pass a five-question quiz first, and passes those who
    keep failing once they bring a Worn Out Scroll.

  ## Credits

  - Original from rAthena, authors and Contributors
    - yoshiki
    - kobra_k88
    - Lupus
    - L0ne_W0lf
    - Yommy
    - SoulBlaker
    - Kisuka
    - Vali
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "gef_tower",
        x: 102,
        y: 24,
        dir: 2,
        sprite: 735,
        name: "Gloomy Wizard",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @magic_questions [
    {"1. Which of the following is not necessary to learn Fire Wall?",
     ["Fire Bolt Lv 4", "Fire Ball Lv 5", "Sight Lv 1", "Napalm Beat Lv 4"], 4},
    {"2. Regaurdless of it's previous attribute, What does the monster's attribute change to when you cast Frost Diver on it?",
     ["Water", "Earth", "Fire", "Wind"], 1},
    {"3. When you completely master Napalm Beat, what is the ratio of the increased MATK using that spell?",
     ["1.6 times", "1.7 times", "2 times", "20 times"], 2},
    {"4. What item do you need when casting Stone Curse?",
     ["Red Blood", "Blue Gemstone", "Yellow Gemstone", "Red Gemstone"], 4},
    {"5. Which of the following is not required to master Safety Wall?",
     [
       "Napalm Beat Lv 4",
       "Soul Strike Lv 5",
       "Increase SP Recovery Lv 6",
       "Safety Wall Lv 7"
     ], 3},
    {"6. Without the INT bonus, what amount of SP is recovered every 10 seconds when you have learned Increase SP Recovery Lv 7?",
     ["14", "21", "28", "35"], 2},
    {"7. Using Energy Coat, when you have 50% of your SP remaining, how much SP is used when hit, and what percentage is damage reduced by?",
     ["Damage 18% SP1.5%", "Damage 18% SP2%", "Damage 24% SP1.5%", "Damage 24% SP2%"], 2},
    {"8. How much SP is consumed and how many times can you avoid attacks when using Safety Wall Lv 6?",
     ["SP 40, 6 times", "SP 35, 6 times", "SP 40, 7 times", "SP 35, 7 times"], 3},
    {"9. How much SP is needed when using Lv 10 Thunderstorm?", ["84", "74", "64", "54"], 2},
    {"10. Which skill is most useful training in the Byalan Dungeon?",
     ["Lightning Bolt", "Fire Bolt", "Cold Bolt", "Sight"], 1}
  ]

  @monster_questions [
    {"1. Which monster can you obtain a slotted Guard from?",
     ["Thief Bug", "PecoPeco", "Pupa", "Kobold (Hammer)"], 3},
    {"2. Which of the following is the easiest monster for a low level Mage to hunt?",
     ["Flora", "Giearth", "Golem", "Myst"], 1},
    {"3. Which monster will not be affected by Stone Curse?",
     ["Elder Willow", "Evil Druid", "Magnolia", "Marc"], 2},
    {"4. When attacking a Lv 3 water attribute monster with a wind attribute weapon, what is the damage percentage?",
     ["125%", "150%", "175%", "200%"], 4},
    {"5. If a Baby Desert Wolf and a Familiar fought, which one would win?",
     ["Baby Desert Wolf", "Familiar", "Neither", "I don't know"], 1},
    {"6. Which of the following cannot be a Cute Pet?",
     ["Poporing", "Roda Frog", "Smokie", "Poison Spore"], 2},
    {"7. Choose the monster that is weak against a fire attribute attack.",
     ["Dagger Goblin", "Mace Goblin", "Morningstar Goblin", "Hammer Goblin"], 4},
    {"8. Which of the following has the highest defense?",
     ["Horn", "Chonchon", "Andre", "Caramel"], 4},
    {"9. Choose the monster that's of a different species.",
     ["Poring", "Mastering", "Ghostring", "Spore"], 3},
    {"10. Which of the following is not an Undead monster?",
     ["Drake", "Megalodon", "Deviace", "Khalitzburg"], 3}
  ]

  @mage_questions [
    {"1. Which stat is the most important for a Mage?", ["INT", "AGI", "DEX", "VIT"], 1},
    {"2. Which attribute does not have a 'Bolt' type attack?", ["Water", "Earth", "Fire", "Wind"],
     2},
    {"3. Choose the one that does not relate to a Mage.",
     [
       "Weak physical strength.",
       "Attacks at a distance.",
       "Good at selling stuff.",
       "Magic Defense is high."
     ], 3},
    {"4. Which town is the home of Mages?", ["Prontera", "Morocc", "Alberta", "Geffen"], 4},
    {"5. Which of the following cards has nothing to do with INT?",
     [
       "Andre Egg Card",
       "Soldier Andre Card",
       "Baby Desert Wolf Card",
       "Elder Willow Card"
     ], 2},
    {"6. What is the Mage good at compared to other job classes?",
     [
       "Exceptional Vocal Ability",
       "Exceptional Acting Ability",
       "Exceptional Dance Skills",
       "Exceptional Magic Skills"
     ], 4},
    {"7. What is the INT bonus at Job Lv 40 for a Mage?", ["8", "7", "6", "5"], 4},
    {"8. Which item can a Mage not equip?", ["Knife", "Boys Cap", "Sandle", "Eye of Dullahan"],
     2},
    {"9. Which of the following is the catalyst when making the Mage test solution 3?",
     ["Blue Gemstone", "Red Gemstone", "Yellow Gemstone", "Red Blood"], 1},
    {"10. Which card is irrelevant to magic?",
     ["Marduk Card", "Magnolia Card", "Willow Card", "Maya Card"], 2}
  ]

  @battle_retest_questions [
    {"1. Choose the monster with a different attribute than the others.",
     ["Mantis", "Cornutus", "Giearth", "Caramel"], 2},
    {"2. Choose the monster that is not a looting one.",
     ["Yoyo", "Magnolia", "Metaller", "Zerom"], 4},
    {"3. Which of these monsters does not recognize casting?",
     ["Marina", "Vitata", "Scorpion", "Giearth"], 1},
    {"4. Choose the spell that would be efficient against a Marine Sphere.",
     ["Cold Bolt", "Fire Bolt", "Lightning Bolt", "Stone Curse"], 3},
    {"5. Choose the monster that can move.",
     ["Hydra", "Madragora", "Greatest General", "Frilldora"], 4}
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if Rathena.job_id(base_job(ctx)) != Rathena.job_id(:mage) do
      turn_away_non_mage(ctx)
    else
      quest_stage(ctx, get_char_var(ctx, :WIZ_Q, 0))
    end
  end

  defp turn_away_non_mage(ctx) do
    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:wizard) ->
        advise_wizard(ctx)

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:priest) ->
        ctx
        |> mes("[Raulel]")
        |> mes("Go away, one who works for the Church!")
        |> mes("Magic repels Holy power, jeez...your messing up my aura.")
        |> next()
        |> mes("[Raulel]")
        |> mes("And plus, *cough* *cough* my health isn't all that good right now either...")
        |> mes("Don't come any closer, just leave!")
        |> close()

      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:novice) ->
        ctx
        |> mes("[Raulel]")
        |> mes("Why did a little one like you come here?!")
        |> mes("Get lost! ~Hahahahaha")
        |> close()
        |> warp("geffen", 120, 110)

      true ->
        ctx
        |> mes("[Raulel]")
        |> mes(
          "*sneeze* *cough* Oooowww...my entire body is in pain. I feel like I'm trapped in a tub of ice water!"
        )
        |> next()
        |> mes("[Raulel]")
        |> mes("What do you want? Jeez...just get lost, won't you?")
        |> close()
    end
  end

  defp advise_wizard(ctx) do
    ctx =
      ctx
      |> mes("[Raulel]")
      |> mes("*Cough* *cough* what do you want?")
      |> mes(
        "If you are a person that uses magic, then you need to make sure you are well informed about it."
      )
      |> next()
      |> mes("[Raulel]")
      |> mes(
        "Don't live dishonestly, or impolitely, or else one day you'll be caught in a spell you can't control, and BOOM, your dead!"
      )

    if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
      ctx
      |> mes("If you don't want that to happen, then learn how to use spells properly!")
      |> next()
      |> mes("[Raulel]")
      |> mes(
        "You may live life crippled if you get obsessed with the love of Greater Magic. ~haha"
      )
      |> close()
    else
      ctx
      |> mes(
        "So learn how to use magic properly, or you would just be better off giving up on using magic."
      )
      |> next()
      |> mes("[Raulel]")
      |> mes("If you don't want that, go hit on a guy or something! ~Hahahaha")
      |> mes("If you don't pay attention to yourself, you'll be engulfed by magic one day...")
      |> close()
    end
  end

  defp quest_stage(ctx, 0) do
    ctx
    |> mes("[Raulel]")
    |> mes(
      "*cough* *cough* *sneeze* I don't know who you are and what you do, but I don't have any business with you."
    )
    |> next()
    |> mes("[Raulel]")
    |> mes("Go away! Get lost!")
    |> close()
  end

  defp quest_stage(ctx, stage) when stage in [1, 2] do
    ctx
    |> mes("[Raulel]")
    |> mes("Hahahaha~ You're the one that wants to become a Wizard?!")
    |> next()
    |> mes("[Raulel]")
    |> mes(
      "*sneeze* If you just lived as you were, all you'd have to do was hunt a little and live the easy life..."
    )
    |> next()
    |> mes("[Raulel]")
    |> mes("*Cough* *cough* Let's see how well you live as a Wizard. ~Hahahahhaha")
    |> close()
  end

  defp quest_stage(ctx, 3) do
    {ctx, choice} =
      ctx
      |> mes("[Raulel]")
      |> mes("*Cough* *cough*...You must've passed the first test.")
      |> mes(
        "Ok, I'm the Wizard in charge of your testing from now on. My name is 'Raulel Asparagus'."
      )
      |> next()
      |> mes("[Raulel]")
      |> mes(
        "*sneeze* It's not too late yet, wouldn't you rather just go back to town and enjoy the peaceful life?"
      )
      |> next()
      |> mes("[Raulel]")
      |> mes("Hahahaha~ You don't know how dangerous it is...to deal with Greater Magic.")
      |> next()
      |> select(["I want to live as a normal Mage.", "I would like to continue with the tests."])

    if choice == 1 do
      ctx
      |> mes("[Raulel]")
      |> mes("Hahaha~ *sneeze* Good choice...*cough* *cough*~")
      |> mes(
        "Best not to even dream about life as a Wizard. Graa...Greaa...*sneeze* Greater Magic wasn't meant for humans to use!"
      )
      |> next()
      |> mes("[Raulel]")
      |> mes("Leave the top of this tower quietly and don't ever look back.")
      |> mes("Just live peacefully with the powers that you have right now.")
      |> close()
    else
      ctx
      |> mes("[Raulel]")
      |> mes("*sneeze* Hahahaha~ Now there's a foolish one here!")
      |> mes(
        "Well then, let's see how good you are. *cough* I want to see this with my own two eyes!"
      )
      |> next()
      |> mes("[Raulel]")
      |> mes("*sneeze* Then let's begin the test!")
      |> mes("If you don't answer them all correctly, you fail. Hahahahahahahahaha~")
      |> next()
      |> mes("[Raulel]")
      |> mes("I'll give you 10 questions so give me the right answers.")
      |> mes("If you get something wrong, I won't tell you what it is!")
      |> start_written_test_quest()
      |> next()
      |> mes("[Raulel]")
      |> mes("*Cough* *cough* Then here go the questions!")
      |> take_written_test()
    end
  end

  defp quest_stage(ctx, 4) do
    {ctx, choice} =
      ctx
      |> mes("[Raulel]")
      |> mes("Hahahaha~ Are you that desperate? *sneeze* What a pain in the arse...")
      |> next()
      |> mes("[Raulel]")
      |> mes(
        "Since you don't want to settle for a stable and peaceful life, I'll give you another chance..."
      )
      |> next()
      |> mes("[Raulel]")
      |> mes(
        "If you miss one single question, then just give up. You wouldn't have any talent in being a Wizard! ~Hahahahaha"
      )
      |> next()
      |> select([
        "Because of you, I want to live as a normal Mage now.",
        "I would like to continue with the tests."
      ])

    if choice == 1 do
      ctx
      |> mes("[Raulel]")
      |> mes(
        "Hahahaha~ Surprising, comming from you, that's a very wise choice...*cough* *cough*"
      )
      |> mes(
        "If i were you, i would never, ever dream of becoming a Wizard again. Gre...Greaa...*sneeze* Greater Magic wasn't meant for humans to use."
      )
      |> next()
      |> mes("[Raulel]")
      |> mes("Just leave the top of this tower quietly and never look back.")
      |> mes("Live peacefully with the powers that you have right now.")
      |> close()
    else
      ctx
      |> mes("[Raulel]")
      |> mes("Hahahahahahaha~ Now there's a foolish one right here!")
      |> mes(
        "Well then, let's see just how good you can be! *sneeze* I want to see this with my own two eyes."
      )
      |> next()
      |> mes("[Raulel]")
      |> mes("Then let's begin the test!")
      |> take_written_test()
    end
  end

  defp quest_stage(ctx, 5) do
    {ctx, choice} =
      ctx
      |> mes("[Raulel]")
      |> mes("Ok, hope you got plenty of rest. Hahahahahah~")
      |> mes("Then let's begin the last test.")
      |> next()
      |> mes("[Raulel]")
      |> mes(
        "Should I explain a little about this final test? It is difficult, I will not hide that from you..."
      )
      |> next()
      |> select(["No, it's ok, I'm ready.", "I would like to listen."])

    if choice == 1 do
      ctx
      |> mes("[Raulel]")
      |> mes(
        "What a rash person. Your the type that rushes into battle without thinking, what in the world are you doing here instead of with the Prontera Chivalry? Heck, go for it! *cough* Not my fault if you end up dying."
      )
      |> mes(
        "Just consider yourself a glass cannon...because the monsters are going to break you into pieces. Hahahahahahahahaha~"
      )
      |> next()
      |> set_char_var(:WIZ_Q, 6)
      |> savepoint("geffen", 120, 107)
      |> mes("[Raulel]")
      |> mes("Then, as you wish. I'll send you there right now.")
      |> mes(
        "Oh, if you see a white light at the end of a tunnel, that means your pathetic cause you failed! Hahahahahah~"
      )
      |> close()
      |> warp("job_wiz", 57, 154)
    else
      explain_battle_test(ctx)
    end
  end

  defp quest_stage(ctx, 6) do
    wiz_q2 = get_char_var(ctx, :WIZ_Q2, 0)

    cond do
      wiz_q2 == 6 -> offer_scroll_deal(ctx)
      wiz_q2 > 6 -> welcome_back_persistent_candidate(ctx)
      true -> battle_retest_quiz(ctx)
    end
  end

  defp quest_stage(ctx, 7) do
    ctx
    |> mes("[Raulel]")
    |> mes("You shouldn't have any more business with me as far as I'm concerned.")
    |> mes("But, since your so darned persistent, I'll let you take the test again. Hahahahaha~")
    |> next()
    |> mes("[Raulel]")
    |> mes("Go! Go and become the Wizard you really want to be.")
    |> mes("And be careful! Greater Magic will always be after you...")
    |> close()
  end

  defp quest_stage(ctx, _stage), do: ctx

  defp start_written_test_quest(ctx) do
    if checkquest(ctx, 9016) == -1 do
      changequest(ctx, 9015, 9016)
    else
      ctx
    end
  end

  defp take_written_test(ctx) do
    ctx = next(ctx)

    questions =
      case Enum.random(1..3) do
        1 -> @magic_questions
        2 -> @monster_questions
        3 -> @mage_questions
      end

    {ctx, score} = ask_questions(ctx, questions, 10)
    ctx = mes(ctx, "[Raulel]")

    if get_char_var(ctx, :WIZ_Q, 0) == 4 do
      grade_written_retake(ctx, score)
    else
      grade_written_first_attempt(ctx, score)
    end
  end

  defp ask_questions(ctx, questions, points) do
    Enum.reduce(questions, {ctx, 0}, fn {question, options, answer}, {ctx, score} ->
      {ctx, choice} =
        ctx
        |> mes("[Raulel]")
        |> mes(question)
        |> next()
        |> select(options)

      if choice == answer and not halted?(ctx),
        do: {ctx, score + points},
        else: {ctx, score}
    end)
  end

  defp halted?(%Ctx{status: {:error, _}}), do: true
  defp halted?(%Ctx{}), do: false

  defp grade_written_retake(ctx, score) do
    ctx =
      ctx
      |> mes(
        "Good job, you finished answered all the questions... Go buy yourself some potions or something if you have the Zeny. Haha..."
      )
      |> next()
      |> mes("[Raulel]")
      |> mes("Your score is... #{score}points.....")

    case score do
      100 ->
        pass_written_retake(ctx, "Hahahahahahah~ Well done, you passed the second test.")

      90 ->
        pass_written_retake(
          ctx,
          "Hahaha~ Since you only missed one problem, you passed the second test."
        )

      80 ->
        pass_written_retake(
          ctx,
          "Sheez... You didn't do very well, but you passed the second test."
        )

      _ ->
        fail_written_retake(ctx)
    end
  end

  defp pass_written_retake(ctx, verdict) do
    ctx
    |> set_char_var(:WIZ_Q, 5)
    |> changequest(9016, 9017)
    |> mes(verdict)
    |> mes("It wasn't done in one try like mine was, but I'll let you slide...")
    |> next()
    |> mes("[Raulel]")
    |> mes("*sneeze* Don't relax just yet, there's still the matter of the third and final test.")
    |> mes(
      "I advise you to rest a bit while the final test is prepared. Your gonna need it. Hahahahaha~"
    )
    |> close()
  end

  defp fail_written_retake(ctx) do
    ctx
    |> mes("You failed. Go study some more!")
    |> next()
    |> mes("[Raulel]")
    |> mes(
      "*cough* *cough* Did you really think you could become a Wizard with such a mediocre level like yours?"
    )
    |> mes(
      "Get lost! If you were a Wizard right now, the monsters that I fight, would eat you up in no time!"
    )
    |> close()
  end

  defp grade_written_first_attempt(ctx, score) do
    ctx =
      ctx
      |> mes(
        "Hmmm...Good job, you finished answering all the questions, go buy yourself some potions or something, thats IF you have the Zeny. Hahahahahahahah~"
      )
      |> next()
      |> mes("[Raulel]")
      |> mes("Your score is... #{score} points!")

    case score do
      100 ->
        pass_written_first_attempt(ctx, "*cough* *Cough* Well done, you passed the second test.")

      90 ->
        pass_written_first_attempt(
          ctx,
          "Hahahaha~ I'll let you slide by since you only missed one problem. You passed the second test."
        )

      _ ->
        ctx
        |> set_char_var(:WIZ_Q, 4)
        |> mes(
          "You failed. I will let you come back again...after you've learned more relating to the type of questions I've asked you."
        )
        |> next()
        |> mes("[Raulel]")
        |> mes(
          "Tisk...not enough, not enough! Did you really think you could become a Wizard with the little bit of knowledge you have?"
        )
        |> mes(
          "Get lost! If you were a Wizard right now, the monsters I deal with would eat you up in no time!"
        )
        |> close()
    end
  end

  defp pass_written_first_attempt(ctx, verdict) do
    ctx
    |> set_char_var(:WIZ_Q, 5)
    |> changequest(9016, 9017)
    |> mes(verdict)
    |> next()
    |> mes("[Raulel]")
    |> mes("Hahahaha~ Don't relax just yet, there's still the third test.")
    |> mes("*sneeze* I advise you to rest a bit while the final test is prepared...Hahahahah~")
    |> close()
  end

  defp explain_battle_test(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Raulel]")
      |> mes("What a devoted person. Very well, I'll explain.")
      |> mes(
        "No matter how hard this last test may seem, if you do as I say, you can finish it quickly and easily."
      )
      |> next()
      |> mes("[Raulel]")
      |> mes("The final test has a total of 3 parts.")
      |> mes(
        "The order is Water Room, Earth Room, Fire Room. In each room, there are monsters of that particular attribute."
      )
      |> next()
      |> mes("[Raulel]")
      |> mes(
        "You'll find out what monsters will be there once you go in. If you use attacks with the *sneeze*"
      )
      |> mes("right attribute, it shouldn't be too hard. Hahaha~")
      |> next()
      |> mes("[Raulel]")
      |> mes("Once you defeat all the monsters within the given time in any one room...")
      |> mes("you'll be moved to the next room.")
      |> next()
      |> mes("[Raulel]")
      |> mes("After these three rooms are clear, the testing is over.")
      |> mes(
        "You will become a Wizard which is controlled by Greater Magic Powers! Know this...There is no returning to an easy life."
      )
      |> next()
      |> mes("[Raulel]")
      |> mes(
        "Hahaha~ You look frightened. You know, it's not too late to turn back and live an easy life."
      )
      |> mes("If you want, I can send you back to town right now... What do you want to do?")
      |> next()
      |> select([
        "Continue testing.",
        "I want to go back because I have butterflies in my stomach."
      ])

    if choice == 1 do
      ctx
      |> set_char_var(:WIZ_Q, 6)
      |> savepoint("geffen", 120, 107)
      |> mes("[Raulel]")
      |> mes("You are indeed, very determined. Ok! Hahahahahaha~")
      |> mes("*Cough* *cough* As you wish, we shall begin the final test!")
      |> close()
      |> warp("job_wiz", 57, 154)
    else
      ctx
      |> set_char_var(:WIZ_Q, 6)
      |> mes("[Raulel]")
      |> mes("Good thinking. This is a better choice for you. Hahahahah~")
      |> mes(
        "Go back and live a easy life, Greater Magic is a force that should not be wield by types like yourself."
      )
      |> close()
      |> warp("geffen", 120, 110)
    end
  end

  defp offer_scroll_deal(ctx) do
    ctx =
      ctx
      |> mes("[Raulel]")
      |> mes("Hahahahahaha~ I've never seen anyone so...sooo...*sneeze* tenacious as you.")
      |> mes(
        "So you want to try again eh? Even though I've ridiculed you for your failures before??"
      )
      |> next()
      |> mes("[Raulel]")
      |> mes(
        "Ok then, here's a proposition. Since you're probably worn out as it is, and I can clearly see the lust for Greater Magic burning in your eyes..."
      )
      |> mes("Hahahahaha~ yeah! Go bring me a ^3355FFWorn Out Scroll^000000.")
      |> next()

    ctx
    |> set_char_var(:WIZ_Q2, get_char_var(ctx, :WIZ_Q2, 0) + 1)
    |> mes("[Raulel]")
    |> mes("If not, you can take the test again...")
    |> mes("Well, I'll send you to take the test for now. Hahahaha~")
    |> close()
    |> warp("job_wiz", 57, 154)
  end

  defp welcome_back_persistent_candidate(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Raulel]")
      |> mes("Oh! So you're back? Hahahahaha~")
      |> mes(
        "*Cough* Cough* Do you want to take the test again? Or did you bring the ^3355FFWorn Out Scroll^000000?"
      )
      |> next()
      |> select(["Continue the test.", "Worn Out Scroll..."])

    cond do
      choice == 1 ->
        ctx
        |> savepoint("geffen", 120, 107)
        |> mes("[Raulel]")
        |> mes("Hahaha~ Ok, at least you have some spirit.")
        |> mes("I'll send you in again, try dying once more will yah? Hahahahahahahahaha~")
        |> close()
        |> warp("job_wiz", 57, 154)

      count_item(ctx, 618) > 0 ->
        ctx
        |> delitem(618, 1)
        |> mes("[Raulel]")
        |> mes(
          "Hahahahahahahaha~ *Cough* *cough* So you ended up bringing one of these eh? Good job..."
        )
        |> mes("I think I can continue my research with this...")
        |> next()
        |> set_char_var(:WIZ_Q2, 0)
        |> set_char_var(:WIZ_Q, 7)
        |> mes("[Raulel]")
        |> mes(
          "Even though your not Grade A Wizard material, I can tell your serious about wanting the Greater Magic. I'll tell Catherine that you passed. Hahahahahahahahah~"
        )
        |> mes(
          "You went through a lot of trouble here, and that is the true purpose for us selecting Wizards. Only those who will devote themselves to the art will ever become Wizards. Good luck to you. Become much Stronger. Hahahahahaha~"
        )
        |> close()

      true ->
        battle_retest_quiz(ctx)
    end
  end

  defp battle_retest_quiz(ctx) do
    {ctx, score} =
      ctx
      |> mes("[Raulel]")
      |> mes("*sneeze* What? You want to take the test again?")
      |> mes(
        "Geez...you already failed the battle test! Hahahahahahahaha~ So you like magic that much, eh?"
      )
      |> next()
      |> mes("[Raulel]")
      |> mes(
        "Since your so weak that you can't finish this final test on your own...you need a separate test to help you out."
      )
      |> mes(
        "*Cough* If you can't pass the battle test, then do a good job with this one. Hahahahahahah~"
      )
      |> next()
      |> mes("[Raulel]")
      |> mes(
        "Well, you better answer these problems if you plan on becoming a Wizard. Hahahahahahaha~"
      )
      |> next()
      |> ask_questions(@battle_retest_questions, 20)

    ctx =
      ctx
      |> mes("[Raulel]")
      |> mes("*pfft* Do it right, so I don't have to ask again.")
      |> next()
      |> mes("[Raulel]")
      |> mes("You got #{score} points.")

    case score do
      100 ->
        ctx
        |> mes(
          "Hahahahahaha~ *Cough* *cough* If you can answer all these questions correctly, how is it you can't do well in battles??"
        )
        |> next()
        |> offer_battle_retest()

      80 ->
        ctx
        |> mes("Eh, soso...")
        |> mes("I'll let you retake the test.")
        |> next()
        |> offer_battle_retest()

      _ ->
        ctx
        |> mes("You failed! Go study some more!")
        |> next()
        |> mes("[Raulel]")
        |> mes(
          "You lack something...*sneez*...like intelligence. That's why you keep on failing. Hahahahahahahaha~"
        )
        |> close()
    end
  end

  defp offer_battle_retest(ctx) do
    {ctx, choice} = select(ctx, ["Begin the test please.", "Can I get another explanation?"])

    if choice == 1 do
      ctx
      |> mes("[Raulel]")
      |> mes("Nobody is going to help you become a Wizard. Hahahahahahahaha~")
      |> mes("*Cough* *cough* No point in crying after dying...")
      |> next()
      |> percent_heal(hp: 100, sp: 100)
      |> mes("[Raulel]")
      |> mes("Then, as you wish. I'll send you to fight.")
      |> mes(
        "Oh! If you see some tall pearly gates and hear a booming deep voice from behind it, that means that your a failure when it comes to Magic. Hahahahahahahahaha~"
      )
      |> close()
      |> warp("job_wiz", 57, 154)
    else
      explain_battle_retest(ctx)
    end
  end

  defp explain_battle_retest(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Raulel]")
      |> mes("*Cough* *cough* Then I shall explain.")
      |> mes("The test may be hard, but just do as I tell you and it shouldn't be a problem.")
      |> next()
      |> mes("[Raulel]")
      |> mes("There are 3 parts to this final test.")
      |> mes(
        "The order is...*sneez*...the Water Room, Earth Room, and then the Fire Room. Each room has monsters of that attribute in it."
      )
      |> next()
      |> mes("[Raulel]")
      |> mes("You'll see what monsters they are when you enter.")
      |> mes(
        "If you use the appropriate spells against them, it shouldn't be that difficult. Hahahahahahaha~"
      )
      |> next()
      |> mes("[Raulel]")
      |> mes("Within the given time, if you defeat all the monsters...")
      |> mes("you will be sent to the next room.")
      |> next()
      |> mes("[Raulel]")
      |> mes("After that, the test is over.")
      |> mes(
        "You will then become a Wizard controlled by Greater Magic powers! There is no coming back to the easy life you have known thus far."
      )
      |> next()
      |> mes("[Raulel]")
      |> mes("Hahahahaha~ You look frightened. It's not too late you know.")
      |> mes(
        "*Cough* *cough* You can give up and go back to town! Just forget about the Greater Magic and live a normal life. What do yah say?"
      )
      |> next()
      |> select(["Continue with the test.", "I'm too scared, I would like to quit."])

    if choice == 1 do
      ctx
      |> percent_heal(hp: 100, sp: 100)
      |> mes("[Raulel]")
      |> mes("This time when you die, don't come back crying. Hahahahahahahahah~ *Cough *cough*")
      |> mes("As you wish, let's begin the final test!")
      |> close()
      |> warp("job_wiz", 57, 154)
    else
      ctx
      |> mes("[Raulel]")
      |> mes(
        "Comming from you, thats some darn good thinking. That's more a fit for you anyways. Hahahahahahahahaha~"
      )
      |> mes("Go back and live a quiet and peaceful life!")
      |> close()
      |> warp("geffen", 120, 110)
    end
  end
end
