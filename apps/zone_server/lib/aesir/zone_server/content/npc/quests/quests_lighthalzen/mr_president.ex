defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.MrPresident do
  @moduledoc """
  President Karl leads the Secret Wing's investigation into Rekenber.

  ## Behavior

  - Assigns missions and reviews evidence as the investigation progresses.
  - Confronts his advisor and later receives the research record.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  - Fixed `lght_boss == 43` to check `lhz_boss == 43`, matching the quest progression.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "yuno_pre", x: 69, y: 79, dir: 4, sprite: 872, name: "Mr. President", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if checkweight(ctx, [{7342, 1}]) != 1 do
      overweight(ctx)
    else
      ctx |> cutin("lhz_karl.bmp", 2) |> talk()
    end
  end

  defp talk(ctx) do
    cond do
      get_char_var(ctx, :lhz_boss, 0) < 11 -> eject(ctx)
      get_char_var(ctx, :lhz_boss, 0) == 14 -> introduction(ctx)
      get_char_var(ctx, :lhz_boss, 0) == 15 -> assign_benith(ctx)
      get_char_var(ctx, :lhz_boss, 0) < 21 -> remind_benith(ctx)
      get_char_var(ctx, :lhz_boss, 0) == 21 -> receive_benith_file(ctx)
      get_char_var(ctx, :lhz_boss, 0) == 22 -> review_benith_file(ctx)
      get_char_var(ctx, :lhz_boss, 0) == 23 -> report_shinokas(ctx)
      get_char_var(ctx, :lhz_boss, 0) == 24 -> discuss_shinokas(ctx)
      get_char_var(ctx, :lhz_boss, 0) == 25 -> review_reports(ctx)
      get_char_var(ctx, :lhz_boss, 0) < 37 -> encourage(ctx)
      get_char_var(ctx, :lhz_boss, 0) == 37 -> receive_archive_file(ctx)
      get_char_var(ctx, :lhz_boss, 0) == 38 -> remind_esuna(ctx)
      get_char_var(ctx, :lhz_boss, 0) == 39 -> receive_esuna_file(ctx)
      get_char_var(ctx, :lhz_boss, 0) == 41 -> summon_advisor(ctx)
      get_char_var(ctx, :lhz_boss, 0) == 42 -> confront_advisor(ctx)
      get_char_var(ctx, :lhz_boss, 0) == 43 -> finish_quests(ctx)
      get_char_var(ctx, :hg_tre, 0) == 56 -> receive_research(ctx)
      get_char_var(ctx, :hg_tre, 0) == 57 -> discuss_research(ctx)
      true -> farewell(ctx)
    end
  end

  defp overweight(ctx) do
    ctx
    |> mes("- Wait a moment! -")
    |> mes("- Currently you're carrying -")
    |> mes("- too many items with you. -")
    |> mes("- Please enlighten your weight -")
    |> mes("- and try again. -")
    |> close()
  end

  defp eject(ctx) do
    ctx
    |> mes("[Karl]")
    |> mes("How did you get in here?")
    |> mes("Please leave this place")
    |> mes("immediately! Security...!")
    |> close2()
    |> cutin("", 255)
    |> warp("yuno_pre", 83, 22)
  end

  defp introduction(ctx) do
    ctx
    |> mes("[Karl]")
    |> mes("Ah, welcome~")
    |> mes("I understand that you")
    |> mes("must have had a lot of")
    |> mes("trouble coming here.")
    |> mes("It's a pleasure to")
    |> mes("finally meet you.")
    |> next()
    |> mes("[Karl]")
    |> mes("As I'm sure Ghalstein")
    |> mes("has told you, ''Secret Wing''")
    |> mes("was formed to overthrow the")
    |> mes("evil Rekenber Corporation.")
    |> mes("Now, I'm sure that you must")
    |> mes("have some questions for me...")
    |> next()
    |> mission_questions()
  end

  defp assign_benith(ctx) do
    ctx
    |> mes("[Karl]")
    |> mes("Now, you must first visit")
    |> mes("the Kafra Headquarters in")
    |> mes("Al De Baran and meet someone")
    |> mes("named ^FF0000Benith^000000. She will tell you")
    |> mes("all about your next mission.")
    |> next()
    |> mes("[Karl]")
    |> mes("Be careful and do not")
    |> mes("freely mention anything")
    |> mes("about ''Secret Wing'' or")
    |> mes("your cooperation with us as")
    |> mes("it may jeopardize our goals.")
    |> mes("Hurry, time is of the essence.")
    |> next()
    |> mes("[Karl]")
    |> mes("Ah, before I forget,")
    |> mes("please bring this file")
    |> mes("folder to ^FF0000Ms. Hes O'Neil^000000")
    |> mes("for me before you leave.")
    |> mes("Thank you very much.")
    |> set_char_var(:lhz_boss, 16)
    |> give_item(7342, 1)
    |> changequest(12_018, 12_019)
    |> close2()
    |> cutin("", 255)
  end

  defp remind_benith(ctx) do
    ctx
    |> mes("[Karl]")
    |> mes("Hurry and complete")
    |> mes("the mission given to")
    |> mes("you by Benith, who is")
    |> mes("in the Kafra Headquarters")
    |> mes("in Al De Baran. It is a very")
    |> mes("urgent, high priority task...")
    |> close2()
    |> cutin("", 255)
  end

  defp receive_benith_file(ctx) do
    if not Rathena.truthy?(count_item(ctx, 7343)) do
      ctx
      |> mes("[Karl]")
      |> mes("Hm? I was expecting")
      |> mes("for you to bring me")
      |> mes("back an important file.")
      |> mes("Please hurry, our entire")
      |> mes("organization is at stake!")
      |> close2()
      |> cutin("", 255)
    else
      ctx
      |> mes("[Karl]")
      |> mes("Ah, you're here.")
      |> mes("Good work, I hear that")
      |> mes("the mission was a success.")
      |> mes("An official success anyway.")
      |> mes("...............................")
      |> next()
      |> mes("[Karl]")
      |> mes("Poor, dear sweet")
      |> mes("Jargeah. Why him?")
      |> mes("Must fate be so cruel")
      |> mes("and harsh? I still can't")
      |> mes("believe he's gone. Just")
      |> mes("last week, we were...")
      |> next()
      |> mes("[Karl]")
      |> mes("I'm sorry. You didn't")
      |> mes("know him that well, but")
      |> mes("all those who did know")
      |> mes("him, loved him. And I can")
      |> mes("say that with pride. L-let")
      |> mes("me check the files a minute...")
      |> delitem(7343, 1)
      |> set_char_var(:lhz_boss, 22)
      |> close2()
      |> cutin("", 255)
    end
  end

  defp review_benith_file(ctx) do
    if Enum.random(1..5) == 3 do
      ctx =
        ctx
        |> mes("[Karl]")
        |> mes("Hm. After completely")
        |> mes("reviewing this file, I've")
        |> mes("found that it offers some")
        |> mes("great leads, but it's still not")
        |> mes("enough hard evidence to")
        |> mes("really hurt Rekenber.")
        |> next()
        |> mes("[Karl]")
        |> mes("However, according to")
        |> mes("this, there's a researcher")
        |> mes("from Rekenber named")
        |> mes("Shinokas who vanished all")
        |> mes("of a sudden. Apparently, he")
        |> mes("knew some kind of secret.")
        |> next()
        |> mes("[Karl]")
        |> mes("Luckily, my men have")
        |> mes("reported sightings of")
        |> mes("Shinokas somewhere in")
        |> mes("Einbroch. He's certainly")
        |> mes("out there. But what does")
        |> mes("he have to hide?")
        |> next()
        |> mes("[Karl]")
        |> mes("We must learn his")
        |> mes("secret if we hope to")
        |> mes("do any lasting damage to")
        |> mes("the Rekenber Corporation.")
        |> mes("Your next mission is to")
        |> mes("find Shinokas. Good luck.")
        |> next()
        |> mes("[Karl]")
        |> mes("And please hurry.")
        |> mes("I don't want our enemies")
        |> mes("to discover Shinokas before")
        |> mes("we can get him to talk.")
        |> changequest(12_022, 12_023)

      ctx =
        if get_char_var(ctx, :Shinokas_Quest, 0) == 11 do
          set_char_var(ctx, :lhz_boss, 24)
        else
          set_char_var(ctx, :lhz_boss, 23)
        end

      ctx |> close2() |> cutin("", 255)
    else
      ctx
      |> mes("[Karl]")
      |> mes("I'm sorry, but it's")
      |> mes("taking me a long time")
      |> mes("to analyze the information")
      |> mes("in this file. A-and Jargeah")
      |> mes("sacrificed himself to get")
      |> mes("it for us. ^333333*Sigh*^000000 Jargeah...")
      |> next()
      |> mes("[Karl]")
      |> mes("Why don't you relax")
      |> mes("while I peruse this")
      |> mes("file? I should be done")
      |> mes("with this soon, hopefully...")
      |> close2()
      |> cutin("", 255)
    end
  end

  defp report_shinokas(ctx) do
    if get_char_var(ctx, :Shinokas_Quest, 0) == 11 do
      ctx
      |> mes("[Karl]")
      |> mes("Ymir's Heart Pieces?")
      |> mes("Is that what they're")
      |> mes("trying to collect?")
      |> mes("What are they going")
      |> mes("to do with something")
      |> mes("so incredibly dangerous?!")
      |> next()
      |> mes("[Karl]")
      |> mes("Huh. This new information")
      |> mes("raises some new questions.")
      |> mes("Fortunately, we have a new")
      |> mes("lead from the spy who got")
      |> mes("us the info on Shinokas.")
      |> next()
      |> mes("[Karl]")
      |> mes("We've recently learned that")
      |> mes("Shinokas managed to access")
      |> mes("the Regenschirm Secret Archive, a lab affiliated with Rekenber.")
      |> mes("That's how Shinokas was able")
      |> mes("to learn so much about them.")
      |> next()
      |> mes("[Karl]")
      |> mes("It will be difficult")
      |> mes("and very dangerous to")
      |> mes("access this archive, so")
      |> mes("I want you to meet with")
      |> mes("someone from the Kafra")
      |> mes("Corporation near Lighthalzen.")
      |> next()
      |> mes("[Karl]")
      |> mes("And don't worry...")
      |> mes("She'll know exactly")
      |> mes("who you are and")
      |> mes("how to help you.")
      |> set_char_var(:lhz_boss, 26)
      |> completequest(12_023)
      |> setquest(12_024)
      |> close2()
      |> cutin("", 255)
    else
      ctx =
        ctx
        |> mes("[Karl]")
        |> mes("We don't know how")
        |> mes("helpful Shinokas's")
        |> mes("information may be for")
        |> mes("us, but we must learn")
        |> mes("anything we can about")
        |> mes("the Rekenber Corporation.")
        |> next()
        |> mes("[Karl]")
        |> mes("There is so much we")
        |> mes("don't know about them.")
        |> mes("Their motives, their methods,")
        |> mes("almost all of the important")
        |> mes("details are still in the dark.")
        |> next()
        |> mes("[Karl]")
        |> mes("By all means, you")
        |> mes("must find Shinokas and")
        |> mes("see what you can learn!")
        |> mes("Your efforts will not go")

      ctx
      |> mes(Rathena.concat(Rathena.concat("unrecognized, ", char_name(ctx, 0)), "."))
      |> close2()
      |> cutin("", 255)
    end
  end

  defp discuss_shinokas(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Karl]")
      |> mes("Hm? What's wrong?")
      |> mes("Now that I think about")
      |> mes("it, you reacted as if you")
      |> mes("recognized his name back")
      |> mes("when I mentioned Shinokas.")
      |> next()
      |> select(["Oh, no. Not really.", "Actually, Shinokas is..."])

    case choice do
      1 ->
        ctx
        |> mes("[Karl]")
        |> mes("Then it must be")
        |> mes("my imagination.")
        |> mes("Okay then, go and")
        |> mes("find Shinokas, he")
        |> mes("may be in grave")
        |> mes("danger as we speak!")
        |> close2()
        |> cutin("", 255)

      2 ->
        ctx
        |> mes("[Karl]")
        |> mes("Oh...")
        |> mes("You've already met")
        |> mes("Shinokas, did you?")
        |> mes("You witnessed his ")
        |> mes("death?! This is a very")
        |> mes("strange coincidence.")
        |> next()
        |> mes("[Karl]")
        |> mes("I see, there must be")
        |> mes("no need to investigate")
        |> mes("Shinokas now. And you")
        |> mes("did learn the secret for")
        |> mes("which he was hunted...")
        |> next()
        |> mes("[Guard]")
        |> mes("Mr. President,")
        |> mes("Ms. Hes O' Neil has an")
        |> mes("urgent message for you.")
        |> next()
        |> mes("[Karl]")
        |> mes("Hmm...")
        |> mes("Then please,")
        |> mes("let her in.")
        |> next()
        |> enablenpc("Secretary#2")
        |> next()
        |> mes("[Hes O'Neil]")
        |> mes("Sir, I'm sorry")
        |> mes("for interrupting")
        |> mes("you, but there's")
        |> mes("something I need to")
        |> mes("show you immediately!")
        |> next()
        |> mes("[Karl]")
        |> mes("Alright, let's")
        |> mes("have it. Let me")
        |> mes("see those new files.")
        |> mes("Oh, these are--! Thank")
        |> mes("you, Ms. O' Neil, you")
        |> mes("may leave now.")
        |> next()
        |> mes("[Hes O'Neil]")
        |> mes("Thank you sir.")
        |> mes("Once again, let me")
        |> mes("apologize for disturbing")
        |> mes("your private conference.")
        |> next()
        |> disablenpc("Secretary#2")
        |> next()
        |> mes("[Karl]")
        |> mes("Alright. Please let me")
        |> mes("review these documents")
        |> mes("to see if there are any")
        |> mes("new developments in the")
        |> mes("investigation involving")
        |> mes("Shinokas and his secret...")
        |> set_char_var(:lhz_boss, 25)
        |> close2()
        |> cutin("", 255)

      _ ->
        ctx
    end
  end

  defp review_reports(ctx) do
    if Enum.random(1..10) == 8 do
      ctx
      |> mes("[Karl]")
      |> mes("Alright, I just")
      |> mes("completed reading")
      |> mes("all of these new reports")
      |> mes("from our field agents.")
      |> mes("Thank you for waiting.")
      |> next()
      |> mes("[Karl]")
      |> mes("We've recently learned that")
      |> mes("Shinokas managed to access")
      |> mes("the Regenschirm  Secret Archive,a lab affiliated with Rekenber.")
      |> mes("That's how Shinokas was able")
      |> mes("to learn so much about them.")
      |> next()
      |> mes("[Karl]")
      |> mes("It will be difficult")
      |> mes("and very dangerous to")
      |> mes("access this archive, so")
      |> mes("I want you to meet with")
      |> mes("someone from the Kafra")
      |> mes("Corporation near Lighthalzen.")
      |> next()
      |> mes("[Karl]")
      |> mes("If you keep looking around")
      |> mes("the ^3355FFfields just outside of")
      |> mes("Lighthalzen^000000, you'll certainly")
      |> mes("find her. I'm sorry that I can't")
      |> mes("tell you more, but we've got")
      |> mes("to protect our security...")
      |> next()
      |> mes("[Karl]")
      |> mes("And don't worry...")
      |> mes("She'll know exactly")
      |> mes("who you are and")
      |> mes("how to help you.")
      |> set_char_var(:lhz_boss, 26)
      |> completequest(12_023)
      |> setquest(12_024)
      |> close2()
      |> cutin("", 255)
    else
      ctx
      |> mes("[Karl]")
      |> mes("I apologize, but it's")
      |> mes("taking me a long time")
      |> mes("to go through all of the")
      |> mes("reports in these files.")
      |> mes("Please give me a little more")
      |> mes("time to make sense of them.")
      |> close2()
      |> cutin("", 255)
    end
  end

  defp encourage(ctx) do
    ctx
    |> mes("[Karl]")
    |> mes("I hope you continue")
    |> mes("to keep up the good")
    |> mes("work, not only for the")
    |> mes("sake of the Schwarzwald")
    |> mes("Republic, but for peace")
    |> mes("on all of Midgard.")
    |> close2()
    |> cutin("", 255)
  end

  defp receive_archive_file(ctx) do
    if not Rathena.truthy?(count_item(ctx, 7344)) do
      ctx
      |> mes("[Karl]")
      |> mes("Did you find any")
      |> mes("of that evidence in")
      |> mes("the Secret Archive yet?")
      |> mes("Hurry! The movements in")
      |> mes("Rekenber Corporation are")
      |> mes("making me feel really uneasy.")
      |> close2()
      |> cutin("", 255)
    else
      ctx
      |> mes("[Karl]")
      |> mes("Ah, you're here.")
      |> mes("I've already received a")
      |> mes("message from Esuna")
      |> mes("about your success.")
      |> mes("If you would, please")
      |> mes("let me read the file...")
      |> next()
      |> mes("[Karl]")
      |> mes("Ah, now everything is")
      |> mes("clearer. Shinokas and his")
      |> mes("friends were killed over")
      |> mes("that piece of Ymir's Heart.")
      |> mes("That's what the Rekenber")
      |> mes("Corporation ultimately wants.")
      |> next()
      |> mes("[Karl]")
      |> mes("But this raises some")
      |> mes("new questions. What")
      |> mes("are they planning to")
      |> mes("do with Ymir's Heart?")
      |> mes("It must be more powerful")
      |> mes("than we had thought...")
      |> next()
      |> mes("[Karl]")
      |> mes("We'll need even more")
      |> mes("information. For now,")
      |> mes("please go back to Esuna.")
      |> mes("It seems that she just")
      |> mes("received some critically")
      |> mes("important intel to give you.")
      |> delitem(7344, 1)
      |> set_char_var(:lhz_boss, 38)
      |> close2()
      |> cutin("", 255)
    end
  end

  defp remind_esuna(ctx) do
    ctx
    |> mes("[Karl]")
    |> mes("Please hurry and meet")
    |> mes("Esuna just outside of")
    |> mes("Lighthalzen. Perhaps I am")
    |> mes("getting paranoid, but I keep")
    |> mes("getting the feeling that")
    |> mes("Rekenber is on to us...")
    |> close2()
    |> cutin("", 255)
  end

  defp receive_esuna_file(ctx) do
    if not Rathena.truthy?(count_item(ctx, 7343)) do
      ctx
      |> mes("[Karl]")
      |> mes("You don't have the")
      |> mes("file? Retrieve it for")
      |> mes("me as soon as you can.")
      |> mes("It's imperative that I read")
      |> mes("what Esuna has to report!")
      |> close2()
      |> cutin("", 255)
    else
      {ctx, choice} =
        ctx
        |> mes("[Karl]")
        |> mes("Ah, good to see you")
        |> mes("again. I hear you have")
        |> mes("some important news for")
        |> mes("me, something of the utmost")
        |> mes("urgency. But I fear the worst.")
        |> next()
        |> select(["Give the file from Esuna."])

      case choice do
        1 ->
          ctx
          |> mes("[Karl]")
          |> mes("What...?")
          |> mes("I can't believe this!")
          |> mes("How can our security")
          |> mes("be breached like this?!")
          |> mes("Only someone from")
          |> mes("really deep inside could...")
          |> next()
          |> mes("[Karl]")
          |> mes("Please...")
          |> mes("Would you go and")
          |> mes("speak to Esuna one")
          |> mes("more time? I need to")
          |> mes("know more about how")
          |> mes("all of this happened...")
          |> delitem(7343, 1)
          |> set_char_var(:lhz_boss, 40)
          |> close2()
          |> cutin("", 255)

        _ ->
          ctx
      end
    end
  end

  defp summon_advisor(ctx) do
    ctx
    |> mes("[Karl]")
    |> mes("No...")
    |> mes("I can't...")
    |> mes("Kurelle? We've")
    |> mes("worked together,")
    |> mes("trusted each other")
    |> mes("for years. No, it's not....")
    |> next()
    |> mes("[Karl]")
    |> mes("If it's true, then")
    |> mes("that means I've been")
    |> mes("playing into the enemy's")
    |> mes("hands this whole time.")
    |> mes("I've... I've got to know")
    |> mes("and ask Kurelle myself.")
    |> next()
    |> mes("[Karl]")
    |> mes("O'Neil!")
    |> mes("Bring Kurelle in")
    |> mes("here, right now!")
    |> next()
    |> mes("[Hes O'Neil]")
    |> mes("...Yes, sir.")
    |> mes("Right away.")
    |> next()
    |> set_char_var(:lhz_boss, 42)
    |> close2()
    |> cutin("", 255)
  end

  defp confront_advisor(ctx) do
    ctx
    |> mes("[Guard]")
    |> mes("Advisor Kurelle")
    |> mes("is here now.")
    |> next()
    |> mes("[Karl]")
    |> mes("Let him in!")
    |> mes("...................")
    |> next()
    |> mes("[Guard]")
    |> mes("...............?")
    |> mes("Yes, sir...")
    |> next()
    |> enablenpc("A Neat Gentleman")
    |> next()
    |> mes("[Kurelle]")
    |> mes("Hello, Mr. President.")
    |> mes("What exactly did you")
    |> mes("need from me today?")
    |> next()
    |> mes("[Karl]")
    |> mes("...........")
    |> mes(".......")
    |> mes("...")
    |> next()
    |> mes("[Kurelle]")
    |> mes("???")
    |> mes(".......")
    |> next()
    |> mes("[Karl]")
    |> mes("Did you...")
    |> mes("Why did you betray us?!")
    |> mes("After all this time, why now?")
    |> next()
    |> mes("[Kurelle]")
    |> mes("...")
    |> mes("......")
    |> mes("So you know.")
    |> mes("Well, you're smarter")
    |> mes("than I gave you credit for.")
    |> next()
    |> mes("[Kurelle]")
    |> mes("Ha ha ha~")
    |> mes("Right, it was me.")
    |> mes("Your right hand man.")
    |> mes("I reported everything")
    |> mes("you were doing to the")
    |> mes("Rekenber Corporation.")
    |> next()
    |> mes("[Karl]")
    |> mes("But why...?")
    |> mes("I thought we were")
    |> mes("working together for")
    |> mes("the greater good, to")
    |> mes("do the right thing?")
    |> next()
    |> mes("[Kurelle]")
    |> mes("Forget that! I'm sick")
    |> mes("of being second place")
    |> mes("to you. All our lives, you've")
    |> mes("always been on top. School,")
    |> mes("athletics, politics. Well, here's my chance to finally beat you!")
    |> next()
    |> mes("[Karl]")
    |> mes("I can't believe this. All")
    |> mes("those years of friendship")
    |> mes("were all a lie? We even")
    |> mes("joined Secret Wing together.")
    |> mes("This whole time, you were")
    |> mes("harboring a silly grudge...")
    |> next()
    |> mes("[Kurelle]")
    |> mes("Shut up! It's not a")
    |> mes("silly grudge! ...You there.")
    |> mes("Adventurer. Can't you see")
    |> mes("this man is finished?! But")
    |> mes("it's not too late. Join us.")
    |> mes("Rekenber could use you.")
    |> next()
    |> mes("[Kurelle]")
    |> mes("Now that I've helped")
    |> mes("the Rekenber Corporation,")
    |> mes("I'll get their support in the")
    |> mes("next presidential election.")
    |> mes("I'll beat you for sure, Karl!")
    |> mes("Bwahahahahahaahahahhaah~!")
    |> next()
    |> disablenpc("A Neat Gentleman")
    |> mes(".......")
    |> mes(".........")
    |> mes("...........")
    |> next()
    |> mes("[Karl]")
    |> mes("It's all over for")
    |> mes("now. This isn't good")
    |> mes("at all. You're finished")
    |> mes("here too. Go and talk to")
    |> mes("^3355FFGhalstein^000000 again. It's time")
    |> mes("we let you loose, adventurer.")
    |> set_char_var(:lhz_boss, 43)
    |> close2()
    |> cutin("", 255)
  end

  defp finish_quests(ctx) do
    ctx
    |> mes("[Karl]")
    |> mes(".........")
    |> mes("............")
    |> set_local(:i, 12_015)
    |> complete_pending_quests()
    |> close()
  end

  defp receive_research(ctx) do
    if not Rathena.truthy?(count_item(ctx, 7342)) do
      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat("[", char_name(ctx, 0)),
          "]"
        )
      )
      |> mes("Ah, where did I put the record?")
      |> close()
    else
      ctx =
        ctx
        |> mes("[Karl]")
        |> mes("It's you.....!")
        |> mes("It's really been a long time.")
        |> next()

      ctx =
        ctx
        |> mes(
          Rathena.concat(
            Rathena.concat("[", char_name(ctx, 0)),
            "]"
          )
        )
        |> mes("So, are you still having the idea to go against Rekenber?")
        |> next()
        |> mes("[Karl]")
        |> mes("...................")
        |> next()
        |> mes("[Karl]")
        |> mes("I'm not sure.")
        |> mes(
          "The Secret Wing has been disbanded and I am just another puppet they have, just like the previous presidents."
        )
        |> next()

      ctx =
        ctx
        |> mes(
          Rathena.concat(
            Rathena.concat("[", char_name(ctx, 0)),
            "]"
          )
        )
        |> mes(
          "Not long ago, the scientists of Regenschrim have stolen the research record and destroyed the machines that they used for research purposes."
        )
        |> next()
        |> emotion(:surprise)
        |> mes("[Karl]")
        |> mes("...!")
        |> mes("Did you do that? ")
        |> mes(
          "I still fail to move on after the incident of my friends' betrayal and the disband of the Secret Wing..."
        )
        |> mes("You are really a great friend.")
        |> next()
        |> mes("[Karl]")
        |> mes("Didn't you speak about the research record just now?")
        |> mes("Oh! Can you give me the record?")
        |> mes("It will be a big trouble to them.")
        |> next()

      ctx =
        ctx
        |> mes(
          Rathena.concat(
            Rathena.concat("[", char_name(ctx, 0)),
            "]"
          )
        )
        |> mes("If you insist to go against them, I will give you the record.")
        |> next()
        |> mes("[Karl]")
        |> mes("I am the president of this country.")
        |> mes("I have failed before but I won't stop trying when there is still an opportunity.")
        |> next()
        |> mes("[Karl]")
        |> mes("You remind me of the day I made up my mind to rebuild this country.")
        |> mes("How could I forgot such important responsibilities of mine.")
        |> next()

      ctx =
        ctx
        |> mes(
          Rathena.concat(
            Rathena.concat("[", char_name(ctx, 0)),
            "]"
          )
        )
        |> mes("That's great.")
        |> mes("Here's the record.")
        |> mes("I hope you will make good use of it. ")
        |> next()
        |> mes("[Karl]")
        |> mes("Let's see...")
        |> next()
        |> mes("[Karl]")
        |> mes("Oh! That's some interesting information.")
        |> next()

      ctx =
        ctx
        |> mes(
          Rathena.concat(
            Rathena.concat("[", char_name(ctx, 0)),
            "]"
          )
        )
        |> mes(
          "I have another good news. The Secret Wing has not given up yet. They are still working on the project and I hope that you won't be giving up on it too."
        )
        |> next()
        |> mes("[Karl]")
        |> mes(".....I feel so sorry for what I did.")
        |> next()
        |> mes("[Karl]")
        |> mes(
          "Thank you for bringing this great gift. I will stay strong and work hard to achieve my target."
        )
        |> next()
        |> mes("[Karl]")
        |> mes(
          "I will recruit the new batch of members and use them to let the world know about what the corporation had really done."
        )
        |> next()
        |> mes("[Karl]")
        |> mes("Thank you so much. ")
        |> mes("You can count on me to right what was wrong.")
        |> set_char_var(:hg_tre, 57)
        |> delitem(7342, 1)

      ctx
      |> getexp(
        if(Rathena.truthy?(checkre(ctx, 3)),
          do: 200_000,
          else: 2_000_000
        ),
        0
      )
      |> give_item(617, 1)
      |> close2()
      |> cutin("", 255)
    end
  end

  defp discuss_research(ctx) do
    ctx
    |> mes("[Karl]")
    |> mes(
      "I am trying to recruit capable people who can help me to bring down Rekenber Corporation."
    )
    |> mes("Thanks to you, I have enough information as a good beginning to nail them now down.")
    |> next()
    |> mes("[Karl]")
    |> mes(
      "I have had my men to gather some information and learned that Regenschrim had stopped operating now."
    )
    |> mes("You have done well for the Schwarzwald Republic.")
    |> close2()
    |> cutin("", 255)
  end

  defp farewell(ctx) do
    ctx
    |> mes("[Karl]")
    |> mes(".........")
    |> mes("............")
    |> close2()
    |> cutin("", 255)
  end

  defp mission_questions(ctx) do
    {ctx, choice} =
      select(ctx, [
        "Secret Wing's Background",
        "Rekenber's Purpose",
        "Secret Wing's Goal",
        "Details about my mission",
        "I'm ready for my mission."
      ])

    case choice do
      1 ->
        ctx
        |> mes("[Karl]")
        |> mes("Rekenber has been")
        |> mes("unopposed for a very long")
        |> mes("time. Our nation is unhappy")
        |> mes("with their rule, but since our")
        |> mes("country lacks solidarity, the")
        |> mes("people can do nothing.")
        |> next()
        |> mes("[Karl]")
        |> mes("But one day, I was contacted")
        |> mes("by some people who claimed to")
        |> mes("share my sentiments against")
        |> mes("the Rekenber Corporation.")
        |> mes("Later, I learned that they were")
        |> mes("from the Kafra Corporation.")
        |> next()
        |> mes("[Karl]")
        |> mes("Apparently, they were")
        |> mes("facing some aggressive")
        |> mes("competition from Cool")
        |> mes("Event Corp, which is")
        |> mes("actually backed by the")
        |> mes("Rekenber Corporation.")
        |> next()
        |> mes("[Karl]")
        |> mes("We decided to pool our")
        |> mes("resources to deal with what")
        |> mes("we perceived as a common")
        |> mes("enemy. Before long, we gathered")
        |> mes("more devotees to our cause and")
        |> mes("formed the ''Secret Wing.''")
        |> next()
        |> mes("[Karl]")
        |> mes("It may be helpful for")
        |> mes("you to know that our")
        |> mes("direct contact to the")
        |> mes("Kafra Corporation is the")
        |> mes("^FF00003rd Security Team^000000. Oh, did")
        |> mes("you have any other questions?")
        |> next()
        |> mission_questions()

      2 ->
        ctx
        |> mes("[Karl]")
        |> mes("It's true that companies")
        |> mes("exist to create money, but")
        |> mes("the Rekenber Corporation")
        |> mes("is much more nefarious.")
        |> mes("They actually want to dominate the entire Midgard continent.")
        |> next()
        |> mes("[Karl]")
        |> mes("In fact, the chairman of")
        |> mes("that company is shrouded")
        |> mes("in mystery. Although I'm")
        |> mes("the president, I go through")
        |> mes("many difficulties just to")
        |> mes("send a message to him.")
        |> next()
        |> mes("[Karl]")
        |> mes("It's disheartening,")
        |> mes("but we really have no")
        |> mes("idea what their true goals")
        |> mes("and plans might be. Now, did")
        |> mes("you have any other questions?")
        |> next()
        |> mission_questions()

      3 ->
        ctx
        |> mes("[Karl]")
        |> mes("''Secret Wing's'' only")
        |> mes("goal is to destroy the")
        |> mes("Rekenber Corporation in")
        |> mes("order to break the Schwarzwald Republic free from its oppression.")
        |> next()
        |> mes("[Karl]")
        |> mes("Of course, we realize")
        |> mes("that it will take time and")
        |> mes("a lot of sacrifice to make")
        |> mes("this a reality. Now, do you")
        |> mes("have anything else to ask?")
        |> next()
        |> mission_questions()

      4 ->
        ctx
        |> mes("[Karl]")
        |> mes("Ah, your next mission.")
        |> mes("I'm ready to give you")
        |> mes("some of the details if")
        |> mes("you no longer have any")
        |> mes("questions to ask. Let me")
        |> mes("know when you are ready.")
        |> next()
        |> mission_questions()

      5 ->
        {ctx, answer} =
          ctx
          |> mes("[Karl]")
          |> mes("Very well, then.")
          |> mes("Your mission will not")
          |> mes("be too difficult, but it does")
          |> mes("have great urgency so you")
          |> mes("must accomplish it as soon")
          |> mes("as you can. Understood?")
          |> next()
          |> select(["Wait, I have one more question!", "Yes sir, Mr. President."])

        case answer do
          1 ->
            ctx
            |> mes("[Karl]")
            |> mes("Hm? I thought you")
            |> mes("didn't have any more")
            |> mes("questions. However, I still")
            |> mes("have the luxury to give you")
            |> mes("any answers that I can provide.")
            |> next()
            |> mission_questions()

          2 ->
            ctx
            |> mes("[Karl]")
            |> mes("I'm glad to hear that.")
            |> mes("Alright, give me a second")
            |> mes("to search for this file before")
            |> mes("I explain the mission.")
            |> set_char_var(:lhz_boss, 15)
            |> close2()
            |> cutin("", 255)

          _ ->
            ctx
        end

      _ ->
        ctx
    end
  end

  defp complete_pending_quests(ctx) do
    if get_local(ctx, :i, 0) < 12_028 do
      ctx =
        if checkquest(ctx, get_local(ctx, :i, 0)) >= 0 and
             checkquest(ctx, get_local(ctx, :i, 0)) < 2 do
          completequest(ctx, get_local(ctx, :i, 0))
        else
          ctx
        end

      ctx |> set_local(:i, get_local(ctx, :i, 0) + 1) |> complete_pending_quests()
    else
      ctx
    end
  end
end
