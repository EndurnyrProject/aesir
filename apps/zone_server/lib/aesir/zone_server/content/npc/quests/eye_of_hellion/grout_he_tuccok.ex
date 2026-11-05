defmodule Aesir.ZoneServer.Content.Npc.Quests.EyeOfHellion.GroutHeTuccok do
  @moduledoc """
  Grout'he sells clues to the Eye of Hellion tablet and helps interpret them.

  ## Behavior

  - Sells four clue items for 10,000 zeny and marks their locations.
  - Guides the player through the clues and toward the tablet piece.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - L0ne_W0lf
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "payon",
        x: 182,
        y: 132,
        dir: 3,
        sprite: 48,
        name: "Grout'he Tuccok",
        scope: :shared,
        unique_name: "Grout'he Tuccok#hellion"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :MaxWeight, 0) - weight(ctx) < 2000 or
         checkweight(ctx, [{1201, 1}]) == 0 do
      ctx
      |> mes("^3355FFHold it right there!")
      |> mes(
        "You're carrying too many items and don't have enough inventory space to receive any rewards. Please make more inventory space available and come back to take this challenge."
      )
      |> close()
    else
      quest_dialogue(ctx, get_char_var(ctx, :HELLIONQ, 0))
    end
  end

  defp quest_dialogue(ctx, step) do
    cond do
      step < 47 -> dismiss(ctx)
      step == 47 -> offer_clues(ctx)
      step == 48 -> first_clue(ctx)
      step == 49 -> stone_heart_clue(ctx)
      step == 50 -> green_herb_clue(ctx)
      step == 51 -> grape_juice_clue(ctx)
      step == 52 -> interpret_clues(ctx)
      step < 55 -> search_progress(ctx)
      step == 55 -> statue_clue(ctx)
      step == 56 -> statue_reminder(ctx)
      step == 57 -> found_piece(ctx)
      step < 71 -> warning(ctx)
      true -> debt_free(ctx)
    end
  end

  defp dismiss(ctx) do
    ctx
    |> mes("[Grout'he]")
    |> mes("Hey...")
    |> mes("Hey you!")
    |> mes("What are you")
    |> mes("looking at?!")
    |> mes("Get outta my")
    |> mes("face, ya jerkwad.")
    |> close()
  end

  defp offer_clues(ctx) do
    ctx =
      ctx
      |> mes("[Grout'he]")
      |> mes("What...?")
      |> mes("You got something")
      |> mes("to tell me or are you")
      |> mes("just bein' a rude prick")
      |> mes("and staring at me like")
      |> mes("this is your turf?!")
      |> next()

    {ctx, choice} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("I'm sorry, but well...")
      |> mes("Chilias'Tyus told me that")
      |> mes("you might know something")
      |> mes("about a piece of a tablet--")
      |> next()
      |> mes("[Grout'he]")
      |> mes("What? Oh, so Chilias'Tyus")
      |> mes("is lookin for the gem too, eh?")
      |> mes("Ooh, that's right. He wants to")
      |> mes("seal its evil or something.")
      |> mes("Yeah, yeah. That's a good")
      |> mes("cause. Real noble and all...")
      |> next()
      |> mes("[Grout'he]")
      |> mes("Tell you what. The only reason")
      |> mes("I want that gem is to sell it so I can pay off all my debts. But")
      |> mes("if I sell you the clues I found, I'll get the zeny I need and the")
      |> mes("gem will be in good hands too.")
      |> next()
      |> mes("[Grout'he]")
      |> mes("So what do you say?")
      |> mes("It's not a bad deal if")
      |> mes("you think about it and")
      |> mes("we might as well kill")
      |> mes("two birds with one stone...")
      |> next()
      |> select(["Alright, I'll buy your clues.", "Why the hell should I pay you?!"])

    if choice == 1 do
      sell_clues(ctx)
    else
      ctx
      |> mes("[Grout'he]")
      |> mes("Why the hell should you")
      |> mes("pay me?! Hey, aren't you")
      |> mes("looking for the gem to help")
      |> mes("the world? Well, I happen to")
      |> mes("be a little part of this world,")
      |> mes("so why don't you help me first?")
      |> next()
      |> mes("[Grout'he]")
      |> mes("Man, you might not")
      |> mes("know it, but the money")
      |> mes("you give me will save")
      |> mes("a life. My own! Dude, how")
      |> mes("can you be so insensitive?")
      |> close()
    end
  end

  defp sell_clues(ctx) do
    ctx =
      ctx
      |> mes("[Grout'he]")
      |> mes("Oh man, thanks a lot.")
      |> mes("Alright, all I'm asking")
      |> mes("for is 10,000 zeny. You get")
      |> mes("my clues and I'll let you know")
      |> mes("where I found 'em, in case")
      |> mes("you can find something new.")
      |> next()

    cond do
      zeny(ctx) < 10_000 ->
        ctx
        |> mes("[Grout'he]")
        |> mes("Oh hey...")
        |> mes("You don't got the zeny.")
        |> mes("Sorry pal, but I've really got")
        |> mes("to pay my debts somehow.")
        |> mes("I don't know if I'm allowed")
        |> mes("to really talk about it...")
        |> mes("^333333*Sob*^000000")
        |> close()

      get_char_var(ctx, :MaxWeight, 0) - weight(ctx) > 1000 ->
        ctx
        |> mes("[Grout'he]")
        |> mes("There you go!")
        |> mes("Thanks for the cash~")
        |> mes("(Now I won't have to")
        |> mes("get my knees all broken!)")
        |> mes("Oh, and let me mark your")
        |> mes("Mini-Map for you real quick...")
        |> next()
        |> mes("[Grout'he]")
        |> mes("You see this here?")
        |> mes("It's where I found the")
        |> mes("Skirt of Virgin I'm about")
        |> mes("to give you. So check that")
        |> mes("spot out and see if you find")
        |> mes("anything new and interesting.")
        |> viewpoint(1, 101, 190, 1, 16_776_960)
        |> next()
        |> mes("[Grout'he]")
        |> mes("Here you go, pal...")
        |> mes("A Stone Heart, Green Herb,")
        |> mes("some Grape Juice and one")
        |> mes("clean and pure Skirt of Virgin.")
        |> mes("If you got any more questions,")
        |> mes("I guess you can ask me later~")
        |> pay_zeny(10_000)
        |> set_char_var(:HELLIONQ, 48)
        |> give_item(953, 1)
        |> give_item(511, 1)
        |> give_item(533, 1)
        |> give_item(1049, 1)
        |> close()

      true ->
        ctx
        |> mes("[Grout'he]")
        |> mes("Whoa whoa...")
        |> mes("But you don't got any room")
        |> mes("in your inventory to hold")
        |> mes("what I wanna give you. It'd")
        |> mes("probably be best to stash your")
        |> mes("stuff in Kafra Storage, yeah?")
        |> close()
    end
  end

  defp first_clue(ctx) do
    ctx
    |> mes("[Grout'he]")
    |> mes("You forgot where I told")
    |> mes("you to look for more clues?")
    |> mes("Eh, I'll let you know once")
    |> mes("again, sure. Keep your eye")
    |> mes("on your Mini-Map, got it?")
    |> viewpoint(1, 101, 190, 1, 16_776_960)
    |> next()
    |> mes("[Grout'he]")
    |> mes("Alright...")
    |> mes("Good luck out there.")
    |> mes("I really hope you can")
    |> mes("keep the gem out of the")
    |> mes("wrong hands. Of course, I was gonna just sell it, but...")
    |> close()
  end

  defp stone_heart_clue(ctx) do
    ctx
    |> mes("[Grout'he]")
    |> mes("You've been to the")
    |> mes("first location? Good.")
    |> mes("Okay, now look over here.")
    |> mes("Check your Mini-Map to")
    |> mes("see where I found that")
    |> mes("Stone Heart, got it?")
    |> viewpoint(1, 82, 109, 2, 16_776_960)
    |> close()
  end

  defp green_herb_clue(ctx) do
    ctx
    |> mes("[Grout'he]")
    |> mes("Alright, here's where")
    |> mes("I found that Green Herb.")
    |> mes("You know you can use that")
    |> mes("to counter poison, right?")
    |> mes("Check that place to see if")
    |> mes("there's anything I missed.")
    |> viewpoint(1, 239, 56, 3, 16_776_960)
    |> close()
  end

  defp grape_juice_clue(ctx) do
    ctx
    |> mes("[Grout'he]")
    |> mes("Okay, here's the last")
    |> mes("place you should double")
    |> mes("check, the place where")
    |> mes("I nabbed that Grape")
    |> mes("Juice. Good luck~")
    |> viewpoint(1, 243, 160, 4, 16_776_960)
    |> close()
  end

  defp interpret_clues(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Grout'he]")
      |> mes("Oh, you need some help")
      |> mes("in figuring out the clues?")
      |> mes("Heh. Alright, let's see.")
      |> mes("You want me to help")
      |> mes("you in making sense of")
      |> mes("this weird riddle?")
      |> next()
      |> select(["Yes, please!", "No, thanks~"])

    if choice == 1 do
      explain_clues(ctx)
    else
      ctx
      |> mes("[Grout'he]")
      |> mes("Oh yeah?")
      |> mes("Well listen, I dunno,")
      |> mes("but this looks to be one")
      |> mes("of those situations where")
      |> mes("two heads are better than one.")
      |> mes("I think we oughta team up~")
      |> close()
    end
  end

  defp explain_clues(ctx) do
    ctx =
      ctx
      |> mes("[Grout'he]")
      |> mes("Alright now. All those")
      |> mes("messages said stuff about")
      |> mes("one sized clothing, dried")
      |> mes("fish and green herbs, wine...")
      |> mes("Huh. It doesn't make sense.")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("What...?")
    |> mes("I could have")
    |> mes("told you that!")
    |> next()
    |> mes("[Grout'he]")
    |> mes("Wait, wait.")
    |> mes("Let's mark all the")
    |> mes("clue locations again")
    |> mes("on your Mini-Map.")
    |> mes("Okay, we've got four")
    |> mes("dots around Payon.")
    |> viewpoint(1, 243, 160, 4, 16_776_960)
    |> viewpoint(1, 239, 56, 3, 16_776_960)
    |> viewpoint(1, 82, 109, 2, 16_776_960)
    |> viewpoint(1, 101, 190, 1, 16_776_960)
    |> next()
    |> mes("[Grout'he]")
    |> mes("Alright, now if")
    |> mes("I connect and intersect")
    |> mes("all the lines, there's")
    |> mes("a point in the middle.")
    |> mes("Why don't you check")
    |> mes("this middle point, eh?")
    |> viewpoint(1, 159, 129, 5, 16_776_960)
    |> next()
    |> mes("[Grout'he]")
    |> mes("Now, this location")
    |> mes("is a house, and I know")
    |> mes("it's pretty random, but")
    |> mes("it's all we got. Heck,")
    |> mes("all these clues make")
    |> mes("less sense than this!")
    |> set_char_var(:HELLIONQ, 53)
    |> close()
  end

  defp search_progress(ctx) do
    ctx
    |> mes("[Grout'he]")
    |> mes("Hey, how's it goin'")
    |> mes("looking for that one")
    |> mes("piece of the tablet?")
    |> mes("It's a lot of trouble,")
    |> mes("but I guess that's the")
    |> mes("case with all treasure.")
    |> close()
  end

  defp statue_clue(ctx) do
    ctx
    |> mes("[Grout'he]")
    |> mes("Oh, so all of those")
    |> mes("items came in handy?")
    |> mes("I don't believe it! So")
    |> mes("this puzzle actually")
    |> mes("makes sense?! So")
    |> mes("what'd the slab say?")
    |> next()
    |> mes("[Grout'he]")
    |> mes("''Compassionate one?''")
    |> mes("Oh hey, there's a giant")
    |> mes("stone statue over in the")
    |> mes("Archer Village that fits")
    |> mes("that description perfectly!")
    |> mes("You should check it out.")
    |> set_char_var(:HELLIONQ, 56)
    |> close()
  end

  defp statue_reminder(ctx) do
    ctx
    |> mes("[Grout'he]")
    |> mes("Hey, you really ought")
    |> mes("to check out the huge")
    |> mes("stone statue over in the")
    |> mes("Archer Village. Now that")
    |> mes("I think about it, it's the")
    |> mes("perfect hiding place!")
    |> close()
  end

  defp found_piece(ctx) do
    ctx
    |> mes("[Grout'he]")
    |> mes("Hey, this is great!")
    |> mes("You actually found the")
    |> mes("next piece of the tablet!")
    |> mes("You better take this back")
    |> mes("to Chilias'Tyus right now~")
    |> next()
    |> mes("[Grout'he]")
    |> mes("Oh. And um, thanks")
    |> mes("for being willing to pay")
    |> mes("me in cash for all those")
    |> mes("little bitty clues. I won't")
    |> mes("forget your help, pal~")
    |> close()
  end

  defp warning(ctx) do
    ctx
    |> mes("[Grout'he]")
    |> mes("Hey, be careful if")
    |> mes("you manage to find that")
    |> mes("Hellion's gem. I dunno if")
    |> mes("it's true, but maybe old")
    |> mes("Tyus was right. Maybe it")
    |> mes("does hold a wicked power...")
    |> close()
  end

  defp debt_free(ctx) do
    ctx
    |> mes("[Grout'he]")
    |> mes("Life sure is a lot")
    |> mes("less tense without")
    |> mes("having debt to worry")
    |> mes("about. I could get")
    |> mes("real used to this...")
    |> close()
  end
end
