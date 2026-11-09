defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.MrKidd do
  @moduledoc """
  Mr. Kidd investigates Satan Morocc's trail and sends his assistant between Rin, the
  scholars, and the space gap.

  ## Behavior

  - Refuses overloaded players and recruits Echinacea's assistant to gather information from Rin.
  - Takes Rin's journal and the Bloody Crystal of Darkness, rewards experience, and sends
    the player through the space gap when it is available.
  - Refers the recovered spell scroll to the scholars and directs the player to investigate
    Rayan's hideout.
  - Receives reports, returns the crystal and journal for delivery to Rin, and answers
    questions about the final assignment.
  - Accepts two Nice Sweet Potatoes from Defaria and answers questions about Dandelion or
    Arunafeltz.

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
        map: "mid_camp",
        x: 199,
        y: 311,
        dir: 7,
        sprite: 884,
        name: "Mr. Kidd",
        scope: :shared,
        unique_name: "Mr. Kidd#ep13_dan01"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: set_server_temp_var(ctx, "moc_mao_gate1", 0)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if checkweight(ctx, [{714, 1}]) == 0 do
      overloaded(ctx)
    else
      at_step(ctx, get_char_var(ctx, :mao_morocc2, 0))
    end
  end

  defp at_step(ctx, step) do
    cond do
      step == 1 -> offered_assistant(ctx)
      step == 2 -> forced_assistant(ctx)
      step == 3 -> reluctant_assistant(ctx)
      step == 4 or step == 5 -> find_rin(ctx)
      step > 5 and step < 9 -> helping_rin(ctx)
      step == 9 -> deliver_journal(ctx)
      step == 10 -> touch_crystal(ctx)
      step == 11 or step == 12 -> return_from_past(ctx)
      step == 13 or step == 14 -> find_scholar(ctx)
      step == 15 -> unseal_scroll(ctx)
      step == 16 -> encouragement(ctx)
      step == 17 -> investigate_scroll(ctx)
      step == 18 -> report_clues(ctx)
      step == 19 -> monitor_rayan(ctx)
      step == 20 -> captured_rayan(ctx)
      step == 21 -> deliver_to_rin(ctx)
      step > 21 and step < 31 -> assist_rin(ctx)
      step > 30 and step < 104 -> thanks_for_service(ctx)
      step == 104 -> sweet_potatoes(ctx)
      step > 104 -> mission_boundaries(ctx)
      true -> guard_space_gap(ctx)
    end
  end

  defp overloaded(ctx) do
    ctx
    |> mes("- You cannot proceed with the quest when you're carrying too many items with you. -")
    |> close()
  end

  defp hide_portrait(ctx), do: cutin(ctx, "mocseal_kid01", 255)

  defp offered_assistant(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("mocseal_kid01", 2)
      |> mes("[Mr. Kidd]")
      |> mes("Hey, you.")
      |> mes("Don't get too close to anything except the gate.")
      |> mes("It's too dangerous.")
      |> next()
      |> mes("[Mr. Kidd]")
      |> mes("......Do you have any business here?")
      |> next()
      |> select(["Echinacea...", "No."])

    case choice do
      1 -> offers_chore(ctx)
      2 -> no_business(ctx)
      _ -> ctx
    end
  end

  defp offers_chore(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Mr. Kidd]")
      |> mes("An assistant? I don't think I need one, but...")
      |> mes("I guess I should give you something to do.")
      |> mes("Do you mind if I entrust you with a chore?")
      |> next()
      |> select(["Yes.", "No, I don't mind at all."])

    case choice do
      1 -> refuses_chore(ctx)
      2 -> accepts_chore(ctx)
      _ -> ctx
    end
  end

  defp refuses_chore(ctx) do
    ctx
    |> mes("[Mr. Kidd]")
    |> mes("Then why did you come all this way?")
    |> mes(
      "I didn't really need any help to begin with. If you don't want to work, then stop bothering me."
    )
    |> next()
    |> mes("[Mr. Kidd]")
    |> mes(
      "If you don't want to help us out then go back to Echinacea and let her know yourself!"
    )
    |> set_char_var(:mao_morocc2, 2)
    |> changequest(7012, 7013)
    |> close()
    |> hide_portrait()
  end

  defp accepts_chore(ctx) do
    ctx
    |> mes("[Mr. Kidd]")
    |> mes("......")
    |> mes("I don't know if Echinacea told you this already, but we are here")
    |> mes("to follow the traces of Satan Morocc.")
    |> mes("Some of us are here in the Ash Vacuum, and the rest are on the Midgard Continent.")
    |> next()
    |> mes("[Mr. Kidd]")
    |> mes(
      "We exchange information with our colleagues in Morocc on a regular basis, but we haven't heard from them for a while."
    )
    |> mes("How'd you like to go gather some information for me?")
    |> mes("It should be simple, so you I hope you'll be able to handle this.")
    |> next()
    |> mes("[Mr. Kidd]")
    |> mes("At Southwest Morocc, you'll find an underground tavern.")
    |> mes("Go find ^4d4dffRin^000000.")
    |> mes("Tell her I've sent you, and she'll take care of you.")
    |> set_char_var(:mao_morocc2, 4)
    |> changequest(7012, 7015)
    |> close()
    |> hide_portrait()
  end

  defp no_business(ctx) do
    ctx
    |> mes("[Mr. Kidd]")
    |> mes("If you don't have any business here, then step aside. It's too dangerous.")
    |> mes(
      "You might not be able to return to this world if you enter a route that hasn't been properly identified."
    )
    |> close()
    |> hide_portrait()
  end

  defp forced_assistant(ctx) do
    ctx
    |> cutin("moc2_kid02", 2)
    |> mes("[Mr. Kidd]")
    |> mes(
      "I guess she forced you to do this, huh? Don't worry; you're not the first victim of her bossiness."
    )
    |> mes("You should tell her if you really don't want to work for me.")
    |> close()
    |> hide_portrait()
  end

  defp reluctant_assistant(ctx) do
    ctx
    |> cutin("moc2_kid05", 2)
    |> mes("[Mr. Kidd]")
    |> mes("I can tell you aren't so happy with this, huh?")
    |> mes("While you're here, why don't you help us out and see where it goes?")
    |> mes("Don't worry, I won't give you a hard time...")
    |> next()
    |> cutin("mocseal_kid01", 2)
    |> mes("[Mr. Kidd]")
    |> mes("......")
    |> mes(
      "I don't know if Echinacea told you this already, but we are here to follow the traces of Satan Morocc."
    )
    |> next()
    |> mes("[Mr. Kidd]")
    |> mes("Some of us are here in the Ash Vacuum, and the rest are on the Midgard Continent.")
    |> next()
    |> mes("[Mr. Kidd]")
    |> mes(
      "We exchange information with our colleagues in Morocc on a regular basis, but we haven't heard from them for a while."
    )
    |> next()
    |> mes("[Mr. Kidd]")
    |> mes("How'd you like to go gather some information for me?")
    |> mes("It should be simple, so you I hope you'll be able to handle this.")
    |> next()
    |> mes("[Mr. Kidd]")
    |> mes("At Southwest Morocc, you'll find an underground tavern.")
    |> mes("Go find ^4d4dffRin^000000.")
    |> mes("Tell her I've sent you, and she'll take care of you.")
    |> set_char_var(:mao_morocc2, 4)
    |> changequest(7014, 7015)
    |> close()
    |> hide_portrait()
  end

  defp find_rin(ctx) do
    ctx
    |> cutin("mocseal_kid01", 2)
    |> mes("[Mr. Kidd]")
    |> mes("Let me explain one more time.")
    |> mes("Go speak to Rin in an underground tavern at Southwest Morocc.")
    |> mes("You won't miss the tavern if you look for a boy named Jack standing out the front.")
    |> close()
    |> hide_portrait()
  end

  defp helping_rin(ctx) do
    ctx
    |> cutin("moc2_kid03", 2)
    |> mes("[Mr. Kidd]")
    |> mes("Are you helping Rin?")
    |> mes("..I see.")
    |> close()
    |> hide_portrait()
  end

  defp deliver_journal(ctx) do
    if count_item(ctx, 6029) == 1 and count_item(ctx, 6027) == 1 do
      accepts_journal(ctx)
    else
      missing_journal(ctx)
    end
  end

  defp accepts_journal(ctx) do
    {ctx, _} =
      ctx
      |> cutin("mocseal_kid01", 2)
      |> mes("[Mr. Kidd]")
      |> mes("I heard Rin is wounded and bedridden...")
      |> mes("What happened?")
      |> next()
      |> mes("- Instead of an answer, you gave him Rin's journal and the bloody crystal.-")
      |> next()
      |> mes("[Mr. Kidd]")
      |> mes("...A journal? I see. Hopefully this'll help me understand the situation..")
      |> mes("Hmm...")
      |> next()
      |> mes("......")
      |> next()
      |> mes("......")
      |> mes("............")
      |> next()
      |> cutin("moc2_kid03", 2)
      |> mes("[Mr. Kidd]")
      |> mes("*Sigh*..")
      |> mes("So Rayan has finally been located, huh?")
      |> mes("There was a skirmish at the mountain, and.. a raid...")
      |> mes("..So, how is she?")
      |> next()
      |> select(["Huh?"])

    ctx =
      ctx
      |> cutin("mocseal_kid01", 2)
      |> mes("[Mr. Kidd]")
      |> mes("I mean Rin. How is she?")
      |> mes("Is she seriously wounded?")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("She needs to spend some time in bed,")
      |> mes("but she's conscious and still in one piece.")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("She seems to have no problem taking care of herself,")
      |> mes(
        "but I'm worried because sometimes she looks extremely exhausted. She mentioned that her vision blurs when she's very tired.."
      )
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes(
        "Don't worry; I don't think it's serious because she still had the strength to yell while writing that journal."
      )
      |> next()
      |> cutin("moc2_kid03", 2)
      |> mes("[Mr. Kidd]")
      |> mes("..Wh.. Who said I'm worried?")
      |> mes("I asked about her because I don't want her injury to interfere with our schedule.")
      |> next()
      |> mes("[Mr. Kidd]")
      |> mes("As for you, I want you to come back later.")
      |> mes("You're my assistant, remember?")
      |> mes("I need you to substitute for Rin until she recovers..")
      |> mes("Is that understood?")
      |> next()
      |> cutin("moc2_kid05", 2)
      |> mes("[Mr. Kidd]")
      |> mes("Hm, thanks for all your help.")
      |> mes(
        "Now, would you leave me alone for a while? I need to write a report based on the findings in this journal."
      )
      |> delitem(6029, 1)
      |> delitem(6027, 1)
      |> set_char_var(:mao_morocc2, 10)

    ctx =
      if Rathena.truthy?(checkre(ctx, 3)) do
        getexp(ctx, 20_000, 1000)
      else
        getexp(ctx, 200_000, 10_000)
      end

    ctx
    |> changequest(7018, 7019)
    |> close()
    |> hide_portrait()
  end

  defp missing_journal(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes(
      "(I was supposed to give him the 'Morocc Pursuit Journal' and a 'Bloody Crystal of the Darkness'..."
    )
    |> mes("Err? Where have they gone? I need to find them.)")
    |> close()
    |> hide_portrait()
  end

  defp touch_crystal(ctx) do
    ctx =
      ctx
      |> mes(
        "Kidd is standing at the side of the space gap, leafing through the journal's pages and taking notes."
      )
      |> mes("The 'Bloody Crystal of Darkness' is sitting aside, and remains untouched.")
      |> next()
      |> mes("I feel the crystal resonating with the space gap.")
      |> mes("I suddenly have the urge to touch the crystal...")
      |> next()
      |> mes("[Mr. Kidd]")
      |> mes("Err? What are you trying to do?")
      |> next()

    if get_server_temp_var(ctx, "moc_mao_gate1", 0) == 0 do
      ctx
      |> warp("que_dan01", 32, 27)
      |> set_server_temp_var("moc_mao_gate1", 1)
    else
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("No, nothing.")
      |> mes("I'm sorry if I bothered you while you were writing your report.")
      |> next()
      |> mes(
        "- Kidd stopped you from touching the crystal, but somehow, it still captivates you. -"
      )
      |> close()
      |> hide_portrait()
    end
  end

  defp return_from_past(ctx) do
    {ctx, _} =
      ctx
      |> cutin("moc2_kid02", 2)
      |> mes("[Mr. Kidd]")
      |> mes("..Are.. Are you alright?")
      |> mes("What just happened?")
      |> next()
      |> select(["Err.. Huh?!"])

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("..Err?")
      |> mes("..Kidd? Someone was calling my name...")
      |> mes("Rin! Where's Rin? What about Rayan?")
      |> next()
      |> mes("[Mr. Kidd]")
      |> mes("Rin? Rayan?")
      |> mes("What are you talking about?")
      |> mes("Where the hell have you been?")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("What do you mean..")
      |> mes("Where I've been?")
      |> mes("..Oh yeah, I saw Rin fighting Rayan.")
      |> mes("She was defeated by magic, and then disappeared...")
      |> next()

    {ctx, _} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Ah?! Ah! Right!")
      |> mes("I heard your voice once I found a strange scroll.")
      |> mes("The scroll!")
      |> next()
      |> mes(
        "- Ignoring the confused look on Mr. Kidd's face, you searched your pockets, and found the mysterious scroll. -"
      )
      |> next()
      |> mes("- It wasn't a dream after all... What you saw actually happened. -")
      |> mes("- You show Kidd the scroll and tell him what happened. -")
      |> next()
      |> cutin("mocseal_kid01", 2)
      |> mes("[Mr. Kidd]")
      |> mes("... ..")
      |> mes(".. Basically,")
      |> mes("you found this from a member of Rayan's gang?")
      |> next()
      |> mes("[Mr. Kidd]")
      |> mes("I know what this is:")
      |> mes(
        "it's a scroll containing a magic spell that can be used by anyone, even if they aren't trained as mages."
      )
      |> next()
      |> cutin("moc2_kid04", 2)
      |> mes("[Mr. Kidd]")
      |> mes("Hmm, this scroll is sealed and needs some kind of pass code to use it.")
      |> mes("I'll consult with the camp scholars about this scroll later.")
      |> next()
      |> cutin("mocseal_kid01", 2)
      |> mes("[Mr. Kidd]")
      |> mes("By the way, I saw you touch this 'Bloody Crystal of Darkness.'")
      |> mes(
        "There was a bright flash of light around you, and then you were suddenly drawn into the space gap."
      )
      |> next()
      |> mes("[Mr. Kidd]")
      |> mes("I thought I was just seeing things, but it's obvious now that it really happened.")
      |> mes("You were actually in the past for a little while there.")
      |> next()
      |> mes("[Mr. Kidd]")
      |> mes("I'm afraid this space gap hides bigger secrets than we thought.")
      |> mes("..It not only warps space, but also time ...")
      |> next()
      |> select(["It warps space and time?"])

    ctx
    |> cutin("moc2_kid03", 2)
    |> mes("[Mr. Kidd]")
    |> mes("Forget it. I was just thinking out loud.")
    |> mes(
      "From now on, we should be extra careful about letting anything into this space gap. I need to report this incident to upper management."
    )
    |> next()
    |> mes("[Mr. Kidd]")
    |> mes("I'm sorry, but can you ask a scholar about this spell scroll?")
    |> mes(
      "If you don't know which scholar you should consult, then you'd better ^4d4dffask Echinacea^000000"
    )
    |> next()
    |> mes("[Mr. Kidd]")
    |> mes("Thanks in advance.")
    |> set_char_var(:mao_morocc2, 13)
    |> changequest(7021, 7022)
    |> close()
    |> hide_portrait()
  end

  defp find_scholar(ctx) do
    ctx
    |> cutin("mocseal_kid01", 2)
    |> mes("[Mr. Kidd]")
    |> mes("Did you find a scholar to ask about the scroll?")
    |> mes("Huh? Not yet?")
    |> mes("If you don't know which scholar to consult, then you'd better ask Echinacea.")
    |> close()
    |> hide_portrait()
  end

  defp unseal_scroll(ctx) do
    ctx
    |> cutin("mocseal_kid01", 2)
    |> mes("[Mr. Kidd]")
    |> mes("So this scroll is from Arunafeltz, huh?")
    |> mes("Is that why you're gathering items to unseal the scroll?")
    |> next()
    |> cutin("moc2_kid03", 2)
    |> mes("[Mr. Kidd]")
    |> mes("I see...")
    |> next()
    |> mes("- Kidd is lost in thought. -")
    |> mes("- Let's bring Defaria the items to unseal the spell scroll. -")
    |> close()
    |> hide_portrait()
  end

  defp encouragement(ctx) do
    ctx
    |> cutin("moc2_kid05", 2)
    |> mes("[Mr. Kidd]")
    |> mes("Keep up the good work, adventurer.")
    |> close()
    |> hide_portrait()
  end

  defp investigate_scroll(ctx) do
    if count_item(ctx, 14_595) > 0 do
      assigns_investigation(ctx)
    else
      asks_about_scroll(ctx)
    end
  end

  defp assigns_investigation(ctx) do
    {ctx, _} =
      ctx
      |> cutin("mocseal_kid01", 2)
      |> mes("[Mr. Kidd]")
      |> mes("This must be the spell scroll, huh?")
      |> mes("It contains a teleportation spell")
      |> mes("that will send the user to a specific location.. Hmm...")
      |> next()
      |> cutin("moc2_kid03", 2)
      |> mes("[Mr. Kidd]")
      |> mes("You said you've heard Rayan ordering others to come to a certain place.")
      |> mes("If the spell of this scroll leads to that place..")
      |> mes(".... . No, it's too dangerous.")
      |> next()
      |> cutin("mocseal_kid01", 2)
      |> mes("[Mr. Kidd]")
      |> mes("Then again.. Somebody will have to go there eventually..")
      |> mes("... .. .. .")
      |> next()
      |> select(["Why are you looking at me?!"])

    ctx =
      ctx
      |> cutin("moc2_kid05", 2)
      |> mes("[Mr. Kidd]")
      |> mes("You're my assistant, aren't you?")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes(".... .....")
    |> mes("......")
    |> next()
    |> cutin("moc2_kid04", 2)
    |> mes("[Mr. Kidd]")
    |> mes(
      ".Alright, then. Would you rather capture reincarnations of Morocc and collect their remnants?"
    )
    |> mes(
      "Scholars suspect the recent space-time phenomenon has been caused by the 'Bloody Crystals of the Darkness,'"
    )
    |> mes(
      "so they want to study the crystals, which they believe are remnants of the of Morocc's reincarnations."
    )
    |> next()
    |> mes("[Mr. Kidd]")
    |> mes("That sounds way more dangerous, doesn't it? Go check that place out instead.")
    |> mes(
      "Both those missions are dangerous, but I think you'll be risking your life less by checking out that place."
    )
    |> next()
    |> cutin("mocseal_kid01", 2)
    |> mes("[Mr. Kidd]")
    |> mes(
      "Now, listen. Use the spell scroll to teleport there, and then investigate the area. Find some clues."
    )
    |> mes("Don't fight them.")
    |> mes("Don't put yourself in danger, and retreat when things get too dangerous.")
    |> next()
    |> mes("[Mr. Kidd]")
    |> mes("By the time you come back,")
    |> mes("we should have figured out the cause of the strange phenomenon near this space gap.")
    |> mes("We'll think about everything else after you come back, alright?")
    |> close()
    |> hide_portrait()
  end

  defp asks_about_scroll(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("mocseal_kid01", 2)
      |> mes("[Mr. Kidd]")
      |> mes("Where's the scroll? Did you use it?")
      |> next()
      |> select(["Yes.", "No."])

    case choice do
      1 -> used_scroll(ctx)
      2 -> lost_scroll(ctx)
      _ -> ctx
    end
  end

  defp used_scroll(ctx) do
    ctx
    |> mes("[Mr. Kidd]")
    |> mes("That scroll contains a teleportation spell.")
    |> mes("Using it will lead you to a place that has something to do with them.")
    |> mes("You're supposed to gather some clues once you're there.")
    |> next()
    |> mes("[Mr. Kidd]")
    |> mes("..I guess you haven't found any clues.")
    |> mes("Do you remember the location of that place?")
    |> mes("Why don't you go it check out again?")
    |> next()
    |> mes("[Mr. Kidd]")
    |> mes("I'm sure you'll find something.")
    |> mes("Yes, there must be some sort of clue there.")
    |> mes("Do you understand?")
    |> close()
    |> hide_portrait()
  end

  defp lost_scroll(ctx) do
    ctx
    |> mes("[Mr. Kidd]")
    |> mes("That scroll contains a teleportation spell.")
    |> mes("Using it will lead you to a place that has something to do with them.")
    |> mes("You're supposed to gather some clues once you're there.")
    |> next()
    |> mes("[Mr. Kidd]")
    |> mes("If you lost the scroll, I expect you to find that place at any cost.")
    |> mes("Is that clear?")
    |> close()
    |> hide_portrait()
  end

  defp report_clues(ctx) do
    ctx
    |> cutin("mocseal_kid01", 2)
    |> mes("[Mr. Kidd]")
    |> mes("Did you find any clues?")
    |> mes("What did you find over there?")
    |> next()
    |> mes(
      "- You interrupted Mr. Kidd, and told him what you heard from the basement in the empty house near the national border. -"
    )
    |> next()
    |> mes("[Mr. Kidd]")
    |> mes("..Are you sure?")
    |> mes("And the location is.. Okay, I got it.")
    |> mes("Thanks.")
    |> next()
    |> cutin("moc2_kid03", 2)
    |> mes("[Mr. Kidd]")
    |> mes("Can you go back and spy on them a bit more?")
    |> mes("I'll follow you as soon as I report these findings to the higher-ups.")
    |> set_char_var(:mao_morocc2, 19)
    |> changequest(7027, 7028)
    |> close()
    |> hide_portrait()
  end

  defp monitor_rayan(ctx) do
    ctx
    |> cutin("mocseal_kid01", 2)
    |> mes("[Mr. Kidd]")
    |> mes("They must be having a serious internal dispute,")
    |> mes("meaning it's the perfect time for us to raid them.")
    |> mes("Keep monitoring them for me, alright?")
    |> close()
    |> hide_portrait()
  end

  defp captured_rayan(ctx) do
    {ctx, _} =
      ctx
      |> cutin("mocseal_kid01", 2)
      |> mes("[Mr. Kidd]")
      |> mes("..Phew, now I've seen everything.")
      |> mes("Oh, hey!")
      |> next()
      |> select(["Where's Rayan?"])

    {ctx, _} =
      ctx
      |> cutin("moc2_kid03", 2)
      |> mes("[Mr. Kidd]")
      |> mes("He's locked up in the basement, and Rin is interrogating him.")
      |> mes(
        "You know, she's the best interrogator we've got. There'll be no escape for that guy .."
      )
      |> next()
      |> cutin("moc2_kid05", 2)
      |> mes("[Mr. Kidd]")
      |> mes("..Wait, what if the same thing happens..?")
      |> mes("No way, that's not possible..")
      |> next()
      |> mes("[Mr. Kidd]")
      |> mes("The crystal no longer resonates with the space gap.")
      |> mes("Now it's exactly the same as a regular Crystal of Darkness.")
      |> next()
      |> mes("[Mr. Kidd]")
      |> mes(
        "That means, the phenomenon that you've experienced with the 'Bloody Crystal of Darkness' can't be.."
      )
      |> mes(".........")
      |> next()
      |> select(["Can't be explained?"])

    {ctx, choice} =
      ctx
      |> cutin("mocseal_kid01", 2)
      |> mes("[Mr. Kidd]")
      |> mes("..I guess not. It might have resonated to your mana or wavelength.")
      |> mes(
        "Why don't you carry it with you? Let me know if you experience any strange phenomenon again."
      )
      |> next()
      |> mes("[Mr. Kidd]")
      |> mes("Oh, and please bring ^4d4dffthis journal to Rin^000000.")
      |> mes("This will be your last assignment from me.")
      |> set_char_var(:mao_morocc2, 21)
      |> give_item(6027, 1)
      |> give_item(6029, 1)
      |> changequest(7029, 7030)
      |> next()
      |> mes("[Mr. Kidd]")
      |> mes("..Do you have any questions?")
      |> next()
      |> select([
        "Is this an exchange journal?",
        "Why should I carry the crystal?",
        "What is this last assignment?"
      ])

    case choice do
      1 -> ctx |> explains_shared_journal() |> last_assignment_reminder()
      2 -> ctx |> explains_crystal() |> last_assignment_reminder()
      3 -> ctx |> explains_last_assignment() |> last_assignment_reminder()
      _ -> ctx
    end
  end

  defp explains_shared_journal(ctx) do
    ctx =
      ctx
      |> cutin("moc2_kid04", 2)
      |> mes("[Mr. Kidd]")
      |> mes("..No, not at all.")
      |> mes("We're just using one journal to record each other's work.")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Why can't you use separate journals and then combine them later?")
    |> next()
    |> cutin("mocseal_kid01", 2)
    |> mes("[Mr. Kidd]")
    |> mes("......")
    |> mes("Ask Echinacea. I'm just doing what the boss tells me to do.")
    |> mes(
      "Using one set journal is a good way to keep in contact and accumulate a history of work in chronological order."
    )
    |> next()
    |> mes("[Mr. Kidd]")
    |> mes("We came up with the idea to share our experiences")
    |> mes("and understand any relation between incidents")
    |> mes("as quickly and easily as possible..")
    |> next()
    |> mes("[Mr. Kidd]")
    |> mes(
      "I know it's a little bit counterproductive, but I'm satisfied with the quality of information shared between us."
    )
    |> mes(
      "The notes that Rin has absent-mindedly written down can turn out to be great clues for me.."
    )
    |> next()
    |> cutin("moc2_kid05", 2)
    |> mes("[Mr. Kidd]")
    |> mes("Yeah, I agree that the journal looks pretty disorganized.")
    |> next()
  end

  defp explains_crystal(ctx) do
    ctx
    |> cutin("moc2_kid04", 2)
    |> mes("[Mr. Kidd]")
    |> mes("... Intuition... I guess?")
    |> mes("... These kind of things.")
    |> next()
  end

  defp explains_last_assignment(ctx) do
    ctx
    |> cutin("mocseal_kid01", 2)
    |> mes("[Mr. Kidd]")
    |> mes("Rayan has already been caught, so the task to locate him and Rin is already done.")
    |> mes("You were just an assistant to start with.")
    |> next()
  end

  defp last_assignment_reminder(ctx) do
    ctx
    |> cutin("moc2_kid03", 2)
    |> mes("[Mr. Kidd]")
    |> mes("Anyways, please deliver the journal to her safely.")
    |> mes("I'm still not done yet; Echinacea already has another task for me..")
    |> mes("..*Sigh*..")
    |> close()
    |> hide_portrait()
  end

  defp deliver_to_rin(ctx) do
    ctx
    |> cutin("mocseal_kid01", 2)
    |> mes("[Mr. Kidd]")
    |> mes("I asked you to deliver the journal to Rin.")
    |> mes("You didn't forget it, did you?")
    |> mes("...")
    |> next()
    |> mes("[Mr. Kidd]")
    |> mes("By the way, I'm still not convinced that we've captured the real Rayan.")
    |> mes("Will you tell Rin to write down the results of her interrogation in the journal?")
    |> next()
    |> mes("[Mr. Kidd]")
    |> mes("Of course, I'm pretty sure she'll do it without me reminding her.")
    |> close()
    |> hide_portrait()
  end

  defp assist_rin(ctx) do
    ctx
    |> cutin("mocseal_kid01", 2)
    |> mes("[Mr. Kidd]")
    |> mes("You don't have to report everything to me.")
    |> mes("I can check the journal later.")
    |> mes("Why don't you go assist Rin for now?")
    |> close()
    |> hide_portrait()
  end

  defp thanks_for_service(ctx) do
    ctx
    |> cutin("moc2_kid05", 2)
    |> mes("[Mr. Kidd]")
    |> mes("..Things didn't turn out exactly as we hoped, but there's nothing we can do for now.")
    |> mes("Thank you for your service;")
    |> mes("you've been of great help to us.")
    |> close()
    |> hide_portrait()
  end

  defp sweet_potatoes(ctx) do
    if count_item(ctx, 549) > 1 do
      accepts_potatoes(ctx)
    else
      missing_potatoes(ctx)
    end
  end

  defp accepts_potatoes(ctx) do
    {ctx, _} =
      ctx
      |> cutin("mocseal_kid01", 2)
      |> mes("[Mr. Kidd]")
      |> mes("What's up?")
      |> mes(
        "I told you that I won't have any more work available for you. Well, for a good while, anyway.."
      )
      |> next()
      |> select(["Want a snack?", "Mr. Defaria has sent me."])

    {ctx, choice} =
      ctx
      |> cutin("moc2_kid05", 2)
      |> mes("[Mr. Kidd]")
      |> mes("..I guess he's finally made a fire, huh?")
      |> mes("Tell him thanks for these sweet potatoes.")
      |> delitem(549, 2)
      |> set_char_var(:mao_morocc2, 105)
      |> next()
      |> select(["Ask about Dandelion.", "Ask about Arunafeltz."])

    case choice do
      1 -> about_dandelion(ctx)
      2 -> about_arunafeltz(ctx)
      _ -> ctx
    end
  end

  defp about_dandelion(ctx) do
    ctx
    |> cutin("moc2_kid03", 2)
    |> mes("[Mr. Kidd]")
    |> mes("I'm indebted to them, but they all died before I had a chance to pay them back.")
    |> next()
    |> mes("[Mr. Kidd]")
    |> mes("If you're asking about my political opinion, I'm not going to answer.")
    |> mes("This isn't something with which I can interfere.")
    |> next()
    |> cutin("moc2_kid04", 2)
    |> mes("[Mr. Kidd]")
    |> mes("My personal opinion?")
    |> mes("Let me tell you that, from their point of view; their one last chance was destroyed.")
    |> mes("They're probably too ashamed to even talk about it.")
    |> next()
    |> mes("[Mr. Kidd]")
    |> mes("Let our diplomats use that fact to their advantage, alright?")
    |> close()
    |> hide_portrait()
  end

  defp about_arunafeltz(ctx) do
    ctx
    |> cutin("mocseal_kid01", 2)
    |> mes("[Mr. Kidd]")
    |> mes("Nothing.")
    |> mes("I have no comments.")
    |> mes("No conflicts have arisen recently, either.")
    |> next()
    |> cutin("moc2_kid04", 2)
    |> mes("[Mr. Kidd]")
    |> mes("Besides, nationality isn't important to us.")
    |> mes(
      "What's important is whether or not they're our enemies, and whether or not they're the target of our missions."
    )
    |> close()
    |> hide_portrait()
  end

  defp missing_potatoes(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Err? I don't have two Nice Sweet Potatoes..")
    |> mes("Where can I get those?")
    |> close()
    |> hide_portrait()
  end

  defp mission_boundaries(ctx) do
    ctx
    |> cutin("mocseal_kid01", 2)
    |> mes("[Mr. Kidd]")
    |> mes("Don't try to understand everything.")
    |> mes("A mission is just a mission.")
    |> mes("Don't get too emotional or curious about it.")
    |> close()
    |> hide_portrait()
  end

  defp guard_space_gap(ctx) do
    ctx
    |> cutin("mocseal_kid01", 2)
    |> mes("[Mr. Kidd]")
    |> mes("...You'd better not approach the space gap off the official route.")
    |> mes(
      "If you're not authorized, then turn away. This thing is too dangerous for capricious exploration."
    )
    |> close()
    |> hide_portrait()
  end
end
