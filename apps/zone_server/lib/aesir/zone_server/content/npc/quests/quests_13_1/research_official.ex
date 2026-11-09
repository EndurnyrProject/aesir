defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.ResearchOfficial do
  @moduledoc """
  The United Research Official asks the adventurer to mediate the three nations' researchers.

  ## Behavior

  - Turns away overloaded adventurers and warns those who have not reached the Ash-Vacuum chapter.
  - Starts the researchers' dispute quest, accepts the Meeting Invitation, and asks the adventurer
    to prepare the researchers and mediate their meeting.
  - Convenes the researchers, then flees a Thief Bug and sends the adventurer outside; on their
    return, a ruined cake ends the meeting and leads to questions about Hansenne taking the blame.
  - Starts a five-minute timer and spawns ten Thief Bugs, hiding the Official and the researchers.
    The Official reappears when the bugs are all dead or the timer kills the remaining bugs.
  - After the researchers reconcile, offers tea, mode-dependent experience, and a First Aid Kit,
    completes the quest, and thanks returning adventurers.

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
        map: "mid_campin",
        x: 376,
        y: 120,
        dir: 0,
        sprite: 754,
        name: "Research Official",
        scope: :shared,
        unique_name: "Research Official#ep131",
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @npc "Research Official#ep131"
  @invitation 6036
  @first_aid_kit 12_110

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      overloaded?(ctx) -> overloaded(ctx)
      in_chapter?(ctx) -> at_step(ctx, get_char_var(ctx, :ep13_1_rhea, 0))
      true -> warns_of_danger(ctx)
    end
  end

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx), do: on_talk(ctx)

  def on_event("OnInit", ctx) do
    enablenpc(ctx, @npc)
  end

  def on_event("OnEnable", ctx) do
    hideoffnpc(ctx, @npc)
  end

  def on_event("OnDisable", ctx) do
    hideonnpc(ctx, @npc)
  end

  def on_event("OnMeet", ctx) do
    ctx
    |> donpcevent("Ryosen#ep131_rhea05::OnEnable")
    |> donpcevent("Hue#ep131_rhea06::OnEnable")
    |> donpcevent("Hansenne#ep131_rhea07::OnEnable")
  end

  def on_event("OnCall", ctx) do
    ctx =
      Enum.reduce(1..10, initnpctimer(ctx), fn _, ctx ->
        summon_mob(ctx,
          mob_id: 1051,
          map: "mid_campin",
          at: {376, 134},
          event: "#{@npc}::OnMyMobDead"
        )
      end)

    ctx
    |> donpcevent("#{@npc}::OnDisable")
    |> donpcevent("Ryosen#ep131_rhea05::OnDisable")
    |> donpcevent("Hue#ep131_rhea06::OnDisable")
    |> donpcevent("Hansenne#ep131_rhea07::OnDisable")
  end

  def on_event("OnMyMobDead", ctx) do
    if mobcount(ctx, "mid_campin", "#{@npc}::OnMyMobDead") < 1 do
      ctx
      |> donpcevent("#{@npc}::OnEnable")
      |> stopnpctimer()
    else
      ctx
    end
  end

  def on_event("OnTimer300000", ctx) do
    ctx
    |> killmonster("mid_campin", "#{@npc}::OnMyMobDead")
    |> donpcevent("#{@npc}::OnEnable")
    |> stopnpctimer()
  end

  defp overloaded?(ctx) do
    checkweight(ctx, [{1201, 1}]) == 0 or
      get_char_var(ctx, :MaxWeight, 0) - weight(ctx) < 3500
  end

  defp in_chapter?(ctx) do
    get_char_var(ctx, :ep13_ryu, 0) > 99 or get_char_var(ctx, :ep13_start, 0) > 99
  end

  defp at_step(ctx, step) do
    cond do
      step < 1 -> asks_for_help(ctx)
      step > 0 and step < 10 -> awaits_researchers(ctx)
      step == 10 -> considers_invitation(ctx)
      step > 10 and step < 19 -> asks_to_mediate(ctx)
      step == 19 -> holds_meeting(ctx)
      step == 20 -> resumes_meeting(ctx)
      step == 21 -> questions_blame(ctx)
      step > 21 and step < 26 -> ctx |> doubts_about_hansenne() |> close()
      step == 26 -> rewards_help(ctx)
      true -> thanks_for_help(ctx)
    end
  end

  defp overloaded(ctx) do
    ctx
    |> mes("[United Research Official]")
    |> mes("How come you've got so much to carry?")
    |> mes("Are you perhaps on training or something?")
    |> close()
  end

  defp warns_of_danger(ctx) do
    ctx
    |> mes("[United Research Official]")
    |> mes("...Mmmm? What brings you here?")
    |> next()
    |> mes("[United Research Official]")
    |> mes("I wouldn't be roaming around this place like that, if I were you.")
    |> mes("It's very dangerous here, and people dwelling is this place are not that nice.")
    |> close()
  end

  defp asks_for_help(ctx) do
    ctx =
      ctx
      |> mes("[United Research Official]")
      |> mes("Hmmmm...mmm...")
      |> next()
      |> mes("[United Research Official]")
      |> mes("Oh! Hello there!")
      |> mes("You must be the adventurer from Midgard.")
      |> next()
      |> mes("[United Research Official]")
      |> mes(
        "We've come all the way here to keep track of Satan Morocc, but... Now it seems that's not our priority anymore... Tsk,tsk..."
      )
      |> next()
      |> mes("[United Research Official]")
      |> mes(
        "Well, since our research group has been gathered in such haste, many of our members collide too often."
      )
      |> mes(
        "I think it's just the process of trial and error, but this really slows things down."
      )
      |> next()
      |> mes("[United Research Official]")
      |> mes(
        "Alas, the head office keeps pushing me to submit a report... As if I could perform miracles!"
      )
      |> emotion(:cry)
      |> next()
      |> mes("[United Research Official]")
      |> mes(
        "I can't go around and meet those people myself, mediate among troubled people... This is impossible!! Unless...Unless someone helps me with that ! I need... someone..."
      )
      |> next()
      |> mes("- He stared at you -")
      |> mes("- with sparkling -")
      |> mes("- eyes as if he were -")
      |> mes("- demanding for help! -")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes(".................")
    |> mes(".................")
    |> next()
    |> mes("[United Research Official]")
    |> mes(
      "Eh?! Oh, my... You really shouldn't. You must be extremely busy tracking down Satan Morocc!"
    )
    |> next()
    |> mes("[United Research Official]")
    |> mes("But... if you say so, could I really use your help? Hahaha.")
    |> next()
    |> mes("[United Research Official]")
    |> mes(
      "Those researchers complain a lot these days. They're terribly stressed out and I think somebody should really listen to their problems."
    )
    |> next()
    |> mes("[United Research Official]")
    |> mes(
      "Especially those dealing with document files that argue with each other so many times! You might wanna start by talking to them."
    )
    |> next()
    |> mes("[United Research Official]")
    |> mes("Sounds good, huh? Please, you should go now.")
    |> set_char_var(:ep13_1_rhea, 1)
    |> setquest(8196)
    |> close()
  end

  defp awaits_researchers(ctx) do
    ctx
    |> mes("[United Research Official]")
    |> mes(
      "Those researchers complain a lot these days. They're terribly stressed out and I think somebody should really listen to their problems."
    )
    |> next()
    |> mes("[United Research Official]")
    |> mes(
      "Especially those dealing with document files that argue with each other so many times! You might wanna start by talking to them."
    )
    |> next()
    |> mes("[United Research Official]")
    |> mes(
      "And, don't worry! I'm even willing to share my snacks with you if things go well. I'm not asking this for free, you got that~?"
    )
    |> close()
  end

  defp considers_invitation(ctx) do
    if count_item(ctx, @invitation) > 0 do
      ctx
      |> mes("[United Research Official]")
      |> mes("Aha!")
      |> next()
      |> mes("[United Research Official]")
      |> mes("Isn't that an invitation to the meeting?")
      |> next()
      |> mes("[United Research Official]")
      |> mes("And...and I really get to sign this thing and approve it...? Hahaha!")
      |> next()
      |> mes("[United Research Official]")
      |> mes("This, this means I need to get prepared for the meeting! Finally!")
      |> mes("Hahahaha!")
      |> next()
      |> mes("[United Research Official]")
      |> mes("Oh, by the way, did you get a rough idea of the atmosphere of this expedition?")
      |> next()
      |> mes("[United Research Official]")
      |> mes(
        "Normally, researchers just take their own instruments and find their own tracks of Satan Morocc."
      )
      |> mes("They don't really need to cooperate with other members.")
      |> next()
      |> mes("[United Research Official]")
      |> mes("Howerver, things get different when it comes to document files.")
      |> mes(
        "Those researchers in charge of document files must contact eachother for information, and this just makes for endless work."
      )
      |> next()
      |> mes("[United Research Official]")
      |> mes("People can't always be perfect, so they stress out and get to arguing...")
      |> next()
      |> mes("[United Research Official]")
      |> mes("So... Could you do me a favor?")
      |> next()
      |> mes("[United Research Official]")
      |> mes(
        "As you've heard, about the 3 researchers, they don't agree with eachother too often. It's just too obvious that their meeting will turn out a disaster, and the whole research group could break down!"
      )
      |> emotion(:cry)
      |> next()
      |> mes("[United Research Official]")
      |> mes("Oh, just thinking about it scares the crap out of me.")
      |> next()
      |> mes("[United Research Official]")
      |> mes(
        "What I'm asking is that you participate in the meeting with them and help them negotiate."
      )
      |> next()
      |> mes("[United Research Official]")
      |> mes(
        "So, first! Can you go meet those 3 researchers and check on them to prepare for the meeting?"
      )
      |> delitem(@invitation, 1)
      |> set_char_var(:ep13_1_rhea, 11)
      |> changequest(8198, 8199)
      |> close()
    else
      ctx
      |> mes("[United Research Official]")
      |> mes("How did it go?")
      |> next()
      |> mes("[United Research Official]")
      |> mes("Did you talk to those researchers in charge of document files?")
      |> close()
    end
  end

  defp asks_to_mediate(ctx) do
    ctx
    |> mes("[United Research Official]")
    |> mes(
      "Please, you should participate in the meeting and mediate them if anything goes wrong!"
    )
    |> next()
    |> mes("[United Research Official]")
    |> mes(
      "First, you should go meet those 3 researchers and check on them to prepare for the meeting. Hope they're not preparing any weapons though..."
    )
    |> emotion(:cry)
    |> close()
  end

  defp holds_meeting(ctx) do
    ctx
    |> changequest(8205, 8206)
    |> mes("[United Research Official]")
    |> mes("Ohhh, you came! How generous of you!")
    |> next()
    |> mes("[United Research Official]")
    |> mes("The meeting's about to begin.")
    |> mes("Whew... I think I'm too tense... My chest hurts... Aaaah.")
    |> next()
    |> mes("- Somebody's knocking -")
    |> mes("- on the door... -")
    |> next()
    |> mes("[United Research Official]")
    |> mes("Finally, the meeting's starting.")
    |> mes("You should come in.")
    |> next()
    |> donpcevent("#{@npc}::OnMeet")
    |> mes("[United Research Official]")
    |> mes("So, everyone's here.")
    |> mes("Let us begin our meeting.")
    |> mes("First, I need to hear the report on the process of tracking Satan Morocc.")
    |> next()
    |> mes("[Ryosen]")
    |> mes(
      "Alright. I'm Ryosen from Rune-Midgarts. We're certain that Satan Morocc came to this place through the crack of dimension, however, we failed to find any traces within the area we inspected."
    )
    |> next()
    |> mes("[Ryosen]")
    |> mes(
      "The Tripartite Union is doing whatever it takes to track down Satan Morocc's whereabouts, but the research in Ash-Vacuum is very limited."
    )
    |> next()
    |> mes("[Ryosen]")
    |> mes(
      "Supplies, reinforcements as wel as demanded goods are all insufficient, so we can't really go on."
    )
    |> next()
    |> mes("[Ryosen]")
    |> mes(
      "I've heard the assassins took action in order to find the traces of Satan Morocc, but nothing's been reported so far."
    )
    |> next()
    |> mes("[Hue]")
    |> mes("I'm Hue from the Schwarzwald Republic.")
    |> next()
    |> mes("[Hue]")
    |> mes(
      "We're still researching on the crack of dimension that Satan Morocc has come through, and the false data research on the noise created when moving through the crack is currently being corrected."
    )
    |> next()
    |> mes("[Hue]")
    |> mes(
      "The real cause of this problem has yet to be found, which makes it hard for us to provide any reinforcements or other supplies."
    )
    |> next()
    |> mes("[United Research Official]")
    |> mes("Ok. I see. How's it going with the research on Ash-Vacuum?")
    |> next()
    |> mes("[Hansenne]")
    |> mes(
      "Hi, I'm Hansenne from Arunafeltz. We have conclused that his world of Ash-Vacuum is nothing related to the continent of Midgard, as it is placed in a totally indipendent world dimension."
    )
    |> next()
    |> mes("[Hansenne]")
    |> mes(
      "The environment of the fields on the East and West where we can work on the research has nothing in common with the environment within the boundrary of the Tripartite Union's army post."
    )
    |> next()
    |> mes("[Hansenne]")
    |> mes("I also have been reported that the ecosystem in the researched are is different.")
    |> next()
    |> mes("[Hansenne]")
    |> mes(
      "We could not go further with the research on the ecosystem due to some violent living creatures which have never been found on the Midgard continent."
    )
    |> next()
    |> mes("[United Research Official]")
    |> mes(
      "So... All in all, nothing has been clearly found. Any problems among the members of the United Research Group?"
    )
    |> next()
    |> mes("[Ryosen]")
    |> mes("......................")
    |> next()
    |> mes("[Hue]")
    |> mes("......................")
    |> next()
    |> mes("[Hansenne]")
    |> mes("......................")
    |> next()
    |> mes("- The room is in awkward silence for a short while... -")
    |> next()
    |> mes("[United Research Official]")
    |> mes("Ha..... Hahahaha...")
    |> mes(
      "... Then, anything you need to request, or suggest, perhaps? Anything you want to complain about?"
    )
    |> next()
    |> mes("- Ryosen, who was fidgeting with -")
    |> mes("- his files, suddenly stops and -")
    |> mes("- studies the others. Then, he takes -")
    |> mes("- out something from the bottom of -")
    |> mes("- the chair and puts it on the table. -")
    |> next()
    |> mes("[Ryosen]")
    |> mes("I'm.... I... The document file...")
    |> next()
    |> mes("[United Research Official]")
    |> mes("Aaaaaahahhhhhhhhhhcckk!!!!!")
    |> next()
    |> mes("- Hue, shocked by the sudden")
    |> mes("scream, stands up frantically and")
    |> mes("accidentally hits and drops the")
    |> mes("object which Ryosen had taken out. -")
    |> next()
    |> mes("[United Research Official]")
    |> mes("Kkkkhaaaaaaahhhhhhhh!!!")
    |> mes("It's the Thief Bug!!!")
    |> next()
    |> mes("- As the Official screamed, all the")
    |> mes("researchers of the union started to")
    |> mes("scream as well, and rushed out of")
    |> mes("the room. -")
    |> set_char_var(:ep13_1_rhea, 20)
    |> donpcevent("#{@npc}::OnCall")
    |> close()
    |> warp("mid_camp", 165, 236)
  end

  defp resumes_meeting(ctx) do
    ctx =
      ctx
      |> mes("[United Research Official]")
      |> mes("Hhmm, hmmmm...")
      |> mes("I really don't know what to say.")
      |> mes(
        "I mean... I'm totally OK with other monsters, mutants or whatever, but that black evil thing... Oh, I can't stand that one..."
      )
      |> emotion(:cry)
      |> next()
      |> mes("- Knock, knock-")
      |> mes("- The researchers come back into the room. -")
      |> next()
      |> donpcevent("#{@npc}::OnMeet")
      |> mes("[Ryosen]")
      |> mes("Uh-hmm! Sorry about the mess.")
      |> mes("I... Something urgent came up...")
      |> mes("............Aaaaaaaaahhhhhhhhh!")
      |> next()
      |> mes("[United Research Official]")
      |> mes("Whhhhhhaaattt!!!! What is it!!?")
      |> mes("The Thief Bug, Again!!!???")
      |> next()
      |> mes(
        "- Except for Ryosen, the rest spring out of their seats and run hurriedly for the door. -"
      )
      |> next()
      |> mes("[Ryosen]")
      |> mes("My... my strawberry cake!!!")
      |> next()
      |> mes("- Ryosen picks up his strawberry cake, all squashed with some fingerprints. -")
      |> next()
      |> mes("[Ryosen]")
      |> mes("Stop! Freeze, everyone!")
      |> mes("Move one more time and you'll be considered guilty!!")
      |> next()
      |> mes("[Ryosen]")
      |> mes(
        "This cake was just fine before that evil thing appeared, and there were only 4 of us here!"
      )
      |> next()
      |> mes("[Ryosen]")
      |> mes("One of you must be guilty of ruining my Rune-Midgarts' Strawberry Cake!!!")
      |> next()
      |> mes("[Ryosen]")
      |> mes(
        "I can't help checking your hands! This must be a fingerprint! It's loud and clear!! Hmm, I bet this is the mark of an index finger!"
      )
      |> next()
      |> mes("[Hue]")
      |> mes(
        "Wait a minute! Wait! Stop treating us like criminals! What is wrong with you, it's only a cake!? Don't you think you're going a little too far?"
      )
      |> next()
      |> mes("[Ryosen]")
      |> mes("Whatttttt!? Only a cake????")
      |> mes(
        "Aha, yeah, I just remembered. You people from Schwarzwald don't ever appreciate food at all, right?"
      )
      |> next()
      |> mes("[Ryosen]")
      |> mes(
        "Especially when the food is NOT yours, huh? That's why you people sneak a taste of other people's food like my strawberry cake!!!"
      )
      |> next()
      |> mes("[Hue]")
      |> mes("Hmm, are you talking about Dusty?")
      |> mes(
        "He was expelled right after the incident and his job was taken away! I told you several times already!"
      )
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Ugh... You guys, I think you should calm down... This is ridiculous.")
      |> next()
      |> mes("[Hansenne]")
      |> mes("Ughhhhh! It was I who did that!!!")
      |> next()
      |> mes("[Hansenne]")
      |> mes(
        "Sorry, I was just too shocked by that thief bug and accidentally touched your cake with my finger!"
      )
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("...Huh? No. Wait...")
    |> next()
    |> mes("[Ryosen]")
    |> mes("You again?!")
    |> mes(
      "I can't belive how careless you are all the time, like with the requested data and all!!"
    )
    |> next()
    |> mes("[Hansenne]")
    |> mes("Ah, I forgot to say thank you.")
    |> mes("Hue, thank you so much for restoring my documents!!!")
    |> mes("Thanks!!!")
    |> mes("Ahahahahaha. Hahahahaha.")
    |> next()
    |> mes("[Hue]")
    |> mes("No, I...")
    |> next()
    |> mes("[Ryosen]")
    |> mes("Hey, stay on topic!!")
    |> mes("You are...")
    |> next()
    |> mes("[United Research Official]")
    |> mes(
      "Ahhhhhh! I guess we should call it a day now! Thanks for comingm all of you. Ok, let's go. Dismissed!"
    )
    |> next()
    |> mes("[United Research Official]")
    |> mes("Come on!!!")
    |> next()
    |> mes(
      "-The three researchers say nothing. They just stare at each other, standing still... Then they finally leave the room. -"
    )
    |> set_char_var(:ep13_1_rhea, 21)
    |> donpcevent("Ryosen#ep131_rhea05::OnDisable")
    |> donpcevent("Hue#ep131_rhea06::OnDisable")
    |> donpcevent("Hansenne#ep131_rhea07::OnDisable")
    |> close()
  end

  defp questions_blame(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Ah...")
      |> next()
      |> mes("[United Research Official]")
      |> mes("Ugh, I've got nothing to say.")
      |> mes(
        "All I wanted was to let those people be closter to each other, become more friendly. But, problems come up every single time."
      )
      |> next()
      |> mes("[United Research Official]")
      |> mes("Can you think of any idea how to get those people to get along??")
      |> next()

    ctx
    |> doubts_about_hansenne()
    |> set_char_var(:ep13_1_rhea, 22)
    |> changequest(8206, 8207)
    |> close()
  end

  defp doubts_about_hansenne(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("... Actually... Hansenne is not the one who ruined that cake.")
      |> next()
      |> mes("[United Research Official]")
      |> mes("Eh? What did you say?")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("But... I don't understand why Hansenne would take the blame...")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("... Well, I should go now.")
    |> next()
    |> mes("[United Research Official]")
    |> mes("What? Ah, adventurer?!")
  end

  defp rewards_help(ctx) do
    ctx =
      ctx
      |> mes("[United Research Official]")
      |> mes("How are they?")
      |> next()
      |> mes(
        "- You tell the Official about the conversation that the 3 researchers had, in detail. -"
      )
      |> next()
      |> mes("[United Research Official]")
      |> mes("Whew, I see.")
      |> next()
      |> mes("[United Research Official]")
      |> mes("Maybe I've been a little too worried.")
      |> next()
      |> mes("[United Research Official]")
      |> mes(
        "How often they collide, it must be a natural thing for people from different countries with different personalities and customs."
      )
      |> next()
      |> mes("[United Research Official]")
      |> mes("Thank you for helping me.")
      |> next()
      |> mes("[United Research Official]")
      |> mes("Here, I'll offer you a cup of tea.")
      |> mes(
        "This is a really special drink I preserved. Please, drink it while it's nice and hot."
      )
      |> next()
      |> mes(
        "- You feel so refreshed and light, as you drink the tea that the Official offered. -"
      )
      |> specialeffect2(:absorbspirits)
      |> set_char_var(:ep13_1_rhea, 100)

    ctx =
      if Rathena.truthy?(checkre(ctx, 3)) do
        getexp(ctx, 80_000, 3000)
      else
        getexp(ctx, 300_000, 100_000)
      end

    ctx
    |> completequest(8210)
    |> next()
    |> mes("[United Research Official]")
    |> mes(
      "Now, I should get to work on the report I need to submit to the head office. Ah, and this is nothing big, but still... This might come in handy when you travel."
    )
    |> next()
    |> mes("[United Research Official]")
    |> mes("Please, stop by and say hellp to us from time to time.")
    |> give_item(@first_aid_kit, 1)
    |> close()
  end

  defp thanks_for_help(ctx) do
    ctx
    |> mes("[United Research Official]")
    |> mes("Thank you for everything.")
    |> next()
    |> mes("[United Research Official]")
    |> mes("Please, stop by and say hellp to us from time to time.")
    |> next()
    |> mes("[United Research Official]")
    |> mes(
      "Oh, I'm not asking you to keep your eye on those 3 researchers. Don't get me wrong, hahaha.~"
    )
    |> close()
  end
end
