defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.AlchemistSkills.Pisruik do
  @moduledoc """
  Pisruik, a sickly Juno researcher whose quest teaches Alchemists to make elemental potions.

  ## Behavior

  - Coughs at Alchemists below job level 40 and offers nothing to everyone else.
  - Asks the Alchemist to recall and deliver 5 Yellow Gemstones, 4 Empty Potion Bottles,
    10 Hearts of Mermaid and 10 Moth Dust (steps 0 to 2).
  - Explains his heat-resistance medicine and asks for 20 Maneater Blossoms, which a refusal
    can still turn into help later (steps 3 to 6).
  - Sometimes asks for one extra Maneater Blossom before the experiment explodes and breaks
    his glasses (steps 6 to 8).
  - In exchange for a pair of Glasses, hands over his thesis (Elemental Potion Creation Guide)
    and then comments on how many copies the Alchemist carries (steps 9 to 11).

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
        map: "yuno_in04",
        x: 33,
        y: 108,
        dir: 4,
        sprite: 883,
        name: "Pisruik",
        scope: :shared,
        unique_name: "Pisruik#qsk_al"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @yellow_gemstone 715
  @empty_potion 1093
  @heart_of_mermaid 950
  @moth_dust 1057
  @maneater_blossom 1032
  @glasses 2243
  @thesis 7434

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      Rathena.job_id(base_job(ctx)) != Rathena.job_id(:alchemist) -> busy(ctx)
      job_level(ctx) < 40 -> coughing(ctx)
      true -> quest_step(ctx, get_char_var(ctx, :ALCHE_SK, 0))
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  # NOTE: SEX_FEMALE/SEX_MALE are read as char vars (unset = 0), so male?/1 is true for
  # female characters at runtime; transpiler quirk kept for behavior parity.
  defp female?(ctx), do: sex(ctx) == get_char_var(ctx, :SEX_FEMALE, 0)
  defp male?(ctx), do: sex(ctx) == get_char_var(ctx, :SEX_MALE, 0)

  defp quest_step(ctx, 0), do: first_meeting(ctx)
  defp quest_step(ctx, 1), do: second_meeting(ctx)
  defp quest_step(ctx, 2), do: recall_materials(ctx)
  defp quest_step(ctx, 3), do: interrupted_talk(ctx)
  defp quest_step(ctx, 4), do: offer_lecture(ctx)
  defp quest_step(ctx, 5), do: refused_blossoms(ctx)
  defp quest_step(ctx, 6), do: deliver_blossoms(ctx)
  defp quest_step(ctx, 7), do: ctx |> set_char_var(:ALCHE_SK, 8) |> one_more_blossom()
  defp quest_step(ctx, 8), do: deliver_last_blossom(ctx)
  defp quest_step(ctx, 9), do: broken_glasses(ctx)
  defp quest_step(ctx, 10), do: offer_thesis_again(ctx)
  defp quest_step(ctx, 11), do: thesis_check(ctx)
  defp quest_step(ctx, _step), do: busy(ctx)

  defp coughing(ctx) do
    ctx
    |> mes("[Pisruik]")
    |> mes("^333333*Cough cough*^000000")
    |> mes("Damn, if only I had")
    |> mes("a little more money")
    |> mes("to buy some medicine.")
    |> mes("I should have stayed")
    |> mes("home today, but...")
    |> close()
  end

  defp busy(ctx) do
    ctx
    |> mes("[Pisruik]")
    |> mes("Mmm...?")
    |> mes("Did you need anything")
    |> mes("in particular? Though,")
    |> mes("I'm afraid someone in")
    |> mes("my position won't be")
    |> mes("much help to you.")
    |> close()
  end

  defp first_meeting(ctx) do
    ctx
    |> mes("[Pisruik]")
    |> mes("^333333*Cough cough*^000000")
    |> mes("Ugh, there's nothing")
    |> mes("worse than working when")
    |> mes("you're supposed to be resting.")
    |> mes("H-hey! Um, what are you doing?")
    |> set_char_var(:ALCHE_SK, 1)
    |> next()
    |> mes("[Pisruik]")
    |> mes("Q-quit looking at")
    |> mes("my test results right")
    |> mes("this inst--oh. Wait.")
    |> mes("You're not one of the")
    |> mes("researchers here. Huh.")
    |> next()
    |> mes("[Pisruik]")
    |> mes("Uh... Don't you have")
    |> mes("anything better to do")
    |> mes("than to breathe down my")
    |> mes("back? I'm trying to finish")
    |> mes("something here! Oh, never")
    |> mes("mind, I'm just cranky...")
    |> close()
  end

  defp second_meeting(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Pisruik]")
      |> mes("You again? You don't seem")
      |> mes("to be doing any research here.")
      |> mes("Is there something you need?")
      |> mes("Though, I'm afraid I can't be")
      |> mes("of very much help to you.")
      |> next()
      |> select(["What are you working on?", "I don't need anything, thanks."])

    case choice do
      1 -> request_materials(ctx)
      _ -> not_a_shop(ctx)
    end
  end

  defp request_materials(ctx) do
    name = char_name(ctx, 0)

    ctx
    |> mes("[Pisruik]")
    |> mes("Well, I'm not sure if I can")
    |> mes("give you all of the details.")
    |> mes("You see, everyone here is")
    |> mes("a researcher that can't afford")
    |> mes("to rent a lab for himself. So we all ended up sharing this one.")
    |> next()
    |> mes("[Pisruik]")
    |> mes("Even though we all pitched")
    |> mes("in to rent this lab, we're all")
    |> mes("getting pretty desperate. In")
    |> mes("fact, a few of us have even")
    |> mes("stolen work from each other.")
    |> mes("That's pretty pathetic, huh?")
    |> next()
    |> mes("[Pisruik]")
    |> mes("I guess that's what happens")
    |> mes("when you're poor and don't")
    |> mes("have a day job. Things are")
    |> mes("so bad right now, I can't even")
    |> mes("afford to get new materials!")
    |> mes("What can I possibly do?")
    |> next()
    |> mes("[Pisruik]")
    |> mes("Ah, I've got it! You're")
    |> mes("an adventurer, right?")
    |> mes("If you're still curious about")
    |> mes("my research, I'll tell you more")
    |> mes("about it if you help me out by")
    |> mes("gathering some supplies for me.")
    |> next()
    |> mes("[Pisruik]")
    |> mes("I guess it couldn't do")
    |> mes("much harm if you knew what")
    |> mes("I was working on, anyway.")
    |> mes("I mean, we'd have to be working")
    |> mes("on the same project for you to")
    |> mes("benefit. So, what's your name?")
    |> next()
    |> mes("[#{name}]")
    |> mes("I am called #{name}.")
    |> next()
    |> set_char_var(:ALCHE_SK, 2)
    |> mes("[Pisruik]")
    |> mes("Ah, #{name}.")
    |> mes("Would you please bring")
    |> mes("^6600005 Yellow Gemstones^000000,")
    |> mes("^6600004 Empty Potion Bottles^000000,")
    |> mes("^66000010 Hearts of Mermaids^000000,")
    |> mes("and ^66000010 Moth Dust^000000?")
    |> close()
  end

  defp not_a_shop(ctx) do
    ctx
    |> mes("[Pisruik]")
    |> mes("If you came here to buy")
    |> mes("Potion Manuals or something")
    |> mes("like that, you've come to the")
    |> mes("wrong guy. Everything you see")
    |> mes("here is for the completion")
    |> mes("of a personal project.")
    |> close()
  end

  defp recall_materials(ctx) do
    {ctx, gemstone} =
      ctx
      |> mes("[Pisruik]")
      |> mes("Great you're back!")
      |> mes("Let's see, you were")
      |> mes("supposed to bring me")
      |> mes("4 Empty Potion Bottles...")
      |> mes("And... And... What else")
      |> mes("did I ask you to get?")
      |> next()
      |> select(["5 Yellow Gemstones", "5 Blue Gemstones", "5 Red Gemstones"])

    case gemstone do
      1 -> recall_hearts_of_mermaid(ctx)
      2 -> wrong_gemstone(ctx, "Blue", "Water")
      3 -> wrong_gemstone(ctx, "Red", "Earth")
      _ -> ctx
    end
  end

  defp wrong_gemstone(ctx, color, property) do
    ctx
    |> mes("[Pisruik]")
    |> mes("#{color} Gemstones...?")
    |> mes("No, that was for the")
    |> mes("potion that increases")
    |> mes("tolerance to the #{property}")
    |> mes("property, I think. What's")
    |> mes("wrong with my memory?!")
    |> close()
  end

  defp recall_hearts_of_mermaid(ctx) do
    {ctx, material} =
      ctx
      |> mes("[Pisruik]")
      |> mes("Right, right!")
      |> mes("5 Yellow Gemstones.")
      |> mes("That's what I needed.")
      |> mes("I'm sure there was more,")
      |> mes("but what I can't recall exactly...")
      |> next()
      |> select(["10 Hearts of Mermaid", "10 Large Jellopies"])

    case material do
      1 -> recall_moth_dust(ctx)
      _ -> large_jellopy(ctx)
    end
  end

  defp large_jellopy(ctx) do
    ctx
    |> mes("[Pisruik]")
    |> mes("Large Jellopy?")
    |> mes("Yes, Large--no.")
    |> mes("Wait, that doesn't")
    |> mes("sound right at all.")
    |> mes("No, it was something")
    |> mes("else I need you to get.")
    |> close()
  end

  defp recall_moth_dust(ctx) do
    {ctx, material} =
      ctx
      |> mes("[Pisruik]")
      |> mes("Of course!")
      |> mes("10 Hearts of Mermaid!")
      |> mes("How could I forget that?")
      |> mes("And then, the last thing")
      |> mes("I asked you for was, um...")
      |> next()
      |> select(["10 Frill", "10 Moth Dust"])

    case material do
      1 ->
        ctx
        |> mes("[Pisruik]")
        |> mes("No, that can't have")
        |> mes("been it. I already have")
        |> mes("plenty of Frills. Hmmm...")
        |> mes("What am I missing now?")
        |> close()

      _ ->
        confirm_delivery(ctx)
    end
  end

  defp confirm_delivery(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Pisruik]")
      |> mes("Right. I was just")
      |> mes("about to say that.")
      |> mes("So did you remember")
      |> mes("to bring me everything?")
      |> next()
      |> select(["No.", "Yes!"])

    case answer do
      1 -> not_brought_yet(ctx)
      _ -> check_materials(ctx)
    end
  end

  defp not_brought_yet(ctx) do
    if Enum.random(1..5) == 1 do
      ctx
      |> mes("[Pisruik]")
      |> mes("You didn't...?")
      |> mes("Oh, just admit it.")
      |> mes("You don't want to")
      |> mes("do this for me, right?")
      |> mes("Don't go wasting your")
      |> mes("time just for my sake.")
      |> close()
    else
      ctx
      |> mes("[Pisruik]")
      |> mes("Not yet, huh?")
      |> mes("Though I hope you can")
      |> mes("bring me that stuff as")
      |> mes("soon as possible, you")
      |> mes("don't have to do it, you")
      |> mes("know. Yeah, no big deal.")
      |> close()
    end
  end

  defp check_materials(ctx) do
    ctx =
      ctx
      |> mes("[Pisruik]")
      |> mes("Really now?")
      |> mes("Well, let me check")
      |> mes("what you brought to")
      |> mes("make sure you didn't")
      |> mes("forget anything. Hm...")
      |> next()

    cond do
      count_item(ctx, @yellow_gemstone) > 4 and count_item(ctx, @empty_potion) > 3 and
        count_item(ctx, @heart_of_mermaid) > 9 and count_item(ctx, @moth_dust) > 9 ->
        take_materials(ctx)

      count_item(ctx, @yellow_gemstone) == 0 and count_item(ctx, @empty_potion) == 0 and
        count_item(ctx, @heart_of_mermaid) == 0 and count_item(ctx, @moth_dust) == 0 ->
        ctx
        |> mes("[Pisruik]")
        |> mes("So you knew what")
        |> mes("you had to bring, came")
        |> mes("to remind me what I had")
        |> mes("forgotten, but didn't bring")
        |> mes("anything? Weird. Ah well.")
        |> mes("Come with the stuff next time.")
        |> close()

      true ->
        ctx
        |> mes("[Pisruik]")
        |> mes("Oh, this isn't good, some")
        |> mes("of the items I asked for are")
        |> mes("missing. I'm sorry, but Alchemy")
        |> mes("gets dangerously unpredictable")
        |> mes("when things aren't used in just")
        |> mes("the right amounts. Hmmm...")
        |> next()
        |> mes("[Pisruik]")
        |> mes("Well, I can afford to")
        |> mes("push my deadlines back")
        |> mes("if you promise to return")
        |> mes("with the materials I need")
        |> mes("as soon as you possibly can.")
        |> close()
    end
  end

  defp take_materials(ctx) do
    {ctx, guess} =
      ctx
      |> delitem(@yellow_gemstone, 5)
      |> delitem(@empty_potion, 4)
      |> delitem(@heart_of_mermaid, 10)
      |> delitem(@moth_dust, 10)
      |> set_char_var(:ALCHE_SK, 3)
      |> mes("[Pisruik]")
      |> mes("Great, it looks like")
      |> mes("everything is here.")
      |> mes("Alright, let me take")
      |> mes("those. Now, guess what")
      |> mes("I'll be making with the")
      |> mes("materials you've brought.")
      |> next()
      |> select(["Medicine?", "Bomb?"])

    ctx
    |> answer_guess(guess)
    |> next()
    |> medicine_lecture()
    |> case do
      {ctx, answer} when answer in 1..3 -> answer_blossom_request(ctx, answer)
      {ctx, _answer} -> large_jellopy(ctx)
    end
  end

  defp answer_guess(ctx, 1) do
    ctx
    |> set_char_var(:ALCHE_SK, 4)
    |> mes("[Pisruik]")
    |> mes("Hahahah, that's right!")
    |> mes("I'm working on making")
    |> mes("a new form of medicine.")
  end

  defp answer_guess(ctx, 2) do
    ctx
    |> set_char_var(:ALCHE_SK, 4)
    |> mes("[Pisruik]")
    |> mes("A bomb? Do I look like")
    |> mes("a nutcase to you? No, no...")
    |> mes("I'm developing a new form of")
    |> mes("medicine. Sure, bombs make")
    |> mes("good money, but where would")
    |> mes("I test them? Here? No way!")
  end

  defp answer_guess(ctx, _guess), do: ctx

  defp medicine_lecture(ctx) do
    ctx
    |> mes("[Pisruik]")
    |> mes("Anyway, this medicine")
    |> mes("reacts with the human body's")
    |> mes("digestive enzymes to initiate")
    |> mes("temporary metabolic changes")
    |> mes("that artificially stop heat")
    |> mes("absorption into the body.")
    |> next()
    |> mes("[Pisruik]")
    |> mes("The actual effect of this")
    |> mes("medicine is that it greatly")
    |> mes("increases the body's resistance")
    |> mes("to most forms of heat! However,")
    |> mes("it will also reduce resistance")
    |> mes("to cold as a side effect.")
    |> next()
    |> mes("[Pisruik]")
    |> mes("I know my medicine sounds")
    |> mes("a little weird, but think of")
    |> mes("the applications! If used in")
    |> mes("the right situations, this")
    |> mes("medicine may be quite handy.")
    |> next()
    |> mes("[Pisruik]")
    |> mes("Ah, seeing as you're still")
    |> mes("here, would you mind helping")
    |> mes("me again? I need about, hmm,")
    |> mes("20 Maneater Blossoms. If you")
    |> mes("could bring them to me, it'd")
    |> mes("really help me out a lot.")
    |> next()
    |> select(["Nope, I'm too busy!", "Sure, I'll help you.", "What's in it for me?"])
  end

  defp answer_blossom_request(ctx, 1), do: decline_to_help(ctx)
  defp answer_blossom_request(ctx, 2), do: agree_to_help(ctx)

  defp answer_blossom_request(ctx, 3) do
    {ctx, answer} =
      ctx
      |> mes("[Pisruik]")
      |> mes("Ha ha ha ha!")
      |> mes("That's real business")
      |> mes("like of you! Alright,")
      |> mes("I may be poor, but if")
      |> mes("you help me, I'll give you")
      |> mes("the results of my research.")
      |> next()
      |> select(["Nah, I'm too busy.", "Alright, I'll help you."])

    case answer do
      1 -> decline_to_help(ctx)
      _ -> agree_to_help(ctx)
    end
  end

  defp decline_to_help(ctx) do
    ctx
    |> set_char_var(:ALCHE_SK, 5)
    |> mes("[Pisruik]")
    |> mes("I guess I'll have to gather")
    |> mes("those on my own. Alright, well,")
    |> mes("seeing as we've both gotten")
    |> mes("what we wanted, I'll suppose")
    |> mes("your business with me is done.")
    |> close()
  end

  defp agree_to_help(ctx) do
    {ctx, _} =
      ctx
      |> set_char_var(:ALCHE_SK, 6)
      |> mes("[Pisruik]")
      |> mes("Thanks, I really")
      |> mes("appreciate it. While")
      |> mes("I'm waiting for you,")
      |> mes("I can start boiling")
      |> mes("the Clover extract.")
      |> next()
      |> select(["Clover extract? What's that for?"])

    ctx =
      ctx
      |> mes("[Pisruik]")
      |> mes("Well, I need the Clover")
      |> mes("extract for a compound")
      |> mes("that I'm going to make with")
      |> mes("the Maneater Blossoms. I'm")
      |> mes("kind of weak, so I try not to")
      |> mes("travel too far when I can.")
      |> next()
      |> mes("[Pisruik]")
      |> mes("Yeah, ever since I was")
      |> mes("little, I've had a weak")
      |> mes("heart and bad eyesight.")
      |> mes("The doctor tells me to avoid")
      |> mes("stress and hard work, but")
      |> mes("researching is my life.")

    ctx =
      if female?(ctx) do
        ctx
        |> next()
        |> mes("[Pisruik]")
        |> mes("I wonder...")
        |> mes("If you understand")
        |> mes("the way I feel, how")
        |> mes("much I've had to sacrifice")
        |> mes("for my dream. Heh, anyway...")
      else
        ctx
      end

    ctx
    |> next()
    |> mes("[Pisruik]")
    |> mes("I hope you understand that")
    |> mes("it's too dangerous for me to")
    |> mes("gather Maneater Blossoms on")
    |> mes("my own, so if I'm going to get")
    |> mes("as much help as I can. Thanks")
    |> mes("again for being cooperative.")
    |> close()
  end

  defp interrupted_talk(ctx) do
    ctx
    |> mes("[Pisruik]")
    |> mes("Why did you just leave?")
    |> mes("You didn't even let me")
    |> mes("finish talking! Oh well,")
    |> mes("maybe it's not your fault.")
    |> mes("Anyway, just so you know,")
    |> mes("I'm developing a new medicine.")
    |> set_char_var(:ALCHE_SK, 4)
    |> close()
  end

  defp offer_lecture(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Pisruik]")
      |> mes("Alright, did you")
      |> mes("want to learn more")
      |> mes("about the medicine that")
      |> mes("I'm developing? I mean,")
      |> mes("that's why you came, right?")
      |> next()
      |> select(["No, thanks.", "Yes, please."])

    case answer do
      1 ->
        ctx
        |> mes("[Pisruik]")
        |> mes("Alright then.")
        |> mes("Really? Well, I'm")
        |> mes("willing to spend the")
        |> mes("time to explain it to")
        |> mes("you. After all, you did")
        |> mes("help me out just then.")
        |> close()

      _ ->
        ctx
        |> mes("[Pisruik]")
        |> mes("I'm working on a new")
        |> mes("form of medicine that,")
        |> mes("hopefully, will be used")
        |> mes("for the betterment and")
        |> mes("protection of mankind!")
        |> next()
        |> medicine_lecture()
        |> case do
          {ctx, answer} when answer in 1..3 -> answer_blossom_request(ctx, answer)
          {ctx, _answer} -> ctx
        end
    end
  end

  defp refused_blossoms(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Pisruik]")
      |> mes("I'm busy right now.")
      |> mes("You didn't forget")
      |> mes("anything did you?")
      |> mes("If not, you better")
      |> mes("get going and let")
      |> mes("me do my work.")
      |> next()
      |> select(["Alright, sorry to bother you.", "Can I still help you?"])

    case answer do
      1 ->
        ctx
        |> mes("[Pisruik]")
        |> mes("Yeah, whatever.")
        |> mes("Just hurry up and leave")
        |> mes("so that I can concentrate.")
        |> close()

      _ ->
        ctx =
          ctx
          |> mes("[Pisruik]")
          |> mes("Huh? What made you")
          |> mes("change your mind? Well,")
          |> mes("I can't afford not to accept")
          |> mes("any help, so I guess that's")
          |> mes("a \"Yes.\" Yeah, you can help.")
          |> next()
          |> mes("[Pisruik]")
          |> mes("Alright, go and get me")
          |> mes("20 Maneater Blossoms.")
          |> mes("If I weren't so sickly, I'd get")
          |> mes("them myself, but--*Cough* as")
          |> mes("you can see, I don't feel so well.")
          |> set_char_var(:ALCHE_SK, 6)
          |> next()
          |> mes("[Pisruik]")

        if female?(ctx) do
          ctx
          |> mes("I... I really")
          |> mes("appreciate your")
          |> mes("willingness to help")
          |> mes("me in my research...")
          |> close()
        else
          ctx
          |> mes("I hope you get those")
          |> mes("items to me as soon as")
          |> mes("you can. And don't flake")
          |> mes("out on me this time!")
          |> close()
        end
    end
  end

  defp deliver_blossoms(ctx) do
    if count_item(ctx, @maneater_blossom) > 19 do
      ctx =
        ctx
        |> delitem(@maneater_blossom, 20)
        |> set_char_var(:ALCHE_SK, 7)
        |> mes("[Pisruik]")
        |> mes("Thanks so much for")
        |> mes("bringing me these")
        |> mes("Maneater Blossoms.")

      ctx =
        if female?(ctx) do
          ctx
          |> mes("You don't know how")
          |> mes("much this means to me~")
        else
          ctx
          |> mes("Now all I have to do")
          |> mes("is mix these with the")
          |> mes("Clover extract I prepared.")
        end

      explosion(ctx)
    else
      ctx
      |> mes("[Pisruik]")
      |> mes("Would you come back with")
      |> mes("20 Maneater Blossoms")
      |> mes("so that I can finish this")
      |> mes("medicine I'm working on?")
      |> mes("Thanks, thanks, I've got")
      |> mes("to hustle with this project...")
      |> close()
    end
  end

  defp one_more_blossom(ctx) do
    ctx
    |> mes("[Pisruik]")
    |> mes("Hmmm...")
    |> mes("Actually, I miscalculated")
    |> mes("the number of Maneater")
    |> mes("Blossoms that I need. Would")
    |> mes("you bring me one more? Sorry, I know it's kind of troublesome...")
    |> close()
  end

  defp deliver_last_blossom(ctx) do
    if count_item(ctx, @maneater_blossom) > 0 do
      ctx =
        ctx
        |> delitem(@maneater_blossom, 1)
        |> set_char_var(:ALCHE_SK, 7)
        |> mes("[Pisruik]")
        |> mes("Thanks so much!")
        |> mes("Now I finally have the")
        |> mes("exact amount of Maneater")
        |> mes("Blossoms that I'll need.")

      ctx =
        if female?(ctx) do
          ctx
          |> mes("I'm really sorry for putting")
          |> mes("your through all this trouble.")
        else
          ctx
          |> mes("Finally, I begin the most")
          |> mes("exciting part of this project!")
        end

      explosion(ctx)
    else
      one_more_blossom(ctx)
    end
  end

  defp explosion(ctx) do
    name = char_name(ctx, 0)

    ctx =
      ctx
      |> next()
      |> set_char_var(:ALCHE_SK, 9)
      |> specialeffect(:sui_explosion)
      |> mes("[Pisruik]")
      |> mes("Ah!")
      |> mes("M-my face!")
      |> next()
      |> mes("[Pisruik]")
      |> mes("Hey...")
      |> mes("Are you alright?")
      |> mes("That was a pretty")
      |> mes("big explosion...")
      |> next()
      |> mes("[#{name}]")
      |> mes("Your glasses...")
      |> mes("They're broken...")
      |> next()

    ctx =
      if female?(ctx) do
        ctx
        |> mes("^3355FFThe explosion destroyed")
        |> mes("Pisruik's glasses, revealing")
        |> mes("the beautiful face of a")
        |> mes("gorgeous, gorgeous man.^000000")
      else
        ctx
        |> mes("^3355FFThe explosion blew off")
        |> mes("Pisruik's glasses. Without")
        |> mes("them, he looks more like")
        |> mes("a male model than a dorky")
        |> mes("scientific researcher.^000000")
      end

    ctx
    |> next()
    |> mes("[#{name}]")
    |> mes("Holy crap!")
    |> mes("You're one")
    |> mes("good looking guy!")
    |> next()
    |> mes("[Pisruik]")
    |> mes("I c-can't see too")
    |> mes("well without my glasses.")
    |> mes("Well, at least I can tell")
    |> mes("that you're not bleeding.")
    |> mes("But are you alright?")
    |> next()
    |> mes("[#{name}]")
    |> mes("Oh, I'm fine.")
    |> mes("But what are you")
    |> mes("going to do about")
    |> mes("your glasses?")
    |> next()
    |> mes("[Pisruik]")
    |> mes("Shoot, you're right.")
    |> mes("I don't happen to have")
    |> mes("an extra pair. Hey, can")
    |> mes("you get me a pair of glasses,")
    |> mes("the same kind I used to wear?")
    |> next()
    |> mes("[Pisruik]")
    |> mes("I know it's too much")
    |> mes("to ask you for, but I'm")
    |> mes("almost blind without them.")
    |> mes("I can't do very much if I can't")
    |> mes("even see. I'm really sorry")
    |> mes("about this, #{name}.")
    |> close()
  end

  defp broken_glasses(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFPisruik is holding his")
      |> mes("broken glasses, squinting")
      |> mes("his eyes. It seems he like")
      |> mes("he really does need them,")
      |> mes("even if he looks much less")
      |> mes("dorky without them.^000000")
      |> next()
      |> select(["Let him try a pair of your glasses", "Don't give him anything"])

    case choice do
      1 -> lend_glasses(ctx)
      _ -> compliment_without_glasses(ctx)
    end
  end

  defp lend_glasses(ctx) do
    if count_item(ctx, @glasses) > 0 do
      name = char_name(ctx, 0)

      {ctx, answer} =
        ctx
        |> delitem(@glasses, 1)
        |> set_char_var(:ALCHE_SK, 10)
        |> mes("[#{name}]")
        |> mes("Here, why don't you")
        |> mes("check I'm carrying and")
        |> mes("see if there's a pair of")
        |> mes("glasses that you can use?")
        |> next()
        |> mes("[Pisruik]")
        |> mes("Huh? Oh, is that you?")
        |> mes("Ah, this pair of glasses")
        |> mes("works! Thanks a lot, now")
        |> mes("I can see again! Now, let")
        |> mes("me check the results of the")
        |> mes("experiment we conducted.")
        |> next()
        |> mes("[Pisruik]")
        |> mes("Okay, the test tube wasn't")
        |> mes("damaged. Yes, according to")
        |> mes("these readings, this medicine")
        |> mes("should be fully functional!")
        |> mes("I think it was a success!")
        |> mes("Well, theoretically anyway.")
        |> next()
        |> mes("[Pisruik]")
        |> mes("Hmm, changing the attributes")
        |> mes("of the human body for certain")
        |> mes("effects may cause controversy")
        |> mes("later, but hopefully this thing")
        |> mes("I've invented will be used for")
        |> mes("good. Ah, that's right!")
        |> next()
        |> mes("[Pisruik]")
        |> mes("Would you like me to")
        |> mes("teach you everything I've")
        |> mes("learned in my research? You")
        |> mes("should be able to create a new")
        |> mes("type of potion by making use of")
        |> mes("the knowledge I can teach you.")
        |> next()
        |> select(["Sure!", "No, thanks."])

      answer_thesis_offer(ctx, answer)
    else
      ctx
      |> mes("^3355FFUnfortunately, there")
      |> mes("is nothing in your inventory")
      |> mes("that seems like a suitable")
      |> mes("replacement for Pisruik's")
      |> mes("broken glasses.^000000")
      |> close()
    end
  end

  defp compliment_without_glasses(ctx) do
    name = char_name(ctx, 0)

    ctx
    |> mes("[#{name}]")
    |> mes("Listen, you look so")
    |> mes("much better when you're")
    |> mes("not wearing glasses.")
    |> next()
    |> mes("[Pisruik]")
    |> mes("Excuse me,")
    |> mes("come again?")
    |> next()
    |> mes("[#{name}]")
    |> mes("Hahahahhaha~!")
    |> mes("No-nothing at all!")
    |> close()
  end

  defp offer_thesis_again(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Pisruik]")
      |> mes("So, #{char_name(ctx, 0)},")
      |> mes("Would you like me to")
      |> mes("teach you the results")
      |> mes("of the research I've''")
      |> mes("been conducting?")
      |> next()
      |> select(["Yes!", "No, thanks."])

    answer_thesis_offer(ctx, answer)
  end

  defp answer_thesis_offer(ctx, 1) do
    ctx =
      ctx
      |> mes("[Pisruik]")
      |> mes("Great, #{char_name(ctx, 0)}!")
      |> mes("I know I can trust you")
      |> mes("to use this research for")
      |> mes("good and noble ends. Now,")
      |> mes("please read this thesis and")
      |> mes("all of my additional notes...")
      |> next()
      |> mes("^3355FFPisruik thoroughly")
      |> mes("explains the properties")
      |> mes("of his medicine, the reaction")
      |> mes("of the human organs to it, as")
      |> mes("well as a few warnings about")
      |> mes("the medicine's side effects.^000000")
      |> next()
      |> set_char_var(:ALCHE_SK, 11)
      |> give_item(@thesis, 1)
      |> mes("[Pisruik]")
      |> mes("Well, you should be")
      |> mes("ready to make your own")
      |> mes("potions that are a variation")
      |> mes("of my medicine. But you'll")
      |> mes("probably need to keep that")
      |> mes("thesis as a ready reference.")
      |> next()
      |> mes("[Pisruik]")

    if male?(ctx) do
      ctx
      |> mes("Hopefully, we'll")
      |> mes("meet again sometime")
      |> mes("in the future. Good luck on")
      |> mes("your journeys, adventurer.")
      |> mes("*Cough cough* Now... What")
      |> mes("will be my next project?")
      |> close()
    else
      ctx
      |> mes("Anyway, I need to be")
      |> mes("working on a new project")
      |> mes("soon, so I suppose this is")
      |> mes("where we part ways for now.")
      |> mes("But I must say, it was truly")
      |> mes("a great pleasure to meet you...")
      |> close()
    end
  end

  defp answer_thesis_offer(ctx, _answer) do
    ctx =
      ctx
      |> mes("[Pisruik]")
      |> mes("R-Really...?")
      |> mes("Well, if you ever change")
      |> mes("your mind, feel free to come")
      |> mes("back for me to teach you.")

    ctx =
      if female?(ctx) do
        ctx
        |> mes("And it's no trouble at all!")
        |> mes("I really enjoy your company...")
      else
        ctx
      end

    close(ctx)
  end

  defp thesis_check(ctx) do
    case count_item(ctx, @thesis) do
      0 ->
        ctx
        |> mes("[Pisruik]")
        |> mes("Uh oh...")
        |> mes("You lost the thesis")
        |> mes("I wrote for you? I don't")
        |> mes("have the time to write")
        |> mes("another one for you now...")
        |> close()

      1 ->
        ctx
        |> mes("[Pisruik]")
        |> mes("So, how have you been")
        |> mes("using the potions that")
        |> mes("I've taught you to make?")
        |> mes("Hopefully, they'll come")
        |> mes("in handy in your adventures.")
        |> close()

      copies when copies > 1 ->
        ctx
        |> mes("[Pisruik]")
        |> mes("Huh, so copies of my")
        |> mes("thesis are circulating")
        |> mes("around in public? Well,")
        |> mes("I'm sorry, but I don't have")
        |> mes("time to autograph your copy...")
        |> close()

      _ ->
        ctx
    end
  end
end
