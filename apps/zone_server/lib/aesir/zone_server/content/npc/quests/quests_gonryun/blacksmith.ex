defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsGonryun.Blacksmith do
  @moduledoc """
  Aumgarl, a blacksmith in Geffen, repairs SaYumMoon's broken sword in the Broken Sword quest
  once the player has helped cure his granddaughter Lyroo.

  ## Behavior

  - Before the quest reaches him, he only sobs over Lyroo.
  - On first contact he says the shop is closed and sends the player away; asking about the
    sword advances the quest, and each later visit warps the player out to Geffen until he
    randomly (1 in 8) gives in and hears the player out.
  - Asking about his granddaughter leads to her illness; agreeing to find someone who can cure
    her advances the quest, while the wrong answers end the talk (claiming to be a doctor also
    warps the player out).
  - While the cure is under way he points the player to crowded places, then upstairs to Lyroo.
  - Once Lyroo is cured he offers to return the favor and asks for 1 Anvil, 2 Rough Oridecons,
    5 Broken Swords, 2 Steel, 1 Hammer of Blacksmith, 2 Star Crumbs and 5 Live Coals; with all
    of them he takes them and starts the repair.
  - Each later visit has a 1 in 5 chance that the repair is done, giving the player
    SaYumMoon's sword (Haedonggum).
  - After the quest he thanks the player.

  ## Credits

  - Original from rAthena, authors and Contributors
    - KarLaeda
    - L0ne_W0lf
    - Paradox924X

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "geffen_in",
        x: 71,
        y: 112,
        dir: 2,
        sprite: 731,
        name: "Blacksmith",
        scope: :shared,
        unique_name: "Blacksmith#SaYumMoon"
      }
    ]

  @anvil 986
  @rough_oridecon 756
  @broken_sword 7110
  @steel 999
  @hammer_of_blacksmith 1005
  @star_crumb 1000
  @live_coal 7098
  @haedonggum 1123

  @materials [
    {@anvil, 1},
    {@rough_oridecon, 2},
    {@broken_sword, 5},
    {@steel, 2},
    {@hammer_of_blacksmith, 1},
    {@star_crumb, 2},
    {@live_coal, 5}
  ]

  @impl true
  def on_talk(ctx) do
    b_sword = get_char_var(ctx, :b_sword, 0)

    cond do
      b_sword < 17 -> sobs(ctx)
      b_sword < 32 -> by_progress(ctx, b_sword)
      true -> thanks(ctx)
    end
  end

  defp sobs(ctx) do
    ctx
    |> mes("[Aumgarl]")
    |> mes("*Sob*..*sob*....")
    |> mes("My poor baby Lyroo..")
    |> mes("*Sniff*...")
    |> close()
  end

  defp thanks(ctx) do
    ctx
    |> mes("[Aumgarl]")
    |> mes("Thank you...")
    |> mes("You've been a great help")
    |> mes("to us. I hope my work")
    |> mes("has been of some use to you.")
    |> close()
  end

  defp by_progress(ctx, 17) do
    {ctx, choice} =
      ctx
      |> mes("[Aumgarl]")
      |> mes("*Sob*...")
      |> mes("My poor baby Lyroo..")
      |> mes("*Sniff*...")
      |> next()
      |> select(["Sir...?", "..........."])

    if choice == 1 do
      asks_who_you_are(ctx)
    else
      ctx
      |> mes("[Aumgarl]")
      |> mes("If you have nothing to say to me,")
      |> mes("then please leave me alone.")
      |> close()
    end
  end

  defp by_progress(ctx, 18) do
    ctx =
      ctx
      |> mes("[Aumgarl]")
      |> mes("Like I said, we're closed!")
      |> mes("Come back later.")

    ctx =
      if Enum.random(1..8) == 7 do
        ctx |> set_char_var(:b_sword, 19) |> mes("Didn't you hear me?! Sheesh!")
      else
        ctx
      end

    ctx |> close() |> warp("geffen", 173, 169)
  end

  defp by_progress(ctx, 19) do
    {ctx, choice} =
      ctx
      |> mes("[Aumgarl]")
      |> mes("Hmm...")
      |> mes("You're a persistent one!!")
      |> mes("What is it that you want?")
      |> next()
      |> select([
        "I want to marry your granddaughter.",
        "Your granddaughter is such a pretty girl.",
        "I came to repair the sword."
      ])

    case choice do
      1 -> rejects_marriage(ctx, "Get the hell out of here!")
      2 -> praises_granddaughter(ctx)
      3 -> too_tired(ctx)
      _ -> ctx
    end
  end

  defp by_progress(ctx, b_sword) when b_sword in 20..23 do
    ctx
    |> mes("[Aumgarl]")
    |> mes("Hmmm...")
    |> mes("Why don't you try looking")
    |> mes("someplace that's always")
    |> mes("crowded with people. I'm")
    |> mes("sure there must be someone")
    |> mes("out there who knows...")
    |> close()
  end

  defp by_progress(ctx, b_sword) when b_sword in 24..26 do
    ctx
    |> mes("[Aumgarl]")
    |> mes("Ahh...")
    |> mes("Lyroo is upstairs...")
    |> mes("Bue she's in pain.")
    |> mes("Try not to talk to her")
    |> mes("for too long.")
    |> close()
  end

  defp by_progress(ctx, 27) do
    ctx
    |> mes("[Aumgarl]")
    |> mes("Oh my...")
    |> mes("Thank you...")
    |> mes("I never thought you'd")
    |> mes("really help me.")
    |> mes("Go ahead and see Lyroo.")
    |> close()
  end

  defp by_progress(ctx, 28) do
    {ctx, choice} =
      ctx
      |> mes("[Aumgarl]")
      |> mes("Thank you so much...")
      |> mes("Without your help...")
      |> emotion(:cry)
      |> mes("it would have been hopeless.")
      |> next()
      |> mes("[Aumgarl]")
      |> mes("Alright....")
      |> mes("Is there anything I can")
      |> mes("do for you? I want to")
      |> mes("return your favor somehow.")
      |> next()
      |> select(["No...I don't need anything.", "Would you repair the sword for me?"])

    case choice do
      1 ->
        ctx
        |> mes("[Aumgarl]")
        |> mes("Hmm...")
        |> mes("Whenever you have a favor to ask,")
        |> mes("come and find me. I'll do")
        |> mes("my best to help you.")
        |> set_char_var(:b_sword, 29)
        |> close()

      2 ->
        examines_sword_after_cure(ctx)

      _ ->
        ctx
    end
  end

  defp by_progress(ctx, 29) do
    {ctx, choice} =
      ctx
      |> mes("[Aumgarl]")
      |> mes("Oh~ It's you.")
      |> mes("Got any favors to ask?")
      |> mes("I'll do my best")
      |> mes("to help you.")
      |> next()
      |> select(["Maybe next time...", "Please repair this sword for me."])

    case choice do
      1 ->
        ctx
        |> mes("[Aumgarl]")
        |> mes("Well...")
        |> mes("If you ever have a favor to")
        |> mes("ask, come and find me.")
        |> close()

      2 ->
        examines_sword_on_return(ctx)

      _ ->
        ctx
    end
  end

  defp by_progress(ctx, 30) do
    if has_materials?(ctx) do
      ctx
      |> mes("[Aumgarl]")
      |> mes("Oh, good! You got them all.")
      |> mes("Alright, come back later,")
      |> mes("and I'll have it repaired.")
      |> take_materials()
      |> set_char_var(:b_sword, 31)
      |> close()
    else
      ctx
      |> mes("[Aumgarl]")
      |> mes("Hmm.....")
      |> mes("Haven't found everything yet?")
      |> mes("Here's the list again-")
      |> next()
      |> material_list("1")
      |> mes("[Aumgarl]")
      |> mes("Wrote them down?")
      |> mes("I've almost found the other materials.")
      |> close()
    end
  end

  defp by_progress(ctx, 31) do
    if Enum.random(1..5) == 2 do
      ctx
      |> mes("[Aumgarl]")
      |> mes("Hey, you're back.")
      |> mes("Here it is! This sword")
      |> mes("is a great one, for")
      |> mes("sure. I noticed that at")
      |> mes("first sight.")
      |> mes("Indeed...")
      |> next()
      |> mes("[Aumgarl]")
      |> mes("I haven't seen quality")
      |> mes("of this magnitude in a")
      |> mes("in a long time.")
      |> mes("I envy you...")
      |> mes("Hehehe......")
      |> next()
      |> mes("'You received repaired")
      |> mes("'^FF0000SaYumMoon's sword^000000'.")
      |> set_char_var(:b_sword, 32)
      |> give_item(@haedonggum, 1)
      |> close()
    else
      ctx
      |> mes("[Aumgarl]")
      |> mes("Umm... it's not done yet.")
      |> mes("Would you give me a little")
      |> mes("bit more time? It's taking")
      |> mes("longer than I thought. Sorry.")
      |> close()
    end
  end

  defp asks_who_you_are(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Aumgarl]")
      |> mes("Hmm...Who are you?")
      |> mes("Do you need something?")
      |> mes("If not, please leave...")
      |> next()
      |> select(["I came to repair this sword.", "I heard you are a famous blacksmith..."])

    if choice == 1 do
      ctx
      |> mes("[Aumgarl]")
      |> mes("Umm...")
      |> mes("I'm sorry, but we're closed.")
      |> mes("Come again another time.")
      |> mes("Goodbye.")
      |> set_char_var(:b_sword, 18)
      |> close()
    else
      ctx
      |> mes("[Aumgarl]")
      |> mes("Yes, I am a blacksmith,")
      |> mes("but I don't think I'm famous.")
      |> mes("And unfortunately, we're closed right now.")
      |> close()
    end
  end

  defp rejects_marriage(ctx, insult) do
    ctx
    |> mes("[Aumgarl]")
    |> mes(".....")
    |> mes(".........")
    |> mes(".............")
    |> mes("...................")
    |> mes("........................")
    |> next()
    |> mes("[Aumgarl]")
    |> mes("Who the heck are you?")
    |> mes("What do you want with my")
    |> mes("granddaughter all of a sudden!?")
    |> mes(insult)
    |> mes("Don't ever come back here again!")
    |> emotion(:hng)
    |> close()
  end

  defp praises_granddaughter(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Aumgarl]")
      |> mes("You're darn right~")
      |> mes("My granddaughter is soo~ pretty.")
      |> mes("Hahaha...ah....hah...")
      |> mes(".....*Sob, sob*....")
      |> next()
      |> select(["I want to marry her...", "I came to repair the sword.", "Anything wrong?"])

    case choice do
      1 -> rejects_marriage(ctx, "Get out of here you pervert!")
      2 -> cannot_repair(ctx)
      3 -> tells_of_illness(ctx)
      _ -> ctx
    end
  end

  defp cannot_repair(ctx) do
    ctx
    |> mes("[Aumgarl]")
    |> mes("...............")
    |> mes("A sword?")
    |> mes("I don't remember when the last")
    |> mes("time I worked with steel was.")
    |> mes("Hmm...")
    |> mes("May I see the sword?")
    |> next()
    |> mes("[Aumgarl]")
    |> mes("Hmm......")
    |> mes("Hmmmm......")
    |> mes("............")
    |> next()
    |> mes("^0000FFHe intently studied the pieces of the sword for a while.^000000")
    |> next()
    |> mes("[Aumgarl]")
    |> mes("Hmm...")
    |> mes("So this is the one, huh?")
    |> mes("Well...I am sorry, but this sword")
    |> mes("is not something I can repair")
    |> mes("at the moment.")
    |> next()
    |> mes("[Aumgarl]")
    |> mes("Why don't you go find")
    |> mes("another blacksmith?")
    |> mes("I am truly sorry.")
    |> close()
  end

  defp tells_of_illness(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Aumgarl]")
      |> mes("Um..well...")
      |> mes("This is not something I normally")
      |> mes("tell strangers, but....")
      |> mes("My granddaughter Lyroo has")
      |> mes("an incurable disease...")
      |> next()
      |> mes("[Aumgarl]")
      |> mes("Not long after she was born,")
      |> mes("her parents died from an accident.")
      |> mes("Since that day, I have been taking care of her...")
      |> next()
      |> mes("[Aumgarl]")
      |> mes("But that wasn't the end of it...")
      |> mes("Soon after, she started to suffer")
      |> mes("from a serious illness. I've met")
      |> mes("doctors from all around")
      |> mes("Midgard...")
      |> next()
      |> mes("[Aumgarl]")
      |> mes("But not one of them could")
      |> mes("diagnose her sickness...")
      |> next()
      |> select(["I am sorry to hear that.", "I'll make her happy.", "I want to cure her."])

    case choice do
      1 ->
        ctx
        |> mes("[Aumgarl]")
        |> mes("*Sigh*...")
        |> mes("I'll just have to accept it")
        |> mes("as her fate. I just feel")
        |> mes("so sorry for Lyroo.")
        |> mes("...")
        |> emotion(:think)
        |> close()

      2 ->
        offers_to_make_her_happy(ctx)

      3 ->
        ctx
        |> mes("[Aumgarl]")
        |> mes(".................")
        |> mes("Thanks for your concern...")
        |> mes("but you're a stranger to us.")
        |> mes("I can't let you do that.")
        |> mes("Thanks anyways.")
        |> close()

      _ ->
        ctx
    end
  end

  defp offers_to_make_her_happy(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Aumgarl]")
      |> mes("Umm...")
      |> mes("What do you mean...?")
      |> mes("'Make her happy?'")
      |> mes("You're not making any sense...")
      |> mes("I'm confused...")
      |> next()
      |> select([
        "I'll make her happy all the time.",
        "I want to take her with me.",
        "I will cure her."
      ])

    case choice do
      1 ->
        ctx
        |> mes("[Aumgarl]")
        |> mes("...")
        |> mes("What are you talking about?")
        |> mes("Make her happy all the time?")
        |> mes("She is dying even at")
        |> mes("this moment.")
        |> next()
        |> mes("[Aumgarl]")
        |> mes("I think you're out of")
        |> mes("your mind, sicko!")
        |> mes("Get out of here!")
        |> close()

      2 ->
        offers_to_take_her(ctx)

      3 ->
        offers_to_cure_her(ctx)

      _ ->
        ctx
    end
  end

  defp offers_to_take_her(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Aumgarl]")
      |> mes("...What do you mean?")
      |> mes("You want to take her to where?")
      |> mes("What are you gonna do?")
      |> next()
      |> select(["I will cure her.", "I am sorry."])

    if choice == 1 do
      ctx
      |> mes("[Aumgarl]")
      |> mes("It's useless talking about")
      |> mes("it any longer. I don't think")
      |> mes("there is anyone who can")
      |> mes("cure my granddaughter.")
      |> close()
    else
      apologizes(ctx)
    end
  end

  defp apologizes(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Aumgarl]")
      |> mes("Ahh...")
      |> mes("I'm not blaming you.")
      |> mes("It's not your fault anyway.")
      |> mes("...*Sigh*...")
      |> next()
      |> select(["Well...", "I'll pray for her recovery."])

    if choice == 1 do
      asks_a_favor(ctx)
    else
      ctx
      |> mes("[Aumgarl]")
      |> mes("Well...thank you.")
      |> mes("I'm going to try my best to")
      |> mes("make her happy until the")
      |> mes("very end..")
      |> mes("Please come by sometime")
      |> mes("to say hi to Lyroo.")
      |> close()
    end
  end

  defp asks_a_favor(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Aumgarl]")
      |> mes("Err..")
      |> mes("I am sorry to ask you this...")
      |> mes("But would you do me a favor?")
      |> mes("Umm...")
      |> next()
      |> select(["No.", "Sure."])

    if choice == 1 do
      ctx
      |> mes("[Aumgarl]")
      |> mes("Err...")
      |> mes("Alright, I won't bother you..")
      |> mes("Goodbye...")
      |> close()
    else
      {ctx, _} =
        ctx
        |> mes("[Aumgarl]")
        |> mes("It won't be easy, but")
        |> mes("would you help me to find")
        |> mes("a doctor...No, anybody")
        |> mes("who can cure Lyroo...")
        |> next()
        |> mes("[Aumgarl]")
        |> mes("Anyone who has any information about her illness?? Please...")
        |> mes("...*Sob*...")
        |> next()
        |> select(["Yes, Sir."])

      ctx
      |> mes("[Aumgarl]")
      |> mes("Oh...")
      |> mes("Thank you so much.")
      |> mes("If Lyroo can get her health back,")
      |> mes("I'll never forget your help.")
      |> next()
      |> mes("[Aumgarl]")
      |> mes("Thank you...")
      |> mes("Thank you...")
      |> set_char_var(:b_sword, 20)
      |> close()
    end
  end

  defp offers_to_cure_her(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Aumgarl]")
      |> mes(".............")
      |> mes("How're you going to cure")
      |> mes("my granddaughter?")
      |> mes("You don't look like")
      |> mes("a doctor to me.")
      |> next()
      |> select(["I am a doctor.", "I know a famous doctor.", "I'll cure her no matter what."])

    case choice do
      1 ->
        ctx
        |> mes("[Aumgarl]")
        |> mes("Ehm...")
        |> mes("Do I look like a fool to you?")
        |> mes("I hate people who lie like that. Get out of my sight.")
        |> mes("Get out of my sight.")
        |> mes(" ")
        |> emotion(:hng)
        |> close()
        |> warp("geffen", 173, 169)

      2 ->
        ctx
        |> mes("[Aumgarl]")
        |> mes("A famous doctor?")
        |> mes("I've met all kinds of")
        |> mes("famous doctors. I've")
        |> mes("probably met whoever")
        |> mes("you may know already.")
        |> close()

      3 ->
        ctx
        |> mes("[Aumgarl]")
        |> mes("................")
        |> mes("You want to cure her")
        |> mes("no matter what?")
        |> mes("How're going to do that?")
        |> mes("What if it turns worse,")
        |> mes("Huh?")
        |> next()
        |> mes("[Aumgarl]")
        |> mes("I'm tired of your bragging.")
        |> mes("Please just leave us alone.")
        |> close()

      _ ->
        ctx
    end
  end

  defp too_tired(ctx) do
    ctx
    |> mes("[Aumgarl]")
    |> mes(".........")
    |> mes("Umm...")
    |> mes("I'm sorry, but I am")
    |> mes("very tired right now.")
    |> mes("Can't help you...")
    |> close()
  end

  defp examines_sword_after_cure(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Aumgarl]")
      |> mes("Hmm....")
      |> mes("Show me this sword.")
      |> mes("I need to take a look at it first")
      |> mes("to find out whether I can repair it or not.")
      |> next()
      |> mes("^0000FFYou Show the pieces of the")
      |> mes("broken sword to Aumgarl.")
      |> mes("....................")
      |> mes("Aumgarl took a careful look")
      |> mes("at the pieces for awhile...^000000")
      |> next()
      |> mes("...")
      |> mes("...")
      |> mes("...")
      |> mes("...")
      |> next()
      |> mes("[Aumgarl]")
      |> mes("Hmm...")
      |> mes("It's not possible to start work")
      |> mes("immediately. I'll need")
      |> mes("some materials.")
      |> next()
      |> asks_for_materials()
      |> select(["Umm...let's do it next time.", "Alright, I'll go get them."])

    if choice == 1 do
      postpones(ctx)
    else
      ctx
      |> lists_materials()
      |> mes("[Aumgarl]")
      |> mes("It's quite a lot, huh?")
      |> mes("But these are the necessary")
      |> mes("supplies we need to repair the sword.")
      |> mes("I'll go find some other materials.")
      |> set_char_var(:b_sword, 30)
      |> close()
    end
  end

  defp examines_sword_on_return(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Aumgarl]")
      |> mes("Hmm....")
      |> mes("Show me this sword.")
      |> mes("I need to take a look at it first")
      |> mes("to find out whether I can repair it or not.")
      |> next()
      |> mes("^0000FFYou show the pieces of the")
      |> mes("broken sword to Aumgarl.")
      |> mes("....................")
      |> mes("Aumgarl took a careful look")
      |> mes("at the pieces for a while...^000000")
      |> next()
      |> mes("...")
      |> mes("...")
      |> mes("...")
      |> mes("...")
      |> next()
      |> mes("[Aumgarl]")
      |> mes("Hmm...")
      |> mes("Well,")
      |> mes("It's not possible to start work")
      |> mes("immediately.")
      |> mes("I need some materials.")
      |> next()
      |> asks_for_materials()
      |> select(["Umm..let's do it next time.", "Alright, I'll go get them."])

    if choice == 1 do
      postpones(ctx)
    else
      ctx
      |> lists_materials()
      |> mes("[Aumgarl]")
      |> mes("It's quite a lot, huh?")
      |> mes("These are necessary supplies.")
      |> mes("We need them to repair the sword.")
      |> mes("I'll go find some other materials.")
      |> set_char_var(:b_sword, 30)
      |> close()
    end
  end

  defp asks_for_materials(ctx) do
    ctx
    |> mes("[Aumgarl]")
    |> mes("To repair this sword, I need")
    |> mes("to restock my supplies.")
    |> mes("Since Lyroo is upstairs in pain,")
    |> mes("I don't think I can leave the house.")
    |> next()
    |> mes("[Aumgarl]")
    |> mes("So...could you get the")
    |> mes("materials for me?")
    |> mes("I am sorry I am asking")
    |> mes("you to do this, as well.")
    |> next()
  end

  defp postpones(ctx) do
    ctx
    |> mes("[Aumgarl]")
    |> mes("Umm.....")
    |> mes("I am sorry I can't")
    |> mes("help you right away.")
    |> mes("Come back here when")
    |> mes("you need my help then.")
    |> close()
  end

  defp lists_materials(ctx) do
    ctx
    |> mes("[Aumgarl]")
    |> mes("Oh~~ really?")
    |> mes("Thank you!")
    |> mes("I'm sure I can repair it for you.")
    |> mes("Now, listen carefully,")
    |> mes("this is what I will need-")
    |> next()
    |> material_list("One")
  end

  defp material_list(ctx, anvils) do
    ctx
    |> mes("[Aumgarl]")
    |> mes("^FF00FF #{anvils} Anvil")
    |> mes("2 Rough Oridecons")
    |> mes("5 Broken Swords")
    |> mes("2 Steels")
    |> mes("1 Hammer of Blacksmith")
    |> mes("2 Star Crumbs")
    |> mes("5 Live Coals^000000")
    |> next()
  end

  defp has_materials?(ctx) do
    Enum.all?(@materials, fn {item, amount} -> count_item(ctx, item) >= amount end)
  end

  defp take_materials(ctx) do
    Enum.reduce(@materials, ctx, fn {item, amount}, ctx -> delitem(ctx, item, amount) end)
  end
end
