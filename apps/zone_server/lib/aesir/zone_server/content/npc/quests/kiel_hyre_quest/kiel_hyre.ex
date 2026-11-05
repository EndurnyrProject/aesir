defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.KielHyre do
  @moduledoc """
  Kiel Hyre reveals his past and guides the investigation into Kiehl and the robot factory.

  ## Behavior

  - Answers questions after his rescue and rewards the player for saving him.
  - Discusses the evidence about Allysia and provides a device to weaken Kiehl.
  - Opens the timed passage to Kiehl and rewards the return of Allysia’s ring.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "kh_mansion",
        x: 22,
        y: 28,
        dir: 4,
        sprite: 903,
        name: "Kiel Hyre",
        scope: :shared,
        unique_name: "Kiel Hyre#kh"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if checkweight(ctx, [{908, 200}]) == 0 do
      ctx
      |> mes("^3355FFJust a second...")
      |> mes("You're carrying too")
      |> mes("many items with you")
      |> mes("right now, so you'll")
      |> mes("need to free up more")
      |> mes("inventory space first...^000000")
      |> close()
    else
      ctx |> cutin("kh_kyel01", 2) |> discuss_quest()
    end
  end

  defp discuss_quest(ctx) do
    quest_stage = get_char_var(ctx, :KielHyreQuest, 0)

    cond do
      quest_stage < 46 ->
        ctx
        |> mes("[Kiel Hyre]")
        |> mes(".........")
        |> mes(".........")
        |> mes("............")
        |> finish_conversation()

      quest_stage == 46 ->
        ctx |> greet_rescuer() |> answer_questions()

      quest_stage == 48 ->
        reward_rescue(ctx)

      quest_stage >= 50 and quest_stage < 64 ->
        ctx |> ask_to_rest() |> finish_conversation()

      quest_stage == 64 ->
        discuss_missing_evidence(ctx)

      quest_stage == 68 ->
        confront_with_evidence(ctx)

      quest_stage <= 70 ->
        explain_kiehls_origin(ctx)

      quest_stage >= 74 and quest_stage <= 104 ->
        offer_secret_passage(ctx)

      quest_stage >= 74 and quest_stage <= 106 ->
        receive_ring(ctx)

      quest_stage >= 108 ->
        ctx
        |> mes("[Kiel Hyre]")
        |> mes("......")
        |> mes(".........")
        |> mes("............")
        |> finish_conversation()

      true ->
        finish_conversation(ctx)
    end
  end

  defp finish_conversation(ctx) do
    ctx |> close() |> cutin("", 255)
  end

  defp greet_rescuer(ctx) do
    ctx
    |> cutin("kh_kyel01", 2)
    |> mes("[Kiel Hyre]")
    |> mes("Ah, you must be #{char_name(ctx, 0)}.")
    |> mes("I'd like to thank you for saving")
    |> mes("my life. You must have many")
    |> mes("questions to ask me, so I'll")
    |> mes("do my best to give you answers.")
    |> next()
  end

  defp reward_rescue(ctx) do
    ctx
    |> mes("[Kiel Hyre]")
    |> mes("Ah, I almost forgot.")
    |> mes("Please, take this as")
    |> mes("a little reward for")
    |> mes("saving my life.")
    |> give_item(12_105, 1)
    |> getexp(if(Rathena.truthy?(checkre(ctx, 3)), do: 70_000, else: 700_000), 0)
    |> set_char_var(:KielHyreQuest, 50)
    |> finish_conversation()
  end

  defp ask_to_rest(ctx) do
    ctx
    |> mes("[Kiel Hyre]")
    |> mes("If you don't have")
    |> mes("anymore questions for me,")
    |> mes("then would you please")
    |> mes("let me rest?? I'm still not")
    |> mes("feeling well from the time")
    |> mes("I was locked up in the factory.")
  end

  defp discuss_missing_evidence(ctx) do
    ctx
    |> cutin("kh_kyel01", 2)
    |> mes("[Kiel Hyre]")
    |> mes("Hm? Did you")
    |> mes("have something")
    |> mes("that you wanted")
    |> mes("to ask me?")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("I don't have enough")
    |> mes("concrete evidence yet,")
    |> mes("but I might have some")
    |> mes("questions soon enough.")
    |> finish_conversation()
  end

  defp confront_with_evidence(ctx) do
    ctx = ctx |> cutin("kh_kyel02", 2) |> mes("[Kiel Hyre]")

    {ctx, _} =
      ctx
      |> mes("Ah, #{char_name(ctx, 0)}.")
      |> mes("It's you. So how can")
      |> mes("I help you today?")
      |> next()
      |> select(["About ^3355FFAllysia^000000..."])

    describe_allysia_portrait(ctx)
  end

  defp describe_allysia_portrait(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("You know, I was looking")
      |> mes("through this deserted house")
      |> mes("in Juno, and discovered")
      |> mes("an old portrait of a woman")
      |> mes("that looks just like Allysia.")
      |> next()
      |> cutin("kh_kyel02", 2)
      |> mes("[Kiel Hyre]")
      |> mes("Oh...")
      |> mes("Is that all?")
      |> mes("I thought you had")
      |> mes("a robotics question.")
      |> next()
      |> cutin("kh_Kyel03", 2)
      |> mes("[Kiel Hyre]")
      |> mes("Anyway, that's a")
      |> mes("strange coincidence.")
      |> mes("Well, I suppose it's")
      |> mes("not so strange to find")
      |> mes("look-a-likes for other people...")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("I don't think it's just")
      |> mes("a coincidence. The woman")
      |> mes("in that thirty year old portrait")
      |> mes("was also named Allysia, and she")
      |> mes("worked at Orsimier street")
      |> mes("in Juno. Does that ring a bell?")
      |> next()
      |> cutin("kh_kyel02", 2)
      |> mes("[Kiel Hyre]")
      |> mes("......")
      |> mes(".........")
      |> mes("............")
      |> next()
      |> cutin("kh_kyel01", 2)

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Then I thought that this")
      |> mes("Allysia must have been the")
      |> mes("woman that you loved, and")
      |> mes("that you based your robot's")
      |> mes("apperance on her.")
      |> next()
      |> cutin("kh_kyel02", 2)
      |> mes("[Kiel Hyre]")
      |> mes("............")
      |> next()
      |> cutin("kh_kyel01", 2)

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("I think this is what happened:")
      |> mes("when you were a young, poor")
      |> mes("man, you fell in love with")
      |> mes("Allysia. However, she was")
      |> mes("in love with Rosimier, who")
      |> mes("was rich and powerful.")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("However, Rosimier was")
      |> mes("betrothed to some other")
      |> mes("woman, and he ended up")
      |> mes("marrying his fiancee, thus")
      |> mes("breaking Allysia's heart.")
      |> next()

    {ctx, _} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Feeling betrayed, her")
      |> mes("heart broken, Allysia jumped")
      |> mes("into a river. Then, you decided")
      |> mes("to get revenge on Rosimier, so")
      |> mes("you ended up joining")
      |> mes("Rekenber Corporation!")
      |> next()
      |> cutin("kh_Kyel03", 2)
      |> mes("[Kiel Hyre]")
      |> mes("Hahahahahahaha!")
      |> mes("Oh, what an imagination~")
      |> mes("That's very ridiculous...")
      |> mes("Though, I admit, maybe")
      |> mes("I did design Allysia after")
      |> mes("seeing that woman long ago.")
      |> next()
      |> mes("[Kiel Hyre]")
      |> mes("I'd almost forgotten")
      |> mes("about her! I think we")
      |> mes("were friends... Though,")
      |> mes("where did you get the idea")
      |> mes("that I might have")
      |> mes("been in love with her?")
      |> next()
      |> select(["Reveal Kiel's Portrait from Hut"])

    question_kiels_denial(ctx)
  end

  defp question_kiels_denial(ctx) do
    ctx =
      ctx
      |> cutin("kh_kyel02", 2)
      |> mes("[Kiel Hyre]")
      |> mes("Wh-what...")
      |> mes("How did...")
      |> mes("Where did you...?")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Kiel Hyre, I found this")
      |> mes("portrait of you as a young")
      |> mes("man from the house of the")
      |> mes("man that bought Allysia's ring.")
      |> mes("I even spoke to the fisherman")
      |> mes("that discovered Allysia's body.")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("You paid an awful lot")
      |> mes("of money to buy Allysia's")
      |> mes("ring. How can you not tell")
      |> mes("me that you didn't love her?")
      |> next()
      |> cutin("kh_Kyel03", 2)
      |> mes("[Kiel Hyre]")
      |> mes("*Sigh...*")
      |> mes("You got me, you got me.")
      |> mes("I didn't want you to learn")
      |> mes("the truth. You are correct.")
      |> mes("I loved Allysia, and designed")
      |> mes("my robot to look just like her.")
      |> next()
      |> mes("[Kiel Hyre]")
      |> mes("I could never forget her.")
      |> mes("Ever. But I would never")
      |> mes("do anything to harm the")
      |> mes("Rosimiers! I'm a scientist!")
      |> mes("I hated him when I was young,")
      |> mes("but things are different now!")
      |> next()
      |> mes("[Kiel Hyre]")
      |> mes("I shed no tears when the")
      |> mes("Rosimiers fell, but I wasn't")
      |> mes("responsible. Besides, I didn't")
      |> mes("have the resources or the")
      |> mes("capability to cause it...")
      |> next()
      |> cutin("kh_kyel02", 2)

    {ctx, _} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("I'm afraid that the")
      |> mes("evidence shows otherwise.")
      |> next()
      |> select(["Reveal Portrait of Rosimiers"])

    expose_rekenber_connection(ctx)
  end

  defp expose_rekenber_connection(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Take a good look")
      |> mes("at this portrait that")
      |> mes("I found at the Rosimiers'")
      |> mes("old house. Do you see")
      |> mes("anything... incriminating?")
      |> next()
      |> cutin("kh_Kyel03", 2)
      |> mes("[Kiel Hyre]")
      |> mes("Aside from that")
      |> mes("James Rosimier, you")
      |> mes("mean? No! I don't see")
      |> mes("anything wrong with")
      |> mes("this picture at all.")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Take a good look")
      |> mes("at the pocketwatch")
      |> mes("in the portrait. That's")
      |> mes("the pocketwatch you")
      |> mes("wear today, isn't it?")
      |> next()
      |> cutin("kh_kyel02", 2)
      |> mes("[Kiel Hyre]")
      |> mes("...!!!")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("You might not have caused")
      |> mes("the downfall of the Rosimiers")
      |> mes("yourself, but with the aid of")
      |> mes("the Rekenber Corporation, I'd")
      |> mes("say it was entirely possible!")
      |> next()
      |> cutin("kh_Kyel03", 2)
      |> mes("[Kiel Hyre]")
      |> mes("Well played, adventurer.")
      |> mes("Well played. I don't regret")
      |> mes("what I did: they killed my")
      |> mes("Allysia! If James didn't betray")
      |> mes("her, if only he didn't drive")
      |> mes("her to commit suicide...")
      |> next()

    {ctx, _} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("That's where you're wrong!")
      |> mes("Allysia was killed, she didn't")
      |> mes("commit suicide. Take a good")
      |> mes("look at this note right here!")
      |> next()
      |> mes("[Kiel Hyre]")
      |> mes("What?!")
      |> next()
      |> select(["Show James's Note"])

    challenge_suicide_account(ctx)
  end

  defp challenge_suicide_account(ctx) do
    ctx =
      ctx
      |> mes("[Kiel Hyre]")
      |> mes("What does this prove?")
      |> mes("This doesn't show that")
      |> mes("James didn't betray Allysia.")
      |> mes("How does this change anything?")
      |> mes("She's dead, nothing I can do")
      |> mes("will bring her back to me!")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("I never said James didn't")
      |> mes("betray her. Look at the date")
      |> mes("on the note. James made plans")
      |> mes("to run away with her on August")
      |> mes("20th. However, her body was")
      |> mes("found on the same day.")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Ergo, Allysia must have")
      |> mes("died on August 19th. If she")
      |> mes("was planning to run away with")
      |> mes("her love on the next day, then")
      |> mes("she had no reason to kill herself!")
      |> next()
      |> mes("[Kiel Hyre]")
      |> mes("No, that's not right!")
      |> mes("She probably couldn't")
      |> mes("trust me! She must have")
      |> mes("realized she was nothing")
      |> mes("but another toy to him!")
      |> next()

    {ctx, _} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Oh yeah? I say she jumped")
      |> mes("into the river because you")
      |> mes("met her on that day. Now,")
      |> mes("take a good look at this!")
      |> next()
      |> select(["Show K.H.'s note"])

    uncover_allysias_death(ctx)
  end

  defp uncover_allysias_death(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("This note was  written by")
      |> mes("a man with your initials,")
      |> mes("K.H. These initials were also")
      |> mes("signed on her portrait. You")
      |> mes("must have written this note:")
      |> mes("there's too many coincidences!")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("According to this note,")
      |> mes("you told Allysia that you")
      |> mes("wanted to see her again")
      |> mes("at the place you first met.")
      |> mes("I think you did see her again...")
      |> mes("on August 19th, the day she died!")
      |> next()

    {ctx, _} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("I'm assuming the place you")
      |> mes("two first met was near the")
      |> mes("river. No more of your lies:")
      |> mes("Tell me what really happened!")
      |> next()
      |> cutin("kh_kyel02", 2)
      |> mes("[Kiel Hyre]")
      |> mes("............")
      |> mes(".........")
      |> mes("......")
      |> next()
      |> cutin("kh_Kyel03", 2)
      |> mes("[Kiel Hyre]")
      |> mes("Hah... Ha ha ha...")
      |> mes("Yes... That's right...")
      |> mes("That horrible night.")
      |> mes("I remember it well...")
      |> mes(".....................")
      |> next()
      |> cutin("kh_kyel02", 2)
      |> mes("[Kiel Hyre]")
      |> mes("That night, when she came")
      |> mes("to the river to meet me as")
      |> mes("I had asked, I begged her to")
      |> mes("run away with me, instead")
      |> mes("of waiting for that James.")
      |> next()
      |> mes("[Kiel Hyre]")
      |> mes("She insisted that James")
      |> mes("never betrayed her, and he")
      |> mes("promised to take her away")
      |> mes("with him the next day. Can")
      |> mes("you imagine how that made")
      |> mes("me feel? I was nothing to her.")
      |> next()
      |> mes("[Kiel Hyre]")
      |> mes("My feelings didn't matter to")
      |> mes("her at all! She kept fidgeting")
      |> mes("with that ring...I lost control")
      |> mes("and tried to take that damned")
      |> mes("thing away from her, and")
      |> mes("throw it into the river...")
      |> next()
      |> mes("[Kiel Hyre]")
      |> mes("But you know what?")
      |> mes("She struggled, she actually")
      |> mes("fought me! It was just a small")
      |> mes("fight, but then, before I knew")
      |> mes("it, the ground underneath us")
      |> mes("collapsed and... the rains...")
      |> next()
      |> select(["........."])

    finish_confession(ctx)
  end

  defp finish_confession(ctx) do
    ctx
    |> mes("[Kiel Hyre]")
    |> mes("I'm not sure what it")
    |> mes("was. The rain weakened")
    |> mes("the ground, something went")
    |> mes("wrong... and she just... just...")
    |> mes("The river swallowed her...")
    |> mes("I felt empty. She was gone. ")
    |> delitem(7499, 1)
    |> delitem(7500, 1)
    |> delitem(7501, 1)
    |> delitem(7502, 1)
    |> delitem(7503, 1)
    |> set_char_var(:KielHyreQuest, 70)
    |> close()
    |> cutin("", 255)
  end

  defp explain_kiehls_origin(ctx) do
    ctx =
      ctx
      |> cutin("kh_kyel01", 2)
      |> mes("[Kiel Hyre]")
      |> mes("You already know that")
      |> mes("she was found dead the")
      |> mes("next day. But what really")
      |> mes("broke my heart was that")
      |> mes("she held that ring so tightly")
      |> mes("in her hand, even in death...")
      |> next()
      |> cutin("kh_kyel03", 2)
      |> mes("[Kiel Hyre]")
      |> mes("His family had everything")
      |> mes("while I had nothing. And")
      |> mes("he had the audacity to take")
      |> mes("Allysia away from me?!")
      |> mes("How could that be right?")
      |> next()
      |> mes("[Kiel Hyre]")
      |> mes("Even though she had passed")
      |> mes("away, I still wanted to prove")
      |> mes("to Allysia what kind of ugly")
      |> mes("person James really was.")
      |> mes("That was when I joined the")
      |> mes("Rekenber Corporation.")
      |> next()
      |> mes("[Kiel Hyre]")
      |> mes("I designed the very first")
      |> mes("First Generation Robot, which")
      |> mes("I named Allysia, and sold the")
      |> mes("designs to Rekenber. I gave them")
      |> mes("robots, and they gave me money,")
      |> mes("power, obedient subordinates.")
      |> next()
      |> mes("[Kiel Hyre]")
      |> mes("Of course I knew they'd use")
      |> mes("my robots for spying and killing!")
      |> mes("But you know what? It didn't")
      |> mes("matter so long as they gave me")
      |> mes("the means to my revenge. It was")
      |> mes("the perfect partnership, really.")
      |> next()
      |> mes("[Kiel Hyre]")
      |> mes("You've got me right")
      |> mes("where you want me.")
      |> mes("Who are you working")
      |> mes("for, and what exactly")
      |> mes("do you want? My designs?")
      |> mes("My death? Everything...?")
      |> next()
      |> cutin("kh_kyel01", 2)

    explain_kiehls_creation(ctx)
  end

  defp explain_kiehls_creation(ctx) do
    {ctx, _} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Actually, I just want")
      |> mes("to ask about the nature")
      |> mes("of your professional")
      |> mes("relationship with the")
      |> mes("Rekenber Corporation.")
      |> mes("And about Kiehl.")
      |> next()
      |> mes("[Kiel Hyre]")
      |> mes("Kiehl, eh? After hearing")
      |> mes("my crazy story, I'm guessing")
      |> mes("that you already suspect the")
      |> mes("truth about him... He's also")
      |> mes("a robot, specifically the first")
      |> mes("of the Second Generation models.")
      |> next()
      |> mes("[Kiel Hyre]")
      |> mes("His mind was developed using.")
      |> mes("an experimental, and unstable,")
      |> mes("form of the Condensed Magic")
      |> mes("Spell Scrolls. He was the only")
      |> mes("Second Generation robot that")
      |> mes("I was allowed to keep.")
      |> next()
      |> mes("[Kiel Hyre]")
      |> mes("I've become very attached")
      |> mes("to Kiehl. It's not surprising,")
      |> mes("seeing that robotics have")
      |> mes("become my life. I even raised")
      |> mes("him as my own son, and taught")
      |> mes("him everything about robotics")
      |> next()
      |> mes("[Kiel Hyre]")
      |> mes("Kiehl is now a genius,")
      |> mes("and has even developed the")
      |> mes("Third Generation of robots.")
      |> mes("Unfortunately, I failed to")
      |> mes("properly raise him with")
      |> mes("human morals and ethics.")
      |> next()
      |> select(["......"])

    request_help_against_kiehl(ctx)
  end

  defp request_help_against_kiehl(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Kiel Hyre]")
      |> mes("He's been transforming")
      |> mes("the Third Generation robots")
      |> mes("into killing machines. That's")
      |> mes("why I tried to put them all")
      |> mes("into the academy, so they")
      |> mes("could learn human behavior.")
      |> next()
      |> mes("[Kiel Hyre]")
      |> mes("Although the academy")
      |> mes("has delayed Kiehl's plans,")
      |> mes("he has succeeded into")
      |> mes("converting all of the robots")
      |> mes("into uncontrollable engines")
      |> mes("of mass destruction.")
      |> next()
      |> mes("[Kiel Hyre]")
      |> mes("Yes, he's been working")
      |> mes("closely with Rekenber.")
      |> mes("Their true objective is to")
      |> mes("create killing machines")
      |> mes("for Rekenber's use.")
      |> next()
      |> mes("[Kiel Hyre]")
      |> mes("You know all the secrets")
      |> mes("of my past now. I'm not")
      |> mes("upset with you or anything,")
      |> mes("but I do have something")
      |> mes("that I want to ask of you.")
      |> next()
      |> mes("[Kiel Hyre]")
      |> mes("Please! Stop Kiehl!")
      |> mes("I don't want his madness")
      |> mes("to destroy any more robots!")
      |> mes("I see each and every one")
      |> mes("of them as one of my children!")
      |> next()
      |> mes("[Kiel Hyre]")
      |> mes("I know that I must take")
      |> mes("full responsibility for all")
      |> mes("that has happened. I promise")
      |> mes("to take any punishment for")
      |> mes("my actions once everything")
      |> mes("has been resolved.")
      |> next()
      |> select(["Accept", "Okay", "Nod"])

    explain_ring_retrieval(ctx)
  end

  defp explain_ring_retrieval(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Kiel Hyre]")
      |> mes("Thank you so much!")
      |> mes("You can find Kiehl")
      |> mes("in the underground")
      |> mes("level in this mansion.")
      |> next()
      |> mes("[Kiel Hyre]")
      |> mes("He stays in the old room")
      |> mes("where he was created, but")
      |> mes("he reconstructed it as some")
      |> mes("kind of cave to keep everyone")
      |> mes("out, including me. Yes, he")
      |> mes("doesn't trust anyone anymore...")
      |> next()
      |> mes("[Kiel Hyre]")
      |> mes("When you find him, I want")
      |> mes("you to take Allysia's ring")
      |> mes("out of his heart. If you")
      |> mes("remove it, that should stop")
      |> mes("him from going berserk.")
      |> next()
      |> select(["Allysia's Ring?"])

    give_weakening_device(ctx)
  end

  defp give_weakening_device(ctx) do
    ctx
    |> mes("[Kiel Hyre]")
    |> mes("Yes... Her ring is the")
    |> mes("beginning of everything")
    |> mes("I put that in his heart so")
    |> mes("that I'd never forget what")
    |> mes("the Rosimiers did to me.")
    |> next()
    |> mes("[Kiel Hyre]")
    |> mes("I think Kiehl's grown")
    |> mes("so powerful that normal")
    |> mes("weapons might not work")
    |> mes("on him anymore. Use this")
    |> mes("device that will cause his")
    |> mes("power supply to fluctuate.")
    |> give_item(7504, 1)
    |> next()
    |> cutin("kh_kyel03", 2)
    |> mes("[Kiel Hyre]")
    |> mes("If you successfully attach")
    |> mes("this to Kiehl's body, then")
    |> mes("he won't be able to use his")
    |> mes("body's full power. While he's")
    |> mes("weakened, open up his chest")
    |> mes("and get the ring from his heart.")
    |> next()
    |> mes("[Kiel Hyre]")
    |> mes("Let me know once")
    |> mes("you're ready. Then, I'll")
    |> mes("guide you Kiehl's room.")
    |> set_char_var(:KielHyreQuest, 74)
    |> finish_conversation()
  end

  defp offer_secret_passage(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Kiel Hyre]")
      |> mes("Are you ready")
      |> mes("to confront")
      |> mes("Kiehl now?")
      |> next()
      |> select(["Yes", "No"])

    case choice do
      1 ->
        ctx
        |> mes("[Kiel Hyre]")
        |> mes("There... the secret")
        |> mes("passage is open now.")
        |> mes("Just go to the right of")
        |> mes("me, but be careful. Kiehl")
        |> mes("is extremely dangerous.")
        |> close()
        |> enablenpc("Kiehl_Room_Warp")
        |> donpcevent("Kiehl_Room_Warp::OnEnable")
        |> cutin("", 255)

      2 ->
        ctx
        |> mes("[Kiel Hyre]")
        |> mes("Please take your")
        |> mes("time. I imagine that")
        |> mes("it won't be easy.")
        |> finish_conversation()

      _ ->
        ctx
    end
  end

  defp receive_ring(ctx) do
    ctx =
      ctx
      |> cutin("kh_kyel01", 2)
      |> mes("[Kiel Hyre]")
      |> mes("You're back...!")
      |> mes("So were you able")
      |> mes("to retrieve Allysia's")
      |> mes("Ring from Kiehl's heart?")
      |> next()

    if count_item(ctx, 7508) < 1 do
      ctx
      |> mes("[Kiel Hyre]")
      |> mes("You mean... You don't have it?")
      |> mes("Please, retrieve Allysia's Ring")
      |> mes("from Kiehl's heart!")
      |> next()
      |> enablenpc("Kiehl_Room_Warp")
      |> donpcevent("Kiehl_Room_Warp::OnEnable")
      |> finish_conversation()
    else
      reward_ring(ctx)
    end
  end

  defp reward_ring(ctx) do
    ctx =
      ctx
      |> mes("[Kiel Hyre]")
      |> mes("Wh-what happened...?")
      |> mes("Kiehl developed a new")
      |> mes("body for himself? Th-that")
      |> mes("would make him a Fourth")
      |> mes("Generation robot. I had")
      |> mes("no idea he was this smart.")
      |> next()
      |> mes("[Kiel Hyre]")
      |> mes("Wait, now that I think about")
      |> mes("it, I did see robot bodies that")
      |> mes("looked like Kiehl when I was")
      |> mes("locked in the factory. So he")
      |> mes("was using those copies to")
      |> mes("develop personal upgrades.")
      |> next()
      |> mes("[Kiel Hyre]")
      |> mes("Here, please take this")
      |> mes("Keycard which will let you")
      |> mes("enter and investigate the")
      |> mes("deepest levels of the factory.")
      |> mes("I'll investigate Kiehl's room.")
      |> give_item(7509, 1)
      |> set_char_var(:KielHyreQuest, 108)
      |> next()
      |> set_player_title()

    ctx
    |> mes("[Kiel Hyre]")
    |> mes("Kiehl is my responsibility...")
    |> mes("No matter what the cost may")
    |> mes("be, I've got to stop him! Oh,")
    |> mes("and here, please take this")
    |> mes("with my thanks for all of")
    |> mes("your help, #{get_local(ctx, :"KHTitle$", "")} #{char_name(ctx, 0)}.")
    |> give_item(616, 1)
    |> delitem(7508, 1)
    |> getexp(if(Rathena.truthy?(checkre(ctx, 3)), do: 100_000, else: 1_000_000), 0)
    |> finish_conversation()
  end

  defp set_player_title(ctx) do
    cond do
      sex(ctx) == 1 ->
        set_local(ctx, :"KHTitle$", "Mr")

      getpartnerid(ctx) == 0 ->
        set_local(ctx, :"KHTitle$", "Miss")

      true ->
        set_local(ctx, :"KHSTitle$", "Mrs")
    end
  end

  defp answer_questions(ctx) do
    {ctx, topic} =
      select(ctx, ["Robots?", "^3355FFKiehl^000000?", "^FF0000Elly^000000's button?"])

    case topic do
      1 -> ctx |> explain_robotics() |> continue_questions()
      2 -> ctx |> explain_kiehl() |> continue_questions()
      3 -> ctx |> explain_button() |> continue_questions()
      _ -> ctx
    end
  end

  defp continue_questions(ctx) do
    ctx = ctx |> set_local(:KHQRead, get_local(ctx, :KHQRead, 0) + 1) |> next()

    if get_local(ctx, :KHQRead, 0) == 3 do
      ctx
      |> ask_to_rest()
      |> delitem(7493, 1)
      |> delitem(7494, 1)
      |> set_char_var(:KielHyreQuest, 48)
      |> finish_conversation()
    else
      answer_questions(ctx)
    end
  end

  defp explain_robotics(ctx) do
    ctx
    |> mes("[Kiel Hyre]")
    |> mes("I've been researching")
    |> mes("robotics for thirty-two")
    |> mes("years now. I'm proud to")
    |> mes("say that I've succeeded")
    |> mes("where the great Sage")
    |> mes("Varmundt did not.")
    |> next()
    |> mes("[Kiel Hyre]")
    |> mes("It's been my dream to")
    |> mes("develop humanoid robots")
    |> mes("from humans. Those Guardians")
    |> mes("might be robots too, but they")
    |> mes("don't operate using free will.")
    |> next()
    |> mes("[Kiel Hyre]")
    |> mes("If you'd like to know more")
    |> mes("of the specifics concerning")
    |> mes("robotics, why don't you speak")
    |> mes("with ^3355FFAllysia^000000? She can explain")
    |> mes("everything much more succinctly")
    |> mes("than I can. I tend to ramble...")
  end

  defp explain_kiehl(ctx) do
    ctx
    |> mes("[Kiel Hyre]")
    |> mes("^3355FFKiehl^000000 is my only son,")
    |> mes("but the love of my life")
    |> mes("died after giving birth to")
    |> mes("him. I'll admit that he's")
    |> mes("a genius in mechanical")
    |> mes("design and development.")
    |> next()
    |> mes("[Kiel Hyre]")
    |> mes("He's largely responsible")
    |> mes("for the creation of Third")
    |> mes("Generation robots like Elly.")
    |> mes("Unfortunately, he's trying to")
    |> mes("modify his creations for")
    |> mes("some sinister purpose.")
    |> next()
    |> mes("[Kiel Hyre]")
    |> mes("I tried to stop him,")
    |> mes("but I ended up getting")
    |> mes("locked inside the factory.")
    |> mes("I don't know why he wants")
    |> mes("to do this. I still have")
    |> mes("absolutely no clue...")
  end

  defp explain_button(ctx) do
    ctx
    |> mes("[Kiel Hyre]")
    |> mes("That button Elly was")
    |> mes("holding has ^3355FFKiehl's emblem^000000")
    |> mes("engraved on it. Ah, and that")
    |> mes("man in black menacing the")
    |> mes("students? That was probably")
    |> mes("^3355FFKaiser^000000, Kiehl's bodyguard.")
    |> next()
    |> mes("[Kiel Hyre]")
    |> mes("Kaiser...")
    |> mes("I don't know")
    |> mes("anything about him.")
    |> mes("I've never even seen")
    |> mes("his face! Kiehl just hired")
    |> mes("him without letting me know...")
  end
end
