defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Laura do
  @moduledoc """
  Laura leads the Rune-Midgarts side of the Odin Shrine expedition.

  ## Behavior

  - Recruits adventurers to survey the shrine and recover Runes of Darkness.
  - Rewards rune delivery and sends adventurers to investigate the rival expedition.
  - Directs the investigation toward the shrine's inner island.

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
    spawn: [%{map: "hu_in01", x: 14, y: 11, dir: 4, sprite: 70, name: "Laura", scope: :shared}]

  alias Aesir.ZoneServer.Script.Rathena

  @rune_of_darkness 7511
  @old_blue_box 603

  @impl true
  def on_talk(ctx) do
    odin = get_char_var(ctx, :hg_odin, 0)

    cond do
      not Rathena.truthy?(odin) -> eject(ctx)
      odin == 1 -> recruitment(ctx)
      odin > 1 and odin < 6 -> rival_office(ctx)
      odin == 6 -> invite_spying(ctx)
      odin == 12 -> survey_reminder(ctx)
      odin == 13 -> survey_result(ctx)
      odin == 14 -> rune_reminder(ctx)
      odin == 15 -> rune_delivery(ctx)
      odin == 16 -> assign_spying(ctx)
      odin == 17 -> spying_reminder(ctx)
      odin in [18, 19] -> report(ctx)
      odin == 20 -> await_research(ctx)
      true -> ctx
    end
  end

  defp eject(ctx) do
    ctx
    |> cutin("hu_laura02.bmp", 2)
    |> mes("[Laura]")
    |> mes("Hm? What are you doing")
    |> mes("here? Ashe, Ashe! Get")
    |> mes("this person out of here!")
    |> close()
    |> cutin("", 255)
    |> warp("hu_in01", 15, 76)
  end

  defp recruitment(ctx) do
    ctx =
      ctx
      |> cutin("hu_laura04.bmp", 2)
      |> mes("[Laura]")
      |> mes("Hm? Oh, you must be")
      |> mes("here in response to our")
      |> mes("recruitment notice, yes?")

    if base_level(ctx) < 60 do
      ctx
      |> cutin("hu_laura01.bmp", 2)
      |> mes("Let me take a look at you...")
      |> mes("Oh, you're all skin and bone!")
      |> mes("I can't use someone like you.")
      |> close()
      |> cutin("", 255)
    else
      explain_expedition(ctx)
    end
  end

  defp explain_expedition(ctx) do
    ctx =
      ctx
      |> mes("I'm Laura Laurence, the")
      |> mes("Rune-Midgarts Kingdom rep")
      |> mes("for the Odin Shrine Expedition.")
      |> next()
      |> mes("[Laura]")
      |> mes("My assistant, Ashe")
      |> mes("Milton, is right over")
      |> mes("there. Say, 'Hello,' Ashe.")
      |> next()

    {ctx, choice} =
      ctx
      |> emotion(:smile, getnpcid(ctx, "Ashe"))
      |> mes("[Ashe]")
      |> mes("Hello!")
      |> next()
      |> mes("[Laura]")
      |> mes("As you may already know,")
      |> mes("we're here to uncover relics")
      |> mes("from the Odin Shrine. However,")
      |> mes("the shrine is infested with")
      |> mes("powerful creatures that a weak")
      |> mes("woman like me can never defeat.")
      |> next()
      |> cutin("hu_laura01.bmp", 2)
      |> mes("[Laura]")
      |> mes("Would you let a poor")
      |> mes("fragile woman like me go")
      |> mes("in there alone? Someone like")
      |> mes("you must go in there for me.")
      |> mes("Hence, the recruitment notice.")
      |> next()
      |> mes("[Laura]")
      |> mes("Now, we can't actually pay")
      |> mes("you for your work. In fact,")
      |> mes("we have absolutely nothing to")
      |> mes("give you. But you'd be doing")
      |> mes("a great service your country,")
      |> mes("the Rune-Midgarts' Kingdom.")
      |> next()
      |> cutin("hu_laura04.bmp", 2)
      |> mes("[Laura]")
      |> mes("Think about it!")
      |> mes("You'd be making a great")
      |> mes("contribution, helping us")
      |> mes("learn more about the age")
      |> mes("when the gods showed")
      |> mes("themselves to humans!")
      |> next()
      |> select(["Nah, forget it.", "Yes, I'll do it!"])

    case choice do
      1 -> reconsider(ctx)
      2 -> accept_expedition(ctx)
      _ -> ctx
    end
  end

  defp reconsider(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("hu_laura01.bmp", 2)
      |> mes("[Laura]")
      |> mes("W-Wait! Think about")
      |> mes("the importance of learning")
      |> mes("about the age of gods! If you")
      |> mes("don't help us, then who will?")
      |> mes("We need to work together to")
      |> mes("build a better future, right?")
      |> next()
      |> select(["But you can't pay me.", "Alright, I'll do it."])

    if choice == 1 do
      ctx
      |> cutin("hu_laura04.bmp", 2)
      |> mes("[Laura]")
      |> mes("You're right.")
      |> mes("It's like I said")
      |> mes("before. I don't have")
      |> mes("anything to pay you.")
      |> mes("...............................")
      |> next()
      |> cutin("hu_laura01.bmp", 2)
      |> mes("[Laura]")
      |> mes("Curses! If this project had")
      |> mes("more funding, we'd have more")
      |> mes("than a cheesy recruitment ad,")
      |> mes("and some professional staff")
      |> mes("like those rich Schwarzwald")
      |> mes("Republic boys in the next room!")
      |> next()
      |> cutin("hu_laura02.bmp", 2)
      |> mes("[Laura]")
      |> mes("Fine, it's your choice")
      |> mes("whether you want to work")
      |> mes("for us. I'm just disappointed")
      |> mes("that someone like you won't")
      |> mes("help us. I mean, don't you")
      |> mes("have any patriotism at all?")
      |> close()
      |> cutin("hu_laura02.bmp", 255)
    else
      accept_expedition(ctx)
    end
  end

  defp accept_expedition(ctx) do
    ctx
    |> mes("[Laura]")
    |> mes("Perfect! Now, you first")
    |> mes("you need to go to the shrine")
    |> mes("and survey the area for your")
    |> mes("own benefit. Talk to the Boatman, and he'll take you there, okay?")
    |> mes("Hurry up and come back soon!")
    |> set_char_var(:hg_odin, 12)
    |> setquest(11003)
    |> close()
    |> cutin("hu_laura04.bmp", 255)
  end

  defp rival_office(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Excuse me, but")
      |> mes("what are you guys")
      |> mes("doing over here?")
      |> next()
      |> cutin("hu_laura04.bmp", 2)
      |> mes("[Laura]")
      |> mes("What are we doing...?")
      |> mes("This is the shrine expedition")
      |> mes("office. You know, we're doing")
      |> mes("research on the artifacts found")
      |> mes("in the Odin Shrine on behalf")
      |> mes("of the Rune-Midgarts Kingdom.")
      |> next()
      |> select(["About Alex and Julian", "Alright, now I understand."])

    case choice do
      1 ->
        ctx = cutin(ctx, "hu_laura01.bmp", 2)

        ctx =
          ctx
          |> mes("[#{char_name(ctx, 0)}]")
          |> mes("These people in the other")
          |> mes("room, Alex and Julian, are")
          |> mes("they also working in this same")
          |> mes("expedition in the Odin Shrine?")
          |> next()
          |> cutin("hu_laura02.bmp", 2)
          |> mes("[Laura]")
          |> mes("...Oh. You must be working")
          |> mes("for those rich Schwaltvalt")
          |> mes("Republic kids. I can't work")
          |> mes("with that impudent girl, at")
          |> mes("all, so we're actually working")
          |> mes("in separate offices.")
          |> next()
          |> cutin("hu_laura04.bmp", 2)
          |> mes("[Laura]")
          |> mes("Sorry, let me introduce")
          |> mes("myself. I'm Laura Laurence,")
          |> mes("the leader of the Odin Shrine")
          |> mes("expedition for the Rune-Midgarts Kingdom. Ashe Milton is my")
          |> mes("assistant for this excavation.")
          |> next()

        ctx
        |> emotion(:smile, getnpcid(ctx, "Ashe"))
        |> mes("[Ashe]")
        |> mes("Hello!")
        |> next()
        |> mes("[Laura]")
        |> mes("If you'd rather do")
        |> mes("a service for your")
        |> mes("country and quit working")
        |> mes("for those wealthy snobs, then")
        |> mes("come back here and let me know.")
        |> close()
        |> cutin("hu_laura04.bmp", 255)

      2 ->
        ctx
        |> cutin("hu_laura01.bmp", 2)
        |> mes("[Laura]")
        |> mes("......")
        |> mes(".........")
        |> mes("............")
        |> close()
        |> cutin("hu_laura01.bmp", 255)

      _ ->
        ctx
    end
  end

  defp invite_spying(ctx) do
    {ctx, _} =
      ctx
      |> cutin("hu_laura04.bmp", 2)
      |> mes("[Laura]")
      |> mes("Hey, I know you...")
      |> mes("You're a volunteer for the")
      |> mes("other office's expedition,")
      |> mes("right? Your timing couldn't")
      |> mes("be more perfect. Why don't")
      |> mes("you help us for a while?")
      |> next()
      |> cutin("hu_laura01.bmp", 2)
      |> mes("[Laura]")
      |> mes("Basically, I want you")
      |> mes("to spy on that snobby girl,")
      |> mes("Alex of the Schwarzwald")
      |> mes("Republic office, and report")
      |> mes("what she's actually doing to me.")
      |> next()
      |> cutin("hu_laura03.bmp", 2)
      |> mes("[Laura]")
      |> mes("I have to know...")
      |> mes("I need to know whether")
      |> mes("they discovered ''that thing''")
      |> mes("already. They can't have found")
      |> mes("it before us. It's impossible!")
      |> next()
      |> cutin("hu_laura04.bmp", 2)
      |> mes("[Laura]")
      |> mes("Anyway, just eavesdrop")
      |> mes("on the Schwaltvalt Office")
      |> mes("by putting your ear really")
      |> mes("close to the door, and listen")
      |> mes("to them talk. Will you do that?")
      |> next()
      |> cutin("hu_laura02.bmp", 2)
      |> mes("[Laura]")
      |> mes("...............................")
      |> mes("Of course, you're")
      |> mes("going to do it. Right?")
      |> next()
      |> cutin("hu_laura03.bmp", 2)
      |> mes("[Laura]")
      |> mes("RIGHT?!")
      |> next()
      |> select([
        "Yeah, yeah, whatever.",
        "Sure thing.",
        "I s-s-s-suppose...!",
        "Yes, Ma'am!"
      ])

    ctx
    |> set_char_var(:hg_odin, 17)
    |> completequest(11002)
    |> setquest(11006)
    |> cutin("hu_laura04.bmp", 2)
    |> mes("[Laura]")
    |> mes("Good.")
    |> mes("Now do it!")
    |> close()
    |> cutin("hu_laura04.bmp", 255)
  end

  defp survey_reminder(ctx) do
    ctx
    |> cutin("hu_laura02.bmp", 2)
    |> mes("[Laura]")
    |> mes("Ask the Boatman to take")
    |> mes("you to the Odin Shrine so")
    |> mes("that you can actually see it")
    |> mes("for yourself. If you don't think you can handle the expedition,")
    |> mes("then you can just let me know.")
    |> close()
    |> cutin("hu_laura02.bmp", 255)
  end

  defp rune_reminder(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("hu_laura02.bmp", 2)
      |> mes("[Laura]")
      |> mes("Hm? You've got a job")
      |> mes("to do, don't you? What")
      |> mes("are you still doing here?")
      |> next()
      |> select([
        "What was I supposed to gather?",
        "Don't worry, I'm leaving."
      ])

    case choice do
      1 ->
        ctx
        |> mes("[Laura]")
        |> mes("You're supposed")
        |> mes("to bring me ^3355FF5 Runes")
        |> mes("of the Darkness^000000. Now,")
        |> mes("don't forget this time!")
        |> close()
        |> cutin("hu_laura02.bmp", 255)

      2 ->
        ctx
        |> mes("[Laura]")
        |> mes("Well, try to hurry up")
        |> mes("if you can. I'm already")
        |> mes("behind schedule because")
        |> mes("we have to work with those")
        |> mes("snobby rich kids in the")
        |> mes("other office. ^333333*Sigh...*^000000")
        |> close()
        |> cutin("hu_laura02.bmp", 255)

      _ ->
        ctx
    end
  end

  defp spying_reminder(ctx) do
    ctx
    |> cutin("hu_laura02.bmp", 2)
    |> mes("[Laura]")
    |> mes("What are you standing")
    |> mes("around here for? Go and")
    |> mes("eavesdrop on those snobs")
    |> mes("next door! I must know")
    |> mes("what they're really up to!")
    |> close()
    |> cutin("hu_laura02.bmp", 255)
  end

  defp await_research(ctx) do
    ctx
    |> cutin("hu_laura01.bmp", 2)
    |> mes("[Laura]")
    |> mes("I wonder...")
    |> mes("What could be going on?")
    |> mes("Hopefully I'll be able")
    |> mes("to find the answers...")
    |> close()
    |> cutin("hu_laura01.bmp", 255)
  end

  defp survey_result(ctx) do
    {ctx, _} =
      ctx
      |> cutin("hu_laura04.bmp", 2)
      |> mes("[Laura]")
      |> mes("Have you been to the")
      |> mes("Odin Shrine already?")
      |> mes("I know it's scary, but we")
      |> mes("need to finish our research")
      |> mes("for the good of mankind.")
      |> next()
      |> select([
        "Yeah, yeah, whatever.",
        "I see.",
        "You're right, Ma'am."
      ])

    {ctx, finding} =
      ctx
      |> mes("[Laura]")
      |> mes("Well, then.")
      |> mes("Did you happen to")
      |> mes("find anything while")
      |> mes("you were there?")
      |> next()
      |> select(["Jellopies.", "No."])

    ctx =
      case finding do
        1 ->
          ctx
          |> cutin("hu_laura01.bmp", 2)
          |> mes("[Laura]")
          |> mes("You can freakin' find")
          |> mes("Jellopy anywhere! I meant,")
          |> mes("did you find anything special")
          |> mes("while you were at the shrine!")
          |> next()

        2 ->
          ctx
          |> cutin("hu_laura01.bmp", 2)
          |> mes("[Laura]")
          |> mes("Well, that's fine.")
          |> mes("I did tell you to just")
          |> mes("take a look around, so")
          |> mes("I didn't expect you to")
          |> mes("bring me anything.")
          |> next()

        _ ->
          ctx
      end

    if finding in 1..2, do: survey_offer(ctx), else: ctx
  end

  defp survey_offer(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("hu_laura04.bmp", 2)
      |> mes("[Laura]")
      |> mes("Anyway, are you still willing")
      |> mes("to help us? I know that I said")
      |> mes("that we can't pay you, but to")
      |> mes("be fair, I can offer you something from my special collection.")
      |> mes("How does that sound?")
      |> next()
      |> select([
        "Who are the guys in the other room?",
        "Well...",
        "Yes!"
      ])

    case choice do
      1 ->
        ctx =
          ctx
          |> cutin("hu_laura01.bmp", 2)
          |> mes("[Laura]")
          |> mes("Oh, those are the")
          |> mes("Schwarzwald Republic")
          |> mes("representatives for this")
          |> mes("Odin Shrine expedition.")
          |> mes("Personally, I think they're")
          |> mes("just a bunch of rich phonies.")
          |> next()
          |> cutin("hu_laura03.bmp", 2)
          |> mes("[Laura]")
          |> mes("And that Alex girl...")
          |> mes("She may seem polite,")
          |> mes("but she's always giving")
          |> mes("these dirty looks, and")
          |> mes("greets me with a fake")
          |> mes("smile. I hate her!")
          |> next()

        ctx
        |> emotion(:profusely_sweat, getnpcid(ctx, "Ashe"))
        |> mes("[Ashe]")
        |> mes("Ms. Laurence...!")
        |> mes("Stop it, please!")
        |> mes("It's embarassing to")
        |> mes("hear you talk about")
        |> mes("a colleague like that.")
        |> next()
        |> mes("[Laura]")
        |> mes("C-colleague?! No way!")
        |> mes("I despise that spoiled brat,")
        |> mes("and she doesn't deserve the")
        |> mes("position that her rich daddy")
        |> mes("probably bought for her! Grrr!")
        |> mes("Come back later, I'm too mad!")
        |> close()
        |> cutin("hu_laura03.bmp", 255)

      2 ->
        ctx
        |> mes("[Laura]")
        |> mes("If you're having second")
        |> mes("thoughts, it might not be")
        |> mes("the best idea to work for me.")
        |> mes("I mean, I believe in following")
        |> mes("your gut instincts, you know?")
        |> close()
        |> cutin("hu_laura04.bmp", 255)

      3 ->
        ctx
        |> set_char_var(:hg_odin, 14)
        |> changequest(11003, 11004)
        |> mes("[Laura]")
        |> mes("That's what I've been")
        |> mes("waiting to hear! Alright,")
        |> mes("please fetch me ^3355FF5 Runes of")
        |> mes("the Darkness^000000 from the Odin")
        |> mes("Shrine. Go now, adventurer~")
        |> close()
        |> cutin("hu_laura04.bmp", 255)

      _ ->
        ctx
    end
  end

  defp assign_spying(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("hu_laura02.bmp", 2)
      |> mes("[Laura]")
      |> mes("I wonder how much progress")
      |> mes("those pampered Schwarzwald")
      |> mes("snobs actually made. They've")
      |> mes("got the funds, so they could")
      |> mes("actually be further ahead")
      |> mes("than we are right now...")
      |> next()
      |> mes("[Laura]")
      |> mes("I have to know...")
      |> mes("I need to know whether")
      |> mes("they discovered ''that thing''")
      |> mes("already. They can't have found")
      |> mes("it before us. It's impossible!")
      |> next()
      |> cutin("hu_laura01.bmp", 2)
      |> mes("[Laura]")
      |> mes("...Hey, you.")
      |> next()
      |> select(["...", "...Me?"])

    ctx =
      if choice == 1 do
        ctx =
          ctx
          |> mes("[Laura]")
          |> mes("Hey, hey!")
          |> mes("Hey hey hey!")
          |> next()

        ctx
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("...Me?")
        |> next()
      else
        ctx
      end

    {ctx, _} =
      ctx
      |> mes("[Laura]")
      |> mes("Basically, I want you")
      |> mes("to spy on that snobby girl,")
      |> mes("Alex of the Schwarzwald")
      |> mes("Republic office, and report")
      |> mes("what she's actually doing to me.")
      |> next()
      |> cutin("hu_laura04.bmp", 2)
      |> mes("[Laura]")
      |> mes("Anyway, just eavesdrop")
      |> mes("on the Schwaltvalt Office")
      |> mes("by putting your ear really")
      |> mes("close to the door, and listen")
      |> mes("to them talk. Will you do that?")
      |> next()
      |> cutin("hu_laura02.bmp", 2)
      |> mes("[Laura]")
      |> mes("...............................")
      |> mes("Of course, you're")
      |> mes("going to do it. Right?")
      |> next()
      |> cutin("hu_laura03.bmp", 2)
      |> mes("[Laura]")
      |> mes("RIGHT?!")
      |> next()
      |> select([
        "Yeah, yeah, whatever.",
        "Sure thing.",
        "I s-s-s-suppose...!",
        "Yes, Ma'am!"
      ])

    ctx
    |> set_char_var(:hg_odin, 17)
    |> set_local(:i, 11002)
    |> complete_prior_quests()
    |> setquest(11006)
    |> cutin("hu_laura04.bmp", 2)
    |> mes("[Laura]")
    |> mes("Good.")
    |> mes("Now do it!")
    |> close()
    |> cutin("hu_laura04.bmp", 255)
  end

  defp rune_delivery(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("hu_laura04.bmp", 2)
      |> mes("[Laura]")
      |> mes("Oh, you've come back.")
      |> mes("So where are the Runes")
      |> mes("of the Darkness you brought?")
      |> next()
      |> select(["Er, I don't have them yet...", "Right here!"])

    case choice do
      1 -> not_ready(ctx)
      2 -> inspect_runes(ctx)
      _ -> ctx
    end
  end

  defp not_ready(ctx) do
    ctx
    |> cutin("hu_laura03.bmp", 2)
    |> mes("[Laura]")
    |> mes("This isn't really one")
    |> mes("of those jobs where you")
    |> mes("can take your time. Sure, I didn't give you a deadline, but")
    |> mes("we can't make progress on our research until you make progress.")
    |> close()
    |> cutin("hu_laura03.bmp", 255)
  end

  defp inspect_runes(ctx) do
    runes = count_item(ctx, @rune_of_darkness)

    cond do
      runes > 4 -> accept_runes(ctx)
      not Rathena.truthy?(runes) -> no_runes(ctx)
      runes == 1 -> one_rune(ctx)
      runes == 2 -> two_runes(ctx)
      true -> few_runes(ctx)
    end
  end

  defp accept_runes(ctx) do
    ctx
    |> delitem(@rune_of_darkness, 5)
    |> set_char_var(:hg_odin, 16)
    |> changequest(11004, 11005)
    |> give_item(@old_blue_box, 1)
    |> mes("[Laura]")
    |> mes("Oooh, nice job. It's good")
    |> mes("that we have more of these")
    |> mes("to study. Though, it seems")
    |> mes("that the more we research,")
    |> mes("the quicker it seems that")
    |> mes("we're not getting anywhere...")
    |> next()
    |> mes("[Laura]")
    |> mes("Hey...")
    |> mes("Ashe. Why aren't we")
    |> mes("making any progress?")
    |> mes("What exactly have you")
    |> mes("been doing? None of those")
    |> mes("runes have any writing?")
    |> next()
    |> mes("[Ashe]")
    |> mes("Well, I think there's")
    |> mes("supposed to be writing,")
    |> mes("but these runes are pretty")
    |> mes("old. I've got to polish this")
    |> mes("gunk off without damaging")
    |> mes("any writing that's there...")
    |> next()
    |> cutin("hu_laura01.bmp", 2)
    |> mes("[Laura]")
    |> mes("By the way, what have the other guys been doing?")
    |> mes("What, they don't do anything but wasting their time?")
    |> mes("Ah~ I see. They are thinking that this is the perfect excuse")
    |> mes("for them to relax and rest.")
    |> mes("Well, somehow they are the citizens of this country, you know.")
    |> next()
    |> cutin("hu_laura02.bmp", 2)
    |> mes("[Laura]")
    |> mes("What do you think those")
    |> mes("Schwarzwald snobs are doing?")
    |> mes("They must think this project")
    |> mes("is an excuse for them to relax")
    |> mes("and slack off! They can afford to, obviously. Hmpf! Rich people!")
    |> next()
    |> cutin("hu_laura03.bmp", 2)
    |> mes("[Laura]")
    |> mes("They've got things so easy,")
    |> mes("while we're barely covering")
    |> mes("our research expenses!")
    |> mes("In fact, we've had to cut")
    |> mes("so many corners, skip")
    |> mes("meals and amenities...")
    |> next()
    |> mes("[Ashe]")
    |> mes("I know! How can we")
    |> mes("carry on professional")
    |> mes("research in a shack?")
    |> mes("We're literally living at")
    |> mes("poverty standards here...")
    |> mes("Are we still researchers?")
    |> next()
    |> cutin("hu_laura02.bmp", 2)
    |> mes("[Laura]")
    |> mes("I know that!")
    |> mes("I know that already!")
    |> mes("S-stop bringing it up!")
    |> next()
    |> cutin("hu_laura01.bmp", 2)
    |> mes("[Laura]")
    |> mes("This is pathetic.")
    |> mes("I can't even afford the")
    |> mes("energy to continue this")
    |> mes("conversation. You too,")
    |> mes("why don't you take a rest?")
    |> close()
    |> cutin("hu_laura01.bmp", 255)
  end

  defp no_runes(ctx) do
    ctx
    |> cutin("hu_laura02.bmp", 2)
    |> mes("[Laura]")
    |> mes("..................")
    |> mes("What is this?!")
    |> mes("You're supposed to")
    |> mes("bring me 5 of them!")
    |> next()
    |> cutin("hu_laura03.bmp", 2)
    |> mes("[Laura]")
    |> mes("Is this your way of")
    |> mes("saying that you don't")
    |> mes("want to work for us?")
    |> mes("Why don't you say it")
    |> mes("to my face, eh?")
    |> next()
    |> mes("[Ashe]")
    |> mes("Ms. Laurence, please,")
    |> mes("calm down! We're in no")
    |> mes("position to yell at anyone,")
    |> mes("especially volunteers! You")
    |> mes("of all people should know")
    |> mes("that they're doing us a favor!")
    |> next()
    |> cutin("hu_laura02.bmp", 2)
    |> mes("[Laura]")
    |> mes("Okay, Ashe, I get it!")
    |> mes("And as for you, I'll give")
    |> mes("you another chance. Next")
    |> mes("time you see me, bring")
    |> mes("5 Runes of the Darkness!")
    |> close()
    |> cutin("hu_laura02.bmp", 255)
  end

  defp one_rune(ctx) do
    ctx
    |> cutin("hu_laura03.bmp", 2)
    |> mes("[Laura]")
    |> mes("...Only one?")
    |> mes("Look at me. I asked")
    |> mes("you for five. I know that")
    |> mes("one is better than nothing...")
    |> mes("But it's pretty darn close. Go")
    |> mes("get me 4 more this instant!")
    |> close()
    |> cutin("hu_laura03.bmp", 255)
  end

  defp two_runes(ctx) do
    ctx
    |> cutin("hu_laura03.bmp", 2)
    |> mes("[Laura]")
    |> mes("One, two...")
    |> mes("Huh? Th-that's all?!")
    |> mes("When I ask for 5 Runes")
    |> mes("of the Darkness, I mean")
    |> mes("5, not 2. Now hurry up")
    |> mes("and just do what I asked!")
    |> close()
    |> cutin("hu_laura03.bmp", 255)
  end

  defp few_runes(ctx) do
    ctx
    |> mes("[Laura]")
    |> mes("One, two, three...")
    |> mes("That's it? Don't you")
    |> mes("know how to count to 5?")
    |> mes("Go and get me more of those")
    |> mes("Runes of the Darkness now!")
    |> next()
    |> cutin("hu_laura03.bmp", 2)
    |> close()
    |> cutin("hu_laura03.bmp", 255)
  end

  defp report(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("hu_laura01.bmp", 2)
      |> mes("[Laura]")
      |> mes("Frankly, I know I'm paying")
      |> mes("you nothing to be spy, but")
      |> mes("please tell me what you")
      |> mes("learned about the Schwarzwald")
      |> mes("Republic Research Team.")
      |> next()
      |> select([
        "Giantes",
        "Ymir's Heart",
        "Nothing"
      ])

    case choice do
      1 -> report_giantes(ctx)
      2 -> report_ymir(ctx)
      3 -> report_nothing(ctx)
      _ -> ctx
    end
  end

  defp report_giantes(ctx) do
    ctx = cutin(ctx, "hu_laura04.bmp", 2)

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("I'm guessing that you're")
      |> mes("already familiar with the")
      |> mes("creature known as Giantes")
      |> mes("since you're an archaeologist.")
      |> next()
      |> cutin("hu_laura02.bmp", 2)
      |> mes("[Laura]")
      |> mes("Of course! It's an")
      |> mes("ancient beast on which")
      |> mes("the Guardians were inspired.")
      |> mes("N-no way...! Are they here to")
      |> mes("finish their guardian research?")
      |> mes("What else did you learn?")
      |> next()

    report_ymir(ctx)
  end

  defp report_ymir(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Well, have you")
      |> mes("ever heard of Ymir's...")
      |> next()

    {ctx, answer} =
      ctx
      |> emotion(:surprise, getnpcid(ctx, "Ashe"))
      |> mes("[Ashe]")
      |> mes("...Heart?")
      |> mes("Ymir's Heart, right?")
      |> next()
      |> mes("[Laura]")
      |> mes("Ashe, you know about")
      |> mes("this? What exactly")
      |> mes("is Ymir's Heart?")
      |> next()
      |> select([
        "It's candy.",
        "It's a book.",
        "It's a place.",
        "Ymir was a giant..."
      ])

    ctx =
      case answer do
        1 ->
          ctx
          |> mes("[#{char_name(ctx, 0)}]")
          |> mes("It's this...")
          |> mes("Um, really...")
          |> next()

        2 ->
          ctx
          |> mes("[#{char_name(ctx, 0)}]")
          |> mes("Er, you see...")
          |> mes("A lot of people know")
          |> mes("about Ymir's Heart...")
          |> next()

        3 ->
          ctx
          |> mes("[#{char_name(ctx, 0)}]")
          |> mes("You know the expression,")
          |> mes("''Home is where the heart")
          |> mes("is?'' Er, well, Ymir's Heart...")
          |> next()

        4 ->
          ctx
          |> mes("[#{char_name(ctx, 0)}]")
          |> mes("The truth is,")
          |> mes("Ymir was this giant...")
          |> next()

        _ ->
          ctx
      end

    if answer in 1..4, do: inner_island(ctx), else: ctx
  end

  defp inner_island(ctx) do
    ctx
    |> emotion(:ok, getnpcid(ctx, "Ashe"))
    |> mes("[Ashe]")
    |> mes("Ymir's Heart?")
    |> mes("That's a clothing")
    |> mes("brand, isn't it? Yeah,")
    |> mes("it's popular amongst")
    |> mes("the trendy crowd in the")
    |> mes("Schwarzwald Republic.")
    |> next()
    |> cutin("hu_laura01.bmp", 2)
    |> mes("[Laura]")
    |> mes("Clothing brand?")
    |> mes("You mean those snobs")
    |> mes("are just spending their")
    |> mes("time talking about fashion")
    |> mes("in there? Huh. Don't they")
    |> mes("have better things to do?")
    |> next()
    |> cutin("hu_laura04.bmp", 2)
    |> mes("[Laura]")
    |> mes("In the meantime, would")
    |> mes("you do one more favor for")
    |> mes("me? I'd like you to go to")
    |> mes("the shrine one last time.")
    |> mes("I hear that it's built on")
    |> mes("two connected islands...")
    |> next()
    |> mes("[Laura]")
    |> mes("I want you to check the")
    |> mes("inner island, and see")
    |> mes("what you can find while")
    |> mes("I investigate the Schwarzwald")
    |> mes("Research Team. I'm sorry, but")
    |> mes("you're the only one I can ask.")
    |> set_char_var(:hg_odin, 20)
    |> changequest(11006, 11007)
    |> close()
    |> cutin("hu_laura04.bmp", 255)
  end

  defp report_nothing(ctx) do
    ctx
    |> mes("[Laura]")
    |> mes("Nothing...?")
    |> mes("Are you sure that's")
    |> mes("all you learned?")
    |> close()
    |> cutin("hu_laura01.bmp", 255)
  end

  defp complete_prior_quests(ctx) do
    Enum.reduce(11002..11005, ctx, fn quest, ctx ->
      ctx =
        if checkquest(ctx, quest) > -1 and checkquest(ctx, quest) < 2 do
          completequest(ctx, quest)
        else
          ctx
        end

      set_local(ctx, :i, quest + 1)
    end)
  end
end
