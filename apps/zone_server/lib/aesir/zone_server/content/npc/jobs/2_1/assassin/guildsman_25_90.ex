defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Assassin.Guildsman2590 do
  @moduledoc """
  Khai, the Assassin Guild clerk who registers applicants for the job test and mocks those
  who fail the written exam.

  ## Behavior

  - Takes the application of Assassin trainees and sends them to the Test Hall, recording
    whether their job level was above 48 for the Guildmaster's later reward.
  - Sends applicants who decline away and clears their quest.
  - Offers applicants who failed the written test either mockery, advice, or random tips
    about the Assassin class, depending on how they ask.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Pgro Team (OwNaGe)
    - kobra_k88
    - Lupus
    - Vicious
    - Silent
    - Toms
    - L0ne_W0lf
    - Samuray22
    - Zephyrus_cr
    - brianluau
    - Kisuka
    - JayPee
    - Euphy
    - MrAntares
    - Atemo

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "in_moc_16",
        x: 25,
        y: 90,
        dir: 1,
        sprite: 730,
        name: "Guildsman",
        scope: :shared,
        unique_name: "Guildsman#ASN2",
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    if get_char_var(ctx, :ASSIN_Q2, 0) == 4 do
      mock_failed_applicant(ctx)
    else
      take_application(ctx)
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Assassin 'Khai']")
    |> mes("Umm?!")
    |> emotion(:surprise)
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes(
      "Come closer. I prefer to talk to people face to face. It really irritates me if I have to raise my voice, just so you can hear me."
    )
    |> mes("I feel irritated when somebody talks to me behind my back.")
    |> close()
  end

  defp mock_failed_applicant(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Assassin 'Khai']")
      |> mes("Ehhh?")
      |> mes("Didn't you just")
      |> mes("pass me a minute ago?")
      |> next()
      |> mes("[Assassin 'Khai']")
      |> mes("Eh...?!")
      |> mes("You failed?")
      |> mes("Even on the")
      |> mes("writing test?")
      |> mes("Bwahahahahaha!")
      |> next()
      |> mes("[Assassin 'Khai']")
      |> mes("Well...")
      |> mes("It's been a long time since")
      |> mes("I've met such a big failure.")
      |> next()
      |> mes("[Assassin 'Khai']")
      |> mes("HAH!")
      |> mes("Hahahahah~!")
      |> mes("Oh, you're killing me....")
      |> next()
      |> mes("[Assassin 'Khai']")
      |> mes(
        "Sorry for laughing, but this is hilarious! Hahaha~ So do you want me to give you some hints?"
      )
      |> next()
      |> select([
        "I beg you, give me hints.",
        "Don't laugh at me! Now, give me hints!",
        "...Shut up, I don't need your help!"
      ])

    respond_to_hint_request(ctx, choice)
  end

  defp respond_to_hint_request(ctx, 1) do
    ctx
    |> mes("[Assassin 'Khai']")
    |> mes("Haaahahahaha!!!")
    |> mes(
      "Well well, aren't we honest. You're not even an Assassin yet, but you're killing me, I tell you, killing me!"
    )
    |> next()
    |> mes("[The Anonymous One]")
    |> mes("Ho ho ho...")
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes("Did you hear that Anonymous one?! 'I beg you, give me hints.' Hahahah!")
    |> next()
    |> mes("[The Anonymous One]")
    |> mes("Yes.")
    |> mes("This one is quite hilarious")
    |> mes("in a pathetic sort of way.")
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes("Hahahahahahah!")
    |> mes("Soooooo, you wanted")
    |> mes("some hints, right?")
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes("...")
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes("...")
    |> mes("......")
    |> mes(".........")
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes("...")
    |> mes("......")
    |> mes(".........")
    |> mes("............")
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes("...")
    |> mes("......")
    |> mes(".........")
    |> mes("............")
    |> mes("...............")
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes("Nah.")
    |> mes("I changed my mind!")
    |> mes("I'm not gonna give you any hints after all. Hee hee hee~")
    |> close()
  end

  defp respond_to_hint_request(ctx, 2) do
    ctx = mes(ctx, "[Assassin 'Khai']")

    ctx =
      if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
        ctx
        |> mes("Huh. You must have a lot of self confidence to be a Thief nowadays.")
        |> next()
        |> mes("[Assassin 'Khai']")
        |> mes(
          "Yeah yeah, I understand. Everyone messes up from time to time. Sorry for laughing at your mistakes."
        )
      else
        mes(
          ctx,
          "Hmm. I like your attitude. You should keep your pride as a Thief. Sorry for laughing at your mistakes. I think you'll do better next time."
        )
      end

    ctx
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes("I'm not allowed to give you hints, I can tell you more about being an Assassin...")
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes(
      "Above all else, we value our dignity. We're Assassins, after all and people will need us."
    )
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes(
      "If people are close to you in some way, they might not understand what I'm saying. We're born to be loners due to our nature."
    )
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes(
      "Imagine if a lover or a friend saw the blood on your hands. There's a chance that they might not stay with you."
    )
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes(
      "Sometimes it gets lonely but it's not that bad. At least I can do what I want to do, you know, and do things my way."
    )
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes("Well, that's all I can tell you for now. Does being an Assassin")
    |> mes("seem depressing to you?")
    |> close()
  end

  defp respond_to_hint_request(ctx, 3) do
    {ctx, choice} =
      ctx
      |> mes("[Assassin 'Khai']")
      |> mes("...Hm.")
      |> next()
      |> mes("[Assassin 'Khai']")
      |> mes("Right, that's the spirit. Don't ever let anyone else look down")
      |> mes("on you. We're Assassins...")
      |> next()
      |> mes("[Assassin 'Khai']")
      |> mes(
        "I apologize for laughing at you earlier. I want you to remember to keep that sense of pride and dignity as an Assassin."
      )
      |> next()
      |> mes("[Assassin 'Khai']")
      |> mes("Along with keeping your pride,")
      |> mes("I want that you respect the blood that may stain your Katar or Dagger.")
      |> next()
      |> select(["...Got you.", "...I'm confused."])

    if choice == 1 do
      ctx
      |> mes("[Assassin 'Khai']")
      |> mes("Yeah, I can trust you now. Let me give you some important tips.")
      |> next()
      |> give_tips(Enum.random(1..3))
      |> mes("[Assassin 'Khai']")
      |> mes(
        "^666666*Phew*^000000 That's all I can tell you, though that's a lot of hints. I don't doubt that I told you almost everything."
      )
      |> next()
      |> mes("[Assassin 'Khai']")
      |> mes("Well then, go ask to take the test again with 'The Anonymous.'")
      |> close()
      |> warp("in_moc_16", 19, 144)
    else
      ctx
      |> mes("[Assassin 'Khai']")
      |> mes("^666666*Sigh...*^000000")
      |> mes(
        "How can you not understand the concept of dignity? You just showed some to me just now!"
      )
      |> next()
      |> mes("[Assassin 'Khai']")
      |> mes("Oh, I get it. It wasn't pride you were showing, you were just being a jerk!")
      |> next()
      |> mes("[Assassin 'Khai']")
      |> mes("Grrrrr...")
      |> mes("WARP PORTAL!")
      |> close()
      |> warp("c_tower4", 64, 76)
    end
  end

  defp respond_to_hint_request(ctx, _choice), do: ctx

  defp give_tips(ctx, 1) do
    ctx
    |> mes("[Assassin 'Khai']")
    |> mes(
      "First of all, Grimtooth is ...A skill specifically for the Katar. Therefore, it doesn't require any skills related to Dagger weapons."
    )
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes(
      "Double attack ...Haven't you tried it? It allows you to attack an enemy twice at a time."
    )
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes(
      "Red Blood is an elemental stone, Blue Gemstone doesn't have to do the Assassin job at all!"
    )
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes(
      "Have you ever seen Mages hunt Elder willow using the Cold Bolt skill? Water overpowers Fire. Water puts Fire under control, and Wind puts water under control."
    )
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes(
      "As long as you stick close to the shadows, by walls and things like that, Cloaking will hide you from sight perfectly! Unless some bastard uses a certain detecting skill, you know."
    )
    |> next()
  end

  defp give_tips(ctx, 2) do
    ctx
    |> mes("[Assassin 'Khai']")
    |> mes("'Sharpened Legbone of Ghoul' possesses the Undead property.")
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes(
      "What kind of weapon have you used so far? Damascus? Gladius? Stiletto? Or Main Gauche? What is that you're carrying now?"
    )
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes(
      "It's possible to get a slotted Katar from Desert Wolf. Well, just keep that in mind. You will need this information someday."
    )
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes(
      "You can gain a slotted Jur from a buddy living in a dark and damp place under the ground. Well, I have no idea why that dude has that weapon... Maybe he needs it to dig a hole?"
    )
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes("And...")
    |> mes("I've always wanted a frog as a pet. But it's impossible!")
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes(
      "As far as I know, a Goblin carrying a hammer possesses the Earth property. Keep in mind that Fire overcomes the Earth property."
    )
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes("You know elemental weapons? The names of Blacksmiths are engraved on them usually...")
    |> next()
  end

  defp give_tips(ctx, 3) do
    ctx
    |> mes("[Assassin 'Khai']")
    |> mes(
      "Sell an Elder Willow Card to a Mage as soon as you can. They are mad about the card for some reason. Doesn't it increase the INT of a character? Hmmm..."
    )
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes(
      "For us, Dodge and Attack is more important than defense. Don't ever think about wearing a helm. It's heavy, uncomfortable and will even block your sight."
    )
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes("'Increase Dodge' allows you to have +3% flee rate per skill lvl.")
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes(
      "As I have told you repeatedly: Katar class weapons (Jamadhar/Jur/Katar etc) are two-handed!"
    )
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes(
      "City of desert... I miss my hometown, Morocc. I haven't been there for a long time. I feel like I became a Thief a few days ago. Time flies so fast..."
    )
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes(
      "Heh. I remember my Thief quest. I was so damn nervous when I broke into the farm to get Mushrooms..."
    )
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes("Insects detect hiding/cloaking skills. Their feelers never fail to find targets.")
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes(
      "I've heard that the Baphomet Jr. Card adds +3 points to Agility and +1 point on Critical Attack..."
    )
    |> next()
    |> mes("[Assassin 'Khai']")
    |> mes(
      "Yeah, we Assassins specialize in training Agility. We can gain a bonus of 10 Agility points even before mastering job level. The problem is it won't go up anymore after that, you know."
    )
    |> next()
  end

  defp give_tips(ctx, _tip_set), do: ctx

  defp take_application(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Assassin 'Khai']")
      |> mes("Oh, you must be an Assassin trainee. You are here to become")
      |> mes("an Assassin, aren't you?")
      |> next()
      |> select(["Yes, I am. ", "...No, I'm not."])

    if choice == 1 do
      fill_application(ctx)
    else
      question_reluctant_applicant(ctx)
    end
  end

  defp fill_application(ctx) do
    ctx =
      ctx
      |> mes("[Assassin 'Khai']")
      |> mes(
        "Okay, good. Let's fill out the application form. Please sign your name and include your job level."
      )
      |> next()
      |> mes("[Assassin 'Khai']")
      |> mes("Let's see.")
      |> mes("Your name is")
      |> mes("#{char_name(ctx, 0)}...")
      |> mes("Job level #{job_level(ctx)}...")
      |> next()

    cond do
      job_level(ctx) > 48 ->
        ctx
        |> mes("[Assassin 'Khai']")
        |> mes(
          "Wait, Job level #{job_level(ctx)}?! I can see you've been training pretty hard! My bosses will like this~"
        )
        |> next()
        |> mes("[Assassin 'Khai']")
        |> mes(
          "Did you finish the form? Alright, go ahead and give it to me. Give me a second and I'll transport you to the Test Hall."
        )
        |> next()
        |> mes("[Assassin 'Khai']")
        |> mes("Alright then,")
        |> mes("best of luck to you!")
        |> close()
        |> send_to_test_hall(1)

      job_level(ctx) < 49 ->
        ctx
        |> mes("[Assassin 'Khai']")
        |> mes("Well, you passed")
        |> mes("the requirements.")
        |> mes("Not bad at all.")
        |> next()
        |> mes("[Assassin 'Khai']")
        |> mes("Go ahead and give")
        |> mes("me the form when you're")
        |> mes("done filling it out.")
        |> mes("Alright, thanks.")
        |> next()
        |> mes("[Assassin 'Khai']")
        |> mes("I'll transport you")
        |> mes("to the Test Hall.")
        |> mes("Best of luck~")
        |> close()
        |> send_to_test_hall(2)

      true ->
        ctx
        |> mes("[Assassin 'Khai']")
        |> mes("Who the")
        |> mes("hell are you?")
        |> mes("...Guards!")
        |> close()
        |> warp("moc_fild16", 206, 229)
    end
  end

  defp question_reluctant_applicant(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Assassin 'Khai']")
      |> mes("Huh...?")
      |> mes("What, are you trying to trick me or something? Don't you wanna be an Assassin?")
      |> next()
      |> select(["No.", "Yes, I want to be an Assassin."])

    if choice == 1 do
      ctx
      |> mes("[Assassin 'Khai']")
      |> mes("Eh, get outta here.")
      |> mes("Stop wastin' my time...")
      |> close()
      |> set_char_var(:ASSIN_Q, 0)
      |> set_char_var(:ASSIN_Q2, 0)
      |> erasequest(8001)
      |> warp("moc_fild16", 206, 229)
    else
      fill_reluctant_application(ctx)
    end
  end

  defp fill_reluctant_application(ctx) do
    ctx =
      ctx
      |> mes("[Assassin 'Khai']")
      |> mes("...")
      |> mes("What the hell?")
      |> mes("Okay, then.")
      |> next()
      |> mes("[Assassin 'Khai']")
      |> mes("Fill out the application form with your name and job level.")
      |> next()
      |> mes("[Assassin 'Khai']")
      |> mes("#{char_name(ctx, 0)}?")
      |> mes("That's your name?")
      |> mes("It sounds funny.")
      |> mes("Let's see... Job Level #{job_level(ctx)}...")
      |> next()

    cond do
      job_level(ctx) > 48 ->
        ctx
        |> mes("[Assassin 'Khai']")
        |> mes(
          "Ho? Job Level #{job_level(ctx)}?! You must have been training really hard. The bosses will like that for sure..."
        )
        |> next()
        |> mes("[Assassin 'Khai']")
        |> mes(
          "Are you done filling out the form? Alright, give it to me so I can send you to the Test Hall. Good luck~"
        )
        |> next()
        |> send_to_test_hall(1)

      job_level(ctx) < 49 ->
        ctx
        |> mes("[Assassin 'Khai']")
        |> mes(
          "Not bad. You fulfilled our requirements. Not bad at all. Now are you done filling out the form?"
        )
        |> next()
        |> mes("[Assassin 'Khai']")
        |> mes("Then give me the form so that I can send you to the Test Hall, alright?")
        |> mes("Good luck...")
        |> next()
        |> send_to_test_hall(2)

      true ->
        ctx
        |> mes("[Assassin 'Khai']")
        |> mes("How the hell did")
        |> mes("you get in here?")
        |> mes("Get out!")
        |> close()
        |> warp("moc_fild16", 206, 229)
    end
  end

  defp send_to_test_hall(ctx, level_rank) do
    ctx =
      if get_char_var(ctx, :ASSIN_Q3, 0) < 3 do
        set_char_var(ctx, :ASSIN_Q3, level_rank)
      else
        ctx
      end

    ctx
    |> set_char_var(:ASSIN_Q, 1)
    |> changequest(8001, 8002)
    |> warp("in_moc_16", 19, 144)
  end
end
