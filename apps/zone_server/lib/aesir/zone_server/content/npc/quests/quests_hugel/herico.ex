defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Herico do
  @moduledoc """
  Herico investigates the Mercenary Rebellion and opposes Rekenber's research.

  ## Behavior

  - Sends the player to investigate Odin's Temple and the rebellion.
  - Enlists the player against Regenschirm and returns research data for the President.
  - Exchanges handcuffs for randomly selected food after the investigation.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "hu_in01", x: 256, y: 40, dir: 3, sprite: 897, name: "Herico", scope: :shared}]

  alias Aesir.ZoneServer.Script.Rathena

  @research_data 7342
  @handcuffs 7345

  @impl true
  def on_talk(ctx) do
    if checkweight(ctx, [{@research_data, 1}]) != 1 do
      ctx
      |> mes("[Herico]")
      |> mes("Why don't you go take some load off your shoulder first, and come back?")
      |> close()
    else
      ctx = cutin(ctx, "heri1.bmp", 2)
      quest = get_char_var(ctx, :hg_tre, 0)

      cond do
        quest < 41 -> before_quest(ctx)
        quest == 41 -> meet_herico(ctx)
        quest == 42 -> ask_about_airship(ctx)
        quest == 43 -> report_island(ctx)
        quest == 44 -> explain_rebellion(ctx)
        quest == 45 -> seek_reporter(ctx)
        quest < 49 -> await_report(ctx)
        quest == 49 -> discuss_documents(ctx)
        quest == 50 -> propose_plan(ctx)
        quest == 51 -> request_research(ctx)
        quest == 52 -> await_research(ctx)
        quest == 53 -> plan_sabotage(ctx)
        quest == 54 -> await_sabotage(ctx)
        quest == 55 -> name_president(ctx)
        true -> after_sabotage(ctx)
      end
    end
  end

  defp before_quest(ctx) do
    ctx
    |> mes("[Herico]")
    |> mes("The weather is beautiful today. *Sigh* But my body aches too badly to go out...")
    |> close()
    |> cutin("", 255)
  end

  defp meet_herico(ctx) do
    ctx =
      ctx
      |> mes("[Herico]")
      |> mes("The weather is beautiful today. *Sigh* But my body aches too badly to go out...")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Hello!")
      |> next()
      |> mes("[Herico]")
      |> mes("Shede?")
      |> next()

    ctx = mes(ctx, "[#{char_name(ctx, 0)}]")

    ctx =
      ctx
      |> mes(
        "Oh, hello. Ms. Shede asked me to drop you by. Nice to meet you, I am ^3131FF#{char_name(ctx, 0)}^000000."
      )
      |> next()
      |> mes("[Herico]")
      |> mes(
        "Ah, hello. I heard that recently an airport was built in this town. So, are you from a different city?"
      )
      |> mes("I like to see new things...although I don't like this chilly wind.")
      |> mes("How do you like Hugel?")
      |> next()

    {ctx, choice} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes(
        "It is a peaceful and beautiful village, although I can tell that it is experiencing a change."
      )
      |> mes("Everyone looks happy, and they feel very different than people in the other areas.")
      |> mes("So I feel like that I am in a different land.")
      |> next()
      |> mes("[Herico]")
      |> mes("Everyone has worries and happyness at the same time.")
      |> mes("You must have travelled many cities of this country,")
      |> mes("and have figured out many things on your own.")
      |> mes("Am I right?")
      |> next()
      |> select(["Yes, you are right.", "I am not so sure.", "No."])

    case choice do
      1 ->
        ctx
        |> cutin("heri2.bmp", 2)
        |> mes("[Herico]")
        |> mes("I think that my senses are still working fine.")
        |> mes("People's eyes tell many things to me.")
        |> next()
        |> cutin("heri1.bmp", 2)
        |> mes("[Herico]")
        |> mes("Your eyes are telling me your admiration and astonishment")
        |> mes("toward what you have seen in Hugel,")
        |> mes("which is a totally different experience for you.")
        |> next()
        |> mes("[Herico]")
        |> mes("People of Hugel don't question anyone.")
        |> mes("It is an unwritten law of this village.")
        |> mes("That is why I could have been resting in this village without worries.")
        |> next()
        |> mes("[Herico]")
        |> mes("However, as I see you, I suddenly have an urge to ruminate on my past")
        |> mes("that I have never spoken to anyone.")
        |> mes("May I have a moment of your time, if you don't mind?")
        |> next()
        |> mes("[Herico]")
        |> mes("Perhaps we will learn something from each other's story.")
        |> set_char_var(:hg_tre, 42)
        |> close()
        |> cutin("", 255)

      2 ->
        ctx
        |> mes("[Herico]")
        |> mes("Then I guess that you have not been deeply impressed by this country.")
        |> mes("Haha, alright, that's fine.")
        |> close()
        |> cutin("", 255)

      3 ->
        ctx
        |> mes("[Herico]")
        |> mes("Oh, am I not?")
        |> mes("Haha, I am sorry for hazarding a conjecture.")
        |> close()
        |> cutin("", 255)

      _ ->
        ctx
    end
  end

  defp ask_about_airship(ctx) do
    ctx =
      ctx |> mes("[Herico]") |> mes("Hmm...can you tell me your name once again?") |> next()

    ctx = mes(ctx, "[#{char_name(ctx, 0)}]")

    ctx
    |> mes("Yes, my name is ^3131FF#{char_name(ctx, 0)}^000000.")
    |> next()
    |> mes("[Herico]")
    |> mes("^3131FF#{char_name(ctx, 0)}^000000, I have many interesting stories for you.")
    |> mes(
      "However, before I tell you my stories, I would like to ask you something. Do you mind?"
    )
    |> next()
    |> mes("[Herico]")
    |> mes(
      "As you see, ever since an airport was built in this Hugel, many strangers are coming in and going out this village."
    )
    |> mes(
      "It may be a good change for Hugel, so that more people will know about its existence."
    )
    |> mes("However, I have this bad feeling about the airport and airships.")
    |> mes(
      "I do not think that this country is not extending their airlines only for the transportation purposes."
    )
    |> next()
    |> mes("[Herico]")
    |> mes(
      "Did you know that more and more people are using the ferry after the airport was built?"
    )
    |> mes("Can't you see the reason of my doubt?")
    |> next()
    |> mes("[Herico]")
    |> mes("Please find out the secret about the airship and the island.")
    |> mes("Then I will tell you my stories.")
    |> mes("I hope that you will do your best to find out the secret.")
    |> set_char_var(:hg_tre, 43)
    |> close()
    |> cutin("", 255)
  end

  defp report_island(ctx) do
    if get_char_var(ctx, :hg_odin, 0) == 60 do
      ctx
      |> mes("[Herico]")
      |> mes(
        "Welcome back. I have been waiting for you with eager anticipation to hear about the secret."
      )
      |> mes("Now, please tell me what you have found out.")
      |> next()
      |> mes("- You told him what you have seen and heard from the Odin Shirine, -")
      |> mes("- such as Giantes, Ymir's Heart and Rekenber. -")
      |> next()
      |> cutin("heri3.bmp", 2)
      |> mes("[Herico]")
      |> mes("Rekenber...So, they have expanded")
      |> mes("their power even to this small village, Hugel.")
      |> next()
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Do you know about them?")
      |> next()
      |> mes("[Herico]")
      |> mes("Of course, I know them too well.")
      |> next()
      |> mes("[Herico]")
      |> mes("............")
      |> next()
      |> cutin("heri1.bmp", 2)
      |> mes("[Herico]")
      |> mes("Thank you so much for your effort.")
      |> mes("I am afraid that your dangerous journey has not been ended.")
      |> next()
      |> mes("[Herico]")
      |> mes("Well, this is time for me to tell you my story.")
      |> mes("I hope that you will enjoy it.")
      |> set_char_var(:hg_tre, 44)
      |> close()
      |> cutin("", 255)
    else
      ctx
      |> mes("[Herico]")
      |> mes("Please find out the secret about the airship and the island.")
      |> mes("Then I will tell you my stories.")
      |> mes("I hope that you will do your best to find out the secret.")
      |> close()
      |> cutin("", 255)
    end
  end

  defp explain_rebellion(ctx) do
    ctx
    |> mes("[Herico]")
    |> mes("Hmm...I don't know where to start.")
    |> next()
    |> mes("[Herico]")
    |> mes("As you know, we have bionic machines called")
    |> mes("^FF0000Guardians^000000.")
    |> mes("We are using Guardians to protect important facilities")
    |> mes("or to avoid meaningless murders.")
    |> next()
    |> mes("[Herico]")
    |> mes("Have you ever thought about how the people in old times")
    |> mes("would protect their important facilities without guardians?")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Perhaps, they hired many men to do that?")
    |> next()
    |> mes("[Herico]")
    |> mes("Yes, you are right.")
    |> mes("For the longest time, Schwarzwald Republic had had")
    |> mes("^3131FFMercenary Soldiers^000000 who exchanged their lives")
    |> mes("with the good money, and they used to take care of")
    |> mes("all the dirty jobs in the past.")
    |> next()
    |> mes("[Herico]")
    |> mes("They lost their jobs when Rekenber successfully invented and publicized guardians.")
    |> mes(
      "Guardians were made for humans, but sadly it was the worst thing that could happen to them."
    )
    |> next()
    |> mes("[Herico]")
    |> mes(
      "As they lost their jobs to guardians, they rose in rebellion called ^FF0000Mercenary Rebellion^000000."
    )
    |> next()
    |> mes("[Herico]")
    |> mes("This Mercenary Rebellion was greatly responded to by the public.")
    |> mes("However, they lost people's trust by choosing ^3131FFa violent method^000000")
    |> mes("to fight, instead of appealing to the public in a convincible way.")
    |> mes("In other words, they lost their game by making a critical mistake.")
    |> next()
    |> mes("[Herico]")
    |> mes("Ever since their rebellion was failed,")
    |> mes("survivors of the rebellion have disappeared beyond history.")
    |> next()
    |> cutin("heri3.bmp", 2)
    |> mes("[Herico]")
    |> mes("Not only that, they held a fight with guardians in")
    |> mes("^FF0000the Sage Varmunt's birthplace^000000")
    |> mes("which was our proud national treasure!")
    |> mes("So the house was completely destroyed by the battle, and")
    |> mes("since then, no one knows where Sage Varmunt is.")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Sage Varmunt.....!")
    |> next()
    |> cutin("heri1.bmp", 2)
    |> mes("[Herico]")
    |> mes("Oh...I must have been really upset about it.")
    |> next()
    |> mes("[Herico]")
    |> mes("To be honest with you,")
    |> mes("Sage Varmunt is partially responsible on guardians.")
    |> mes("You know that he was the one")
    |> mes("who created their motive power.")
    |> next()
    |> mes("[Herico]")
    |> mes("It is riduculous that the mercenary soldiers were trying to")
    |> mes("make their revenge on Sage Varmunt")
    |> mes("for inventing guardians, you know.")
    |> mes("But, it is understandable because they lost their jobs to guardians.")
    |> next()
    |> mes("[Herico]")
    |> mes("I heard about the Mercenary Rebellion after everything was ended,")
    |> mes("so there was nothing that I could do about Sage Varmunt.")
    |> mes("He disappeared, and I couldn't figure out more")
    |> mes("than what I found from his birth place...so...")
    |> mes("I came to Hugel and settled down here.")
    |> next()
    |> mes("[Herico]")
    |> mes("I tried to find at least a little bit of his documents from his laboratory...")
    |> mes("but everything was gone...huh?")
    |> mes("Hold on, I just remember something very important!")
    |> next()
    |> mes("[Herico]")
    |> mes("Where are all of his research documents?")
    |> mes("No...did mercenary soldiers took them or...possibly dispose them?")
    |> next()
    |> mes("[Herico]")
    |> mes("Damn it! I am so stupid! Grrr...")
    |> mes("How couldn't I think about this earlier?")
    |> next()
    |> mes("[Herico]")
    |> mes("#{char_name(ctx, 0)}, can you see what I want to tell you now?")
    |> mes("I have to take a long time to remember everything")
    |> mes("about the incident, but you must understand")
    |> mes("that this is an extremely important matter.")
    |> next()
    |> mes("[Herico]")
    |> mes("Mercenary Rebellion was a huge issue back then.")
    |> mes("Hopefully, there will be at least one news reporter")
    |> mes("who remembers about the rebellion.")
    |> next()
    |> mes("[Herico]")
    |> mes("Please go to Lighthalzen and find a news reporter")
    |> mes("who still remembers about the rebellion.")
    |> mes("If you find him, please ask him if he knows whereabouts of the rebellion survivors,")
    |> mes("so that you can find out what happened to Sage Varmunt and his research documents.")
    |> set_char_var(:hg_tre, 45)
    |> close()
    |> cutin("", 255)
  end

  defp seek_reporter(ctx) do
    ctx
    |> mes("[Herico]")
    |> mes("Please go to Lighthalzen and find a news reporter")
    |> mes("who still remembers about the rebellion.")
    |> mes("If you find him, please ask him if he knows whereabouts of the rebellion survivors,")
    |> mes("so that you can find out what happened to Sage Varmunt and his research documents.")
    |> close()
    |> cutin("", 255)
  end

  defp await_report(ctx) do
    ctx
    |> mes("[Herico]")
    |> mes("How have you been doing?")
    |> close()
    |> cutin("", 255)
  end

  defp discuss_documents(ctx) do
    ctx =
      ctx
      |> mes("[Herico]")
      |> mes("Did you find Sage Varmunt's research documents?")
      |> next()
      |> cutin("", 255)

    {ctx, choice} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Well, about the documents...")
      |> next()
      |> select(["I ate them.", "Rekenber has taken them into their possession."])

    case choice do
      1 ->
        ctx
        |> mes("I ate them.")
        |> next()
        |> mes("[Herico]")
        |> mes("Hahaha! That's funny!")
        |> next()
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("No, it is not funny.")
        |> next()
        |> mes("[Herico]")
        |> mes(".................")
        |> next()
        |> mes("[Herico]")
        |> mes("Then...SPIT THEM OUT!")
        |> percent_heal(hp: -5, sp: 0)
        |> specialeffect2(:hit4)
        |> next()
        |> mes("[Herico]")
        |> mes("SPIT THEM OUT!")
        |> percent_heal(hp: -5, sp: 0)
        |> specialeffect2(:hit4)
        |> next()
        |> mes("[Herico]")
        |> mes("I SAID, SPIT THEM OUUUUUT!")
        |> percent_heal(hp: -5, sp: 0)
        |> specialeffect2(:hit4)
        |> next()
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("Err...I was just kidding...")
        |> next()
        |> cutin("heri2.bmp", 2)
        |> mes("[Herico]")
        |> mes("Haha, the first part was funny,")
        |> mes("but the second part was kind of scary, you know?")
        |> emotion(:think)
        |> emotion(:cry, playerattached(ctx))
        |> next()
        |> mes("[Herico]")
        |> mes("So, tell me, where are all of his research documents?")
        |> next()
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("Rekenber has taken them into their possession.")
        |> next()
        |> explain_research()

      2 ->
        ctx
        |> mes("Rekenber has taken them into their possession.")
        |> next()
        |> explain_research()

      _ ->
        ctx
    end
  end

  defp explain_research(ctx) do
    ctx
    |> cutin("heri3.bmp", 2)
    |> mes("[Herico]")
    |> mes("...........................")
    |> next()
    |> cutin("heri1.bmp", 2)
    |> mes("[Herico]")
    |> mes("It was expected.")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("What do you have in mind?")
    |> next()
    |> mes("[Herico]")
    |> mes("First, I think that I should inform you about my true identity.")
    |> mes("I may now be an old man whose days are numbered,")
    |> mes("but I used to work at ^3131FFthe Ymir's Heart imitation research department")
    |> mes(" in Regenschirm laboratory^000000 under Sage Varmunt's supervision.")
    |> emotion(:huk, playerattached(ctx))
    |> next()
    |> cutin("heri2.bmp", 2)
    |> mes("[Herico]")
    |> mes("You look very surprised.")
    |> next()
    |> cutin("heri1.bmp", 2)
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Does it mean that you are the one")
    |> mes("who created the Ymir's Heart imitation?")
    |> next()
    |> mes("[Herico]")
    |> mes("Well, I was a mere assistant of Sage Varmunt,")
    |> mes("so I can't say that I created it.")
    |> next()
    |> mes("[Herico]")
    |> mes("Rekenber has been secretly gathering ^FF0000Ymir's Heart Pieces^000000.")
    |> mes("They are very obsessed with Ymir's Heart Pieces,")
    |> mes(
      "and I guess that it is because of the enormous power that the heart pieces possess within.."
    )
    |> next()
    |> mes("[Herico]")
    |> mes("However, the power of the original heart pieces")
    |> mes("are too strong for humans to control.")
    |> mes("Thus, it is not fiseable to manipulate the power")
    |> mes("as energy sources.")
    |> mes("That is why ^3131FFthe imitations of Ymir's Heart")
    |> mes("Pieces^000000 have been created.")
    |> next()
    |> mes("[Herico]")
    |> mes("We, researchers including Sage Varmunt, endeavoured")
    |> mes("our effort in studying and analyzing the revolutionary energy source")
    |> mes("for a long time.")
    |> mes("And our effort has gained a fruitful result; the Imitations of Ymir's Heart Piece.")
    |> next()
    |> mes("[Herico]")
    |> mes("With the invention, we could create guardians.")
    |> mes("We were so happy for the fact that we")
    |> mes("finally made our dream come true.")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("But, Sage Varmunt was against the idea of using guardians")
    |> mes("for militant purposes, and I heard that he also participated")
    |> mes("in the Mercenary Rebellion.")
    |> next()
    |> mes("- You told him what you knew about the Mercenary Rebellion. -")
    |> next()
    |> mes("[Herico]")
    |> mes("Hmm...now I see.")
    |> next()
    |> mes("[Herico]")
    |> mes("After we succeeded in creating the imitations of Ymir's Heart Piece,")
    |> mes("Sage Varmunt looked pretty depressed for some reason.")
    |> mes("After all, he left the laboratory and said that ^3131FFby him")
    |> mes("staying with Regenschirm laboratory")
    |> mes("will make everyone miserable^000000.")
    |> mes("I still don't figure out why he said that.")
    |> next()
    |> mes("[Herico]")
    |> mes("He was a really great scholar.")
    |> mes("He always tried to use his knowledge in science for humankind.")
    |> next()
    |> mes("[Herico]")
    |> mes("As expected, after Sage Varmunt left Regenschirm,")
    |> mes("almost every research process started stagnating.")
    |> mes("Even many projects were canceled or postponed.")
    |> next()
    |> cutin("heri3.bmp", 2)
    |> mes("[Herico]")
    |> mes("The upper management were threatened by the phenomenon,")
    |> mes("so they yelled at people to ^FF0000continue")
    |> mes("with their research by all means^000000.")
    |> mes("They even allowed people to experiment")
    |> mes("on anything that is alive.")
    |> next()
    |> cutin("heri1.bmp", 2)
    |> mes("[Herico]")
    |> mes("......................")
    |> mes("That gave me a reason to leave Regenschirm.")
    |> next()
    |> mes("[Herico]")
    |> mes("Rekenber will do anything to achieve their goals.")
    |> mes("They have become too powerful to just be considered a big corporation.")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("That was why they founded the \"Bio Lab\"")
    |> mes("in order to continue with their research without Sage Varmunt.")
    |> next()
    |> cutin("heri3.bmp", 2)
    |> emotion(:anger)
    |> mes("[Herico]")
    |> mes("What? \"Bio Lab\"? I didn't image that they could")
    |> mes("even think of that! I can't express enough of my resentment toward them!")
    |> next()
    |> mes("[Herico]")
    |> mes("Science is to benefit humankinds,")
    |> mes("not to harm them. I think that something must be done.")
    |> mes("Can you bring me a glass of water?")
    |> set_char_var(:hg_tre, 50)
    |> close()
    |> cutin("", 255)
  end

  defp propose_plan(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Herico]")
      |> mes("Can you guess what I am thinking right now?")
      |> next()
      |> mes("[Herico]")
      |> mes("I am thinking about ^3131FFdestroying Regenschirm^000000.")
      |> next()
      |> mes("[Herico]")
      |> mes("Rekenber has become as powerful as this Schwarzwald Republic.")
      |> mes("I don't think that I could destroy the entire corporation.")
      |> mes("But even if I could, it could also lead to the fall of my country,")
      |> mes("because that's who big Rekenber means to this country.")
      |> next()
      |> mes("[Herico]")
      |> mes("So, instead, I am thinking to destroy \"Regenschirm\".")
      |> mes("Because the laboratory may not be as big as the corporation,")
      |> mes("but at the same time, it has a great meaning to them.")
      |> mes("I want to stop their inhumane and dangerous practice in research.")
      |> next()
      |> mes("[Herico]")
      |> mes("...*Sigh*...Unfortunately, I do not possess any power to")
      |> mes("proceed with my plan. Thus, I need your help, desperately.")
      |> next()
      |> mes("[Herico]")
      |> mes("Let me hear your opinion.")
      |> mes("Will you join me in destroying Regenschirm?")
      |> next()
      |> select(["Sorry, I won't", "Yes, I will."])

    case choice do
      1 ->
        ctx
        |> mes("[Herico]")
        |> mes("I respect your decision since this is not something")
        |> mes("that is okay for you to make a quick judgement.")
        |> mes("I appreciate everything that you have done for me so far.")
        |> mes("And if you change your mind, feel free to come back any time.")
        |> close()
        |> cutin("", 255)

      2 ->
        ctx
        |> cutin("heri2.bmp", 2)
        |> mes("[Herico]")
        |> mes("I knew that you are too righteous to")
        |> mes("neglect lies and injustice.")
        |> mes("I have seen that through your eyes.")
        |> mes("I don't know how much we can achieve with this mission,")
        |> mes("but it is very meaningful for us to at least try.")
        |> next()
        |> mes("[Herico]")
        |> mes("Let's discuss further what we should do.")
        |> set_char_var(:hg_tre, 51)
        |> close()
        |> cutin("", 255)

      _ ->
        ctx
    end
  end

  defp request_research(ctx) do
    ctx
    |> mes("[Herico]")
    |> mes("We must find out how we can stop them")
    |> mes("from doing more evil things, at least for a while.")
    |> mes("Regenschirm is a historic laboratory, and thus")
    |> mes("an enormous amount of accumulated research data")
    |> mes("has been saved within the laboratory.")
    |> mes("Without the research data,")
    |> mes("all the researching activity within Regenschirm")
    |> mes("will not be progressed.")
    |> next()
    |> mes("[Herico]")
    |> mes("Regenschirm is located at the underground level")
    |> mes("of Rekenber's Lighthalzen headquarters.")
    |> mes("It is where their filthy ambitions are reflected on.")
    |> mes("Please sneak into the laboratory")
    |> mes("and bring ^FF0000their research data^000000 to me.")
    |> set_char_var(:hg_tre, 52)
    |> close()
    |> cutin("", 255)
  end

  defp await_research(ctx) do
    ctx
    |> mes("[Herico]")
    |> mes("Regenschirm is located at the underground level")
    |> mes("of Rekenber's Laighthalzen headquarters.")
    |> mes("Can you sneak into the place and bring me their research data?")
    |> close()
    |> cutin("heri1.bmp", 255)
  end

  defp plan_sabotage(ctx) do
    ctx
    |> mes("[Herico]")
    |> mes("Ah, you are back.")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("I had a little bit of trouble because I was caught by a guard.")
    |> mes("But I took care of it.")
    |> next()
    |> mes("[Herico]")
    |> mes("Thank you so much for your trouble.")
    |> mes("Haha, since they lost their research data,")
    |> mes("they wouldn't be able to continue with their research")
    |> mes("at least for a while, I hope.")
    |> next()
    |> mes("[Herico]")
    |> mes("Now, let's get into the next step, shall we?")
    |> mes("I know that you have gone through many difficulties so far,")
    |> mes("but this might be the most difficult thing that you've ever done.")
    |> next()
    |> mes("[Herico]")
    |> mes("In my opinion, the bio lab is the most important facility in Regenschirm.")
    |> mes("We must not let that kind of inhumane place exist in this world any longer.")
    |> mes("I am so horrified by the thought that they have been doing all sorts of evil things")
    |> mes("under an excuse of scientific research.")
    |> next()
    |> mes("[Herico]")
    |> mes("As I analyzed the research data which you have brought to me,")
    |> mes("the bio lab is consisted of 3 levels,")
    |> mes("and I suspect that the 2nd level is used to")
    |> mes("perform experimental research on living bodies.")
    |> next()
    |> mes("[Herico]")
    |> mes("I am pretty sure that we can find")
    |> mes("a miner who knows how to make")
    |> mes("Marine Sphere Bottles in ^3131FFEinbech^000000,")
    |> mes("since the Marine Sphere Bottles are needed to")
    |> mes("blast tunnels inside mines.")
    |> next()
    |> mes("[Herico]")
    |> mes("Haha...you know what I am going to ask you now, don't you?")
    |> next()
    |> mes("[Herico]")
    |> mes("Please go meet with ^3131FFthe Marine Sphere Bottle manufacturer^000000,")
    |> mes("and purchase some Marine Sphere Bottles.")
    |> mes("And explode ^3131FFthe bio experiment equipment^000000 in the 2nd level of bio lab!")
    |> next()
    |> mes("[Herico]")
    |> mes("I know that this is a difficult task. But, please understand")
    |> mes("that you are the only hope that I have.")
    |> mes("Please stop them from performing experimental research on living bodies!")
    |> delitem(@research_data, 1)
    |> set_char_var(:hg_tre, 54)
    |> close()
    |> cutin("", 255)
  end

  defp await_sabotage(ctx) do
    ctx
    |> mes("[Herico]")
    |> mes("Please go meet with ^3131FFthe Marine Sphere Bottle manufacturer^000000,")
    |> mes("and purchase some Marine Sphere Bottles.")
    |> mes("And explode ^3131FFthe bio experiment equipment^000000 in the 2nd level of bio lab.")
    |> mes("You are the only hope that I have.")
    |> mes("Let's hope that it will work out well.")
    |> next()
    |> mes("[Herico]")
    |> mes("If you know anyone")
    |> mes("who can create Marine Sphere Bottles for you,")
    |> mes("you may use his instead.")
    |> close()
    |> cutin("", 255)
  end

  defp name_president(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("The machine was blown up.")
      |> next()
      |> cutin("heri2.bmp", 2)
      |> mes("[Herico]")
      |> mes("Excellent! Excellent!")
      |> next()
      |> mes("[Herico]")
      |> mes("Now, I am relieved that they won't be able to")
      |> mes("proceed with their bio research at least for a while.")
      |> mes("You did a great job, and I am so proud of you.")
      |> next()
      |> cutin("heri1.bmp", 2)
      |> mes("[Herico]")
      |> mes("I assume that there are")
      |> mes("some failed experimental objects remaining within the laboratory.")
      |> mes("According to the research document,")
      |> mes("those experimental objects are identified with ^3131FFHandcuffs^000000.")
      |> next()
      |> mes("[Herico]")
      |> mes("From now on, I will reward you every time when you bring me")
      |> mes("a certain amount of the Handcuffs.")
      |> next()
      |> mes("[Herico]")
      |> mes("And...even though we succeeded in stopping them for now,")
      |> mes("it will not last that long.")
      |> mes("We need someone who has a power to stop them permanently.")
      |> mes("Sadly, I am not the one.")
      |> next()
      |> mes("[Herico]")
      |> mes("By any chance, do you know a man who can aid his power in stopping them?")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"inputstr$", answer)

    if answer in ["President Karl", "President Weierstrass", "President", "Karl Weierstrass"] do
      ctx =
        ctx
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("I think that I know one...")
        |> next()
        |> mes("[Herico]")
        |> mes("Okay, tell me who he is.")
        |> next()

      ctx =
        ctx
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("Mr. President.....!")
        |> mes("Mr. President must be the one who can help us.")
        |> next()
        |> mes("[Herico]")
        |> mes("You mean Karl...something something?")
        |> mes("I may well say that Rekenber owns this country.")
        |> mes("I don't think that he has not been influenced by them.")
        |> next()

      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("No, Mr. President, who I know,")
      |> mes("has been trying to free this country from Rekenber.")
      |> mes("Even if he was frustrated by a ridiculous reason at the last time,")
      |> mes("I believe that he has not given up in his hope.")
      |> next()
      |> mes("[Herico]")
      |> mes("Hmm...I see. Then I must count on your word.")
      |> mes("I am giving the research data back to you,")
      |> mes("so please bring it to Mr. President.")
      |> mes("Let's see how well he can handle it.")
      |> mes("I appreciate you for doing everything for me so far,")
      |> mes("I really appreciate it.")
      |> set_char_var(:hg_tre, 56)
      |> give_item(@research_data, 1)
      |> close()
      |> cutin("", 255)
    else
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Umm...no, I don't think that I know anyone.")
      |> next()
      |> mes("[Herico]")
      |> mes("Oh...okay. Hmm...we certainly need someone")
      |> mes("with a power who can stop them permanently.")
      |> mes("Why don't you go to different cities and find the one")
      |> mes("who can help us? I am pretty sure that")
      |> mes("you will find one.")
      |> close()
      |> cutin("", 255)
    end
  end

  defp after_sabotage(ctx) do
    if Rathena.truthy?(count_item(ctx, @research_data)) do
      ctx
      |> mes("[Herico]")
      |> mes("Why are you still here?")
      |> mes("That research data will aid a great help to Mr. President.")
      |> mes("Please deliver it to him as soon as you can.")
      |> close()
      |> cutin("", 255)
    else
      {ctx, choice} =
        ctx
        |> mes("[Herico]")
        |> mes("Hey, welcome back.")
        |> next()
        |> select([
          "I brought Handcuffs",
          "Regarding Sage Varmunt's documents"
        ])

      case choice do
        1 ->
          {ctx, exchange} =
            ctx
            |> mes("[Herico]")
            |> mes("I am willing to exchange 1 of level 4 food with 100 Handcuffs.")
            |> next()
            |> select(["Exchange", "Cancel."])

          ctx =
            if exchange == 1 do
              if count_item(ctx, @handcuffs) > 99 do
                ctx =
                  ctx
                  |> mes("[Herico]")
                  |> mes("There you go, thank you for your trouble.")
                  |> delitem(@handcuffs, 100)

                food = Enum.random(1..6)

                case food do
                  1 ->
                    give_item(ctx, 12044, 1)

                  2 ->
                    give_item(ctx, 12049, 1)

                  3 ->
                    give_item(ctx, 12059, 1)

                  4 ->
                    give_item(ctx, 12064, 1)

                  5 ->
                    give_item(ctx, 12069, 1)

                  6 ->
                    give_item(ctx, 12054, 1)

                  _ ->
                    ctx
                end
              else
                ctx
                |> mes("[Herico]")
                |> mes("I don't think that you have brought me 100 Handcuffs.")
              end
            else
              ctx
            end

          ctx |> close() |> cutin("", 255)

        2 ->
          ctx
          |> mes("[Herico]")
          |> mes("When I checked the research data that you have brought to me,")
          |> mes("it seemed that Sage Varmunt wrote his documents in cipher,")
          |> mes("so they could not decode them.")
          |> mes("That explains why they have been obsessed")
          |> mes("with bionic researches to figure out on their own.")
          |> close()
          |> cutin("", 255)

        _ ->
          ctx
      end
    end
  end
end
