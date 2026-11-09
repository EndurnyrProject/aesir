defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Rin do
  @moduledoc """
  Rin, the injured guild investigator resting in the room behind Morocc, who sends the
  player to the mountain west of Abyss Lake for traces of Rayan's Dandelions.

  ## Behavior

  - Refuses the conversation while the player carries too many items.
  - `mao_morocc2` 5 asks who sent the player and, on "Mr. Kidd sent me.", tells the Rayan
    story and opens the investigation (step 6).
  - 6 hands out the location and advances quest 7015 to 7016 (step 7), 7 repeats the location,
    8 takes the Bloody Crystal of Darkness (6027) and hands over the Morocc Tracing Log (6029,
    quest 7017 to 7018, step 9), and 9 hurries the player back to Mr. Kidd.
  - Any other step only says she is resting.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_job01",
        x: 84,
        y: 17,
        dir: 3,
        sprite: 885,
        name: "Rin",
        scope: :shared,
        unique_name: "Rin#moc_room2_1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @dark_crystal 6027
  @tracing_log 6029

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if checkweight(ctx, [{714, 1}]) == 0 do
      overloaded(ctx)
    else
      at_step(ctx, get_char_var(ctx, :mao_morocc2, 0))
    end
  end

  # Every branch of the reference ends in `close2`, which keeps the script running, so the
  # portrait is cleared on the way out of each of them.
  defp hide_portrait(ctx), do: cutin(ctx, "moc2_rin03", 255)

  defp at_step(ctx, 5), do: first_meeting(ctx)
  defp at_step(ctx, 6), do: gives_the_location(ctx)
  defp at_step(ctx, 7), do: repeats_the_location(ctx)
  defp at_step(ctx, 8), do: reports_back(ctx)
  defp at_step(ctx, 9), do: sends_to_mr_kidd(ctx)
  defp at_step(ctx, _step), do: still_recovering(ctx)

  defp overloaded(ctx) do
    ctx
    |> mes("- You cannot proceed with the quest when you're carrying too many items with you. -")
    |> close()
  end

  defp still_recovering(ctx) do
    ctx
    |> cutin("moc2_rin03", 2)
    |> mes("[Rin]")
    |> mes("..Argh.. I'm still recovering .. I'm not supposed to move~")
    |> close()
    |> hide_portrait()
  end

  defp first_meeting(ctx) do
    ctx =
      if get_char_var(ctx, :mao_request, 0) > 103 do
        ctx
        |> mes("[Rin]")
        |> mes("...#{char_name(ctx, 0)}...?")
        |> mes("It's been a long time. What's going on?")
        |> cutin("moc2_rin02", 2)
      else
        ctx
        |> mes("[Rin]")
        |> mes("Who are you? Only authorized personnel can enter this area.")
        |> cutin("moc2_rin01", 2)
      end

    {ctx, choice} = ctx |> next() |> select(["Mr. Kidd sent me.", "Just passing by."])

    case choice do
      1 -> he_sent_me(ctx)
      2 -> just_passing_by(ctx) |> hide_portrait()
      _ -> ctx
    end
  end

  defp he_sent_me(ctx) do
    ctx =
      ctx
      |> cutin("moc2_rin02", 2)
      |> mes("[Rin]")
      |> mes("...?")
      |> mes("...Ah.. Ahh, I see.")
      |> mes("I haven't contacted him for a while, and so he's sent you to me...")
      |> mes("*Sigh*.. *Cough*.")
      |> next()
      |> cutin("moc2_rin01", 2)
      |> mes("[Rin]")
      |> mes(
        "As you see, I've been feeling under the weather. I'm in no condition to contact him."
      )
      |> mes("...Let me think. Where I should start..?")
      |> next()
      |> tells_about_rayan()

    {ctx, choice} =
      ctx
      |> mes("[Rin]")
      |> mes("Our job is primarily investigating Satan Morocc's whereabouts")
      |> mes("as well as the relation between the space gap and Satan Morocc...")
      |> next()
      |> mes("[Rin]")
      |> mes("We, however, couldn't let Rayan get away with what he's done")
      |> mes("I've been focusing on pursuing Rayan.")
      |> next()
      |> mes("[Rin]")
      |> mes("If we capture him, we might also find out some information about Satan Morocc:")
      |> mes(
        "we might be able to learn where he tried to summon Satan Morocc, and where we should send Satan Morocc back to..."
      )
      |> next()
      |> cutin("moc2_rin03", 2)
      |> mes("[Rin]")
      |> mes("I really want to know how the space gap is linked to Satan Morocc...")
      |> mes("*Pant Pant*... ...")
      |> next()
      |> select(["And then what?", "Don't strain yourself."])

    case choice do
      1 -> ctx |> asks_to_go_on() |> records_the_incident() |> hide_portrait()
      2 -> ctx |> accepts_the_concern() |> records_the_incident() |> hide_portrait()
      _ -> ctx
    end
  end

  # The reference prints this opening line without a speaker tag for two `mao_request` ranges and
  # with one everywhere else; every other line is shared.
  defp tells_about_rayan(ctx) do
    request = get_char_var(ctx, :mao_request, 0)

    opening =
      "I don't know if you know this, but something catastrophic happened in this town before Satan Morocc resurrected himself."

    ctx =
      if (request > 25 and request < 31) or (request > 125 and request < 129) do
        mes(ctx, opening)
      else
        ctx |> mes("[Rin]") |> mes(opening)
      end

    ctx
    |> next()
    |> mes("[Rin]")
    |> mes("R, otherwise known as 'Rayan,' performed a ritual to break Satan Morocc's seal.")
    |> next()
    |> mes("[Rin]")
    |> mes("We were able to gather a group of people and stop him from completing the ritual,")
    |> mes("and although the seal wasn't broken, he succeeded in weakening it.")
    |> next()
    |> mes("[Rin]")
    |> mes("Soon after we captured him, an army of monsters attacked this town")
    |> mes("as Satan Morocc's angry roars echoed in the air.")
    |> cutin("moc2_rin04", 2)
    |> next()
    |> mes("[Rin]")
    |> mes("R, otherwise known as Rayan, is responsible for these series of events.")
    |> mes("He caused everything that's happening now.")
    |> next()
  end

  defp asks_to_go_on(ctx) do
    ctx
    |> cutin("moc2_rin01", 2)
    |> mes("[Rin]")
    |> mes(
      "I'm sorry, but I'm not yet fully recovered... I need to speak slowly. Please bear with me."
    )
    |> next()
  end

  defp accepts_the_concern(ctx) do
    ctx
    |> cutin("moc2_rin01", 2)
    |> mes("[Rin]")
    |> mes("Thank you for your kindness.")
    |> mes("...*Pant Pant*...")
    |> next()
  end

  defp records_the_incident(ctx) do
    ctx
    |> mes("[Rin]")
    |> mes(
      "I received these injuries from Rayan and his gang. I finally located them after a long stakeout and pursuit..."
    )
    |> mes("......... ...")
    |> next()
    |> mes("[Rin]")
    |> mes("Yes... I need to write this down...")
    |> next()
    |> mes("- Mumbling something, she took down notes in an old notebook as she spoke. -")
    |> next()
    |> mes("[Rin]")
    |> mes("The Dandelions.. They're Rayan's puppets.")
    |> mes("I was ambushed by them in a mountain far from a village...")
    |> next()
    |> mes("[Rin]")
    |> mes("When I woke up, I was here.")
    |> mes(
      "Since then, my vision's been blurry. I guess that must have been caused by my injuries..."
    )
    |> next()
    |> mes("[Rin]")
    |> mes(
      "How'd you like to conduct an investigation around that area? We might find something.."
    )
    |> mes("Like important clues or where they've headed...")
    |> set_char_var(:mao_morocc2, 6)
    |> next()
    |> mes("[Rin]")
    |> mes("^4d4dffIf you're interested in helping me, I'll continue talking.^000000")
    |> close()
  end

  defp just_passing_by(ctx) do
    ctx
    |> cutin("moc2_rin03", 2)
    |> mes("[Rin]")
    |> mes("Did you just come by for no reason?")
    |> mes("...God, I can't believe just let you come here!")
    |> mes("Grr.. I need to teach them a lesson. Why can't they let me rest for God's sake!")
    |> next()
    |> mes("[Rin]")
    |> mes("I'm sorry, but I'm extremely tired and cranky.")
    |> mes("If you don't have anything important to tell me, then I'd like you to leave.")
    |> close()
  end

  defp gives_the_location(ctx) do
    ctx
    |> cutin("moc2_rin01", 2)
    |> mes("[Rin]")
    |> mes("So, are you interested in helping me?")
    |> mes("I remember the location was... Southwest from a village called Hugel.")
    |> mes("Do you know where to find Abyss Lake, where the Dragons reside?.")
    |> next()
    |> mes("[Rin]")
    |> mes(
      "^4d4dffWhen you pass Abyss Lake and head west,^000000 you'll arrive at stiff mountains."
    )
    |> mes(
      "I was ambushed somewhere ^4d4dffsouth of the second hill from the top of the mountain^000000"
    )
    |> next()
    |> mes("[Rin]")
    |> mes("They ganged up on me, but I put up a good fight...")
    |> mes("I'm sure I at least made them drop something..")
    |> mes("Please try to find something there that might serve as a clue.")
    |> next()
    |> mes("[Rin]")
    |> mes("While you're gone, I'll be preparing a document to send to Mr. Kidd.")
    |> mes("Be safe, and look out for yourself, okay?")
    |> set_char_var(:mao_morocc2, 7)
    |> changequest(7015, 7016)
    |> close()
    |> hide_portrait()
  end

  defp repeats_the_location(ctx) do
    ctx
    |> cutin("moc2_rin01", 2)
    |> mes("[Rin]")
    |> mes("I remember the location was...")
    |> mes("somewhere south of the second hill of a mountain west from Abyss Lake.")
    |> next()
    |> mes("[Rin]")
    |> mes("What are you looking at?")
    |> mes("How do I remember the location so clearly?")
    |> mes("It's the last location where I searched for Rayan. How can I not remember?")
    |> next()
    |> cutin("moc2_rin02", 2)
    |> mes("[Rin]")
    |> mes("Don't underestimate me; I'm an elite member of my guild.")
    |> close()
    |> hide_portrait()
  end

  defp reports_back(ctx) do
    ctx =
      ctx
      |> cutin("moc2_rin02", 2)
      |> mes("[Rin]")
      |> mes("Have you found anything?")
      |> next()
      |> mes("- You told her you couldn't find anything regarding their whereabouts,")
      |> mes("but you found the ''Bloody Crystal of Darkness'' in the bushes.")
      |> next()

    if count_item(ctx, @dark_crystal) > 0 do
      hand_over_the_log(ctx)
    else
      missing_the_crystal(ctx)
    end
  end

  defp hand_over_the_log(ctx) do
    ctx
    |> cutin("moc2_rin01", 2)
    |> mes("[Rin]")
    |> mes("..This is...it.")
    |> mes("You can feel the evil spirit just by looking at it.")
    |> mes(
      "This...there's no doubt. It's the same kind of crystal as the ones found on Satan Morocc and his minions."
    )
    |> next()
    |> cutin("moc2_rin04", 2)
    |> mes("[Rin]")
    |> mes("But...this crystal...left there..")
    |> mes("..Was it them who dropped it?")
    |> mes(
      "So it seems Rayan and Satan Morocc...there really is something going on between those two."
    )
    |> next()
    |> cutin("moc2_rin01", 2)
    |> mes("[Rin]")
    |> mes("You've worked hard. Thank you.")
    |> mes("Ha...")
    |> mes("Just lying here, not being able to do anything...it's so frustrating.")
    |> next()
    |> mes("[Rin]")
    |> mes("Here, take this journal to Mr. Kidd.")
    |> mes("It should've been done a while ago.")
    |> mes("Oh, bring this crystal to him as well.")
    |> next()
    |> mes("[Rin]")
    |> mes("Ah..the journal..Yes, I should record this incident onto the journal.")
    |> next()
    |> mes("......")
    |> next()
    |> mes("......")
    |> mes("......")
    |> next()
    |> cutin("moc2_rin02", 2)
    |> mes("[Rin]")
    |> mes("All done. Here you go.")
    |> mes("Here's the journal and the crystal.")
    |> mes("Take them to Mr. Kidd for me.")
    |> next()
    |> mes("- You received the journal from Rin.")
    |> mes("Instead of a journal, it's more like a bunch of documents being exchanged. -")
    |> set_char_var(:mao_morocc2, 9)
    |> give_item(@tracing_log, 1)
    |> changequest(7017, 7018)
    |> close()
    |> hide_portrait()
  end

  defp missing_the_crystal(ctx) do
    ctx =
      ctx
      |> cutin("moc2_rin01", 2)
      |> mes("[Rin]")
      |> mes("..A bloody Crystal of the Darkness?")
      |> mes("Can you show it to me?")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Oh, I don't have it with me. I'll go bring it right away.")
    |> mes("^4d4dff(Wait, what did I do with it? I didn't sell it or anything, did I?)^000000")
    |> close()
    |> hide_portrait()
  end

  defp sends_to_mr_kidd(ctx) do
    ctx
    |> cutin("moc2_rin03", 2)
    |> mes("[Rin]")
    |> mes("Hurry up; deliver the journal and crystal to Mr. Kidd.")
    |> mes("That's your job, isn't it?")
    |> mes("*Pant* I need to rest now..")
    |> next()
    |> mes("[Rin]")
    |> mes("My eyes are blurry...")
    |> mes("*Pant Pant*...")
    |> close()
    |> hide_portrait()
  end
end
