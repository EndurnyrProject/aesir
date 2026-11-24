defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Alex do
  @moduledoc """
  Alex supervises the Odin Shrine expedition and recruits adventurers.

  ## Behavior

  - Recruits qualified adventurers and asks them to survey the shrine.
  - Requests five Runes of Darkness and rewards their delivery.
  - Discusses the rival expedition as the quest progresses.

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
    spawn: [%{map: "hu_in01", x: 19, y: 161, dir: 0, sprite: 803, name: "Alex", scope: :shared}]

  alias Aesir.ZoneServer.Script.Rathena

  @rune_of_darkness 7511
  @old_blue_box 603

  @impl true
  def on_talk(ctx) do
    odin = get_char_var(ctx, :hg_odin, 0)

    cond do
      not Rathena.truthy?(odin) -> dismiss(ctx)
      odin == 1 -> recruitment(ctx)
      odin == 2 -> survey_reminder(ctx)
      odin == 3 -> expedition_offer(ctx)
      odin == 4 -> rune_reminder(ctx)
      odin == 5 -> rune_delivery(ctx)
      odin == 6 -> research(ctx)
      odin > 11 and odin < 17 -> rival_expedition(ctx)
      true -> busy(ctx)
    end
  end

  defp dismiss(ctx) do
    ctx
    |> mes("[Alex]")
    |> mes("Whatever you're")
    |> mes("trying to sell me,")
    |> mes("I'm not interested!")
    |> mes("Now get out of here!")
    |> close()
  end

  defp recruitment(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("hu_alex01.bmp", 2)
      |> mes("[Alex]")
      |> mes("Huh...?")
      |> mes("What do you want?")
      |> next()
      |> select(["Excuse me...", "I saw the recruitment notice and..."])

    case choice do
      1 ->
        ctx
        |> mes("[Alex]")
        |> mes("Whatever you're")
        |> mes("trying to sell me,")
        |> mes("I'm not interested!")
        |> mes("Now get out of here!")
        |> close()
        |> cutin("", 255)

      2 ->
        qualify(ctx)

      _ ->
        ctx
    end
  end

  defp qualify(ctx) do
    ctx =
      ctx
      |> mes("[Alex]")
      |> mes("Oh, so you saw the")
      |> mes("recruitment notice for the")
      |> mes("Odin Shrine Expedition, eh?")

    if base_level(ctx) > 59 do
      ctx
      |> mes("Hmmm... Alright, you look")
      |> mes("like you're strong enough.")
      |> mes("Yeah, I think you qualify.")
      |> next()
      |> cutin("hu_alex03.bmp", 2)
      |> mes("[Alex]")
      |> mes("I'm Alex Helmut, and I'm")
      |> mes("in charge of the expedition.")
      |> mes("See that guy over there? That's")
      |> mes("my younger brother Julian who's")
      |> mes("also working on the excavation.")
      |> next()
      |> mes("[Alex]")
      |> mes("Our main goal in this")
      |> mes("excavation is to retrieve")
      |> mes("some extremely valuable")
      |> mes("item inside the shrine. However, it's too dangerous to go in there")
      |> mes("if you're not strong enough.")
      |> next()
      |> mes("[Alex]")
      |> mes("Anyway, if you'd like to")
      |> mes("help us, please take a look")
      |> mes("around the shrine and see")
      |> mes("if you'd want to work for us.")
      |> mes("Please talk to the Boatman")
      |> mes("to travel to the shrine, okay?")
      |> set_char_var(:hg_odin, 2)
      |> setquest(11000)
      |> close()
      |> cutin("", 255)
    else
      ctx
      |> cutin("hu_alex02.bmp", 2)
      |> mes("Well, I dunno. I think that")
      |> mes("kind of expedition would")
      |> mes("eat you alive. No offense...")
      |> next()
      |> mes("[Alex]")
      |> mes("Look, I'll reconsider")
      |> mes("whether you qualify after")
      |> mes("you get train a little more,")
      |> mes("develop your skills, you know,")
      |> mes("get stronger. For now, though,")
      |> mes("I don't think we can use you.")
      |> close()
      |> cutin("", 255)
    end
  end

  defp survey_reminder(ctx) do
    ctx
    |> cutin("hu_alex03.bmp", 2)
    |> mes("[Alex]")
    |> mes("You really oughtta")
    |> mes("check out the shrine")
    |> mes("for yourself first. Just talk")
    |> mes("to the Boatman so that")
    |> mes("he take you over there.")
    |> close()
    |> cutin("", 255)
  end

  defp expedition_offer(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("hu_alex01.bmp", 2)
      |> mes("[Alex]")
      |> mes("Oh, so you've gone")
      |> mes("and seen the shrine")
      |> mes("already. So will you help")
      |> mes("us in our expedition?")
      |> next()
      |> select(["Who are the people in the next room?", "Well...", "Yes, I do."])

    case choice do
      1 ->
        ctx
        |> cutin("hu_alex02.bmp", 2)
        |> mes("[Alex]")
        |> mes("Oh... Them.")
        |> mes("They're officially my")
        |> mes("co-workers, but quite")
        |> mes("frankly, they were forced")
        |> mes("upon me by the Rune-Midgarts")
        |> mes("Kingdom. It can't be helped...")
        |> next()
        |> mes("[Alex]")
        |> mes("Anyway, I have to accept")
        |> mes("them to help international")
        |> mes("relations or something silly")
        |> mes("like that. They say they're here to research religious relics,")
        |> mes("but I just don't trust them.")
        |> next()
        |> cutin("hu_alex04.bmp", 2)
        |> mes("[Alex]")
        |> mes("In fact, I think it's")
        |> mes("obvious that they're here")
        |> mes("for something else, though")
        |> mes("I'm not sure what it may be.")
        |> mes("And that gray haired lady...")
        |> mes("She totally creeps me out!")
        |> close()
        |> cutin("", 255)

      2 ->
        ctx
        |> mes("[Alex]")
        |> mes("Yeah, well, I know")
        |> mes("it might be a tough")
        |> mes("decision to make. Well,")
        |> mes("take your time. I understand")
        |> mes("that you have to weigh the")
        |> mes("risks and everything.")
        |> close()
        |> cutin("", 255)

      3 ->
        ctx
        |> mes("[Alex]")
        |> mes("Great! In that case, your")
        |> mes("first assignment is to bring")
        |> mes("me ^3355FF5 Runes of the Darkness^000000")
        |> mes("from the shrine. Don't worry,")
        |> mes("I'll make sure that you're")
        |> mes("rewarded for your efforts.")
        |> set_char_var(:hg_odin, 4)
        |> changequest(11000, 11001)
        |> next()
        |> mes("[Alex]")
        |> mes("This is your chance")
        |> mes("to show me that your")
        |> mes("dependability and sense")
        |> mes("of responsibility. Then,")
        |> mes("we can move on to the")
        |> mes("more important stuff.")
        |> close()
        |> cutin("", 255)

      _ ->
        ctx
    end
  end

  defp rune_reminder(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("hu_alex02.bmp", 2)
      |> mes("[Alex]")
      |> mes("What are you still")
      |> mes("doing here? Shouldn't")
      |> mes("you be headed to the")
      |> mes("shrine already?")
      |> next()
      |> select(["What was I supposed to gather?", "I'm leaving, I'm leaving!"])

    case choice do
      1 ->
        ctx
        |> cutin("hu_alex03.bmp", 2)
        |> mes("[Alex]")
        |> mes("You've forgotten")
        |> mes("already? I asked you")
        |> mes("to bring me ^3355FF5 Runes")
        |> mes("of the Darkness^000000. Okay,")
        |> mes("now hurry up and get to it.")
        |> close()
        |> cutin("", 255)

      2 ->
        ctx
        |> mes("[Alex]")
        |> mes("That's fine...")
        |> mes("Just keep in mind that")
        |> mes("we're running behind")
        |> mes("schedule. If only that")
        |> mes("grey haired crone wasn't")
        |> mes("here... We'd be done by now!")
        |> close()
        |> cutin("", 255)

      _ ->
        ctx
    end
  end

  defp rune_delivery(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("hu_alex01.bmp", 2)
      |> mes("[Alex]")
      |> mes("Well, it's about")
      |> mes("time you came back.")
      |> mes("So did you bring me")
      |> mes("^3355FF5 Runes of the Darkness^000000?")
      |> next()
      |> select(["Er, not yet...", "There you go!"])

    case choice do
      1 ->
        ctx =
          ctx
          |> cutin("hu_alex02.bmp", 2)
          |> mes("[Alex]")
          |> mes("Wh-what?!")
          |> mes("You came here just to")
          |> mes("tell me that? Come back")
          |> mes("when you're done and")
          |> mes("don't waste my time!")
          |> next()

        ctx
        |> emotion(:delight, getnpcid(ctx, "Julian"))
        |> mes("[Julian]")
        |> mes("Hey, you know what,")
        |> mes("Alex? You can't push")
        |> mes("people around like that.")
        |> mes("Besides, this adventurer")
        |> mes("isn't a pushover, you know?")
        |> next()
        |> cutin("hu_alex03.bmp", 2)
        |> emotion(:fret)
        |> mes("[Alex]")
        |> mes("What was that...?")
        |> mes("Are you trying to")
        |> mes("make me mad, Julian?")
        |> next()
        |> cutin("hu_alex02.bmp", 2)
        |> mes("[Julian]")
        |> mes("All I'm saying is that")
        |> mes("most adventurers know that")
        |> mes("you can't pay them what they're")
        |> mes("worth. That's why so many of")
        |> mes("them are going in and out")
        |> mes("of the other room, you know.")
        |> next()
        |> cutin("hu_alex04.bmp", 2)
        |> mes("[Alex]")
        |> mes("That... grey... haired...!")
        |> mes("N-no... Calm down, Alex...")
        |> mes("Lose your head, you lose")
        |> mes("everything... D-don't stoop")
        |> mes("down to her level.")
        |> next()
        |> cutin("hu_alex01.bmp", 2)
        |> mes("[Alex]")
        |> mes("Alright, I'm not in any")
        |> mes("position to make demands")
        |> mes("of you... But I would really")
        |> mes("appreciate it if you would")
        |> mes("bring me 5 Runes of the")
        |> mes("Darkness as soon as possible.")
        |> close()
        |> cutin("", 255)

      2 ->
        if count_item(ctx, @rune_of_darkness) > 4 do
          ctx
          |> delitem(@rune_of_darkness, 5)
          |> set_char_var(:hg_odin, 6)
          |> changequest(11001, 11002)
          |> give_item(@old_blue_box, 1)
          |> mes("[Alex]")
          |> mes("Oh! Thank you")
          |> mes("so much, I'm sure")
          |> mes("these Runes will help")
          |> mes("us in our research. I know")
          |> mes("this isn't much, but please")
          |> mes("accept this Old Blue Box.")
          |> next()
          |> mes("[Julian]")
          |> mes("Wait...")
          |> mes("Research?")
          |> mes("Since when did")
          |> mes("you do research?")
          |> next()
          |> cutin("hu_alex03.bmp", 2)
          |> mes("[Alex]")
          |> mes("Gosh, Julian,")
          |> mes("will you just")
          |> mes("shut up for a bit?")
          |> next()
          |> mes("[Julian]")
          |> mes("Why? I'm the one who")
          |> mes("does all the grunt work")
          |> mes("and actual research.")
          |> mes("You think you're so")
          |> mes("big just ''supervising...''")
          |> next()
          |> cutin("hu_alex04.bmp", 2)
          |> mes("[Alex]")
          |> mes("J-Julian!")
          |> next()
          |> mes("[Julian]")
          |> mes("Right, right, we've")
          |> mes("got a visitor. Yeah,")
          |> mes("okay, sorry about that.")
          |> next()
          |> cutin("hu_alex02.bmp", 2)
          |> mes("[Alex]")
          |> mes("I'm sorry about all")
          |> mes("this. If you don't mind,")
          |> mes("we'll continue our research")
          |> mes("and hopefully finish our")
          |> mes("project soon. Thanks once")
          |> mes("again for all of your help.")
          |> close()
          |> cutin("", 255)
        else
          ctx
          |> cutin("hu_alex02.bmp", 2)
          |> mes("[Alex]")
          |> mes("Hm? Oh, this isn't")
          |> mes("enough Runes of the")
          |> mes("Darkness. I asked you")
          |> mes("to bring me 5 of them...")
          |> close()
          |> cutin("", 255)
        end

      _ ->
        ctx
    end
  end

  defp research(ctx) do
    ctx
    |> cutin("hu_alex02.bmp", 2)
    |> mes("[Alex]")
    |> mes("...Darn it! I think I might")
    |> mes("have miscalculated. Maybe")
    |> mes("I really do need more of")
    |> mes("these. What am I gonna do?")
    |> mes("And what is that grey haired")
    |> mes("crone thinking? Hmmmm...")
    |> next()
    |> emotion(:huk)
    |> cutin("hu_alex03.bmp", 2)
    |> cutin("hu_alex01.bmp", 2)
    |> mes("[Alex]")
    |> mes("O-Oh! I had no idea that")
    |> mes("you were there! Y-you")
    |> mes("didn't hear anything")
    |> mes("s-strange, did you?")
    |> mes("Hahahahahahaha!")
    |> close()
    |> cutin("", 255)
  end

  defp rival_expedition(ctx) do
    ctx
    |> cutin("hu_alex03.bmp", 2)
    |> mes("[Alex]")
    |> mes("Excuse me?")
    |> mes("The grey haired crone")
    |> mes("offered you a part time")
    |> mes("job, but won't pay you?")
    |> next()
    |> mes("[Alex]")
    |> mes("She's really shameless!")
    |> mes("We don't have much to pay")
    |> mes("volunteers, but we should")
    |> mes("at least give them something!")
    |> mes("How can she do this?! Oh, er,")
    |> mes("let me introduce myself first.")
    |> next()
    |> cutin("hu_alex01.bmp", 2)
    |> mes("[Alex]")
    |> mes("I'm Alex Helmut, and I'm")
    |> mes("in charge of the expedition.")
    |> mes("See that guy over there? That's")
    |> mes("my younger brother Julian who's")
    |> mes("also working on the excavation.")
    |> next()
    |> cutin("hu_alex02.bmp", 2)
    |> mes("[Alex]")
    |> mes("As supervisor of this")
    |> mes("operation, I'm ashamed to")
    |> mes("say that the excavation is")
    |> mes("proceeding behind schedule.")
    |> mes("If only that grey haired crone")
    |> mes("in the next room weren't here!")
    |> next()
    |> mes("[Alex]")
    |> mes("I can't work with")
    |> mes("her at all! She's")
    |> mes("manipulative, greedy,")
    |> mes("selfish, and two faced!")
    |> mes("There's got to be another")
    |> mes("reason why she's here...!")
    |> close()
    |> cutin("", 255)
  end

  defp busy(ctx) do
    ctx
    |> cutin("hu_alex02.bmp", 2)
    |> mes("[Alex]")
    |> mes("Hm? Did you need")
    |> mes("something? I'm sorry,")
    |> mes("but I can't help you")
    |> mes("right now. I'm pretty")
    |> mes("busy, so I just want to")
    |> mes("be left alone for a while.")
    |> close()
    |> cutin("", 255)
  end
end
