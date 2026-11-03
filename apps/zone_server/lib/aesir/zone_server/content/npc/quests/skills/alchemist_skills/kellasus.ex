defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.AlchemistSkills.Kellasus do
  @moduledoc """
  Kellasus, the Lighthalzen Alchemist who teaches Bioethics at the end of the Bioethics quest.

  ## Behavior

  - Starts the quest for Alchemists and walks them through his warnings about Homunculus
    research (steps 0 to 3).
  - Refuses to teach Homunculus skills until the Alchemist answers his three Homunculus questions
    after training with Skrajjad, Keshibien and Broncher (step 7).
  - After the Alchemist appeals to his love for his son, agrees to teach and grants Bioethics
    (steps 9 to 12).
  - Muses about forbidden knowledge to everyone else.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - Samuray22
    - L0ne_W0lf
    - DracoRPG
    - Toms
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in01",
        x: 224,
        y: 140,
        dir: 3,
        sprite: 57,
        name: "Kellasus",
        scope: :shared,
        unique_name: "Kellasus#qsk_al"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @bioethics 238

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if alchemist?(ctx),
      do: bioethics_step(ctx, get_char_var(ctx, :bioeth, 0)),
      else: musing(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp alchemist?(ctx), do: Rathena.job_id(base_job(ctx)) == Rathena.job_id(:alchemist)

  defp bioethics_step(ctx, 13), do: encouragement(ctx)
  defp bioethics_step(ctx, 12), do: teach_bioethics(ctx)
  defp bioethics_step(ctx, 11), do: agree_to_teach(ctx)
  defp bioethics_step(ctx, 10), do: confusion(ctx)
  defp bioethics_step(ctx, 9), do: humanitarian_appeal(ctx)
  defp bioethics_step(ctx, 8), do: plea_to_give_up(ctx)
  defp bioethics_step(ctx, 7), do: quiz(ctx)
  defp bioethics_step(ctx, bioeth) when bioeth > 3, do: refusal(ctx)
  defp bioethics_step(ctx, 3), do: offer_advice(ctx)
  defp bioethics_step(ctx, 2), do: forbidden_knowledge(ctx)
  defp bioethics_step(ctx, 1), do: alchemy_lecture(ctx)
  defp bioethics_step(ctx, _bioeth), do: first_meeting(ctx)

  defp encouragement(ctx) do
    ctx
    |> mes("[Kellasus]")
    |> mes("Keep up the")
    |> mes("good work. I get")
    |> mes("the feeling that")
    |> mes("our future might")
    |> mes("be depending on you...")
    |> close()
  end

  defp teach_bioethics(ctx) do
    name = char_name(ctx, 0)

    ctx
    |> mes("[Kellasus]")
    |> mes("Alright then, I'll begin")
    |> mes("by teaching you ^FF0000Bioethics^000000,")
    |> mes("the fundamental skill for")
    |> mes("creating Homunculi.")
    |> next()
    |> mes("[Kellasus]")
    |> mes("In order to master Bioethics,")
    |> mes("you've got to appreciate the")
    |> mes("sweetness of life and genuinely")
    |> mes("care about living creatures.")
    |> mes("And so, you must always take")
    |> mes("care of your Homunculus.")
    |> next()
    |> mes("[Kellasus]")
    |> mes("You must constantly check")
    |> mes("to see if your Homunculus")
    |> mes("is tired or hungry, or if it's")
    |> mes("been hurt. You must also take")
    |> mes("into account your Homunculus's feelings towards you, its owner.")
    |> next()
    |> mes("[Kellasus]")
    |> mes("When that nurturing attitude")
    |> mes("becomes second nature to you,")
    |> mes("you will have mastered Bioethics. It sounds simple, but you can only")
    |> mes("understand a relationship with a Homunculus through experience.")
    |> next()
    |> mes("[Kellasus]")
    |> mes("Well, you should know enough")
    |> mes("by now to create and care for")
    |> mes("your own Homunculus. I trust")
    |> mes("that you will be responsible")
    |> mes("in your search for discoveries")
    |> mes("that may benefit mankind.")
    |> next()
    |> mes("[Kellasus]")
    |> mes("Before we part")
    |> mes("ways, would you")
    |> mes("tell me your name?")
    |> next()
    |> mes("[#{name}]")
    |> mes("My name is...")
    |> mes("#{name}.")
    |> next()
    |> set_char_var(:bioeth, 13)
    |> skill(@bioethics, 1, :permanent)
    |> mes("[Kellasus]")
    |> mes("Ah...")
    |> mes("#{name}.")
    |> mes("I'll remember that. Goodbye")
    |> mes("for now, and I hope that you")
    |> mes("make a great contribution to")
    |> mes("the world of Alchemy someday.")
    |> close()
  end

  defp agree_to_teach(ctx) do
    name = char_name(ctx, 0)

    ctx
    |> mes("[Kellasus]")
    |> mes("Our viewpoints may be")
    |> mes("different, but I'll agree that")
    |> mes("there's too much potential in")
    |> mes("studying Homunculi that I can")
    |> mes("no longer ignore as a scientist")
    |> mes("and as a humanitarian.")
    |> next()
    |> mes("[Kellasus]")
    |> mes("If I teach you these skills,")
    |> mes("you may be treading a moral")
    |> mes("line. But I believe it should")
    |> mes("be alright if you work to learn")
    |> mes("something that will benefit")
    |> mes("the greater good.")
    |> next()
    |> mes("[#{name}]")
    |> mes("Does...")
    |> mes("Does that mean")
    |> mes("you'll teach me?")
    |> next()
    |> mes("[Kellasus]")
    |> mes("Now don't get too excited.")
    |> mes("I'm still unsure if Homunculus")
    |> mes("Study should be open to all")
    |> mes("Alchemists, but for now,")
    |> mes("I believe I can trust you.")
    |> next()
    |> mes("[Kellasus]")
    |> mes("However, you've got to")
    |> mes("use the skills I teach you")
    |> mes("to ultimately benefit other")
    |> mes("people. It's not like I can force you to forget once you know how")
    |> mes("to make Homunculi, understand?")
    |> next()
    |> set_char_var(:bioeth, 12)
    |> mes("[Kellasus]")
    |> mes("Please give me a little")
    |> mes("time to prepare my lesson")
    |> mes("for you. It's been a very long")
    |> mes("time since I've done this...")
    |> close()
  end

  defp confusion(ctx) do
    ctx
    |> set_char_var(:bioeth, 11)
    |> mes("[Kellasus]")
    |> mes("^333333*Sigh*^000000")
    |> mes("I'm so confused...")
    |> mes("There's no denying that")
    |> mes("everything you said is right.")
    |> mes("But now I don't know what")
    |> mes("I should believe...")
    |> close()
  end

  defp humanitarian_appeal(ctx) do
    name = char_name(ctx, 0)

    ctx
    |> mes("[Kellasus]")
    |> mes("Have you come to")
    |> mes("ask me again to teach")
    |> mes("you Homunculus skills?")
    |> mes("You're awfully persistent,")
    |> mes("but I suppose that might be")
    |> mes("how you became an Alchemist...")
    |> next()
    |> mes("[#{name}]")
    |> mes("Well, I sort of came")
    |> mes("here to ask about that.")
    |> mes("But first, I heard a rumor")
    |> mes("that your son was really")
    |> mes("sick for a while...")
    |> next()
    |> mes("[Kellasus]")
    |> mes("Y-yes. It's really")
    |> mes("difficult for me to")
    |> mes("talk about that time.")
    |> mes("The thought of losing")
    |> mes("my boy is too much to bear.")
    |> mes("He means the world to me...")
    |> next()
    |> mes("[Kellasus]")
    |> mes("I was so desperate to")
    |> mes("keep my boy alive that")
    |> mes("I would have sold my soul")
    |> mes("without any regret. I'm more")
    |> mes("than willing to sacrifice my")
    |> mes("own life for his sake.")
    |> next()
    |> mes("[Kellasus]")
    |> mes("Luckily, my son")
    |> mes("recovered from his")
    |> mes("disease and he is very")
    |> mes("healthy nowadays. But")
    |> mes("why are you reminding")
    |> mes("me of something like this?")
    |> next()
    |> mes("[#{name}]")
    |> mes("You're right that the creation")
    |> mes("of Homunculi brings up a moral")
    |> mes("issue. But instead of morals,")
    |> mes("I want to appeal to your sense")
    |> mes("of humanitarianism if I can.")
    |> next()
    |> mes("[Kellasus]")
    |> mes("I don't follow.")
    |> mes("What exactly")
    |> mes("do you mean by")
    |> mes("humanitarianism?")
    |> next()
    |> mes("[#{name}]")
    |> mes("I believe that the")
    |> mes("study of Homunculi")
    |> mes("could help us discover")
    |> mes("the secret of life. There")
    |> mes("is just too much")
    |> mes("potential to do good to ignore.")
    |> next()
    |> mes("[#{name}]")
    |> mes("I'm not interested in")
    |> mes("creating new creatures or")
    |> mes("playing God. What I do want")
    |> mes("is the knowledge to cure people")
    |> mes("regardless of the disease. No")
    |> mes("matter how desperate it may be.")
    |> next()
    |> mes("[#{name}]")
    |> mes("It may be immoral to")
    |> mes("create experimental life")
    |> mes("forms and to sacrifice them,")
    |> mes("but I'm willing to do that for")
    |> mes("the people who may need")
    |> mes("that cure I might discover...")
    |> next()
    |> mes("[#{name}]")
    |> mes("When your son was")
    |> mes("sick, you were willing")
    |> mes("to make sacrifices to see")
    |> mes("that he recover. But still,")
    |> mes("there are other people in the")
    |> mes("world with worse ailments...")
    |> next()
    |> mes("[#{name}]")
    |> mes("I want to study")
    |> mes("Homunculi because")
    |> mes("there's a chance that")
    |> mes("I might be able to bring")
    |> mes("hope to someone's")
    |> mes("hopeless situation...")
    |> next()
    |> set_char_var(:bioeth, 10)
    |> mes("[Kellasus]")
    |> mes("I've never...")
    |> mes("I never thought...")
    |> mes("I'm sorry. I need")
    |> mes("some time alone...")
    |> close()
  end

  defp plea_to_give_up(ctx) do
    ctx
    |> mes("[Kellasus]")
    |> mes("Although I admit that")
    |> mes("you're capabile of learning")
    |> mes("what I might be able to teach")
    |> mes("you about Homunculi, I can't")
    |> mes("in good conscience do it. I'm")
    |> mes("sorry, but please give up.")
    |> close()
  end

  defp quiz(ctx) do
    name = char_name(ctx, 0)

    {ctx, answer} =
      ctx
      |> mes("[Kellasus]")
      |> mes("How many times must I tell")
      |> mes("you? I'm sorry, but I can't teach you anything related to Homunculi.")
      |> mes("It especially bothers me that you know nothing at all about them...")
      |> next()
      |> mes("[#{name}]")
      |> mes("But while I was gone,")
      |> mes("I spent so much time")
      |> mes("studying about Homunculi")
      |> mes("from these Alchemy experts.")
      |> mes("I guarantee that I'm qualified")
      |> mes("to learn the fundamentals!")
      |> next()
      |> mes("[Kellasus]")
      |> mes("Experts...? Ah, you mean")
      |> mes("Skrajjad, Keshibien and")
      |> mes("Broncher. My old colleages.")
      |> mes("Alright. But I'll be the judge")
      |> mes("of whether or not you learned")
      |> mes("anything about Homunculi.")
      |> next()
      |> mes("[Kellasus]")
      |> mes("I'm going to give you")
      |> mes("several questions, so")
      |> mes("I hope you answer all")
      |> mes("of these correctly.")
      |> mes("Are you ready?")
      |> next()
      |> mes("[Kellasus]")
      |> mes("First question.")
      |> mes("What skill, mastered")
      |> mes("at Skill Level 1, allows")
      |> mes("the caster to retreat a")
      |> mes("Homunculus, putting it in")
      |> mes("an inert state of hibernation?")
      |> next()
      |> input(:string)

    if answer == "Vaporize", do: second_question(ctx), else: failed_first_question(ctx)
  end

  defp second_question(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Kellasus]")
      |> mes("Hmm, not bad. So you've")
      |> mes("been studying. Now, the second")
      |> mes("question. What is the item, whose name indicates a very early stage")
      |> mes("of Homunculus development, used for the Call Homunculus skill?")
      |> next()
      |> input(:string)

    if answer == "Embryo", do: third_question(ctx), else: failed_second_question(ctx)
  end

  defp third_question(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Kellasus]")
      |> mes("Huh. You got that one")
      |> mes("right too. Alright, third")
      |> mes("question. What is the")
      |> mes("name of the skill, mastered")
      |> mes("at Skill Level 5, which allows")
      |> mes("you to resurrect Homunculi?")
      |> next()
      |> input(:string)

    if answer == "Homunculus Resurrection",
      do: passed_quiz(ctx),
      else: failed_third_question(ctx)
  end

  defp passed_quiz(ctx) do
    ctx
    |> mes("[Kellasus]")
    |> mes("So you have been putting")
    |> mes("a lot of effort in studying")
    |> mes("this. I really admire your")
    |> mes("dedication and it looks like")
    |> mes("you've got the potential to")
    |> mes("be a really great Alchemist.")
    |> next()
    |> mes("[Kellasus]")
    |> mes("Still, even though you're")
    |> mes("qualified to learn all the")
    |> mes("Homunculus skills, I choose")
    |> mes("not to teach them based on")
    |> mes("my own personal principles.")
    |> mes("Nothing can change my mind.")
    |> next()
    |> mes("[Kellasus]")
    |> mes("I admit that I'm proud")
    |> mes("of the progress you've")
    |> mes("made, but I just can't")
    |> mes("bring myself to be a part")
    |> mes("of what I believe to be an")
    |> mes("abuse of the gift of life.")
    |> next()
    |> set_char_var(:bioeth, 8)
    |> mes("[Kellasus]")
    |> mes("There's just so much")
    |> mes("risk! I don't think I can")
    |> mes("bear to be responsible for")
    |> mes("any of the consequences that")
    |> mes("may come with the existence")
    |> mes("of artificially created life.")
    |> close()
  end

  defp failed_third_question(ctx) do
    ctx
    |> mes("[Kellasus]")
    |> mes("I'm disappointed...")
    |> mes("I really thought you")
    |> mes("had learned everything")
    |> mes("you could about Homunculi,")
    |> mes("but it looks like there are a")
    |> mes("few gaps in your knowledge.")
    |> close()
  end

  defp failed_second_question(ctx) do
    ctx
    |> mes("[Kellasus]")
    |> mes("Hmm... It looks like")
    |> mes("you still haven't learned")
    |> mes("enough about Homunculi.")
    |> mes("Even if I wanted to teach")
    |> mes("you, it looks like you're")
    |> mes("not quite ready to learn...")
    |> close()
  end

  defp failed_first_question(ctx) do
    ctx
    |> mes("[Kellasus]")
    |> mes("You'd be able to get")
    |> mes("the first question right")
    |> mes("if you were really serious")
    |> mes("about studying Homunculi.")
    |> mes("You'd better just give up and")
    |> mes("find a new alchemic interest.")
    |> close()
  end

  defp refusal(ctx) do
    ctx
    |> mes("[Kellasus]")
    |> mes("I'm sorry, but")
    |> mes("I refuse to teach")
    |> mes("you anything related")
    |> mes("to the Homunculus skills.")
    |> next()
    |> mes("[Kellasus]")
    |> mes("I should feel insulted that")
    |> mes("you asked me, but once there")
    |> mes("was a time when I was more")
    |> mes("like you, so I can understand")
    |> mes("how you feel. However, my")
    |> mes("views are much different now...")
    |> close()
  end

  defp offer_advice(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Kellasus]")
      |> mes("Oh, hello, what")
      |> mes("brings you this way?")
      |> mes("As your senior in the")
      |> mes("field of Alchemy, I can")
      |> mes("give you some advice if you're stumped by a particular problem...")
      |> next()
      |> select(["Teach me the Homunculus Skills.", "No, nothing."])

    if choice == 1, do: request_homunculus_skills(ctx), else: no_advice_needed(ctx)
  end

  defp request_homunculus_skills(ctx) do
    name = char_name(ctx, 0)

    ctx
    |> mes("[#{name}]")
    |> mes("I want you to")
    |> mes("teach me how to")
    |> mes("create a Homunculus.")
    |> next()
    |> mes("[Kellasus]")
    |> mes("...")
    |> mes("Come again?")
    |> mes("I don't think I heard")
    |> mes("what you said quite right.")
    |> next()
    |> mes("[#{name}]")
    |> mes("I said...")
    |> mes("I want you to")
    |> mes("teach me the skills")
    |> mes("for Homunculus creation.")
    |> next()
    |> mes("[Kellasus]")
    |> mes("After all of my talk...")
    |> mes("My warnings about knowledge")
    |> mes("that should be forbidden to")
    |> mes("Alchemists, you want to go")
    |> mes("and create a Homunculus?!")
    |> next()
    |> mes("[Kellasus]")
    |> mes("Perhaps I never should")
    |> mes("have mentioned that subject.")
    |> mes("But I still don't understand why you would suddenly want to ")
    |> mes("learn those skills. Yes, it's")
    |> mes("true that I could teach you...")
    |> next()
    |> set_char_var(:bioeth, 4)
    |> mes("[Kellasus]")
    |> mes("But I refuse to pass down")
    |> mes("my knowledge of Homunculi")
    |> mes("to anyone for any reason.")
    |> mes("Surely, you must know that")
    |> mes("by now. I'm stupefied that you")
    |> mes("even had the audacity to ask!")
    |> close()
  end

  defp no_advice_needed(ctx) do
    ctx
    |> mes("[Kellasus]")
    |> mes("No? Well, I suppose")
    |> mes("learning something on")
    |> mes("your own is good, but")
    |> mes("sometimes it's good to ask")
    |> mes("for help from those who are")
    |> mes("more experienced than you.")
    |> close()
  end

  defp forbidden_knowledge(ctx) do
    ctx
    |> mes("[Kellasus]")
    |> mes("Ah, you've returned...")
    |> mes("Now, you must be wondering")
    |> mes("why I have been warning you")
    |> mes("about the dangers of using")
    |> mes("Alchemy to obtain knowledge")
    |> mes("that should be forbidden.")
    |> next()
    |> mes("[Kellasus]")
    |> mes("It is better that you know now")
    |> mes("than to find out later and not")
    |> mes("be prepared. There is a skill")
    |> mes("in Alchemy that transgresses")
    |> mes("the natural laws by creating")
    |> mes("life not intended by God.")
    |> next()
    |> mes("[Kellasus]")
    |> mes("It is an extremely")
    |> mes("dangerous skill that was")
    |> mes("developed out of human")
    |> mes("arrogance. Life is a beautiful")
    |> mes("thing, a precious gift, that")
    |> mes("we dare not tamper with.")
    |> next()
    |> mes("[Kellasus]")
    |> mes("My greatest shame in")
    |> mes("life is my contribution to")
    |> mes("that field of knowledge. At")
    |> mes("that time I was young and")
    |> mes("headstrong, too proud to")
    |> mes("admit I was playing God.")
    |> next()
    |> mes("[Kellasus]")
    |> mes("I even went so far as to")
    |> mes("become the most skilled")
    |> mes("Alchemist in the creation")
    |> mes("of ^FF0000Homunculi^000000. But I've")
    |> mes("changed my ways. I don't...")
    |> mes("I'll never create one again.")
    |> next()
    |> mes("[Kellasus]")
    |> mes("Alchemy is an incredible")
    |> mes("field of study, and it's great")
    |> mes("that you've dedicated yourself")
    |> mes("to it, but always remember that")
    |> mes("this science has great potential for abuse, as well as for good.")
    |> next()
    |> mes("[Kellasus]")
    |> mes("I only fear that your quest")
    |> mes("for knowledge, your insatiable")
    |> mes("curiosity to reveal the unknown, may lead you on the path of the")
    |> mes("Homunculus. For your own sake, don't bother considering the idea.")
    |> next()
    |> set_char_var(:bioeth, 3)
    |> mes("[Kellasus]")
    |> mes("Remember that all life is")
    |> mes("precious. If your motives")
    |> mes("are good, and untainted by")
    |> mes("the desire for fame or fortune,")
    |> mes("and if you work for the greater good of mankind, you'll be fine.")
    |> close()
  end

  defp alchemy_lecture(ctx) do
    ctx
    |> mes("[Kellasus]")
    |> mes("Ah, it's you again.")
    |> mes("Since you're here, let")
    |> mes("me ask you a question.")
    |> mes("What exactly do you")
    |> mes("think of Alchemy?")
    |> next()
    |> mes("[Kellasus]")
    |> mes("Wait. Don't answer")
    |> mes("that. As someone more")
    |> mes("experienced in this field,")
    |> mes("I believe that the answer")
    |> mes("to that question is more")
    |> mes("complicated than you think.")
    |> next()
    |> mes("[Kellasus]")
    |> mes("Most people see Alchemists")
    |> mes("as greedy scientists, assuming")
    |> mes("that we use our skills exclusively for^FFFFFF.^000000the transmutation of gold. Of")
    |> mes("course, learning how to do that")
    |> mes("is part of our basic training.")
    |> next()
    |> mes("[Kellasus]")
    |> mes("But learning transmutation")
    |> mes("is part of something bigger.")
    |> mes("All Alchemists must strive to")
    |> mes("harness nature for the good")
    |> mes("of mankind. To do this requires")
    |> mes("the study of every science.")
    |> next()
    |> mes("[Kellasus]")
    |> mes("The fields of Medicine,")
    |> mes("Chemistry, Biology, Geology,")
    |> mes("Astronomy, Astrology, Geomancy,")
    |> mes("Mathematics, Physics and even")
    |> mes("Philosophy must all be learned")
    |> mes("by the competent Alchemist.")
    |> next()
    |> set_char_var(:bioeth, 2)
    |> mes("[Kellasus]")
    |> mes("Once you've entered the")
    |> mes("exciting vastness of Alchemy,")
    |> mes("there is no turning back. Do")
    |> mes("your best to learn all that you")
    |> mes("can, and never forget that you have responsibilities to mankind.")
    |> close()
  end

  defp first_meeting(ctx) do
    ctx
    |> mes("[Kellasus]")
    |> mes("You're another")
    |> mes("practitioner of")
    |> mes("Alchemy, aren't you?")
    |> mes("It's been a long time")
    |> mes("since I've spoken to")
    |> mes("such a young colleague...")
    |> next()
    |> mes("[Kellasus]")
    |> mes("As your elder colleague,")
    |> mes("I encourage you to focus")
    |> mes("on your training. Enlighten")
    |> mes("yourself and satisfy your")
    |> mes("curiosity by solving the")
    |> mes("riddles of science.")
    |> next()
    |> mes("[Kellasus]")
    |> mes("But heed my words...")
    |> mes("There are secrets of")
    |> mes("science that must never")
    |> mes("be discovered by humans.")
    |> mes("Do not be so proud as to")
    |> mes("seek out forbidden truths.")
    |> next()
    |> set_char_var(:bioeth, 1)
    |> mes("[Kellasus]")
    |> mes("Good luck in your")
    |> mes("studies, and I hope")
    |> mes("you never use your")
    |> mes("search for answers as")
    |> mes("an excuse to give in to")
    |> mes("greed and obsession.")
    |> close()
  end

  defp musing(ctx) do
    ctx
    |> mes("[Kellasus]")
    |> mes("Hmm. Who decides what")
    |> mes("is right and wrong? What is")
    |> mes("meant to be known and what")
    |> mes("secrets were never intended")
    |> mes("for mankind to understand?")
    |> next()
    |> mes("[Kellasus]")
    |> mes("There are many who would")
    |> mes("agree that God alone wields")
    |> mes("authority over life and death.")
    |> mes("But Alchemy does provide")
    |> mes("a way for the audacious...")
    |> close()
  end
end
