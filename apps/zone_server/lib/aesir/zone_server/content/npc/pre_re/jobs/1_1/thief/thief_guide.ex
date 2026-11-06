defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.M11.Thief.ThiefGuide do
  @moduledoc """
  Interviews prospective Thieves and explains the Mushroom Farm entrance test.

  ## Behavior

  - Registers applicants, checks their Basic Skills, and starts the mushroom-gathering quest.
  - Promotes eligible reborn Novices and responds to visitors by job and quest progress.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - Lupus
    - massdriller
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script pre-re/jobs/1-1/thief.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "moc_prydb1",
        x: 39,
        y: 129,
        dir: 2,
        sprite: 69,
        name: "Thief Guide",
        scope: :pre_renewal
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      upper(ctx) == 1 ->
        greet_reborn(ctx)

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:thief) ->
        ctx
        |> mes("[Thief Guide]")
        |> mes("If you have a problem, feel free to speak to me anytime, alright?")
        |> close()

      Rathena.job_id(base_job(ctx)) != Rathena.job_id(:novice) ->
        greet_other_job(ctx)

      (get_char_var(ctx, :job_thief_q, 0) == 3 and count_item(ctx, 1069) > 0) or
          count_item(ctx, 1070) > 0 ->
        ctx
        |> mes("[Thief Guide]")
        |> mes("Hmmm?")
        |> mes("You gathered Mushrooms for")
        |> mes("the Thief test, right?")
        |> next()
        |> mes("[Thief Guide]")
        |> mes(
          "Here, talk to the other guy right next to me. He's the one in charge of checking your Mushrooms."
        )
        |> close()

      get_char_var(ctx, :job_thief_q, 0) == 3 ->
        ask_about_farm(ctx)

      get_char_var(ctx, :job_thief_q, 0) == 2 ->
        offer_reminder(ctx)

      true ->
        greet_applicant(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp greet_reborn(ctx) do
    cond do
      get_char_var(ctx, :ADVJOB, 0) != Rathena.job_id(:assassin_cross) and
          get_char_var(ctx, :ADVJOB, 0) != Rathena.job_id(:stalker) ->
        ctx = mes(ctx, "[Thief Guide]")
        ctx = if sex(ctx) == 1, do: mes(ctx, "Hey, dude."), else: mes(ctx, "Hey, baby.")

        ctx
        |> mes(
          "...Hey! You look too goody-goody to want to be a Thief!! Now scram, I'm busy. Next!"
        )
        |> close()

      Rathena.job_id(class(ctx)) != Rathena.job_id(:novice_high) ->
        ctx = mes(ctx, "[Thief Guide]")
        ctx = if sex(ctx) == 1, do: mes(ctx, "Hey, dude."), else: mes(ctx, "Hey, baby~")
        close(ctx)

      true ->
        promote_reborn(ctx)
    end
  end

  defp promote_reborn(ctx) do
    ctx =
      ctx
      |> mes("[Thief Guide]")
      |> mes(
        "Huh? Do I know you? It's creepy that you seem so familiar. You don't have a twin, do you?"
      )
      |> next()

    if Rathena.truthy?(can_change_job?(ctx)) do
      ctx
      |> mes("[Thief Guide]")
      |> mes(
        "Well, I got this feeling like you've been through a lifetime of fighting, so I'm promoting you to a Thief right this minute. I better give you tough guys what you want..."
      )
      |> next()
      |> skill(143, 0, :permanent)
      |> jobchange(:thief_high)
      |> skill(149, 1, :permanent)
      |> skill(150, 1, :permanent)
      |> skill(151, 1, :permanent)
      |> skill(152, 1, :permanent)
      |> mes("[Thief Guide]")
      |> mes("Since you've become a Thief, live as a Thief. Now, go for it! Next~")
      |> close()
    else
      ctx
      |> mes("[Thief Guide]")
      |> mes(
        "What, do you want to be a Thief? I'm sorry, but you look like you need more training."
      )
      |> next()
      |> mes("[Thief Guide]")
      |> mes(
        "Take your time and learn all the Basic Skills, will you? Well then, see you later~!"
      )
      |> close()
    end
  end

  defp greet_other_job(ctx) do
    ctx = ctx |> mes("[Thief Guide]") |> mes("What the heck...?")

    case Rathena.job_id(class(ctx)) do
      8 ->
        ctx
        |> mes("Oh my God...")
        |> mes("Am I dying?")
        |> next()
        |> mes("[Thief Guide]")
        |> mes(
          "Why else would a Priest come here? I guess I better start confessing all of my misdeeds."
        )
        |> close()

      12 ->
        ctx
        |> mes(
          "Didn't you use to be one of us?! Man, you changed. You seem real dangerous now..."
        )
        |> close()

      17 ->
        ctx
        |> mes(
          "Man, you got real cool all of a sudden! You must have some skills I can only dream of!"
        )
        |> close()

      job_id ->
        ctx
        |> taunt_visitor(job_id)
        |> next()
        |> mes("[Thief Guide]")
        |> mes(
          "*Sigh* Look, there's really no need for you to be in this kind of place. You oughta go where you ought to go."
        )
        |> close()
    end
  end

  defp taunt_visitor(ctx, job_id) do
    case job_id do
      1 ->
        ctx
        |> mes("Huh.")
        |> mes("Now, that's")
        |> mes("a big sword.")
        |> next()
        |> mes("[Thief Guide]")
        |> mes("So...")
        |> mes("Trying to make")
        |> mes("up for something")
        |> mes("...Buddy?")

      2 ->
        ctx
        |> mes(
          "What's a Mage doin' here? Shouldn't you be doing card tricks elsewhere? Oh well, it's a free country..."
        )
        |> next()
        |> mes("[Thief Guide]")
        |> mes("Oh wait,")
        |> mes("it's not...")
        |> mes("Get outta here!")

      3 ->
        ctx
        |> mes("Man, shouldn't you")
        |> mes("Archers be playing")
        |> mes("in the forest")
        |> mes("or something?")

      4 ->
        mes(
          ctx,
          "You know we all steal for a living, right? What are you doing in this kinda place, Acolyte?"
        )

      5 ->
        ctx
        |> mes("You're a Merchant,")
        |> mes("right? Why are you")
        |> mes("walking into a den")
        |> mes("of Thieves?!")
        |> next()
        |> mes("[Thief Guide]")
        |> mes("It's like you're begging")
        |> mes("us to steal from you!")
        |> mes("Come on, hurry and")
        |> mes("get outta here~")

      _ ->
        ctx
    end
  end

  defp ask_about_farm(ctx) do
    {ctx, experience} =
      ctx
      |> mes("[Thief Guide]")
      |> mes("So how was the")
      |> mes("Mushroom Farm?")
      |> mes("Have any fun?")
      |> next()
      |> select(["Yeah, kinda Cool.", "It was horrible."])

    if experience == 1 do
      ctx
      |> mes("[Thief Guide]")
      |> mes(
        "Heh heh! That's a good attitude. In our line of work, you gotta enjoy getting your hands dirty, one way or another."
      )
      |> close()
    else
      ctx
      |> mes("[Thief Guide]")
      |> mes(
        "Yeah? I've been there too, so I can see why that place isn't everyone's cup of tea. Still, being a Thief isn't all glamour and trendy night life."
      )
      |> close()
    end
  end

  defp offer_reminder(ctx) do
    {ctx, reminder} =
      ctx
      |> mes("[Thief Guide]")
      |> mes(
        "Hey, whaddya doin' here? Aren't you supposed to be gathering Mushrooms? Or did you need it explained to you again?"
      )
      |> next()
      |> select(["Yes.", "No, that's okay."])

    if reminder == 1 do
      ctx
      |> mes("[Thief Guide]")
      |> mes("*Sigh* Well, there's always one in the bunch. Alright, listen carefully.")
      |> next()
      |> mes("[Thief Guide]")
      |> mes(
        "Alright, for your test, you gotta steal Mushrooms from a farm. Don't worry, the guy who owns the farm deserves to be robbed."
      )
      |> explain_mushrooms()
      |> close()
    else
      ctx
      |> mes("[Thief Guide]")
      |> mes("Huh. For a second there, I thought you had something really important to tell me.")
      |> close()
    end
  end

  defp greet_applicant(ctx) do
    ctx = mes(ctx, "[Thief Guide]")

    ctx =
      if get_char_var(ctx, :job_thief_q, 0) == 0 do
        ctx |> mes("What brings you down") |> mes("here to this rathole?")
      else
        ctx
        |> mes("Ah...")
        |> mes("You came back.")
        |> mes("Are you sure you're")
        |> mes("ready to try again?")
      end

    {ctx, intention} =
      ctx
      |> next()
      |> select(["Hey, I came here to be a Thief!", "Nah, I'm just looking around."])

    cond do
      intention != 1 ->
        close(ctx)

      get_char_var(ctx, :job_thief_q, 0) == 0 ->
        start_application(ctx)

      true ->
        ctx
        |> mes("[Thief Guide]")
        |> mes("Okay...")
        |> mes("Give me")
        |> mes("one second.")
        |> next()
        |> check_applicant()
    end
  end

  defp start_application(ctx) do
    {ctx, motivation} =
      ctx
      |> mes("[Thief Guide]")
      |> mes(
        "Heh, I like your confidence. Still, you know being a Thief isn't all what it's cracked up to be."
      )
      |> next()
      |> mes("[Thief Guide]")
      |> mes("Still...")
      |> mes("Do you really")
      |> mes("want to be")
      |> mes("a Thief?")
      |> next()
      |> select(["Yeah.", "No, just wasting your time.", "Why did you become a Thief?"])

    case motivation do
      1 ->
        ctx |> mes("[Thief Guide]") |> mes("Really...") |> offer_application()

      2 ->
        ctx
        |> mes("[Thief Guide]")
        |> mes("Yeah...")
        |> mes("I can see that.")
        |> offer_application()

      3 ->
        ctx
        |> mes("[Thief Guide]")
        |> mes("Me...?")
        |> mes(
          "I had no choice at the time. It was either steal or starve. But it's not like I need to give you my life story."
        )
        |> offer_application()

      _ ->
        ctx
    end
  end

  defp offer_application(ctx) do
    {ctx, application} =
      ctx
      |> next()
      |> mes("[Thief Guide]")
      |> mes("So do you want to")
      |> mes("apply to become")
      |> mes("a Thief or not?")
      |> next()
      |> select(["Yes, I will.", "I'm too scared to be a Thief!"])

    case application do
      1 ->
        register_applicant(ctx)

      2 ->
        ctx
        |> mes("[Thief Guide]")
        |> mes("Too scared?!?")
        |> mes("Hahahahahahah!")
        |> mes("Oh, please...!")
        |> mes("That's hilarious!")
        |> close()

      _ ->
        ctx
    end
  end

  defp register_applicant(ctx) do
    ctx =
      ctx
      |> mes("[Thief Guide]")
      |> mes("Alright, tell")
      |> mes("me your name.")
      |> next()
      |> mes("[Thief Guide]")

    {ctx, readiness} =
      ctx
      |> mes("#{char_name(ctx, 0)}?")
      |> mes("What kind of name is #{char_name(ctx, 0)}? Anyway, give me a second.")
      |> set_char_var(:job_thief_q, 1)
      |> next()
      |> mes("[Thief Guide]")
      |> mes(
        "Alright, your registration has been processed. Okay, you can begin your test if you're ready."
      )
      |> next()
      |> select(["Yeah, I'm ready.", "No, I'm not ready yet."])

    case readiness do
      1 ->
        check_applicant(ctx)

      2 ->
        ctx
        |> mes("[Thief Guide]")
        |> mes("Not ready?")
        |> mes("How can you")
        |> mes("not be ready?!")
        |> close()

      _ ->
        ctx
    end
  end

  defp check_applicant(ctx) do
    ctx =
      ctx
      |> mes("[Thief Guide]")
      |> mes("Your name is...")
      |> mes("#{char_name(ctx, 0)}? Um, where is it? Ah, here it is. Let's see...")
      |> next()
      |> mes("[Thief Guide]")

    if Rathena.truthy?(can_change_job?(ctx)) do
      pass_interview(ctx)
    else
      ctx
      |> mes(
        "Isn't that cute? I can see you're ambitious, but you gotta learn all of the Basic Skills before you can become a Thief."
      )
      |> close()
    end
  end

  defp pass_interview(ctx) do
    {ctx, knows_test} =
      ctx
      |> mes(
        "Alright. I looked at your Felony Record, and you seem to have a very interesting history. You might have what it takes to be a Thief."
      )
      |> next()
      |> mes("[Thief Guide]")
      |> mes(
        "Because I feel like it, I now decree that you have passed this interview. Good work!"
      )
      |> set_char_var(:job_thief_q, 2)
      |> setquest(1013)
      |> next()
      |> mes("[Thief Guide]")
      |> mes(
        "Now, your actual abilities will need to be tested. Do you know anything about the test?"
      )
      |> next()
      |> select(["Yes, I do.", "Sorry, I don't."])

    case knows_test do
      1 ->
        ctx
        |> mes("[Thief Guide]")
        |> mes("Oh yeah? Well, this makes things a lot easier.")
        |> advise_preparation()

      2 ->
        ctx
        |> mes("[Thief Guide]")
        |> mes(
          "Alright, let me inform you then. Listen carefully. This test decides if you are worthy of becoming a Thief."
        )
        |> next()
        |> mes("[Thief Guide]")
        |> mes(
          "You will be sneaking to Shibu's Farm. He is the worst Merchant, in terms of character, in Morocc."
        )
        |> next()
        |> mes("[Thief Guide]")
        |> mes(
          "Alright, for your test, you gotta steal Mushrooms from his farm. Don't worry, that guy deserves to be robbed."
        )
        |> explain_mushrooms()
        |> advise_preparation()

      _ ->
        ctx
    end
  end

  defp explain_mushrooms(ctx) do
    ctx
    |> next()
    |> mes("[Thief Guide]")
    |> mes(
      "Anyway, you gotta gather two kinds of Mushrooms: ^0000FFOrange Net Mushrooms^000000 and ^0000FFOrange Gooey Mushrooms^000000."
    )
    |> next()
    |> mes("[Thief Guide]")
    |> mes(
      "Be careful, since there are monsters are the farm that are there to protect the Mushrooms. So this will be no walk in the park."
    )
    |> next()
    |> mes("[Thief Guide]")
    |> mes(
      "When you come back here after gathering Mushrooms, you'll be graded on the Mushrooms you've collected."
    )
    |> next()
    |> mes("[Thief Guide]")
    |> mes(
      "Each Orange Net Mushroom gets you 3 points, and you get 1 point for each Orange Gooey Mushroom. You need a total of 25 points to pass the test."
    )
    |> next()
    |> mes("[Thief Guide]")
    |> mes(
      "Go outside and keep going ahead toward the Eastern Field of the Pyramids. Then you will see one of our comrades between two columns."
    )
    |> next()
    |> mes("[Thief Guide]")
    |> mes("Speak to that guy, and he'll take you to the farm through the backdoor.")
    |> next()
    |> mes("[Thief Guide]")
    |> mes(
      "On that field, I think his coordinates are '^FF0000141, 125^000000.' Just type ^3355FF/where^000000 in the right side of your chat box to check your present coordinates."
    )
  end

  defp advise_preparation(ctx) do
    ctx
    |> next()
    |> mes("[Thief Guide]")
    |> mes(
      "Don't forget to make plans and prepare yourself before you go inside the Mushroom Farm. Move as quickly as you can and try not to get killed, alright?"
    )
    |> close()
  end
end
