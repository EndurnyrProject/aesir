defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Daewoon do
  @moduledoc """
  Daewoon, the Payon examiner of The Sign quest who tests the player's character in conversation.

  ## Behavior

  - At step 14 with a Sobbing Starlight fragment (7177) he asks a series of personality
    questions, each answer adding to a hidden score that starts at 1.
  - A score above 26 passes: he advances the quest to step 15, gives another fragment and grants
    base EXP by level (renewal 300 to 1800, pre-renewal 3000 to 18000), with a warmer farewell
    above 29. Answering "To hell with this!" also costs 10% HP.
  - A score below 27 fails the test without consuming anything, so it can be retried.
  - At step 14 without the fragment, before step 14, at step 15, on a failed quest (98) or after
    completion (99) he only gives the matching dialogue.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "payon_in03",
        x: 11,
        y: 31,
        dir: 4,
        sprite: 808,
        name: "Daewoon",
        scope: :shared,
        unique_name: "Daewoon#sign"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars
  alias Aesir.ZoneServer.Script.Rathena

  @starlight_fragment 7177

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])

    ctx =
      ctx
      |> mes("[Daewoon]")
      |> mes("Mwah ah hah!")
      |> mes("Feasting and merriment,")
      |> mes("wine, women and song!")
      |> mes("I could ask for nothing more!")
      |> next()
      |> mes("[Daewoon]")
      |> mes("The most scrumptious")
      |> mes("delicacies are all mine to")
      |> mes("taste! And I'm not just talking about the food. Mwah ah hah!")
      |> mes("I'm the king of the world!")
      |> next()

    talk(ctx, get_char_var(ctx, :sign_q, 0))
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp talk(ctx, 14) do
    ctx =
      ctx
      |> mes("[Daewoon]")
      |> mes("Oh, a visitor?")
      |> mes("I'm sorry, but I believe")
      |> mes("you're an uninvited guest~")
      |> uninvited_guest_remark()
      |> next()

    if count_item(ctx, @starlight_fragment) > 0 do
      take_test(ctx)
    else
      ctx
      |> mes("[Daewoon]")
      |> mes("I wonder...")
      |> mes("Someone should have")
      |> mes("passed Arian's test by now.")
      |> mes("I can't wait to see who was")
      |> mes("actually able to impress him...")
      |> close()
    end
  end

  defp talk(ctx, step) when step < 14 do
    ctx
    |> mes("[Daewoon]")
    |> mes("Mwah ah hah~!")
    |> mes("I couldn't be happier!")
    |> mes("What more do I need?")
    |> mes("Gourmet food, fine wine,")
    |> mes("nubile women...!")
    |> close()
  end

  defp talk(ctx, 98) do
    ctx
    |> mes("[Daewoon]")
    |> mes("I'm sorry, but ")
    |> mes("no price can make")
    |> mes("me change my mind.")
    |> mes("You... You've failed.")
    |> mes("I'm sorry, friend.")
    |> close()
  end

  defp talk(ctx, 99) do
    ctx
    |> emotion(:surprise)
    |> mes("[Daewoon]")
    |> mes("Oh~! It's you!")
    |> mes("It has been a while since")
    |> mes("we last conversed. Now that")
    |> mes("you've accessed the power")
    |> mes("behind the Sobbing Starlight,")
    |> mes("do you like it?")
    |> next()
    |> select(["Yes", "No"])
    |> power_opinion()
  end

  defp talk(ctx, 15) do
    ctx
    |> mes("[Daewoon]")
    |> mes("Hm...?")
    |> mes("Weren't you on")
    |> mes("your way to find")
    |> mes("^CE0000Sir Jore^000000 in Al de Baran?")
    |> next()
    |> mes("[Daewoon]")
    |> mes("Oh, having trouble")
    |> mes("finding him, are you?")
    |> mes("Well, he's fairly shy, but")
    |> mes("I'm sure he's hiding some")
    |> mes("place in that town.")
    |> close()
  end

  defp talk(ctx, _step) do
    ctx
    |> mes("[Daewoon]")
    |> mes("Ah, I feel so...")
    |> mes("Satiated. The food was ")
    |> mes("stupendous and the women")
    |> mes("have been even more so.")
    |> mes("Servants! Fan me please~")
    |> next()
    |> mes("[Daewoon]")
    |> mes("^333333*Yawn...*")
    |> mes("...z...z...Z....ZZzZZ^000000")
    |> close()
  end

  defp uninvited_guest_remark(ctx) do
    if sex(ctx) == 1 do
      ctx
      |> mes("You'll have to forgive me")
      |> mes("if I wish to spend my time with maidens as opposed to men.")
    else
      ctx
      |> mes("No matter, a beauty is a beauty, whether or not I know her name.")
      |> mes("Come and drink with me~")
    end
  end

  defp power_opinion({ctx, 1}) do
    ctx
    |> mes("[Daewoon]")
    |> mes("Ah, how great~!")
    |> mes("Just remember that")
    |> mes("power can be addictive.")
    |> mes("Even if you don't agree,")
    |> mes("it's still wise to avoid")
    |> mes("greedy tendencies, yes?")
    |> next()
    |> mes("[Daewoon]")
    |> mes("Please make good use of")
    |> mes("the power you have obtained.")
    |> mes("I am counting on you to be")
    |> mes("responsbile and to never lose")
    |> mes("that smile on your face, okay?")
    |> mes("Mwah ah hah~!")
    |> close()
  end

  defp power_opinion({ctx, 2}) do
    ctx
    |> emotion(:scratch)
    |> mes("[Daewoon]")
    |> mes("Eh...?")
    |> mes("That's quite a surprise.")
    |> mes("Perhaps Metz didn't know")
    |> mes("enough about it? Still, I'm")
    |> mes("sorry to hear you don't like it.")
    |> next()
    |> mes("[Daewoon]")
    |> mes("But in the end, keep in mind")
    |> mes(
      "that you must have learned some great lesson from this experience. Anyway, please do your best to use the power responsibly, okay?"
    )
    |> mes("Mwah ah hah~!")
    |> close()
  end

  defp power_opinion({ctx, _}), do: ctx

  defp take_test(ctx) do
    with {:ok, ctx, points} <- ask_about_jewel(ctx, 1),
         {:ok, ctx, points} <- ask_readiness(ctx, points),
         {:ok, ctx, points} <- ask_about_friends(ctx, points),
         {:ok, ctx, points} <- ask_about_mob_training(ctx, points),
         {:ok, ctx, points} <- ask_about_emperium(ctx, points),
         {:ok, ctx, points} <- ask_about_enemy(ctx, points),
         {:ok, ctx} <- ask_about_life(ctx) do
      judge(ctx, points)
    else
      {:end, ctx} -> ctx
    end
  end

  defp ask_about_jewel(ctx, points) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Sure...")
    |> mes("But first, would you")
    |> mes("take a look at this?")
    |> next()
    |> mes("^3355FFYou carefully take")
    |> mes("out the small, lucid")
    |> mes("jewel that Arian gave")
    |> mes("you and reveal it to")
    |> mes("Daewoon's roving eyes.^000000")
    |> next()
    |> emotion(:surprise)
    |> mes("[Daewoon]")
    |> mes("Eh? Why that's...")
    |> mes("I see now, Arian must")
    |> mes("have sent you! Oh you")
    |> mes("should have said so")
    |> mes("at the very beginning~")
    |> next()
    |> mes("[Daewoon]")
    |> mes("My apologies~")
    |> mes("Lately I've been attracting")
    |> mes(
      "all sorts of strange attention like some kind of teen celebrity. I've gotten used to being too careful in screening out the dangerous sort."
    )
    |> next()
    |> mes("[Daewoon]")
    |> mes("Now then.")
    |> mes("Do you have any")
    |> mes("idea what that jewel")
    |> mes("you're holding actually is?")
    |> next()
    |> select(["Kind of?", "How the hell would I know?", "No, but would you tell me?"])
    |> jewel_answer(points)
  end

  defp jewel_answer({ctx, 1}, points) do
    ctx
    |> mes("[Daewoon]")
    |> mes("Oh...!")
    |> mes("You must be much")
    |> mes("smarter than I expected.")
    |> mes("So tell me, what do you")
    |> mes("understand about this jewel?")
    |> next()
    |> select(["It's handy.", "I actually don't know..."])
    |> jewel_understanding(points)
  end

  defp jewel_answer({ctx, 2}, points) do
    ctx =
      ctx
      |> mes("[Daewoon]")
      |> emotion(:think)
      |> mes("...")
      |> mes("A rather crass way")
      |> mes("of speaking, but perhaps")
      |> mes("you picked it up from Arian.")
      |> mes("In any case, let me explain.")
      |> next()

    {:ok, ctx, points}
  end

  defp jewel_answer({ctx, 3}, points) do
    ctx =
      ctx
      |> mes("[Daewoon]")
      |> mes("Didn't Arian tell you")
      |> mes("anything? I appreciate")
      |> mes("your honesty. And I don't")
      |> mes("mind chatting a while, I much")
      |> mes("prefer speaking to honest people rather than foolish know-it-alls.")
      |> next()

    {:ok, ctx, points + 5}
  end

  defp jewel_answer({ctx, _}, _points), do: {:end, ctx}

  defp jewel_understanding({ctx, 1}, points) do
    ctx =
      ctx
      |> mes("[Daewoon]")
      |> emotion(:think)
      |> mes("Mmm...?")
      |> mes("Handy? If you truly")
      |> mes("understood, I don't")
      |> mes("think you'd describe this")
      |> mes("jewel as merely 'handy.'")
      |> next()

    {:ok, ctx, points + 2}
  end

  defp jewel_understanding({ctx, 2}, points) do
    ctx =
      ctx
      |> emotion(:hng)
      |> mes("[Daewoon]")
      |> mes("Really?")
      |> mes("Mm. At least you")
      |> mes("admit it. *Sigh*")
      |> next()

    {:ok, ctx, points + 4}
  end

  defp jewel_understanding({ctx, _}, _points), do: {:end, ctx}

  defp ask_readiness(ctx, points) do
    ctx
    |> mes("[Daewoon]")
    |> mes("That ^31009CSobbing Starlight^000000")
    |> mes("is no mere jewel. It is a key")
    |> mes(
      "item for unlocking some incredible power. I believe Metz happened to obtain a piece, though I am"
    )
    |> mes("unsure how...")
    |> next()
    |> mes("[Daewoon]")
    |> mes("Metz has asked me and")
    |> mes("some other friends who")
    |> mes("hold the fragments of the")
    |> mes("Sobbing Starlight to entrust")
    |> mes("them to someone worthy of")
    |> mes("finding the power it leads to.")
    |> next()
    |> mes("[Daewoon]")
    |> mes("Of course, we all agreed")
    |> mes("and now you're here for me")
    |> mes("to judge whether or not you're")
    |> mes("qualified for this task. Now,")
    |> mes("are you ready for my test?")
    |> next()
    |> select([
      "I'M READY! YEEAH!",
      "I'll do my best!",
      "To hell with this!",
      "Fine. Let's get it over with."
    ])
    |> readiness_answer(points)
  end

  defp readiness_answer({ctx, 1}, points) do
    ctx =
      ctx
      |> mes("[Daewoon]")
      |> mes("Ooh~")
      |> mes("Such unbridled")
      |> mes("enthusiasm usually")
      |> mes("does more good than harm.")
      |> next()

    {:ok, ctx, points + 5}
  end

  defp readiness_answer({ctx, 2}, points) do
    ctx =
      ctx
      |> emotion(:ok)
      |> mes("[Daewoon]")
      |> mes("Mwah ah hah!")
      |> mes("That's exactly what")
      |> mes("I wanted to hear! That")
      |> mes("kind of quiet and careful")
      |> mes("confidence will help you")
      |> mes("in the future, you'll see~")
      |> next()

    {:ok, ctx, points + 7}
  end

  defp readiness_answer({ctx, 3}, points) do
    ctx =
      ctx
      |> emotion(:fret)
      |> mes("[Daewoon]")
      |> mes("E...")
      |> mes("Excuse me?")
      |> next()
      |> emotion(:anger)
      |> mes("[Daewoon]")
      |> mes("How can you be")
      |> mes("so ridiculous at")
      |> mes("at time like this?")
      |> mes("Either mind your manners")
      |> mes("or don't take this test at")
      |> mes("all! ^333333*SLAP--!!*^000000")
      |> percent_heal(hp: -10, sp: 0)
      |> next()

    {:ok, ctx, points + 2}
  end

  defp readiness_answer({ctx, 4}, points) do
    ctx =
      ctx
      |> emotion(:think)
      |> mes("[Daewoon]")
      |> mes("Hmm. That kind of half-hearted")
      |> mes(
        "attitude won't get you very far on your adventures. Still, so long as you don't get overly negative, you should have a decent chance of surviving your challenges."
      )
      |> next()

    {:ok, ctx, points + 4}
  end

  defp readiness_answer({ctx, _}, _points), do: {:end, ctx}

  defp ask_about_friends(ctx, points) do
    ctx
    |> mes("[Daewoon]")
    |> mes("Now, Metz expects me to ask")
    |> mes("some rather serious questions,")
    |> mes("but that really isn't my style. For this test, why don't we just talk?")
    |> mes("Just answer me honestly and")
    |> mes("light heartedly, alright?")
    |> emotion(:scratch)
    |> next()
    |> mes("[Daewoon]")
    |> mes("So...")
    |> mes("Do you have a lot")
    |> mes("of friends that you can")
    |> mes("constantly party with?")
    |> next()
    |> select(["Yes, I do.", "I prefer soloing.", "I am lonely."])
    |> friends_answer(points)
  end

  defp friends_answer({ctx, 1}, points) do
    ctx =
      ctx
      |> emotion(:huk)
      |> mes("[Daewoon]")
      |> mes("Oh, that's great~!")
      |> mes("To have many friends")
      |> mes("is a priceless blessing.")
      |> mes("Friends bring us joy and")
      |> mes("aid when we find ourselves")
      |> mes("suffering from difficulties.")
      |> next()
      |> mes("[Daewoon]")
      |> mes("Wouldn't you")
      |> mes("agree that being")
      |> mes("really close friends")
      |> mes("with someone can be")
      |> mes("a life long benefit?")
      |> next()

    {:ok, ctx, points + 5}
  end

  defp friends_answer({ctx, 2}, points) do
    ctx =
      ctx
      |> mes("[Daewoon]")
      |> mes("Well, everybody")
      |> mes("needs to be alone once")
      |> mes("in a while. And there are")
      |> mes("some battles you must")
      |> mes("fight all on your own.")
      |> next()
      |> mes("[Daewoon]")
      |> mes("Also, if you never")
      |> mes("deal with other people,")
      |> mes("you may grow selfish or")
      |> mes("needy. It's better to go")
      |> mes("out and meet people,")
      |> mes("don't you think?")
      |> next()

    {:ok, ctx, points + 4}
  end

  defp friends_answer({ctx, 3}, points) do
    ctx =
      ctx
      |> mes("[Daewoon]")
      |> mes("You don't have any")
      |> mes("friends at all? Well,")
      |> mes("you better learn how")
      |> mes("to get along with others")
      |> mes("as soon as you can...!")
      |> next()

    {:ok, ctx, points + 3}
  end

  defp friends_answer({ctx, _}, _points), do: {:end, ctx}

  defp ask_about_mob_training(ctx, points) do
    ctx
    |> mes("[Daewoon]")
    |> mes("Now, what's your opinion")
    |> mes("on purposely getting lots")
    |> mes("of monsters to follow you")
    |> mes("around. I believe this is")
    |> mes("called ''Mob Training...''")
    |> next()
    |> select(["Awesome~!", "I hate people who do that.", "I do it sometimes..."])
    |> mob_training_answer(points)
  end

  defp mob_training_answer({ctx, 1}, points) do
    ctx =
      ctx
      |> emotion(:fret)
      |> mes("[Daewoon]")
      |> mes("But...")
      |> mes("Wouldn't that be really")
      |> mes("rude to anyone else hunting")
      |> mes("on that same map? I think")
      |> mes("it would even interfere with")
      |> mes("someone else's gameplay...")
      |> next()
      |> emotion(:fret)
      |> mes("[Daewoon]")
      |> mes("Perhaps you should try")
      |> mes("to consider other people's")
      |> mes("feelings. Mob Training seems")
      |> mes("to only be good at getting other")
      |> mes("people angry with you...")
      |> next()

    {:ok, ctx, points}
  end

  defp mob_training_answer({ctx, 2}, points) do
    ctx =
      ctx
      |> mes("[Daewoon]")
      |> mes("Really?")
      |> mes("I do too!")
      |> next()
      |> mes("[Daewoon]")
      |> mes("Just the other day, I've")
      |> mes("heard some ruffians boasting")
      |> mes(
        "of their mob training activities. But personally, I feel they were compensating for their own shortcomings. "
      )
      |> next()
      |> emotion(:fret)
      |> mes("[Daewoon]")
      |> mes("Such behavior truly")
      |> mes("bothers me. Although I have")
      |> mes("spent years in developing an")
      |> mes("unflappable personality, I find")
      |> mes("myself irked when encountering")
      |> mes("such troublemakers.")
      |> next()
      |> emotion(:best)
      |> mes("[Daewoon]")
      |> mes("When you face obstacles")
      |> mes(
        "in your own training, never give in to weakness. Assert yourself and find the determination to overcome your tribulations with honor!"
      )
      |> next()

    {:ok, ctx, points + 5}
  end

  defp mob_training_answer({ctx, 3}, points) do
    ctx =
      ctx
      |> mes("[Daewoon]")
      |> mes("At least you're honest.")
      |> mes("But let me say that I cannot")
      |> mes("condone that sort of weak willed behavior. True strength can only")
      |> mes("be found through honor.")
      |> mes("Remember that.")
      |> next()
      |> mes("[Daewoon]")
      |> mes("In the face of overwhelming")
      |> mes(
        "odds, do not despair. After all, what is achievement if it is not earned without difficulty? The greater the challenge, the"
      )
      |> mes("greater the glory.")
      |> next()
      |> mes("[Daewoon]")
      |> mes("Even if you are having hard time,")
      |> mes("try to take a firm stand.")
      |> mes("One day, you will realise how strong you have become.")
      |> next()
      |> mes("[Daewoon]")
      |> mes("And...")
      |> mes("Don't ever partake in")
      |> mes("mob training again, okay?")
      |> next()

    {:ok, ctx, points + 3}
  end

  defp mob_training_answer({ctx, _}, _points), do: {:end, ctx}

  defp ask_about_emperium(ctx, points) do
    ctx
    |> mes("[Daewoon]")
    |> mes("Anyway, I'm sure you're")
    |> mes("aware of the War of Emperium")
    |> mes(
      "in which mighty guilds all across Midgard battle for guild castle dominion. It's actually quite popular, really."
    )
    |> next()
    |> mes("[Daewoon]")
    |> mes("Now imagine that both of us")
    |> mes(
      "are in the midst of a heated guild war. The sounds of explosions and earth shaking magic spells are all we can hear. At any time, we can"
    )
    |> mes("be lost in that mindless chaos.")
    |> next()
    |> mes("[Daewoon]")
    |> mes("Finally, through incredible")
    |> mes("good fortune, we manage to")
    |> mes(
      "infiltrate the enemy guild castle and reach their Emperium. If we destroy that Emperium, that castle will belong to our guild."
    )
    |> next()
    |> mes("[Daewoon]")
    |> mes("However...! This is")
    |> mes("no ordinary Emperium!")
    |> mes("It is a masterful sculpture")
    |> mes("of a gorgeous Priestess!")
    |> mes("Answer me, adventurer!")
    |> mes("Would you still destroy it?!")
    |> next()
    |> select([
      "Destroy it!",
      "I can't destroy such beauty...",
      "I'd close my eyes, then destroy it."
    ])
    |> emperium_answer(points)
  end

  defp emperium_answer({ctx, 1}, points) do
    ctx =
      ctx
      |> mes("[Daewoon]")
      |> mes("Hmm. You have a truly")
      |> mes("strong will. Then again,")
      |> beauty_remark()

    {:ok, ctx, points + 3}
  end

  defp emperium_answer({ctx, 2}, points) do
    ctx =
      ctx
      |> mes("[Daewoon]")
      |> mes(
        "Ah yes! I felt you would answer that way! We must cherish and protect what is beautiful in this world. I would never be able to harm a Priestess, even in"
      )
      |> mes("statue form...")

    {:ok, ctx, points + 5}
  end

  defp emperium_answer({ctx, 3}, points) do
    ctx =
      ctx
      |> mes("[Daewoon]")
      |> mes("Interesting...!")
      |> mes("Although you cherish")
      |> mes("the beauty of the Priestess,")
      |> mes("your loyalty to your guild")
      |> mes("proves stronger. A most")
      |> mes("admirable attitude!")

    {:ok, ctx, points + 6}
  end

  defp emperium_answer({ctx, _}, _points), do: {:end, ctx}

  defp beauty_remark(ctx) do
    if sex(ctx) == 1 do
      ctx
      |> mes("perhaps you lack a true")
      |> mes("appreciation for beauty.")
      |> mes("Even in Emperium form, how")
      |> mes("could you harm a Priestess?")
    else
      ctx
      |> mes("perhaps you cannot appreciate")
      |> mes("a Priestess's beauty in the")
      |> mes("way that a man would.")
    end
  end

  defp ask_about_enemy(ctx, points) do
    ctx
    |> next()
    |> mes("[Daewoon]")
    |> mes("But yes, if it were")
    |> mes("me, I would protect that")
    |> mes("Priestess shaped Emperium")
    |> mes("until the end of the guild war.")
    |> mes("Mwah ah hah~!")
    |> next()
    |> mes("[Daewoon]")
    |> mes("While we're on the topic")
    |> mes("of guilds, let me present")
    |> mes(
      "another guild related scenario. Let's say that you joined a very popular guild with many allies,"
    )
    |> mes("as well as formidable enemies.")
    |> next()
    |> mes("[Daewoon]")
    |> mes("Now, during one of your.")
    |> mes("hunts, you happen to meet")
    |> mes(
      "a member of one of your enemy guilds. The two of you are the only people on that map. Suddenly, he finds himself in mortal danger!"
    )
    |> next()
    |> mes("[Daewoon]")
    |> mes("This enemy guild member")
    |> mes("begins to yell for help. Now,")
    |> mes("would you give your enemy")
    |> mes("the help that he needs?")
    |> next()
    |> select([
      "Yes, of course!",
      "I'd pretend not to hear anything.",
      "I'd make fun of him, then run off."
    ])
    |> enemy_answer(points)
  end

  defp enemy_answer({ctx, 1}, points) do
    ctx =
      ctx
      |> mes("[Daewoon]")
      |> mes("Ah, you would help him!")
      |> mes("Good, good. I'm glad to see")
      |> mes(
        "that you understand that such pettiness should not get in the way of doing what is good and right."
      )

    {:ok, ctx, points + 6}
  end

  defp enemy_answer({ctx, 2}, points) do
    ctx =
      ctx
      |> mes("[Daewoon]")
      |> mes("True, you're not really")
      |> mes("obligated to help your")
      |> mes("enemy. Besides, you may")
      |> mes("hurt his feelings once he")
      |> mes("realizes that he's had to")
      |> mes("depend on his rival for help.")

    {:ok, ctx, points + 5}
  end

  defp enemy_answer({ctx, 3}, points) do
    ctx =
      ctx
      |> mes("[Daewoon]")
      |> mes("Even though he is")
      |> mes("your enemy, I still")
      |> mes("believe it's important")
      |> mes("that you treat him with")
      |> mes("respect. Where is your honor?")

    {:ok, ctx, points + 4}
  end

  defp enemy_answer({ctx, _}, _points), do: {:end, ctx}

  defp ask_about_life(ctx) do
    ctx
    |> next()
    |> mes("[Daewoon]")
    |> mes("Well, there's one")
    |> mes("last thing I want to")
    |> mes("know about you. It's the")
    |> mes("most important question")
    |> mes("in the world once you")
    |> mes("think about it.")
    |> next()
    |> mes("[Daewoon]")
    |> mes("...")
    |> mes("......")
    |> mes("Do you enjoy life?")
    |> next()
    |> select(["Yes", "No"])
    |> life_answer()
  end

  defp life_answer({ctx, 1}) do
    ctx =
      ctx
      |> mes("[Daewoon]")
      |> emotion(:smile)
      |> mes("I'm glad.")
      |> mes("When you don't live")
      |> mes("with zeal, it's easy to")
      |> mes("forget your goals and your")
      |> mes("purpose for living. Don't have")
      |> mes("any? Then make some up.")
      |> next()
      |> mes("[Daewoon]")
      |> mes("I hope you always enjoy")
      |> mes("life as much as you can.")
      |> mes("As for me, I'm always happy")
      |> mes("with my wine, women and song~")
      |> mes("Mwah ah hah~!")
      |> next()

    {:ok, ctx}
  end

  defp life_answer({ctx, 2}) do
    ctx =
      ctx
      |> mes("[Daewoon]")
      |> mes("I understand.")
      |> mes("People cannot be happy")
      |> mes("all the time. Sometimes")
      |> mes("it's easy to forget your")
      |> mes("goals and purpose in life.")
      |> next()
      |> mes("[Daewoon]")
      |> mes("But you know what? If you")
      |> mes("have just one dream, one goal")
      |> mes(
        "to strive towards, things shall get better. If you think you don't have dreams, look back to your past. What you remember may surprise you."
      )
      |> next()
      |> mes("[Daewoon]")
      |> mes("It's important to look forward,")
      |> mes(
        "but first you must find what is truly precious to you before you can define your happiness. That's why I think it's good to experience new things as well as reflect."
      )
      |> next()
      |> emotion(:best)
      |> mes("[Daewoon]")
      |> mes("Now, what's precious to me?")
      |> mes("Three things, actually...")
      |> mes("Wine. Women. And song!")
      |> mes("Though, if I had to rank them,")
      |> mes("women would top that list.")
      |> mes("Mwah ah hah~!")
      |> next()

    {:ok, ctx}
  end

  defp life_answer({ctx, _}), do: {:end, ctx}

  defp judge(ctx, points) when points > 29 do
    ctx
    |> hand_over_fragment()
    |> emotion(:smile)
    |> mes("[Daewoon]")
    |> mes("Well, I must say that I've")
    |> mes("grown quite fond of you. Of")
    |> mes("course, it helps that we have so much in common. Mwah ah hah~!")
    |> mes("It was an honor to meet you~")
    |> next()
    |> send_to_sir_jore()
  end

  defp judge(ctx, points) when points > 26 do
    ctx
    |> hand_over_fragment()
    |> mes("[Daewoon]")
    |> mes("You know, after talking with")
    |> mes(
      "you for a while, I now feel fairly comfortable with leaving you this piece of the Sobbing Starlight. Somehow, I think you're strong enough to get all the pieces."
    )
    |> next()
    |> mes("[Daewoon]")
    |> mes("I hope you will pass the rest of the test")
    |> mes("and acquire the power.")
    |> next()
    |> send_to_sir_jore()
  end

  defp judge(ctx, _points) do
    ctx
    |> mes("[Daewoon]")
    |> mes("It pains me to say this,")
    |> mes("but I do not think you're")
    |> mes("worthy of holding my fragment")
    |> mes("of the Sobbing Starlight. But")
    |> mes("I am willing to give you")
    |> mes("another chance~")
    |> close()
  end

  defp hand_over_fragment(ctx) do
    ctx =
      ctx
      |> set_char_var(:sign_q, 15)
      |> give_item(@starlight_fragment, 1)

    getexp(ctx, test_exp(ctx), 0)
  end

  defp test_exp(ctx) do
    {renewal_exp, pre_renewal_exp} = exp_by_level(base_level(ctx))
    if Rathena.truthy?(checkre(ctx, 3)), do: renewal_exp, else: pre_renewal_exp
  end

  defp exp_by_level(level) when level < 60, do: {300, 3000}
  defp exp_by_level(level) when level < 70, do: {750, 7500}
  defp exp_by_level(level) when level < 80, do: {1000, 10_000}
  defp exp_by_level(level) when level < 90, do: {1300, 13_000}
  defp exp_by_level(_level), do: {1800, 18_000}

  defp send_to_sir_jore(ctx) do
    ctx
    |> mes("[Daewoon]")
    |> mes("Oh yes! Your next test")
    |> mes("examiner is ^CE0000Sir Jore^000000, also")
    |> mes(
      "known as the Ghost of Al de Baran. Although he's always sick, he has great passion for his research."
    )
    |> next()
    |> mes("[Daewoon]")
    |> mes("Alright, then.")
    |> mes("Good luck in")
    |> mes("Al de Baran~!")
    |> close()
  end
end
