defmodule Aesir.ZoneServer.Content.Npc.Quests.EyeOfHellion.SageWelshyun do
  @moduledoc """
  Sage Welshyun guides the player through the last tablet piece and reassembles the tablet.

  ## Behavior

  - Sends the player to Enoz and tests their knowledge for the final tablet piece.
  - Combines the four pieces and offers a warp to the Hellion Revenant.
  - Reacts when the player carrying a tablet piece approaches him.

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
        map: "geffen",
        x: 110,
        y: 200,
        dir: 3,
        sprite: 754,
        name: "Sage Welshyun",
        scope: :shared,
        unique_name: "Sage Welshyun#hellion",
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    if get_char_var(ctx, :HELLIONQ, 0) == 58 and count_item(ctx, 7335) > 0 do
      ctx
      |> specialeffect2(:heal2)
      |> specialeffect(:heal2)
      |> mes("^3355FFThe piece of tablet")
      |> mes("that you have is shining")
      |> mes("with light as if in response")
      |> mes("to something in the area.^000000")
      |> close()
    else
      ctx
    end
  end

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
      step < 58 -> dismiss(ctx)
      step == 58 -> meet_player(ctx)
      step == 59 -> report_reminder(ctx)
      step == 60 -> thirsty(ctx)
      step == 61 -> offer_potion(ctx)
      step == 62 -> report_reminder(ctx)
      step == 63 -> return_reference_book(ctx)
      step == 64 -> book_reminder(ctx)
      step == 65 -> gemstone_test(ctx)
      step == 66 -> visit_chilias(ctx)
      step == 67 -> assemble_tablet(ctx)
      step < 71 -> ask_about_chilias(ctx)
      true -> laugh_at_enoz(ctx)
    end
  end

  defp dismiss(ctx) do
    ctx
    |> mes("[Welshyun]")
    |> mes("Hm? Oh, pardon me.")
    |> mes("I didn't notice you. I was")
    |> mes("far too occupied thinking")
    |> mes("deep important thoughts")
    |> mes("that your puny little mind")
    |> mes("couldn't possibly fathom.")
    |> close()
  end

  defp meet_player(ctx) do
    {ctx, choice} =
      ctx
      |> specialeffect2(:heal2)
      |> specialeffect(:heal2)
      |> mes("[Welshyun]")
      |> mes("That...")
      |> mes("That eerie glow...")
      |> next()
      |> mes("[Welshyun]")
      |> mes("You! Identify yourself")
      |> mes("and explain how you came")
      |> mes("about to get those tablet")
      |> mes("pieces! Now answer me!")
      |> next()
      |> mes("[Welshyun]")
      |> mes("Ah, forgive me. You're")
      |> mes("helping Chilias, are you?")
      |> mes("I see. So you must be here")
      |> mes("to seek my help in finding")
      |> mes("the final piece, am I correct?")
      |> next()
      |> select(["Shut up, I know you have it, so give it!", "Yes, please help me."])

    if choice == 1 do
      ctx
      |> mes("[Welshyun]")
      |> mes("Such insolence!")
      |> mes("Huh. I suppose Chilias")
      |> mes("may have misjudged you")
      |> mes("when he entrusted you with")
      |> mes("this important mission. Huh.")
      |> mes("A reevaluation is in order...")
      |> set_char_var(:HELLIONQ, 60)
      |> close()
    else
      ctx
      |> mes("[Welshyun]")
      |> mes("Of course, in the")
      |> mes("interest of mankind,")
      |> mes("I shall help you. But first,")
      |> mes("I have a favor to ask of you.")
      |> next()
      |> mes("[Welshyun]")
      |> mes("My student in the Geffen")
      |> mes("Tower has not reported back to")
      |> mes("me about his research project,")
      |> mes("so I would like for you to find")
      |> mes("him and retrieve the report")
      |> mes("for me. Not a big deal, right?")
      |> next()
      |> mes("[Welshyun]")
      |> mes("The title of his report")
      |> mes("should be, ''^4D4DFFMonster Life")
      |> mes("in the Geffen Area^000000,'' so")
      |> mes("please remember that.")
      |> mes("Ah, and my student's")
      |> mes("name is Enoz.")
      |> set_char_var(:HELLIONQ, 59)
      |> close()
    end
  end

  defp report_reminder(ctx) do
    ctx
    |> mes("[Welshyun]")
    |> mes("Please bring me the")
    |> mes("report entitled, ''^4D4DFFMonster")
    |> mes("Life in the Geffen Area^000000,''")
    |> mes("from my student Enoz in")
    |> mes("the Geffen Tower. Thank")
    |> mes("you, I appreciate your help.")
    |> close()
  end

  defp thirsty(ctx) do
    ctx
    |> mes("[Welshyun]")
    |> mes("^333333*Ahem*^000000 Oh dear me...")
    |> mes("I'm unfathomably thirsty...")
    |> mes("There's no way I can do any")
    |> mes("serious thinking with such")
    |> mes("a dry, parched throat...")
    |> set_char_var(:HELLIONQ, 61)
    |> close()
  end

  defp offer_potion(ctx) do
    if count_item(ctx, 504) > 0 do
      ctx
      |> mes("[Welshyun]")
      |> mes("Oh, a White Potion?")
      |> mes("Yes, may I please have")
      |> mes("one? Ahh, most refreshing~")
      |> mes("You may not be such a bad")
      |> mes("person after all! Now shall I help you find that tablet piece?")
      |> next()
      |> mes("[Welshyun]")
      |> mes("Of course, in the")
      |> mes("interest of mankind,")
      |> mes("I shall help you. But first,")
      |> mes("I have a favor to ask of you.")
      |> next()
      |> mes("[Welshyun]")
      |> mes("My student in the Geffen")
      |> mes("Tower has not reported back to")
      |> mes("me about his research project,")
      |> mes("so I would like for you to find")
      |> mes("him and retrieve the report")
      |> mes("for me. Not a big deal, right?")
      |> next()
      |> mes("[Welshyun]")
      |> mes("The title of his report")
      |> mes("should be, ''^4D4DFFMonster Life")
      |> mes("in the Geffen Area^000000,'' so")
      |> mes("please remember that.")
      |> mes("Ah, and my student's")
      |> mes("name is Enoz.")
      |> delitem(504, 1)
      |> set_char_var(:HELLIONQ, 62)
      |> close()
    else
      ctx
      |> mes("[Welshyun]")
      |> mes("Oh...! Still so...")
      |> mes("Exasperatingly thirsty!")
      |> mes("If I only had something")
      |> mes("cool, refreshing and with")
      |> mes("a high restorative value")
      |> mes("to quench this thirst!")
      |> close()
    end
  end

  defp return_reference_book(ctx) do
    ctx
    |> mes("[Welshyun]")
    |> mes("Hm? What's that strange")
    |> mes("expression on your face?")
    |> mes("Prank? Oh please. Such")
    |> mes("chicanery is beneath me...")
    |> mes("But even if I did play a joke, believe me. It builds character.")
    |> next()
    |> mes("[Welshyun]")
    |> mes("First and foremost,")
    |> mes("I want to test you to see")
    |> mes("if you are worthy of this")
    |> mes("tablet piece. I want to see")
    |> mes("for myself if you are a person")
    |> mes("of honor. Someone of character.")
    |> next()
    |> mes("[Welshyun]")
    |> mes("Oh yes, I accidentally")
    |> mes("took this Master Science")
    |> mes("Reference Book from Enoz,")
    |> mes("so would you please return it")
    |> mes("to him for me? Oh, and please")
    |> mes("bring back 1 Blue Gemstone.")
    |> next()
    |> mes("^3355FFYou received the")
    |> mes("incredibly heavy tome,")
    |> mes("the Master Science")
    |> mes("Reference Book.^000000")
    |> set_char_var(:HELLIONQ, 64)
    |> close()
  end

  defp book_reminder(ctx) do
    ctx
    |> mes("[Welshyun]")
    |> mes("Please deliver the Master")
    |> mes("Science Reference Book to")
    |> mes("Enoz, and come back to me")
    |> mes("with 1 Blue Gemstone.")
    |> close()
  end

  defp gemstone_test(ctx) do
    if count_item(ctx, 717) > 0 do
      ask_riddle(ctx)
    else
      ctx
      |> mes("[Welshyun]")
      |> mes("Ah, I've heard that")
      |> mes("Enoz received the Master")
      |> mes("Science Reference Book")
      |> mes("from you. But did you remember")
      |> mes("to bring me a Blue Gemstone?")
      |> close()
    end
  end

  defp ask_riddle(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Welshyun]")
      |> mes("Thank you. You've")
      |> mes("brought the book to Enoz")
      |> mes("and delivered a Gemstone")
      |> mes("to me as I've asked. Now,")
      |> mes("there is one final test...")
      |> next()
      |> mes("[Welshyun]")
      |> mes("Answer this question.")
      |> mes("Where is the abode of the")
      |> mes("departed souls with a shining")
      |> mes("silver roof that is mentioned")
      |> mes("in the third part of the ballad")
      |> mes("of Grimnir? Well, adventurer?")
      |> next()
      |> input(:string)

    if answer == "Valaskjalf" do
      ctx
      |> mes("[Welshyun]")
      |> mes("Ah, well met, well met.")
      |> mes("You are as well learned as")
      |> mes("you are brave. As promised,")
      |> mes("you may have this piece of")
      |> mes("the tablet, which I've already found. The clues were too simple...")
      |> delitem(717, 1)
      |> set_char_var(:HELLIONQ, 66)
      |> give_item(7336, 1)
      |> next()
      |> mes("[Welshyun]")
      |> mes("Please send my regards")
      |> mes("to my dear friend, Chilias,")
      |> mes("who has dedicated his life")
      |> mes("to sealing the evil within")
      |> mes("the Hellion's gem.")
      |> close()
    else
      ctx
      |> mes("[Welshyun]")
      |> mes("Bwahahaah! Only")
      |> mes("a superior mind could")
      |> mes("know the answer to such")
      |> mes("a question! Go forth and")
      |> mes("learn the answer, else")
      |> mes("I cannot help you, adventurer~")
      |> close()
    end
  end

  defp visit_chilias(ctx) do
    ctx
    |> mes("[Welshyun]")
    |> mes("Hm. You should visit")
    |> mes("Chilias and determine")
    |> mes("your next course of action,")
    |> mes("now that you have all four")
    |> mes("of the pieces of the tablet.")
    |> close()
  end

  defp assemble_tablet(ctx) do
    if count_item(ctx, 7333) > 0 and count_item(ctx, 7334) > 0 and
         count_item(ctx, 7335) > 0 and count_item(ctx, 7336) > 0 do
      combine_tablet(ctx)
    else
      ctx
      |> mes("[Welshyun]")
      |> mes("So, were you able")
      |> mes("to deliver the tablet")
      |> mes("and the Hellion's gem to")
      |> mes("Chilias safely? I hope so...")
      |> close()
    end
  end

  defp combine_tablet(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Welshyun]")
      |> mes("Hm? Did you need")
      |> mes("me to combine all four")
      |> mes("pieces of the tablet and")
      |> mes("make it whole again? Oh.")
      |> mes("All this time I thought you")
      |> mes("knew how to do it. Alright.")
      |> next()
      |> mes("[Welshyun]")
      |> mes("As a matter of fact,")
      |> mes("I was planning on using")
      |> mes("the Blue Gemstone you gave")
      |> mes("me to do this. But since you")
      |> mes("never really asked... In any")
      |> mes("case, let me concentrate.")
      |> next()
      |> mes("[Welshyun]")
      |> mes("Shadows remembered by time.")
      |> mes("Help me retrieve the forgotten")
      |> mes("stories that have been scattered in the wind. Right here. Right now.")
      |> specialeffect(:beginspell2)
      |> next()
      |> mes("[Welshyun]")
      |> mes("...")
      |> mes("Okay...")
      |> mes("That was tough.")
      |> specialeffect(:spellbreaker)
      |> next()
      |> mes("[Welshyun]")
      |> mes("That was tough")
      |> mes("complete tablet.")
      |> mes("Please bring this")
      |> mes("safely back to Chilias.")
      |> delitem(7333, 1)
      |> delitem(7334, 1)
      |> delitem(7335, 1)
      |> delitem(7336, 1)
      |> set_char_var(:HELLIONQ, 68)
      |> give_item(7332, 1)
      |> next()
      |> mes("[Welshyun]")
      |> mes("Wait, take a look!")
      |> mes("There's a map on the back")
      |> mes("of the tablet. Although the gem")
      |> mes("is already embedded within the")
      |> mes("tablet, who knows where this map may lead? Perhaps Hellion Revenant?")
      |> next()
      |> mes("[Welshyun]")
      |> mes("I don't know if Chilias")
      |> mes("told you, but the name of")
      |> mes("the monster that guards and")
      |> mes("follows this gem is Hellion")
      |> mes("Revenant. But why mark its")
      |> mes("location on this tablet?")
      |> next()
      |> mes("[Welshyun]")
      |> mes("Well, it will be dangerous, but")
      |> mes("I'm sure that you're strong enough to confront this monster. I believe")
      |> mes("it was the wish of this tablet's creator for someone to defeat")
      |> mes("the Hellion Revenant...")
      |> next()
      |> select([
        "Alright, I'll do it!",
        "I better get this tablet to Chilias..."
      ])

    if choice == 1 do
      ctx
      |> mes("[Welshyun]")
      |> mes("Well, I'm almost certain")
      |> mes("this map will lead you to")
      |> mes("Hellion Revenant. Let me")
      |> mes("warp you to the location")
      |> mes("marked on the tablet's map...")
      |> close()
      |> warp("gef_fild09", 368, 88)
    else
      ctx
      |> mes("[Welshyun]")
      |> mes("Yes, that's true.")
      |> mes("Chilias has been waiting")
      |> mes("his whole life to seal this")
      |> mes("gem. Plus, who knows what")
      |> mes("may happen while it is in")
      |> mes("your possession?")
      |> close()
    end
  end

  defp ask_about_chilias(ctx) do
    ctx
    |> mes("[Welshyun]")
    |> mes("So, were you able")
    |> mes("to deliver the tablet")
    |> mes("and the Hellion's gem to")
    |> mes("Chilias safely? Ah, and")
    |> mes("how has my friend been?")
    |> close()
  end

  defp laugh_at_enoz(ctx) do
    ctx
    |> mes("[Welshyun]")
    |> mes("Heh heh~")
    |> mes("Enoz must be")
    |> mes("panicking right")
    |> mes("about now. Oh,")
    |> mes("students are always")
    |> mes("good for a laugh...")
    |> close()
  end
end
