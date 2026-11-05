defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.CuteStudent do
  @moduledoc """
  Elly recruits help baking cookies and investigating her missing grandfather.

  ## Behavior

  - Collects cookie ingredients, rewards the delivery with cookies, and sends them to her
    grandfather.
  - Provides the Cottage Key, reads his warning letter, and directs a trusted friend to the study
    and her dormitory.

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
        map: "kh_school",
        x: 179,
        y: 39,
        dir: 0,
        sprite: 895,
        name: "Cute Student",
        scope: :shared,
        unique_name: "Cute Student#kh"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if checkweight(ctx, [{908, 200}]) == 0 do
      inventory_full(ctx)
    else
      ctx |> cutin("kh_elly01", 2) |> discuss_quest()
    end
  end

  defp discuss_quest(ctx) do
    case get_char_var(ctx, :KielHyreQuest, 0) do
      stage when stage < 4 -> spilled_ingredients(ctx)
      4 -> offer_help(ctx)
      6 -> deliver_ingredients(ctx)
      8 -> reward_cookies(ctx)
      10 -> offer_cookie_delivery(ctx)
      12 -> cottage_directions(ctx)
      14 -> lend_cottage_key(ctx)
      stage when stage >= 14 and stage < 20 -> missing_grandfather(ctx)
      20 -> read_letter(ctx)
      22 -> discuss_family(ctx)
      stage when stage >= 24 and stage <= 26 -> arrange_dorm_visit(ctx)
      _ -> dismiss_visitor(ctx)
    end
  end

  defp finish_dialogue(ctx), do: ctx |> close() |> cutin("", 255)

  defp inventory_full(ctx) do
    ctx
    |> mes("[Elly]")
    |> mes("I'm sorry, but would you")
    |> mes("put some of your things in")
    |> mes("your Kafra Storage first or")
    |> mes("something? I can't really")
    |> mes("help you when you're ")
    |> mes("carrying so much stuff.")
    |> close()
  end

  defp spilled_ingredients(ctx) do
    ctx
    |> cutin("kh_elly03", 2)
    |> mes("[Elly]")
    |> mes("W-wah! Oh...!")
    |> mes("^333333*Phew*^000000 That was close,")
    |> mes("I almost dropped them ")
    |> mes("again! Why do I have so much")
    |> mes("trouble handling ingredients?")
    |> finish_dialogue()
  end

  defp offer_help(ctx) do
    {ctx, response} =
      ctx
      |> cutin("kh_elly03", 2)
      |> mes("[Elly]")
      |> mes("Oh no, what should")
      |> mes("I do? ^333333*Sob*^000000 Wh-what")
      |> mes("am I going to do? ^333333*Sniff*^000000")
      |> next()
      |> select(["What happened?", "......"])

    case response do
      1 -> explain_spilled_ingredients(ctx)
      2 -> ctx |> mes("[Elly]") |> mes("*Sob*...") |> finish_dialogue()
      _ -> ctx
    end
  end

  defp explain_spilled_ingredients(ctx) do
    {ctx, response} =
      ctx
      |> mes("[Elly]")
      |> mes("I... I have to finish baking")
      |> mes("this batch of cookies by the")
      |> mes("end of today, but then I spilled")
      |> mes("all of the ingredients on the")
      |> mes("floor. I don't know how I can")
      |> mes("bake those cookies now...")
      |> next()
      |> select(["What can I do to help you?", "Oh, I'm so sorry."])

    case response do
      1 -> ctx |> welcome_help() |> request_ingredients()
      2 -> ask_adventurer(ctx)
      _ -> ctx
    end
  end

  defp welcome_help(ctx) do
    ctx
    |> cutin("kh_elly02", 2)
    |> mes("[Elly]")
    |> mes("What was that...?")
    |> mes("You'll really help")
    |> mes("me? That's wonderful!")
    |> mes("Thank you! Thanks so much!")
    |> next()
  end

  defp ask_adventurer(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Elly]")
      |> mes("Wait, you don't go")
      |> mes("to this school, don't")
      |> mes("you? Y-you're one of")
      |> mes("those adventurers, right?")
      |> next()
      |> select(["Yeah, that's right."])

    {ctx, response} =
      ctx
      |> mes("Listen, I know you")
      |> mes("probably have your own")
      |> mes("plans, but do  you think")
      |> mes("you can help me with this")
      |> mes("huge problem that I have?")
      |> next()
      |> select(["Accept", "Decline"])

    case response do
      1 -> ctx |> welcome_adventurer() |> request_ingredients()
      2 -> decline_help(ctx)
      _ -> ctx
    end
  end

  defp welcome_adventurer(ctx) do
    ctx
    |> cutin("kh_elly02", 2)
    |> mes("How Wonderful!")
    |> mes("Thank you! Thank you")
    |> mes("so much! I'm supposed to")
    |> mes("finish baking this batch of")
    |> mes("cookies soon, but I spilled")
    |> mes("all of the ingredients...")
    |> next()
  end

  defp decline_help(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("I'm outta here.")
    |> next()
    |> cutin("kh_elly04", 2)
    |> mes("[Elly]")
    |> mes("W-wait...!")
    |> mes("Come back, you")
    |> mes("d-don't...! I really")
    |> mes("need some help!")
    |> emotion(:cry)
    |> finish_dialogue()
  end

  defp request_ingredients(ctx) do
    ctx
    |> cutin("kh_elly01", 2)
    |> mes("[Elly]")
    |> mes("Well, I guess the only way")
    |> mes("I can bake these cookies is")
    |> mes("to get some new ingredients.")
    |> mes("I'm sorry to be such a burden,")
    |> mes("but if you didn't offer to help")
    |> mes("me, then I'd have no one to ask!")
    |> next()
    |> cutin("kh_elly04", 2)
    |> mes("[Elly]")
    |> mes("You don't understand how")
    |> mes("important it is that I bake")
    |> mes("these cookies... If I don't")
    |> mes("finish this assignment, then")
    |> mes("Mrs. Crank will fail me for")
    |> mes("the entire semester!")
    |> next()
    |> mes("[Elly]")
    |> cutin("kh_elly01", 2)
    |> mes("Okay, I need to calm")
    |> mes("down. I think I can do")
    |> mes("this with your help.")
    |> mes("Would you please do me")
    |> mes("this huge favor and bring")
    |> mes("all of these ingredients?")
    |> next()
    |> mes("[Elly]")
    |> mes("^3355FF1 Wine^000000,")
    |> mes("^3355FF7 Milks^000000,")
    |> mes("^3355FF5 Cacaos^000000,")
    |> mes("^3355FF2 Cheeses^000000,")
    |> mes("^3355FF1 Egg^000000, and")
    |> mes("^3355FF1 Bag of Flour^000000.")
    |> next()
    |> mes("[Elly]")
    |> mes("Let's see... You can")
    |> mes("get Wine from a pub in")
    |> mes("Juno, Cacaos from hunting")
    |> mes("Yoyos, and you can get flour")
    |> mes("and Eggs from the girl that")
    |> mes("runs the Toast Stand in Juno.")
    |> next()
    |> mes("[Elly]")
    |> mes("Good luck, getting")
    |> mes("everything, and I hope")
    |> mes("you hurry back here with")
    |> mes("those cookie ingredients")
    |> mes("as quickly as you can, okay?")
    |> set_char_var(:KielHyreQuest, 6)
    |> finish_dialogue()
  end

  defp deliver_ingredients(ctx) do
    ctx =
      if count_item(ctx, 519) < 7 or count_item(ctx, 548) < 2 or
           count_item(ctx, 7182) < 5 or count_item(ctx, 7487) < 1 or
           count_item(ctx, 7488) < 1 do
        ctx
        |> mes("[Elly]")
        |> mes("Let's see, would you")
        |> mes("like me to remind you")
        |> mes("which ingredients I need?")
        |> mes("Please bring these things as")
        |> mes("soon as you can so that I can")
        |> mes("quickly bake some cookies~")
        |> next()
        |> mes("[Elly]")
        |> mes("^3355FF1 Wine^000000,")
        |> mes("^3355FF7 Milks^000000,")
        |> mes("^3355FF5 Cacaos^000000,")
        |> mes("^3355FF2 Cheeses^000000,")
        |> mes("^3355FF1 Egg^000000, and")
        |> mes("^3355FF1 Bag of Flour^000000.")
        |> next()
        |> cutin("kh_elly01", 2)
        |> mes("[Elly]")
        |> mes("Let's see... You can")
        |> mes("get Wine from a pub in")
        |> mes("Juno, Cacaos from hunting")
        |> mes("Yoyos, and you can get flour")
        |> mes("and Eggs from the girl that")
        |> mes("runs the Toast Stand in Juno.")
      else
        ctx
        |> cutin("kh_elly02", 2)
        |> mes("[Elly]")
        |> mes("Hooray! Finally, I have")
        |> mes("everything I need! This is")
        |> mes("great! Oh, would you please")
        |> mes("give me a moment while I bake")
        |> mes("these cookies?  It shouldn't take")
        |> mes("long, so hold on just a bit.")
        |> delitem(519, 7)
        |> delitem(548, 2)
        |> delitem(7182, 5)
        |> delitem(7487, 1)
        |> delitem(7488, 1)
        |> set_char_var(:KielHyreQuest, 8)
        |> set_char_var(:KHPubMasterEnd, 0)
        |> set_char_var(:KHToastGirlEnd, 0)
        |> emotion(:delight)
      end

    finish_dialogue(ctx)
  end

  defp reward_cookies(ctx) do
    ctx
    |> mes("[Elly]")
    |> mes("Tadah! I did it!")
    |> mes("They're finally done!")
    |> mes("Elly's special cookies.")
    |> mes("I'd like you to have some")
    |> mes("as thanks for helping me out.")
    |> next()
    |> mes("[Elly]")
    |> mes("I'm sorry, but I was so")
    |> mes("preoccupied with baking")
    |> mes("these cookies that I didn't")
    |> mes("even ask for your name. I'm")
    |> mes("^FF0000Ellyja^000000, but everybody calls me,")
    |> mes("''Elly.'' What's your name?")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("^3355FF#{char_name(ctx, 0)}^000000.")
    |> mes("It's ^3355FF#{char_name(ctx, 0)}^000000.")
    |> next()
    |> cutin("kh_elly02", 2)
    |> mes("[Elly]")
    |> mes("#{char_name(ctx, 0)}?")
    |> mes("...that name! It's wonderful!")
    |> give_item(538, 5)
    |> set_char_var(:KielHyreQuest, 10)
    |> finish_dialogue()
  end

  defp offer_cookie_delivery(ctx) do
    {ctx, response} =
      ctx
      |> mes("[Elly]")
      |> mes("I'm sorry, but I have")
      |> mes("another favor to ask you")
      |> mes("if you don't mind helping")
      |> mes("me out again. Don't worry,")
      |> mes("you won't have to hurry as")
      |> mes("quickly as you did last time.")
      |> next()
      |> select(["What do you need?", "Sorry, but I'm pretty busy..."])

    case response do
      1 -> ask_cookie_delivery(ctx)
      2 -> decline_delivery(ctx)
      _ -> ctx
    end
  end

  defp ask_cookie_delivery(ctx) do
    {ctx, response} =
      ctx
      |> mes("[Elly]")
      |> mes("You know how you helped")
      |> mes("me bake those cookies?")
      |> mes("It's the first time I was able")
      |> mes("to do it without burning them!")
      |> mes("I just know Grandfather'd")
      |> mes("be so proud of me!")
      |> next()
      |> mes("[Elly]")
      |> mes("I really want Grandfather")
      |> mes("to taste the cookies I baked,")
      |> mes("but the cookies will be stale")
      |> mes("by the time I'm able to leave")
      |> mes("campus. Would you deliver these")
      |> mes("cookies to my grandfather for me?")
      |> next()
      |> select(["Sure", "I'm busy."])

    case response do
      1 -> accept_cookie_delivery(ctx)
      2 -> decline_delivery(ctx)
      _ -> ctx
    end
  end

  defp accept_cookie_delivery(ctx) do
    ctx
    |> cutin("kh_elly02", 2)
    |> mes("[Elly]")
    |> mes("Oh, #{char_name(ctx, 0)}!")
    |> mes("Thank you so much, I knew")
    |> mes("you'd understand! Would you")
    |> mes("please bring the cookies to")
    |> mes("him at ^FF0000Kiel Hyre's cottage^000000?")
    |> next()
    |> mes("[Elly]")
    |> mes("Oh, right! They're really")
    |> mes("careful about visitors and")
    |> mes("keeping strangers off the")
    |> mes("property, but if you mention")
    |> mes("my name, they'll let you in.")
    |> mes("Alright then, see you~")
    |> set_char_var(:KielHyreQuest, 12)
    |> finish_dialogue()
  end

  defp decline_delivery(ctx) do
    ctx
    |> cutin("kh_elly03", 2)
    |> mes("[Elly]")
    |> mes("Oh, um...")
    |> mes("Okay, I'm sorry to")
    |> mes("have bothered you...")
    |> finish_dialogue()
  end

  defp cottage_directions(ctx) do
    ctx
    |> mes("[Elly]")
    |> mes("Oh, you don't know where")
    |> mes("to find Kiel Hyre's cottage?")
    |> mes("It's just north from this")
    |> mes("academy. Please deliver my")
    |> mes("cookies to Grandfather, and")
    |> mes("let him know I really miss him.")
    |> finish_dialogue()
  end

  defp lend_cottage_key(ctx) do
    ctx
    |> cutin("kh_elly03", 2)
    |> mes("[Elly]")
    |> mes("Hm? Grandfather's not")
    |> mes("home? That's strange, he")
    |> mes("didn't mention anything about")
    |> mes("any business trips. I thought")
    |> mes("he'd be at home all day...")
    |> next()
    |> cutin("kh_elly04", 2)
    |> mes("[Elly]")
    |> mes("Would you go back to his")
    |> mes("cottage one more time? Here,")
    |> mes("you can use this Cottage Key.")
    |> mes("That way, you can just go")
    |> mes("inside and talk to him~")
    |> give_item(7489, 1)
    |> set_char_var(:KielHyreQuest, 16)
    |> finish_dialogue()
  end

  defp read_letter(ctx) do
    ctx
    |> mes("[Elly]")
    |> mes("Hmm...?")
    |> mes("What's this,")
    |> mes("a letter for me?")
    |> next()
    |> mes("^3355FFElly opened the envelope")
    |> mes("and started reading the letter.^000000")
    |> next()
    |> mes("^333333Dearest Elly,")
    |> mes(" ")
    |> mes("I have something to discuss")
    |> mes("with my son Kiehl, so I am")
    |> mes("leaving to meet with him.")
    |> mes("If you don't hear from me")
    |> mes("after 7 days after I've written")
    |> mes("this letter, then you must")
    |> mes("escape the academy as soon")
    |> mes("as possible, and retrieve")
    |> mes("something inside our ")
    |> mes("cottage's study.")
    |> mes(" ")
    |> mes("If you have a friend you")
    |> mes("can trust, please ask him")
    |> mes("to follow my traces in the")
    |> mes("cottage. I might be in danger,")
    |> mes("and in dire need of rescue.")
    |> mes(" ")
    |> mes("Elly, don't trust anyone")
    |> mes("in the academy, even your")
    |> mes("classmates, since they may")
    |> mes("be influenced by Kiehl.")
    |> mes(" ")
    |> mes("Be careful, and I love you.")
    |> mes(" ")
    |> mes("--Grandpa^000000")
    |> next()
    |> cutin("kh_elly03", 2)
    |> mes("[Elly]")
    |> mes("What? Oh no, it's been")
    |> mes("ten days since he wrote")
    |> mes("this letter! Ah, does this")
    |> mes("mean that he's in danger?!")
    |> mes("Oh no, what should I do?")
    |> delitem(7490, 1)
    |> set_char_var(:KielHyreQuest, 22)
    |> finish_dialogue()
  end

  defp missing_grandfather(ctx) do
    ctx
    |> mes("[Elly]")
    |> mes("That's so weird...")
    |> mes("I thought Grandfather")
    |> mes("said that he'd be at")
    |> mes("home all day today...")
    |> finish_dialogue()
  end

  defp discuss_family(ctx) do
    {ctx, topic} =
      ctx
      |> cutin("kh_elly03", 2)
      |> mes("[Elly]")
      |> mes("......")
      |> mes(".........")
      |> mes("............")
      |> next()
      |> select([
        "About your grandpa",
        "Tell me about Kiehl",
        "What's with this academy?"
      ])

    case topic do
      1 -> discuss_grandfather(ctx)
      2 -> discuss_kiehl(ctx)
      3 -> discuss_academy(ctx)
      _ -> ctx
    end
  end

  defp discuss_grandfather(ctx) do
    ctx
    |> mes("[Elly]")
    |> mes("Oh! My grandfather is")
    |> mes("Kiel Hyre, founder and")
    |> mes("CEO of the Kiel Hyre")
    |> mes("foundation. He looks")
    |> mes("strict and cold hearted,")
    |> mes("but he's actually very nice!")
    |> next()
    |> mes("[Elly]")
    |> mes("We're not related by")
    |> mes("blood, but he's taken")
    |> mes("care of me ever since")
    |> mes("I lost my parents. Oh,")
    |> mes("Grandapa, where are you?")
    |> mes("I'm getting so worried!")
    |> finish_dialogue()
  end

  defp discuss_kiehl(ctx) do
    ctx
    |> mes("[Elly]")
    |> mes("Kiehl? That's my")
    |> mes("grandfather's son...")
    |> mes("I don't know him that")
    |> mes("well, and only saw him")
    |> mes("once at an academy event.")
    |> next()
    |> mes("[Elly]")
    |> mes("Mmm, he's a good looking")
    |> mes("guy with pale skin, silver")
    |> mes("hair, and this cold, fierce")
    |> mes("stare. A lot of my classmates")
    |> mes("worship Kiehl because he's")
    |> mes("also a business genius~")
    |> next()
    |> mes("[Elly]")
    |> mes("It's weird though...")
    |> mes("I have no idea why my")
    |> mes("grandpa and Kiehl don't")
    |> mes("get along. They're both")
    |> mes("really good at what they do...")
    |> finish_dialogue()
  end

  defp discuss_academy(ctx) do
    ctx =
      ctx
      |> mes("[Elly]")
      |> mes("Well, I know the security")
      |> mes("here is really tight, but")
      |> mes("that's because everything")
      |> mes("here is so luxurious and")
      |> mes("expensive, you know~")
      |> next()
      |> mes("[Elly]")
      |> mes("We also have a very")
      |> mes("special curriculum where")
      |> mes("you learn more of what you")
      |> mes("want. Personally, I want to")
      |> mes("become a great career woman")
      |> mes("like ^0000FFMs. Allysia^000000. Heh heh~")
      |> next()
      |> mes("[Elly]")
      |> mes("This place certainly")
      |> mes("isn't like other schools.")
      |> mes("Yeah, everything is made to")
      |> mes("fit each of the student's needs.")
      |> next()
      |> mes("[Elly]")
      |> mes("Recently, though?")
      |> mes("Some really weird stuff")
      |> mes("has been happening. All of")
      |> mes("my classmates are afraid of")
      |> mes("going out alone by themselves.")
      |> next()
      |> cutin("kh_elly02", 2)
      |> mes("[Elly]")
      |> mes("But I'll be okay!")
      |> mes("You'll be there to")
      |> mes("rescue me from danger,")

    {ctx, topic} =
      ctx
      |> mes("right, #{char_name(ctx, 0)}?")
      |> next()
      |> select(["Who is Ms. Allysia?", "Strange incidents?"])

    case topic do
      1 -> discuss_allysia(ctx)
      2 -> discuss_ghost(ctx)
      _ -> ctx
    end
  end

  defp discuss_allysia(ctx) do
    ctx
    |> mes("[Elly]")
    |> mes("Oh, Ms. Allysia is")
    |> mes("Grandfather's secretary~")
    |> mes("She's so beautiful, and")
    |> mes("my grandfather really")
    |> mes("trusts her with everything!")
    |> finish_dialogue()
  end

  defp discuss_ghost(ctx) do
    ctx
    |> cutin("kh_elly04", 2)
    |> mes("[Elly]")
    |> mes("Well, #{char_name(ctx, 0)}...")
    |> mes("I'm not supposed to tell")
    |> mes("anyone outside of the school,")
    |> mes("but I can trust you! You see...")
    |> mes("We're haunted by a ghost!")
    |> next()
    |> mes("[Elly]")
    |> mes("I know it sounds crazy,")
    |> mes("but this ghost wanders the")
    |> mes("campus, and curses its victims,")
    |> mes("making them so cold and lifeless.")
    |> mes("It happened to my roommate,")
    |> mes("Mayo. It's like she's a statue...")
    |> next()
    |> mes("[Elly]")
    |> mes("I snuck into the medical")
    |> mes("office to see her, and she...")
    |> mes("She couldn't do anything!")
    |> mes("What would happen if the")
    |> mes("ghost decided to curse me?!")
    |> next()
    |> cutin("kh_elly02", 2)
    |> mes("[Elly]")
    |> mes("You know what...?")
    |> mes("If I ever got cursed")
    |> mes("by that ghost, just yell")
    |> mes("''^FF0000Wake up, Elly!^000000''")
    |> mes("That'll wake me up for sure!")
    |> set_char_var(:KielHyreQuest, 24)
    |> finish_dialogue()
  end

  defp arrange_dorm_visit(ctx) do
    ctx
    |> cutin("kh_elly04", 2)
    |> mes("[Elly]")
    |> mes("Argh, I'm in a fix!")
    |> mes("I have to finish my")
    |> mes("homework before it's due!")
    |> mes("Yeah, I've got to go see")
    |> mes("Mrs. Lecollane now.")
    |> next()
    |> mes("[Elly]")
    |> mes("Say, #{char_name(ctx, 0)},")
    |> mes("if it's okay, would you")
    |> mes("please go find what my")
    |> mes("grandpa left for me in")
    |> mes("the ^FF0000cottage study^000000? You're")
    |> mes("the only one I can trust!")
    |> next()
    |> mes("[Elly]")
    |> mes("Anyway, I'll see you later")
    |> mes("in the evening! Please come")
    |> mes("by my ^FF0000dorm room^000000. Um, the")
    |> mes("dorms are in the church just")
    |> mes("behind the academy, okay?")
    |> next()
    |> mes("[Elly]")
    |> mes("My room is in the back,")
    |> mes("and it's on the ^FF0000second floor^000000")
    |> mes("^FF0000on the left side^000000. Please use")
    |> mes("a ladder to come up, okay?")
    |> mes("I'll leave my window open")
    |> mes("for you, so just come, okay?")
    |> next()
    |> mes("[Elly]")
    |> mes("Hurry, hurry, the")
    |> mes("teacher's coming!")
    |> set_char_var(:KielHyreQuest, 26)
    |> finish_dialogue()
  end

  defp dismiss_visitor(ctx) do
    ctx
    |> mes("[Elly]")
    |> mes("Hurry, hurry, the")
    |> mes("teacher's coming!")
    |> finish_dialogue()
  end
end
