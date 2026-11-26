defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Seals.MegingardSeal.RebarevDoug do
  @moduledoc """
  Rebarev Doug, a retired Crusader instructor, crafts Gleipnir and drives the Megingjard Seal
  quest around his lost squad.

  ## Behavior

  - Refuses to talk to a player carrying too much weight.
  - With 4 Cat Tread, 5 Woman's Moustache, 4 Root of Stone, 3 Sputum of Bird and 3 Sinew of Bear,
    offers to trade them for Gleipnir before his usual talk.
  - Before the Megingjard seal phase opens, explains Crusader skills and what Gleipnir needs.
  - During the phase, asks players of base level 60 or more to find the 1st Squad of his old
    platoon, points them to the Prontera Library records, hears their report and finally reveals
    his part in the squad's fate; lower-level players are dismissed.
  - After the phase ends, only talks about the coming Holy War.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Lupus
    - L0ne_W0lf
    - Samuray22
    - brianluau
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{name: "Rebarev Doug_", scope: :shared},
      %{
        map: "prt_cas",
        x: 180,
        y: 269,
        dir: 6,
        sprite: 56,
        name: "Rebarev Doug",
        unique_name: "Rebarev Doug",
        scope: :renewal
      },
      %{
        map: "prt_castle",
        x: 44,
        y: 151,
        dir: 0,
        sprite: 56,
        name: "Rebarev Doug",
        unique_name: "Rebarev Doug",
        scope: :pre_renewal
      }
    ]

  @impl true
  def on_talk(ctx) do
    if checkweight(ctx, [{1301, 3}]) == 0 do
      ctx |> mes("- You are carrying too many items! -") |> close()
    else
      ctx = cutin(ctx, "god_rebeireb", 2)

      with {:ok, ctx} <- offer_gleipnir(ctx),
           {:ok, ctx} <- talk(ctx) do
        ctx |> close2() |> cutin("god_rebeireb", 255)
      else
        {:cancel, ctx} -> ctx
      end
    end
  end

  defp offer_gleipnir(ctx) do
    if has_gleipnir_materials?(ctx) do
      {ctx, choice} =
        ctx
        |> mes("[Rebarev Doug]")
        |> mes("What's this?")
        |> mes("You...! You have")
        |> mes("everything I need to")
        |> mes("create Gleipnir!")
        |> next()
        |> select(["Make Gleipnir.", "Cancel."])

      case choice do
        1 -> {:ok, make_gleipnir(ctx)}
        2 -> {:ok, ctx}
        _ -> {:cancel, ctx}
      end
    else
      {:ok, ctx}
    end
  end

  defp has_gleipnir_materials?(ctx) do
    count_item(ctx, 7080) > 3 and count_item(ctx, 7081) > 4 and count_item(ctx, 7082) > 3 and
      count_item(ctx, 7084) > 2 and count_item(ctx, 7085) > 2
  end

  defp make_gleipnir(ctx) do
    ctx
    |> mes("[Rebarev Doug]")
    |> mes("I'm the only human on earth")
    |> mes(
      "blessed with the ability to create Gleipnir. Aside from the Dwarves, I'm the only person that can make this item!"
    )
    |> next()
    |> delitem(7080, 4)
    |> delitem(7081, 5)
    |> delitem(7082, 4)
    |> delitem(7084, 3)
    |> delitem(7085, 3)
    |> give_item(7058, 1)
    |> mes("[Rebarev Doug]")
    |> mes("There you go!")
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes(
      "Gleipnir is said to be so strong that not even the Fenrir Wolf could break it! I take great pride in being able to create this!"
    )
  end

  defp talk(ctx) do
    cond do
      get_server_var(ctx, "God1", 0) < get_server_temp_var(ctx, "god_check1", 0) ->
        crusader_lessons(ctx)

      get_server_var(ctx, "God1", 0) >= get_server_temp_var(ctx, "god_check1", 0) and
          get_server_var(ctx, "God2", 0) < get_server_temp_var(ctx, "god_check2", 0) ->
        megingard_phase(ctx)

      true ->
        {:ok, holy_war_greeting(ctx)}
    end
  end

  defp holy_war_greeting(ctx) do
    ctx
    |> mes("[Rebarev Doug]")
    |> mes("We are Crusaders that have")
    |> mes("been training in preparation")
    |> mes("for the Holy War that is to come.")
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes("As our forefathers have")
    |> mes(
      "done a thousand years ago, we shall vanquish the hordes of Demons when the day comes."
    )
  end

  defp crusader_lessons(ctx) do
    {ctx, choice} =
      ctx
      |> holy_war_greeting()
      |> next()
      |> mes("[Rebarev Doug]")
      |> mes("If you have any questions about Crusaders, feel free to ask me.")
      |> mes(
        "I may be too old and weak for fighting, but I will spread our message as much as I can."
      )
      |> next()
      |> select([
        "What is Holy Cross?",
        "What is Grand Cross?",
        "What is Sacrifice?",
        "What is Gleipnir?"
      ])

    case choice do
      1 -> {:ok, explain_holy_cross(ctx)}
      2 -> {:ok, explain_grand_cross(ctx)}
      3 -> {:ok, explain_sacrifice(ctx)}
      4 -> {:ok, explain_gleipnir(ctx)}
      _ -> {:cancel, ctx}
    end
  end

  defp explain_holy_cross(ctx) do
    ctx
    |> mes("[Rebarev Doug]")
    |> mes(
      "Holy Cross is the first manifestation of a Crusader's faith. By making the sign of the cross, Crusader's can inflict a holy attack on their enemies."
    )
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes(
      "Monsters that are weak against holiness, particularly the Undead, will be blinded by the light of the Holy Cross. All they can do is wait for holy judgment."
    )
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes("Based on our latest research,")
    |> mes(
      "the Holy Cross can inflict 4.5 times more damage than a normal attack once it is mastered."
    )
  end

  defp explain_grand_cross(ctx) do
    ctx
    |> mes("[Rebarev Doug]")
    |> mes("Grand Cross...!")
    |> mes("The righteous fury of God is")
    |> mes("given form in this destructive skill.")
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes("God grants us his power so that")
    |> mes(
      "we may punish the forces of evil, and one's rage is embodied in a giant crucifix of power."
    )
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes(
      "The power of the crucifix of light can damage the enemy three times. Each strike will have five times the strength of your normal attacks."
    )
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes(
      "However, when Crusaders use Grand Cross, they must exercise extreme caution. The human body is too weak to fully embrace the will of God."
    )
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes(
      "Therefore, using this skill, will cause the Crusader to suffer from damage. However, this damage can"
    )
    |> mes("be reduced to half with Faith.")
  end

  defp explain_sacrifice(ctx) do
    ctx
    |> mes("[Rebarev Doug]")
    |> mes("In practicing what we preach, Crusaders choose to protect")
    |> mes("others by bearing the suffering of their fellow man.")
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes(
      "The Sacrifice skill allows Crusaders to keep their comrades safe from harm by receiving the damage that was intended for them."
    )
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes("It is the greatest demonstration of faith,")
    |> mes(
      "as well as of love for your comrades. Such an attitude is essential for a servant of God!"
    )
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes(
      "However, if the people you want to protect stray away from you, you cannot use the Sacrifice skill for them unless they are close to you again."
    )
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes(
      "As you visualize the suffering of those you want to protect, you'll never hesitate to sacrifice yourself."
    )
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes("Thank you, God, for granting me with the power to protect my people.")
  end

  defp explain_gleipnir(ctx) do
    ctx
    |> mes("[Rebarev Doug]")
    |> mes("Gleipnir is the essence of Megingjard which I have been researching.")
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes(
      "It's the only binding strong enough that will allow a human to wear Megingjard around his waist."
    )
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes(
      "Although I can no longer fight, I've been studying how to create Gleipnir for years. I will be more than willing to create it for you if you can bring me..."
    )
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes("^0000FF4 Cat Tread^000000,")
    |> mes("^0000FF5 Woman's Moustache^000000,")
    |> mes("^0000FF4 Root of Stone^000000,")
    |> mes("^0000FF3 Sputum of Bird^000000 and")
    |> mes("^0000FF3 Sinew of Bear^000000.")
  end

  defp megingard_phase(ctx) do
    if base_level(ctx) > 59 do
      squad_quest(ctx, get_char_var(ctx, :god_eremes, 0))
    else
      {:ok,
       ctx
       |> mes("[Rebarev Doug]")
       |> mes("You're not fit")
       |> mes("to even speak to me.")
       |> mes("Even if you are an adventurer...")}
    end
  end

  defp squad_quest(ctx, 0), do: ask_favor(ctx)

  defp squad_quest(ctx, stage) when stage in 1..3 do
    if Enum.random(1..10) > 6 and stage == 2 do
      remind_with_final_mission(ctx)
    else
      remind_search(ctx)
    end
  end

  defp squad_quest(ctx, stage) when stage in 4..17, do: {:ok, librarian_refused(ctx)}
  defp squad_quest(ctx, stage) when stage in 18..19, do: {:ok, report_squad(ctx)}
  defp squad_quest(ctx, stage) when stage in 20..22, do: welcome_back(ctx)
  defp squad_quest(ctx, stage) when stage in 23..24, do: {:ok, confronted(ctx)}

  defp squad_quest(ctx, 25) do
    {:ok,
     ctx
     |> mes("[Rebarev Doug]")
     |> mes("I didn't think")
     |> mes("you'd actually do it.")
     |> mes("But you'll be sorry later...")}
  end

  defp squad_quest(ctx, _stage), do: {:ok, untouchable(ctx)}

  defp ask_favor(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Rebarev Doug]")
      |> mes("...")
      |> next()
      |> mes("[Rebarev Doug]")
      |> mes("Why are you wandering")
      |> mes("around this sacred place?")
      |> mes("Do you not understand that")
      |> mes("we must prepare for")
      |> mes("the Holy War?")
      |> next()
      |> mes("[Rebarev Doug]")
      |> mes(
        "No matter how much I explain, the ignorant never fully understand the importance of our task. The balance of power will shift when we least expect it!"
      )
      |> next()
      |> mes("[Rebarev Doug]")
      |> mes("I wish I could go back")
      |> mes("to those times when I would")
      |> mes("train Crusaders, rather than")
      |> mes("preach to the ignorant.")
      |> next()
      |> mes("[Rebarev Doug]")
      |> mes("I miss my Crusaders who")
      |> mes(
        "were enthusiastic to listen to what I had to say, and carried out their orders with loyalty."
      )
      |> next()
      |> mes("[Rebarev Doug]")
      |> mes("I am wonder")
      |> mes("where they have")
      |> mes("all gone now...")
      |> next()
      |> mes("[Rebarev Doug]")
      |> mes("...")
      |> mes("......")
      |> mes(".........")
      |> next()
      |> mes("[Rebarev Doug]")
      |> mes(
        "Adventurer, if you have the time to listen to me speak to myself, why don't you perform a task for me?"
      )
      |> next()
      |> mes("[Rebarev Doug]")
      |> mes("It may be an enriching")
      |> mes(
        "experience for you. It's possible that you'll even have a greater appreciation for Crusaders."
      )
      |> next()
      |> select(["What is it?", "I'm sick and tired of doin' favors."])

    case choice do
      1 -> explain_favor(ctx)
      2 -> {:ok, favor_refused(ctx)}
      _ -> {:cancel, ctx}
    end
  end

  defp explain_favor(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Rebarev Doug]")
      |> mes(
        "I want you to find the members of the 1st Squad in the 3rd Platoon of the 3rd Company. If you happen to encounter them in your travels, please ask them how they are doing."
      )
      |> next()
      |> mes("[Rebarev Doug]")
      |> mes(
        "It shouldn't be that difficult to do and won't be a waste of your time if you are already planning"
      )
      |> mes("to explore the world.")
      |> next()
      |> select(["Sure, why not.", "I'm sorry, but no."])

    case choice do
      1 -> {:ok, accept_favor(ctx)}
      2 -> {:ok, decline_favor(ctx)}
      _ -> {:cancel, ctx}
    end
  end

  defp accept_favor(ctx) do
    ctx
    |> mes("[Rebarev Doug]")
    |> mes("Excellent!")
    |> mes("All I want you to do is find my old comrades, and inform me of how")
    |> mes("they are doing.")
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes("However...")
    |> mes("There is one problem.")
    |> mes("I don't where they are.")
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes(
      "You could try to find a record of residency changes by citizens of the Rune-Midgarts Kingdom in"
    )
    |> mes("the Prontera Library...")
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes("However, the records of")
    |> mes(
      "Crusader personnel is considered confidential, so I am not sure of whether or not you can view them."
    )
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes(
      "You must understand, my position requires me to remain in this area 24 hours, 7 days a week. I cannot leave without the consent of the upper hierarchy."
    )
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes(
      "However, I know you have the freedom and the time to go wherever you please. I'd appreciate if you would do this for me."
    )
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes("My old comrades in arms.")
    |> mes("You have no idea how much")
    |> mes("I miss them...")
    |> set_char_var(:god_eremes, 1)
  end

  defp decline_favor(ctx) do
    ctx
    |> mes("[Rebarev Doug]")
    |> mes("^333333*Sigh...*^000000")
    |> mes("Please understand that")
    |> mes("I would not be asking this")
    |> mes("of you if it were not for")
    |> mes("the restraints of")
    |> mes("my position.")
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes("I have an obligation to this Kingdom to keep my post and")
    |> mes("inform adventurers about the")
    |> mes("Crusader class. Because of this")
    |> mes("awesome responsibility, I must")
    |> mes("remain here, ever vigilant.")
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes("If you can't understand, then you must be taking your freedom for granted...")
  end

  defp favor_refused(ctx) do
    ctx
    |> mes("[Rebarev Doug]")
    |> mes("As far as I remember, this is the first time I have asked you to do me a favor.")
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes("Unlike you, I know the meaning")
    |> mes(
      "of responsibility. I remain here, helping inquisitive adventurers for the sake of King and country."
    )
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes("Still...")
    |> mes("Know this.")
    |> mes(
      "Although the results may not be immediate, you will always be rewarded when you help others."
    )
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes("Please reconsider")
    |> mes("when you get the chance.")
  end

  defp wondering_about_comrades(ctx) do
    ctx
    |> mes("[Rebarev Doug]")
    |> mes("I wonder how my old")
    |> mes("comrades are doing now.")
    |> mes("I can't even remember")
    |> mes("the last time I saw them...")
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes("Hmm...?")
    |> mes("Haven't you left")
    |> mes("to search for them yet?")
    |> next()
  end

  defp about_to_leave(ctx) do
    ctx
    |> mes("[Rebarev Doug]")
    |> mes("Oh, you are...")
    |> mes("I wonder what they")
    |> mes("have been doing since")
    |> mes("our ^0000FFfinal mission^000000...")
  end

  defp remind_with_final_mission(ctx) do
    {ctx, choice} =
      ctx
      |> wondering_about_comrades()
      |> select([
        "Where should I go?",
        "I am about to leave.",
        "What do you mean by final mission?"
      ])

    case choice do
      1 ->
        {:ok,
         ctx
         |> mes("[Rebarev Doug]")
         |> mes("Well...")
         |> mes("You should be able")
         |> mes("find some clue as to")
         |> mes("where to find them through")
         |> mes("^0000FFThe Platoon Records^000000 in")
         |> mes("the Prontera Library.")}

      2 ->
        {:ok, about_to_leave(ctx)}

      3 ->
        {:ok, explain_final_mission(ctx)}

      _ ->
        {:cancel, ctx}
    end
  end

  defp explain_final_mission(ctx) do
    ctx
    |> mes("[Rebarev Doug]")
    |> mes("Final mission...?")
    |> mes("Well, I can't recall")
    |> mes("everything at the moment,")
    |> mes("but it was the reason why")
    |> mes("our squad broke up.")
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes("We were a great team.")
    |> mes("But in the military system,")
    |> mes("you need to follow the orders")
    |> mes("of your superiors...")
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes("If only...")
    |> mes("^660000He^000000 hadn't interfered...")
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes("...")
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes(
      "Let's not talk about that. What's important that our squad was disbanded because of we failed our final mission. Now, will you please go find ^0000FFThe 3rd Platoon Records^000000 in the Prontera Library for me?"
    )
    |> set_char_var(:god_eremes, 3)
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes(
      "Remember, it might be helpful to ask the librarian for the file with a record on ^660000the 1st squad's final mission^000000."
    )
  end

  defp remind_search(ctx) do
    {ctx, choice} =
      ctx
      |> wondering_about_comrades()
      |> select(["Where should I go?", "I am about to leave."])

    case choice do
      1 ->
        {:ok,
         ctx
         |> mes("[Rebarev Doug]")
         |> mes("Well...")
         |> mes("You should be able")
         |> mes("find some clue as to")
         |> mes("where to find them through")
         |> mes("^0000FFThe 3rd Platoon Records^000000 in")
         |> mes("the Prontera Library.")}

      2 ->
        {:ok, ctx |> about_to_leave() |> set_char_var(:god_eremes, 2)}

      _ ->
        {:cancel, ctx}
    end
  end

  defp librarian_refused(ctx) do
    ctx
    |> mes("[Rebarev Doug]")
    |> mes("Huh...?")
    |> mes("The librarian")
    |> mes("didn't let you")
    |> mes("read the records?")
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes("He may have responsibility,")
    |> mes(
      "but at the end of the day, he's just like you and me. You can find some way to convince him to help you, I'm sure."
    )
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes("Please, I beg you,")
    |> mes("would you find out")
    |> mes("what happened to the")
    |> mes("rest of the 1st Squad?")
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes("Oh...")
    |> mes(
      "It might be helpful to know that we were the ^660000Crusader Third Company, Third Platoon, First Squad^000000."
    )
  end

  defp report_squad(ctx) do
    if met_a_squad_member?(ctx) do
      ctx
      |> mes("[Rebarev Doug]")
      |> mes("Oh...")
      |> mes("So did you meet them?")
      |> mes("Are they all okay?")
      |> next()
      |> mes("^3355FFYou tell Rebarev Doug")
      |> mes("that although they are")
      |> mes("suffering from migraines")
      |> mes("and memory loss, the rest")
      |> mes("of the 1st Squad is fine.")
    else
      ctx
      |> mes("^3355FFYou tell Rebarev Doug")
      |> mes("that you have read the")
      |> mes("3rd Platoon records and")
      |> mes("explain what you have")
      |> mes("managed to learn.^000000")
      |> next()
      |> mes("[Rebarev Doug]")
      |> mes("Oh, I'm glad to hear that")
      |> mes("you were able to read the")
      |> mes("records! But I don't trust")
      |> mes("what's written on paper.")
      |> mes("After all, it may be")
      |> mes("out of date...")
      |> next()
      |> mes("[Rebarev Doug]")
      |> mes(
        "If it's possible, I hope you can meet the rest of the 1st Squad face to face, so I can know for sure that they're all alright."
      )
      |> next()
      |> mes("[Rebarev Doug]")
      |> mes("A man's life is too")
      |> mes("short and his friends")
      |> mes("are too few. Please find")
      |> mes("out how my old comrades")
      |> mes("are doing for me.")
    end
  end

  defp met_a_squad_member?(ctx) do
    Enum.any?(
      [:god_megin_1, :god_megin_2, :god_megin_3, :god_megin_4, :god_megin_5, :god_megin_6],
      &(get_char_var(ctx, &1, 0) > 0)
    )
  end

  defp welcome_back(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Rebarev Doug]")
      |> mes("Welcome back~")
      |> mes("It's been a while since I've last seen you. Have you met the rest")
      |> mes("of the 1st Squad?")
      |> next()
      |> mes("[Rebarev Doug]")
      |> mes("Hm...?")
      |> mes("What's that")
      |> mes("strange look for?")
      |> next()
      |> select(["Confront Rebarev Doug.", "Act unsuspicious."])

    case choice do
      1 -> {:ok, confront_about_squad(ctx)}
      2 -> {:ok, keep_suspicions(ctx)}
      _ -> {:cancel, ctx}
    end
  end

  defp confront_about_squad(ctx) do
    ctx
    |> mes(
      "^3355FFYou confront Rebarev Doug about the memory problems and migraines of the 1st Squad...^000000"
    )
    |> next()
    |> mes(
      "^3355FFThinking about Royal Myst's story and the mentions of Egnigem begin to jumble your thoughts...^000000"
    )
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes(
      "What are you talking about? I don't understand, you're talking about lots of different things at once!"
    )
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes("Don't look at me like that. If you're done speaking, please")
    |> mes("excuse me and tell me your news some other time.")
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes("I appreciate that you've delivered news of my old comrades to me.")
    |> mes("Now, I need to continue my research under the command of his Majesty.")
    |> set_char_var(:god_eremes, 21)
  end

  defp keep_suspicions(ctx) do
    ctx
    |> mes(
      "^3355FFYou keep your suspicions to yourself and tell Rebarev Doug about the members of"
    )
    |> mes("the 1st Squad.^000000")
    |> next()
    |> mes(
      "^3355FFOf course, you withhold some details and only tell him what he seems to want to hear.^000000."
    )
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes("Great!")
    |> mes("I'm glad to hear")
    |> mes("they're doing so well!")
    |> mes("Ha ha! Hahahahahahaahah!")
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes("I appreciate that you've delivered news of my old comrades to me.")
    |> mes(
      "Now, I need to continue my research under the command of his Majesty. Once again, thank you for your help."
    )
    |> set_char_var(:god_eremes, 22)
  end

  defp confronted(ctx) do
    ctx
    |> mes("^3355FFYou confront")
    |> mes("Rebarev Doug with the")
    |> mes("information you learned")
    |> mes("from Egnigem.^000000")
    |> next()
    |> mes("^3355FFHowever, he didn't")
    |> mes(
      "seem the least bit agitated. In fact, he exuded a calmness that makes you feel nervous.^000000"
    )
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes(
      "It's far too late to talk about that, though I feel sorry for you for knowing too much. At this point, there's nothing you can prove."
    )
    |> next()
    |> untouchable()
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes("Do you hate me?")
    |> mes("Do you really hate me?")
    |> mes("Take a look at this face.")
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes("This is the")
    |> mes("face of authority!")
    |> mes(
      "Go ahead and report me to the judge in charge of all military crimes! He's right behind me!"
    )
    |> next()
    |> mes("[Rebarev Doug]")
    |> mes("If at least 100 people report the same crime, then maybe he'll hold")
    |> mes("a trial. But do you really want to reveal this to the public?")
  end

  defp untouchable(ctx) do
    ctx
    |> mes("[Rebarev Doug]")
    |> mes("Don't you get it?")
    |> mes(
      "The elite and powerful rule this world. I am untouchable! And the weak and the lowly can rot in hell! Heh heh!"
    )
  end
end
