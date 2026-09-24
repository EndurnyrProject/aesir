defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Knight.ChivalryCaptain do
  @moduledoc """
  Captain Herman of the Prontera Chivalry, who starts and concludes the Knight job quest.

  ## Behavior

  - Registers Job Level 40+ Swordmen with no unused skill points as Knight applicants.
  - Tells candidates which Knight tests them next as they progress.
  - Once every test is passed, gathers the Knights' reviews, changes the candidate
    to Knight, clears job quest variables, and gives 7 Awakening Potions.
  - Greets Novices, Knights, other jobs, and advanced classes with flavor dialogue.

  ## Credits

  - Original from rAthena, authors and Contributors
    - PGRO TEAM (Aegis)
    - kobra_k88
    - Lupus
    - Vicious
    - L0ne_W0lf
    - Samuray22
    - Kisuka
    - Vali
    - Euphy
    - Joseph

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_in",
        x: 88,
        y: 101,
        dir: 4,
        sprite: 56,
        name: "Chivalry Captain",
        scope: :shared,
        unique_name: "Chivalry Captain#knt"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FClearjobvar
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Captain Herman]")

    cond do
      upper(ctx) == 1 -> bless_advanced_class(ctx)
      Rathena.job_id(base_job(ctx)) != Rathena.job_id(:swordman) -> greet_non_swordman(ctx)
      true -> talk_about_quest(ctx)
    end
  end

  defp bless_advanced_class(ctx) do
    ctx
    |> mes(
      "Hm? You're... What is it about you? I've been an honorable Knight for a long time, but I cannot understand this feeling I'm getting from you..."
    )
    |> next()
    |> mes("[Captain Herman]")
    |> mes(
      "May god bless your body and soul, warrior. I hope you will show your courage and protect those who are weaker than you."
    )
    |> close()
  end

  defp greet_non_swordman(ctx) do
    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:knight) ->
        ctx
        |> mes("Ah, a member of our Chivalry.")
        |> mes(
          "I hope you are living up to my expectations. We have vowed to be strong for our kingdom, even if death is upon us..."
        )
        |> close()

      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:novice) ->
        greet_novice(ctx)

      true ->
        ctx
        |> mes(
          "Welcome. We, the proud Knights of the Prontera Chivalry, will give our lives for king and country! Please enjoy your stay."
        )
        |> close()
    end
  end

  defp greet_novice(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Welcome,")
      |> mes("this is the")
      |> mes("Prontera Chivalry.")
      |> mes("What brings you here?")
      |> next()
      |> select([
        "I want to change my job to Swordman.",
        "I want to change my job to a Knight.",
        "Just visiting."
      ])

    case choice do
      1 ->
        youth = if male?(ctx), do: "lad", else: "lass"

        ctx
        |> mes("[Captain Herman]")
        |> mes("A-ha~")
        |> mes("A Swordman, you say?")
        |> mes("I'm sorry, #{youth}, but you've")
        |> mes("come to the wrong place!")
        |> next()
        |> mes("[Captain Herman]")
        |> mes(
          "This isn't the Swordsman guild, it's the Prontera Chivalry! If you wish to become a Swordman, visit the Swordman Guild located in Izlude."
        )
        |> close()

      2 ->
        ctx
        |> mes("[Captain Herman]")
        |> mes(
          "Ah, I see that you have great ambition. But you must first become a Swordman before becoming"
        )
        |> mes("a Knight. One step at a time...")
        |> next()
        |> mes("[Captain Herman]")
        |> mes(
          "First, visit the Swordman guild in Izlude. Then, come visit us again once you have become a well experienced Swordman."
        )
        |> close()

      3 ->
        ctx
        |> mes("[Captain Herman]")
        |> mes("Aha~")
        |> mes(
          "You must have lots of free time. Why don't you go hunt some monsters instead of wandering about aimlessly?"
        )
        |> close()

      _ ->
        talk_about_quest(ctx)
    end
  end

  defp talk_about_quest(ctx) do
    quest = get_char_var(ctx, :KNIGHT_Q, 0)

    cond do
      quest == 0 -> offer_application(ctx)
      quest == 1 -> point_to_first_test(ctx)
      quest == 4 -> ctx |> ask_about_progress() |> point_to_sir_siracuse()
      quest == 6 -> ctx |> ask_about_progress() |> point_to_sir_windsor()
      quest == 8 -> ctx |> ask_about_progress() |> point_to_lady_amy()
      quest == 10 -> ctx |> ask_about_progress() |> point_to_sir_edmond()
      quest == 12 -> ctx |> ask_about_progress() |> point_to_sir_gray()
      quest == 13 -> urge_final_test(ctx)
      quest == 14 -> evaluate(ctx)
      true -> encourage(ctx)
    end
  end

  defp offer_application(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Welcome, this is")
      |> mes("the Prontera Chivalry.")
      |> mes("What brings you here?")
      |> next()
      |> select(["I want to change my job to a Knight.", "Just visiting."])

    if choice == 1 do
      explain_application(ctx)
    else
      ctx
      |> mes("[Captain Herman]")
      |> mes(
        "Come to think of it, aren't you a Swordman? It looks like you've encountered many foes in battle."
      )
      |> next()
      |> mes("[Captain Herman]")
      |> mes(
        "You should consider changing jobs to a Knight. Come and talk to me if you are interested."
      )
      |> next()
      |> mes("[Captain Herman]")
      |> mes("Please take")
      |> mes("your time in")
      |> mes("looking around.")
      |> mes("Good day.")
      |> close()
    end
  end

  defp explain_application(ctx) do
    applicant = if male?(ctx), do: "man", else: "lady"

    {ctx, choice} =
      ctx
      |> mes("[Captain Herman]")
      |> mes("Ohh...")
      |> mes("A young #{applicant} who wishes")
      |> mes("to become a Knight!")
      |> mes("Our Prontera Chivalry")
      |> mes("will assist you.")
      |> next()
      |> mes("[Captain Herman]")
      |> mes(
        "First of all, I am the captain of the Prontera Chivalry, Herman Phon Efesirsus. I'm pleased to meet young people eager to join the Prontera Chivalry."
      )
      |> next()
      |> mes("[Captain Herman]")
      |> mes("We only accept Swordmen")
      |> mes("who are at least Job Level 40.")
      |> mes(
        "We cannot consider applicants that are not yet experienced enough to become Knights."
      )
      |> next()
      |> mes("[Captain Herman]")
      |> mes("Once you apply, and we find")
      |> mes("you eligible, we will begin the job change procedure. Would you")
      |> mes("like to apply now?")
      |> next()
      |> select(["Yes, I would like to apply.", "I'd like to think about it please."])

    if choice == 1 do
      apply_for_knighthood(mes(ctx, "[Captain Herman]"))
    else
      ctx
      |> mes("[Captain Herman]")
      |> mes("Oh...!")
      |> mes(
        "Well, I don't want to pressure you. Take your time and think it over. Return when you are ready to"
      )
      |> mes("change jobs, for we will be waiting.")
      |> close()
    end
  end

  defp apply_for_knighthood(ctx) do
    cond do
      job_level(ctx) < 40 ->
        ctx
        |> mes(
          "Ah, you are not yet ready to become a Knight! Didn't I specifically mention the Job Level 40 requirement?"
        )
        |> next()
        |> mes("[Captain Herman]")
        |> mes(
          "Of course I understand your strong desire to join us, but now is not the time. Go out and fight some more monsters. We will be here waiting."
        )
        |> close()

      Rathena.truthy?(skill_point(ctx)) ->
        ctx
        |> mes("Ah...!")
        |> mes(
          "You cannot change jobs if you have unused skill points remaining. Return when you have used"
        )
        |> mes("all of your skill points.")
        |> close()

      true ->
        register_applicant(ctx)
    end
  end

  defp register_applicant(ctx) do
    ctx =
      ctx
      |> set_char_var(:KNIGHT_Q, 1)
      |> setquest(9000)
      |> mes("Let me see...")
      |> mes("Your name is")

    ctx
    |> mes("#{char_name(ctx, 0)}...")
    |> mes("Is that right?")
    |> next()
    |> mes("[Captain Herman]")
    |> mes(
      "Let me explain the job change procedure. You must visit a series of Knights and pass each"
    )
    |> mes("of their tests.")
    |> next()
    |> mes("[Captain Herman]")
    |> mes(
      "Once all the tests are completed, every Knight involved in your testing will gather and discuss your performance."
    )
    |> next()
    |> mes("[Captain Herman]")
    |> mes(
      "The Knights must unanimously approve of you before you can join the Prontera Chivalry. If only one person objects, you must"
    )
    |> mes("start over.")
    |> next()
    |> mes("[Captain Herman]")
    |> mes(
      "But I believe if you persist with an earnest heart, you shall be acknowledged by the Knights and ultimately recognized as a member of our Chivalry."
    )
    |> next()
    |> mes("[Captain Herman]")
    |> mes(
      "So, let's not waste any more time talking! Go and meet these Knights and begin their tests. Once you have completed all of the tests, come back to me."
    )
    |> close()
  end

  defp point_to_first_test(ctx) do
    ctx
    |> mes("Mmm?")
    |> mes("#{char_name(ctx, 0)},")
    |> mes("what can I do for you?")
    |> mes("Ah, you don't know")
    |> mes("who to visit?")
    |> next()
    |> mes("[Captain Herman]")
    |> mes(
      "I believe the Knights in charge of testing have set an order in which you must visit them. I suppose it helps the testing process."
    )
    |> next()
    |> mes("[Captain Herman]")
    |> mes("First, go and visit")
    |> mes(
      "Sir Andrew for your first test. Don't be too nervous, he'll explain everything once you talk to him."
    )
    |> close()
  end

  defp point_to_sir_siracuse(ctx) do
    ctx
    |> mes(
      "It appears that you have finished one test. Let's see. Sir Andrew, who must this Swordman visit next?"
    )
    |> next()
    |> mes("[Sir Andrew]")
    |> mes("I said to")
    |> mes("visit Sir Siracuse.")
    |> mes("Funny, I thought I told")
    |> mes("you. Did I forget...?")
    |> next()
    |> mes("[Captain Herman]")
    |> mes("Did you hear?")
    |> mes(
      "Go to Sir Siracuse and take his test. Once you complete his test, do not forget who you're supposed to visit next as well."
    )
    |> close()
  end

  defp point_to_sir_windsor(ctx) do
    ctx
    |> mes("Let's see...")
    |> mes("You've completed two tests.")
    |> mes("Sir Siracuse, who must this Swordman visit next?")
    |> next()
    |> mes("[Sir Siracuse]")
    |> mes("Oh...!")
    |> mes("Um, who was next...?")
    |> mes("Right! Sir Windsor!")
    |> next()
    |> mes("[Captain Herman]")
    |> mes("Head over to")
    |> mes(
      "Sir Windsor Benedict for your next test. Listen carefully to the Knights in charge of testing so that you don't feel lost, alright?"
    )
    |> close()
  end

  defp point_to_lady_amy(ctx) do
    ctx
    |> mes("Sir Windor...?")
    |> mes("Who must this")
    |> mes("Swordman visit")
    |> mes("next?")
    |> next()
    |> mes("[Sir Windsor]")
    |> mes("...")
    |> next()
    |> mes("[Sir Windsor]")
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes("[Sir Windsor]")
    |> mes("...Amy Beatrice.")
    |> next()
    |> mes("[Captain Herman]")
    |> mes("Ah, go and visit")
    |> mes(
      "Lady Amy and take her test. Make sure you pay attention to who you must go to for your next test."
    )
    |> close()
  end

  defp point_to_sir_edmond(ctx) do
    ctx
    |> mes("Let's see...")
    |> mes("Lady Amy, who")
    |> mes("must this Swordman")
    |> mes("visit next?")
    |> next()
    |> mes("[Lady Amy]")
    |> mes("Oh...")
    |> mes("I said to visit")
    |> mes("Sir Edmond!")
    |> mes("Tee hee~")
    |> next()
    |> mes("[Captain Herman]")
    |> mes("Now, go and speak")
    |> mes("to Sir Edmond. He will")
    |> mes("be in charge of your")
    |> mes("next test.")
    |> close()
  end

  defp point_to_sir_gray(ctx) do
    ctx
    |> mes("Don't you only have to visit one more person? The Knight in")
    |> mes("charge of the final test")
    |> mes("is Sir Gray Prospheiro.")
    |> next()
    |> mes("[Sir Edmond]")
    |> mes("This world operates according")
    |> mes("to the law of cause and effect.")
    |> mes("All will be revealed in the end.")
    |> next()
    |> mes("[Captain Herman]")
    |> mes("Be alert and do")
    |> mes("your best, as this")
    |> mes("is the last test.")
    |> next()
    |> mes("[Captain Herman]")
    |> mes("Return to me")
    |> mes("after you have")
    |> mes("completed the")
    |> mes("final test.")
    |> close()
  end

  defp urge_final_test(ctx) do
    ctx
    |> mes("Finish the last test.")
    |> mes(
      "Once that is complete, all the Knights involved in your testing shall gather, and we will evaluate your performance."
    )
    |> close()
  end

  defp evaluate(ctx) do
    if Rathena.truthy?(skill_point(ctx)) do
      ctx
      |> mes("Oh...!")
      |> mes(
        "You cannot change jobs if you have unused skill points remaining. Return once you have distributed all your skill points."
      )
      |> close()
    else
      gather_reviews(ctx)
    end
  end

  defp gather_reviews(ctx) do
    ctx
    |> mes("Oh, have you completed all the tests? But not everyone who completes the tests can")
    |> mes("become a Knight.")
    |> next()
    |> mes("[Captain Herman]")
    |> mes(
      "During the test we see how loyal, honorable and strong you are. We also see if you were courteous and if you know the value of modesty and reverence."
    )
    |> next()
    |> mes("[Captain Herman]")
    |> mes(
      "Through this process, I have also observed your actions. All seven of our opinions will be reflected in the decision of your job change."
    )
    |> next()
    |> mes("[Captain Herman]")
    |> mes("Then...")
    |> mes("We shall listen")
    |> mes("to everyone's thoughts!")
    |> mes("Andrew, what do you think?")
    |> next()
    |> mes("[Sir Andrew]")
    |> review_by_sir_andrew()
    |> next()
    |> mes("[Captain Herman]")
    |> mes("Hmm.")
    |> mes("What a nice review.")
    |> mes("Siracuse, what are your thoughts?")
    |> next()
    |> mes("[Sir Siracuse]")
    |> mes("Heh, very well. Not quite what")
    |> mes("I would want, but hopefully will become better in the future.")
    |> next()
    |> mes("[Sir Siracuse]")
    |> mes(
      "After becoming a Knight, you must build a good reputation through honor. Ehh... I approve."
    )
    |> next()
    |> mes("[Captain Herman]")
    |> mes("Okay...")
    |> mes("Windsor,")
    |> mes("what about you?")
    |> next()
    |> mes("[Sir Windsor]")
    |> mes("...")
    |> next()
    |> mes("[Sir Windsor]")
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes("[Sir Windsor]")
    |> mes("....Approved.")
    |> next()
    |> mes("[Captain Herman]")
    |> mes("I don't think")
    |> mes("he disapproves.")
    |> mes("Then, let's listen")
    |> mes("to Amy's opinion.")
    |> next()
    |> mes("[Lady Amy]")
    |> review_by_lady_amy()
    |> next()
    |> mes("[Captain Herman]")
    |> mes("Well...")
    |> mes("A strange review,")
    |> mes("but I believe")
    |> mes("she approves.")
    |> mes("Edmond, speak")
    |> mes("your mind.")
    |> next()
    |> mes("[Sir Edmond]")
    |> review_by_sir_edmond()
    |> next()
    |> mes("[Captain Herman]")
    |> mes("Lastly...")
    |> mes("Gray. I would like")
    |> mes("to hear your thoughts.")
    |> next()
    |> mes("[Gray]")
    |> promote_to_knight()
  end

  defp review_by_sir_andrew(ctx) do
    if job_level(ctx) == 50 do
      ctx
      |> mes("What can I say?")
      |> mes("I approve!")
      |> mes("Having lived as")
      |> mes("a Swordsman up")
      |> mes("until now")
      |> mes("is enough.")
    else
      pronoun = if male?(ctx), do: "", else: "s"

      ctx
      |> mes("This one has")
      |> mes("gathered items")
      |> mes("that are troublesome")
      |> mes("to obtain. I approve!")
      |> mes("I believe #{pronoun}he will continue to be loyal after becoming a Knight.")
    end
  end

  defp review_by_lady_amy(ctx) do
    if male?(ctx) do
      ctx
      |> mes("Mmm~ He's so polite!")
      |> mes(
        "He'll grow to be a wonderful Knight. And he's got such cute widdle cheeeeks~ Hee hee!"
      )
    else
      ctx
      |> mes("Mmm~ She should be great!")
      |> mes("She's very courteous and also very cute, so a few more points! Heh~")
      |> mes("I shouldn't be saying things like this!")
    end
  end

  defp review_by_sir_edmond(ctx) do
    if male?(ctx) do
      ctx
      |> mes(
        "He seems a little rough, but something bright shines within him. With polish and refinement, his true value will shine forth"
      )
      |> mes("as the sun.")
    else
      ctx
      |> mes(
        "It's difficult to see, but there is a spiritual beauty within her. With polish and refinement, her true value will glow as resplendently"
      )
      |> mes("as the moon.")
    end
  end

  defp promote_to_knight(ctx) do
    candidate = if male?(ctx), do: "gentleman", else: "lady"

    {ctx, _} =
      ctx
      |> mes(
        "A young #{candidate} coming here with the determination to become a Knight is enough..."
      )
      |> next()
      |> mes("[Captain Herman]")
      |> mes("Everyone")
      |> mes("has approved.")
      |> mes("No one has opposed.")
      |> mes("Then I shall tell")
      |> mes("you my opinion.")
      |> next()
      |> mes("[Captain Herman]")
      |> mes("My decision is...")
      |> next()
      |> mes("[Captain Herman]")
      |> mes("I approve.")
      |> next()
      |> mes("[Captain Herman]")
      |> mes(
        "You may not have finished all the tests perfectly, but you have all the necessary qualities to become"
      )
      |> mes("a Knight.")
      |> next()
      |> completequest(9012)
      |> jobchange(:knight)
      |> FClearjobvar.call([])

    ctx
    |> mes("[Captain Herman]")
    |> mes("I hereby declare")
    |> mes("you a member of")
    |> mes("the Prontera Chivalry.")
    |> mes("Protect the weak and")
    |> mes("live with honor.")
    |> next()
    |> give_item(656, 7)
    |> mes("[Captain Herman]")
    |> mes("Oh...")
    |> mes(
      "We have prepared a small gift to congratulate you on your job change. Please use it when you are in battle as you honorably protect others."
    )
    |> next()
    |> mes("[Captain Herman]")
    |> mes("Go forth!")
    |> mes("The future of")
    |> mes("Rune-Midgarts")
    |> mes("rests on your")
    |> mes("shoulders!")
    |> close()
  end

  defp ask_about_progress(ctx) do
    ctx
    |> mission_opening()
    |> mes("Ah~ You do not know")
    |> mes("who to visit next?")
    |> next()
    |> mes("[Captain Herman]")
  end

  defp encourage(ctx) do
    ctx
    |> mission_opening()
    |> mes("It may be difficult,")
    |> mes("but do your best.")
    |> close()
  end

  defp mission_opening(ctx) do
    ctx
    |> mes("Mmm?")
    |> mes("Swordman #{char_name(ctx, 0)}.")
    |> mes("How are the tests?")
  end

  defp male?(ctx), do: sex(ctx) == get_char_var(ctx, :SEX_MALE, 0)
end
