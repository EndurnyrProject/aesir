defmodule Aesir.ZoneServer.Content.Npc.Quests.EyeOfHellion.OldScholarTyus do
  @moduledoc """
  Old Scholar Tyus guides the search for the Hellion's gem and seals its darkness.

  ## Behavior

  - Checks inventory capacity and recruits adventurers of at least level 60.
  - Guides the tablet search through Prontera, Payon, and Geffen and supplies a piece.
  - Smites players who return without the required tablet pieces at key quest steps.
  - Seals the completed tablet and grants a Nile Rose and mode-dependent experience,
    with an extra reward when the player brings an Eye of Hellion.
  - Reacts to a nearby glowing tablet piece and removes remaining eyes after completion.

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
        map: "morocc_in",
        x: 116,
        y: 101,
        dir: 3,
        sprite: 735,
        name: "Old Scholar Tyus",
        scope: :shared,
        unique_name: "Old Scholar Tyus#hellion",
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    if get_char_var(ctx, :HELLIONQ, 0) == 57 and count_item(ctx, 7334) > 0 do
      ctx
      |> specialeffect2(:heal2)
      |> specialeffect(:heal2)
      |> mes("^3355FFOne of the Tablet Pieces")
      |> mes("that you have is beginning to")
      |> mes("shine with light, as if it were")
      |> mes("responding to something...^000000")
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
      quest_progress(ctx, get_char_var(ctx, :HELLIONQ, 0))
    end
  end

  defp quest_progress(ctx, step) when step < 36, do: greet(ctx)

  defp quest_progress(ctx, 36) do
    ctx
    |> mes("[Sir Chilias'Tyus]")
    |> mes("Please seek out")
    |> mes("Clanux Heffron in")
    |> mes("Prontera. He may have")
    |> mes("information regarding a")
    |> mes("clue leading to the Hellion")
    |> mes("gem. Good luck to you.")
    |> close()
  end

  defp quest_progress(ctx, 37), do: reconsider_request(ctx)

  defp quest_progress(ctx, step) when step > 37 and step < 45 do
    ctx
    |> mes("[Sir Chilias'Tyus]")
    |> mes("Try to see what you can")
    |> mes("learn from Clanux Heffron.")
    |> mes("I don't know how cooperative")
    |> mes("he will be, but I'm sure that")
    |> mes("he'll tell you something one")
    |> mes("way or another.")
    |> close()
  end

  defp quest_progress(ctx, step) when step == 45 or step == 46 do
    ctx
    |> mes("[Sir Chilias'Tyus]")
    |> mes("Ah, yes! This is one piece")
    |> mes("of the tablet that will lead")
    |> mes("you to the Hellion's gem!")
    |> mes("This engraving was definitely")
    |> mes("made by my grandfather, and Christopher was one of his friends.")
    |> next()
    |> mes("[Sir Chilias'Tyus]")
    |> mes("I suppose he hid these pieces")
    |> mes("in the places that reminded him")
    |> mes("of his friends. Now according")
    |> mes("to the tablet's message, you")
    |> mes("should find the next piece in ''the city of thickest forest.''")
    |> next()
    |> mes("[Sir Chilias'Tyus]")
    |> mes("I'm sure that the")
    |> mes("next tablet piece is")
    |> mes("in Payon, so go there")
    |> mes("and see if you can find")
    |> mes("it. Good luck to you,")
    |> mes("kind adventurer.")
    |> set_char_var(:HELLIONQ, 47)
    |> close()
  end

  defp quest_progress(ctx, 47) do
    ctx
    |> mes("[Sir Chilias'Tyus]")
    |> mes("Now that I think about")
    |> mes("it, there's a guy in Payon")
    |> mes("that I know named Grout'the")
    |> mes("Tuccok who knew my grandfather.")
    |> mes("He might know something, but")
    |> mes("he's a little, well... Hmm...")
    |> close()
  end

  defp quest_progress(ctx, step) when step > 47 and step < 57 do
    ctx
    |> mes("[Sir Chilias'Tyus]")
    |> mes("I think you're doing")
    |> mes("a good job in finding")
    |> mes("those clues in Payon.")
    |> mes("Please do your best in")
    |> mes("finding the rest of the")
    |> mes("pieces of that tablet.")
    |> close()
  end

  defp quest_progress(ctx, 57) do
    if count_item(ctx, 7333) > 0 and count_item(ctx, 7334) > 0 do
      ctx
      |> mes("[Sir Chilias'Tyus]")
      |> mes("While you were gone,")
      |> mes("I felt a little bad that you")
      |> mes("were searching for the")
      |> mes("tablets pieces on your own,")
      |> mes("so I managed to find this")
      |> mes("piece here in Morocc. But...")
      |> next()
      |> mes("[Sir Chilias'Tyus]")
      |> mes("Why are they glowing like")
      |> mes("this? In any case, we have")
      |> mes("this piece I found here in")
      |> mes("Morocc, and the pieces you")
      |> mes("found in Prontera and Payon. There's one more left in Geffen.")
      |> specialeffect2(:heal2)
      |> specialeffect(:heal2)
      |> next()
      |> mes("[Sir Chilias'Tyus]")
      |> mes("Anyway, on the tablet")
      |> mes("piece that I found, it")
      |> mes("says ''Hakim loved magic,")
      |> mes("and always enjoyed its")
      |> mes("wondrous city,'' so I'm sure")
      |> mes("the last piece is in Geffen.")
      |> next()
      |> mes("[Sir Chilias'Tyus]")
      |> mes("Please, take this third")
      |> mes("tablet piece and find the")
      |> mes("final piece so that we can")
      |> mes("fulfill my dear grandfather's")
      |> mes("greatest wish and forever")
      |> mes("seal away the Hellion's gem.")
      |> set_char_var(:HELLIONQ, 58)
      |> give_item(7335, 1)
      |> next()
      |> mes("[Sir Chilias'Tyus]")
      |> mes("When you get to Geffen,")
      |> mes("please speak to Welshyun,")
      |> mes("who's been helping me in")
      |> mes("creating a device to seal the")
      |> mes("gem's darkness. He is worthy of trust and will surely help us.")
      |> close()
    else
      smite_missing_pieces(ctx)
    end
  end

  defp quest_progress(ctx, step) when step > 57 and step < 66 do
    ctx
    |> mes("[Sir Chilias'Tyus]")
    |> mes("Please visit the")
    |> mes("sage named Welshyun")
    |> mes("in Geffen. We are good")
    |> mes("friends, so I am sure")
    |> mes("that you can trust him.")
    |> close()
  end

  defp quest_progress(ctx, 66) do
    if count_item(ctx, 7333) > 0 and count_item(ctx, 7334) > 0 and
         count_item(ctx, 7335) > 0 and count_item(ctx, 7336) > 0 do
      ctx
      |> mes("[Sir Chilias'Tyus]")
      |> mes("You have all four")
      |> mes("pieces of the tablet?")
      |> mes("That's great news! Ah,")
      |> mes("and the gem is embedded")
      |> mes("in each of the tablet pieces.")
      |> mes("We're so close to finishing!")
      |> next()
      |> ask_welshyun_to_combine()
      |> set_char_var(:HELLIONQ, 67)
      |> close()
    else
      smite_missing_pieces(ctx)
    end
  end

  defp quest_progress(ctx, 67), do: ctx |> ask_welshyun_to_combine() |> close()

  defp quest_progress(ctx, 68) do
    cond do
      count_item(ctx, 7332) > 0 and count_item(ctx, 7337) > 0 ->
        finish_with_eye(ctx)

      count_item(ctx, 7332) > 0 ->
        finish_without_eye(ctx)

      true ->
        ctx
        |> mes("[Sir Chilias'Tyus]")
        |> mes("Where is the complete")
        |> mes("tablet? We need that in")
        |> mes("order to extract the Hellion's")
        |> mes("gem in order to seal its power!")
        |> close()
    end
  end

  defp quest_progress(ctx, step) when step > 68 and step < 71, do: reunion(ctx)

  defp quest_progress(ctx, _step) do
    ctx |> mes("[Sir Chilias'Tyus]") |> mes("... ... ...") |> close()
  end

  defp greet(ctx) do
    ctx =
      ctx
      |> mes("[Sir Chilias'Tyus]")
      |> mes("Greetings...")
      |> mes("My name is Sir Chilias'Tyus.")
      |> mes("I've lived a long time here in")
      |> mes("Rune-Midgarts and I've come")
      |> mes("to see and know a lot of things. Power, jealously, hardship...")
      |> next()

    {ctx, choice} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("So what exactly")
      |> mes("brings you here to")
      |> mes("the middle of Morocc?")
      |> next()
      |> mes("[Sir Chilias'Tyus]")
      |> mes("This land has grown corrupt")
      |> mes("with the diseases of greed")
      |> mes("and selfishness. Everywhere")
      |> mes("you go, people are heartless,")
      |> mes("but I still believe that I'll find the one worthy enough to help me...")
      |> next()
      |> mes("[Sir Chilias'Tyus]")
      |> mes("There is no shortage of")
      |> mes("brave and strong warriors")
      |> mes("in these dangerous times.")
      |> mes("But for the thing I seek,")
      |> mes("I must have the help of one")
      |> mes("who is truly pure of heart...")
      |> next()
      |> select(["What are you looking for?", "Pure of heart? Hah! Good luck!"])

    if choice == 1 do
      hear_request(ctx)
    else
      ctx
      |> mes("[Sir Chilias'Tyus]")
      |> mes("Times are bad when")
      |> mes("even the youth have")
      |> mes("been jaded. But I refuse")
      |> mes("to believe that hope is")
      |> mes("truly lost in this age...")
      |> close()
    end
  end

  defp hear_request(ctx) do
    if base_level(ctx) < 60 do
      ctx
      |> mes("[Sir Chilias'Tyus]")
      |> mes("Heh heh~ I see your eyes")
      |> mes("glimmer with enthusiasm,")
      |> mes("but it seems this task might")
      |> mes("be a little too much for you.")
      |> mes("I'm sorry, but that's the")
      |> mes("reality I can't ignore...")
      |> next()
      |> mes("[Sir Chilias'Tyus]")
      |> mes("Go out in to the world,")
      |> mes("and grow in strength.")
      |> mes("Perhaps after you become")
      |> mes("more capable, I'll find that")
      |> mes("I can rely on your help.")
      |> close()
    else
      grandfathers_story(ctx)
    end
  end

  defp grandfathers_story(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sir Chilias'Tyus]")
      |> mes("I suppose I should tell you")
      |> mes("first about my grandfather,")
      |> mes("who was once a young and")
      |> mes("feareless adventurer, much")
      |> mes("like yourself. Yes, he traveled the world with his three friends...")
      |> next()
      |> mes("[Sir Chilias'Tyus]")
      |> mes("The four of them went on")
      |> mes("many expeditions together")
      |> mes("and earned themselves a")
      |> mes("reputation as a courageous")
      |> mes("team that worked especially")
      |> mes("well together after many years.")
      |> next()
      |> mes("[Sir Chilias'Tyus]")
      |> mes("Then, on what was supposed")
      |> mes("to be a typical journey, they found an uncharted cave. Curious, and")
      |> mes("in need of rest, the four ventured inside. There, they encountered")
      |> mes("that most horrible creature...")
      |> next()
      |> mes("[Sir Chilias'Tyus]")
      |> mes("It was a ferocious beast")
      |> mes("with horns as large and as")
      |> mes("sharp as their weapons, with")
      |> mes("eyes that blazed with hellfire.")
      |> mes("My grandfather could tell that")
      |> mes("it was thirsty for blood.")
      |> next()
      |> mes("[Sir Chilias'Tyus]")
      |> mes("They ran from the beast")
      |> mes("as quickly as they could,")
      |> mes("but the four were separated")
      |> mes("in the cave's darkness. It was")
      |> mes("all they could do to hide in")
      |> mes("the darkness of the cave...")
      |> next()
      |> mes("[Sir Chilias'Tyus]")
      |> mes("From his hiding place, my")
      |> mes("grandfather heard the screams")
      |> mes("of his friends as the monster")
      |> mes("slaughtered them, one by one.")
      |> mes("The screams and the monster's")
      |> mes("growls were getting closer...")
      |> next()
      |> mes("[Sir Chilias'Tyus]")
      |> mes("Unable to endure the")
      |> mes("suffering of his trusted")
      |> mes("comrades, my grandfather")
      |> mes("jumped out hiding and tried")
      |> mes("to save his friends. The beast")
      |> mes("found him and they battled.")
      |> next()
      |> mes("[Sir Chilias'Tyus]")
      |> mes("It was no use. The beast")
      |> mes("was too powerful and my")
      |> mes("grandfather was knocked out.")
      |> mes("When he came to, his friends")
      |> mes("were all dead and a shining")
      |> mes("gem lay in a pool of blood.")
      |> next()
      |> mes("[Sir Chilias'Tyus]")
      |> mes("My grandfather buried")
      |> mes("his friends that day. He")
      |> mes("took that gem as a memento")
      |> mes("of their final expedition, but")
      |> mes("wondered why the beast")
      |> mes("had decided to spare him.")
      |> next()
      |> mes("[Sir Chilias'Tyus]")
      |> mes("It wasn't long before he")
      |> mes("experienced the gem's curse")
      |> mes("firsthand. The gem inexplicably")
      |> mes("drew people to it, taking the")
      |> mes("greed in their hearts and")
      |> mes("twisting their minds...")
      |> next()
      |> mes("[Sir Chilias'Tyus]")
      |> mes("Grandfather believed the")
      |> mes("beast let him live so that")
      |> mes("the gem would be set loose")
      |> mes("upon the outside world, free")
      |> mes("to pollute it with its evil. He had to do something...")
      |> next()
      |> mes("[Sir Chilias'Tyus]")
      |> mes("However, the gem proved")
      |> mes("to be formed out of pure evil")
      |> mes("and could not be destroyed")
      |> mes("by human means. In the end,")
      |> mes("my grandfather hid the gem")
      |> mes("someplace safe...")
      |> next()
      |> mes("[Sir Chilias'Tyus]")
      |> mes("However, the threat of the")
      |> mes("gem still exists. Grandfather")
      |> mes("and my father worked for years to find a way to seal its darkness.")
      |> mes("Only now have I been able to create a bracelet to seal its evil power.")
      |> next()
      |> mes("[Sir Chilias'Tyus]")
      |> mes("For my grandfather and his")
      |> mes("friends to truly rest in peace,")
      |> mes("I must find an adventurer of")
      |> mes("pure heart who can find the")
      |> mes("gem and bring it to me so that")
      |> mes("I can finally seal its power.")
      |> next()
      |> mes("[Sir Chilias'Tyus]")
      |> mes("I think... I think you")
      |> mes("might be the hero that")
      |> mes("I've been waiting for. Will")
      |> mes("you help an old man for the")
      |> mes("sake of all that is good?")
      |> next()
      |> select(["Of course, I will.", "I'm sorry, but I can't."])

    if choice == 1 do
      accept_request(ctx)
    else
      ctx |> understand_refusal() |> set_char_var(:HELLIONQ, 37) |> close()
    end
  end

  defp accept_request(ctx) do
    ctx
    |> mes("[Sir Chilias'Tyus]")
    |> mes("Good, good, but first")
    |> mes("I must test to see if you")
    |> mes("are worthy of holding the")
    |> mes("Hellion's gem. I can't tell")
    |> mes("you exactly where it is, but")
    |> mes("I will give you some clues.")
    |> next()
    |> mes("[Sir Chilias'Tyus]")
    |> mes("First, speak to Clanux")
    |> mes("Heffron in Prontera. He")
    |> mes("has offered to help me find")
    |> mes("the gem, but I do not know if")
    |> mes("I can trust him. Please help me protect this world from the gem...")
    |> set_char_var(:HELLIONQ, 36)
    |> close()
  end

  defp understand_refusal(ctx) do
    ctx
    |> mes("[Sir Chilias'Tyus]")
    |> mes("I understand...")
    |> mes("I know I am asking much")
    |> mes("of you, and this task is not")
    |> mes("one to take lightly. However,")
    |> mes("I believe that you are wholly")
    |> mes("capable of accomplishing this.")
  end

  defp reconsider_request(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sir Chilias'Tyus]")
      |> mes("So have you considered")
      |> mes("my proposal? I believe that")
      |> mes("you may be the one who will")
      |> mes("help me in sealing away the")
      |> mes("Hellion gem's evil forever.")
      |> next()
      |> select(["I will help you.", "...Sorry about that."])

    if choice == 1 do
      accept_request(ctx)
    else
      ctx |> understand_refusal() |> close()
    end
  end

  defp smite_missing_pieces(ctx) do
    ctx
    |> mes("[Sir Chilias'Tyus]")
    |> mes("Where are the tablet pieces?")
    |> mes("Have you hoarded them away")
    |> mes("to steal the Hellion's gem")
    |> mes("for yourself?! I must smite")
    |> mes("you now before you are")
    |> mes("consumed by its darkness!")
    |> close()
    |> percent_heal(hp: -100, sp: 0)
  end

  defp ask_welshyun_to_combine(ctx) do
    ctx
    |> mes("[Sir Chilias'Tyus]")
    |> mes("Ah, would you go back")
    |> mes("to Welshyun? I know it's")
    |> mes("a hassle, but he is probably")
    |> mes("the only one who can combine")
    |> mes("the tablet pieces into the its")
    |> mes("complete form. Thank you...")
  end

  defp begin_sealing(ctx) do
    ctx
    |> mes("[Sir Chilias'Tyus]")
    |> mes("At long last. We have")
    |> mes("everything. The Tablet")
    |> mes("and the Hellion's gem.")
    |> mes("Now I can finally use")
    |> mes("this bracelet to seal")
    |> mes("its power forever...")
    |> next()
  end

  defp reveal_grandfathers_fate(ctx) do
    ctx =
      ctx
      |> mes("[Sir Chilias'Tyus]")
      |> mes("But your eyes...")
      |> mes("They seem so tired")
      |> mes("and I can sense some")
      |> mes("sort of pain from them.")
      |> mes("Did something happen?")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("I learned the secret of")
      |> mes("the Hellion's gem. It...")
      |> mes("It turns people into")
      |> mes("Hellion Revenants.")
      |> mes("It's what happened")
      |> mes("to your grandfather...")
      |> next()
      |> mes("[Sir Chilias'Tyus]")
      |> mes("What...")
      |> mes("What did you just say?")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("The tablet had a map that")
      |> mes("let me to the chamber where")
      |> mes("your grandfather locked himself")
      |> mes("up before he completed turned")
      |> mes("into the Hellion Revenant.")
      |> mes("It was horrible...")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("At the entrance, he")
      |> mes("left a message that said")
      |> mes("that he wanted to be killed.")
      |> mes("So that he could finally join")
      |> mes("his friends instead of living")
      |> mes("as a monster. So I... So I...")
      |> next()
      |> mes("[Sir Chilias'Tyus]")
      |> mes("It's okay. I know you")
      |> mes("did the right thing. It's")
      |> mes("what my grandfather")
      |> mes("would have wanted most.")
      |> mes("Thank you for finally freeing")
      |> mes("his soul and giving him peace.")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Here, I think you")
    |> mes("should have this Eye")
    |> mes("of Hellion, in case you")
    |> mes("wanted a memento of")
    |> mes("your dear grandfather.")
    |> next()
    |> mes("[Sir Chilias'Tyus]")
    |> mes("I'd appreciate that.")
    |> mes("Grandfather's eye...")
    |> mes("It's full of the painful")
    |> mes("experiences of the people")
    |> mes("who were turned into Hellion")
    |> mes("Revenants against their will.")
    |> next()
    |> mes("[Sir Chilias'Tyus]")
    |> mes("But... Now is not the")
    |> mes("time for sentiment. For")
    |> mes("the sake of my grandfather,")
    |> mes("I must seal the power of")
    |> mes("the Hellion's gem now!")
    |> next()
  end

  defp seal_ritual(ctx) do
    ctx
    |> mes("[Sir Chilias'Tyus]")
    |> mes("Darkness that writhes,")
    |> mes("souls lost in the inferno,")
    |> mes("I offer you comfort, I offer")
    |> mes("you peace. To the despairing")
    |> mes("ones, to the shameless ones,")
    |> mes("I give guidance to heaven...")
    |> specialeffect(:beginspell)
    |> next()
    |> mes("[Sir Chilias'Tyus]")
    |> mes("Instead of sadness,")
    |> mes("let there be joy. Instead")
    |> mes("of anger, let there be")
    |> mes("love. Souls that are")
    |> mes("lost will now find")
    |> mes("their way...")
    |> specialeffect(:beginspell6)
    |> next()
    |> mes("[Sir Chilias'Tyus]")
    |> mes("Light and hope...")
    |> mes("Heaven and earth...")
    |> mes("Cast away the darkness.")
    |> specialeffect(:sanctuary)
    |> next()
    |> mes("[Sir Chilias'Tyus]")
    |> mes("I did it.")
    |> mes("After all these")
    |> mes("long years, I finally did")
    |> mes("it. Thanks to your help.")
    |> next()
    |> mes("[Sir Chilias'Tyus]")
    |> mes("Please take this")
    |> mes("Nile Rose, which will")
    |> mes("keep the power of the gem")
    |> mes("in check. I trust that you will")
    |> mes("keep its secret and protect it")
    |> mes("from those motivated by greed.")
    |> delitem(7332, 1)
  end

  defp thank_hero(ctx) do
    ctx
    |> mes("[Sir Chilias'Tyus]")
    |> mes("Thank you, kind")
    |> mes("adventurer, for bringing")
    |> mes("peace to my grandfather's")
    |> mes("soul and for working to")
    |> mes("protect peace in our world.")
    |> mes("You are the truest of heroes.")
  end

  defp finish_with_eye(ctx) do
    ctx =
      ctx
      |> begin_sealing()
      |> reveal_grandfathers_fate()
      |> seal_ritual()

    ctx =
      ctx
      |> delitem(7337, count_item(ctx, 7337))
      |> set_char_var(:HELLIONQ, 69)
      |> give_item(2658, 1)
      |> give_item(603, 1)

    ctx
    |> getexp(
      if(Rathena.truthy?(checkre(ctx, 3)),
        do: 120_000,
        else: 1_200_000
      ),
      0
    )
    |> next()
    |> thank_hero()
    |> next()
    |> mes("^3355FFYou have received the")
    |> mes("Nile Rose in which the")
    |> mes("Hellion's gem is sealed.")
    |> mes("The Eye of the Hellion has")
    |> mes("granted you some experience")
    |> mes("through its strange powers.^000000")
    |> close()
  end

  defp finish_without_eye(ctx) do
    ctx =
      ctx
      |> begin_sealing()
      |> seal_ritual()
      |> set_char_var(:HELLIONQ, 70)
      |> give_item(2658, 1)

    ctx
    |> getexp(
      if(
        Rathena.truthy?(checkre(ctx, 3)),
        do: 100_000,
        else: 1_000_000
      ),
      0
    )
    |> next()
    |> thank_hero()
    |> close()
  end

  defp reunion(ctx) do
    if count_item(ctx, 7337) > 0 do
      ctx =
        ctx
        |> mes("[Sir Chilias'Tyus]")
        |> mes("Long time no see. So, are you doing well to keep the promise with me?")
        |> mes("Please handle it with care")
        |> mes("to prevent the evil power within from being released.")
        |> next()
        |> mes("[Sir Chilias'Tyus]")
        |> mes("You still have the Hellion's Eye.")
        |> mes("I can see the pain in your eyes.")
        |> mes("Let me lighten your burden. It will be better this way.")

      ctx
      |> delitem(
        7337,
        count_item(ctx, 7337)
      )
      |> next()
      |> mes("[Sir Chilias'Tyus]")
      |> mes("May God bless you.")
      |> close()
    else
      ctx
      |> mes("[Sir Chilias'Tyus]")
      |> mes("Long time no see. So, are you doing well to keep the promise with me?")
      |> mes("Please handle it with care")
      |> mes("to prevent the evil power within from being released.")
      |> close()
    end
  end
end
