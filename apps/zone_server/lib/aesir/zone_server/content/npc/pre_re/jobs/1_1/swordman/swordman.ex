defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.M11.Swordman.Swordman do
  @moduledoc """
  Swordman Association receptionist in Izlude who signs up applicants and promotes them to Swordman.

  ## Behavior

  - Reborn characters are handled first: a Novice High whose advanced job is Lord Knight or Paladin
    is promoted to High Swordman at once; every other reborn character is turned away.
  - Novices may apply, which sets the save point, flags the quest and offers the interview; the
    application is then reviewed against the Basic Skill requirement and the test result.
  - An applicant without all Basic Skills, or without a passed test, is sent away with the matching
    explanation; an applicant who passed becomes a Swordman and the quest is closed.
  - Also describes the job and lists its two requirements: the Basic Skills and the Swordman Test.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - ultramage

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script pre-re/jobs/1-1/swordman.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "izlude_in",
        x: 74,
        y: 172,
        dir: 4,
        sprite: 119,
        name: "Swordman",
        scope: :pre_renewal,
        unique_name: "Swordman#swd_1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @menu ["Job Change", "About Swordman.", "About the Job requirements.", "Cancel."]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if upper(ctx) == 1 do
      reborn(ctx)
    else
      association(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp reborn(ctx) do
    if Rathena.job_id(class(ctx)) == Rathena.job_id(:novice_high) and
         get_char_var(ctx, :ADVJOB, 0) in [
           Rathena.job_id(:lord_knight),
           Rathena.job_id(:paladin)
         ] do
      promote_high_swordman(ctx)
    else
      ctx
      |> mes("[Swordman]")
      |> mes("Hm...?")
      |> mes("You're a reborn")
      |> mes("warrior, aren't you?")
      |> next()
      |> mes("[Swordman]")
      |> mes("Hmmm...")
      |> mes("It seems that being")
      |> mes("a Swordman is not part")
      |> mes("of your destiny. I'm sorry,")
      |> mes("but it seems there is nothing")
      |> mes("I can do for you.")
      |> close()
    end
  end

  defp promote_high_swordman(ctx) do
    ctx =
      ctx
      |> mes("[Swordman]")
      |> mes("It...")
      |> mes("Can't be...")
      |> mes("You've been reborn, haven't you?")
      |> next()
      |> mes("[Swordman]")
      |> mes(
        "I see you're retreading the path of the Swordman! Once you've gotten used to brandishing a sword, you can never go back!!"
      )
      |> next()

    if Rathena.truthy?(can_change_job?(ctx)) do
      ctx
      |> mes("[Swordman]")
      |> mes("Excellent! Let me promote you to a Swordman right away!")
      |> next()
      |> skill(143, 0, :permanent)
      |> jobchange(:swordman_high)
      |> skill(144, 1, :permanent)
      |> skill(145, 1, :permanent)
      |> skill(146, 1, :permanent)
      |> mes("[Swordman]")
      |> mes(
        "Hmm... You look like a well-experienced Swordman. Still, I'm sure that you must train to improve your skills and gain strength!"
      )
      |> close()
    else
      ctx
      |> mes("[Swordman]")
      |> mes(
        "Hmm? Ah, you must first master the Basic Skills before you are ready to become a Swordman."
      )
      |> next()
      |> mes("[Swordman]")
      |> mes("Come back to me when you have finished learning the Basic Novice Skills.")
      |> close()
    end
  end

  defp association(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Swordman]")
      |> mes("Welcome to the")
      |> mes("Swordman Association!")
      |> next()
      |> mes("[Swordman]")
      |> mes("So...")
      |> mes("What business")
      |> mes("brings you to us?")
      |> next()
      |> select(@menu)

    case choice do
      1 -> request_change(ctx)
      2 -> describe_job(ctx)
      3 -> list_requirements(ctx)
      4 -> ctx |> mes("[Swordman]") |> mes("Ha ha ha!") |> mes("Ah, youth!") |> close()
      _ -> ctx
    end
  end

  defp request_change(ctx) do
    job = Rathena.job_id(base_job(ctx))

    cond do
      job == Rathena.job_id(:swordman) ->
        ctx
        |> mes("[Swordman]")
        |> mes("Job change? Muhahaha! But you're already a Swordman! Be proud and be strong!")
        |> close()
        |> halt()

      job != Rathena.job_id(:novice) ->
        ctx
        |> mes("[Swordman]")
        |> mes(
          "Haha! Oh boy. I'm flattered, but you already have another job! Still, I can't blame you..."
        )
        |> close()
        |> halt()

      true ->
        ctx
        |> sign_up()
        |> review_application()
        |> describe_job()
    end
  end

  defp sign_up(ctx) do
    if get_char_var(ctx, :job_sword_q, 0) == 0 do
      {ctx, choice} =
        ctx
        |> mes("[Swordman]")
        |> mes("So you wish to become a proud Swordman? By all means, please sign up!")
        |> next()
        |> select(["Sign up.", "Cancel."])

      if choice == 1 do
        interview(ctx)
      else
        ctx
        |> mes("[Swordman]")
        |> mes(
          "Hm? Alright, come back whenever you change your mind. The world can always use another Swordman!"
        )
        |> close()
        |> halt()
      end
    else
      ctx
    end
  end

  defp interview(ctx) do
    {ctx, choice} =
      ctx
      |> savepoint("izlude_in", 65, 165)
      |> set_char_var(:job_sword_q, 1)
      |> setquest(1014)
      |> mes("[Swordman]")
      |> mes("Ah, yes. Your application will be reviewed as soon as possible.")
      |> next()
      |> mes("[Swordman]")
      |> mes(
        "If you have already met the requirements, you can take an interview right now. Would you like to?"
      )
      |> next()
      |> select(["Yes.", "No."])

    if choice == 1 do
      ctx
      |> mes("[Swordman]")
      |> mes("Good, good.")
      |> mes("Now, let's see...")
      |> next()
    else
      ctx
      |> mes("[Swordman]")
      |> mes(
        "Alright then. Feel free to come back whenever you are ready. All you have to do now is meet our requirements. Good luck to you."
      )
      |> close()
      |> halt()
    end
  end

  defp review_application(ctx) do
    ctx = mes(ctx, "[Swordman]")
    quest_state = get_char_var(ctx, :job_sword_q, 0)

    cond do
      not Rathena.truthy?(can_change_job?(ctx)) ->
        ctx
        |> mes(
          "Hm, you still haven't learned all of the Basic Skills. You need to do that before you can become a Swordman."
        )
        |> next()
        |> mes("[Swordman]")
        |> mes("Check the requirements for job change again, and come back when you are ready.")
        |> close()
        |> halt()

      quest_state <= 3 ->
        ctx
        |> mes(
          "Hm, you've learned all of the Basic Skills but didn't take the test yet. You must first pass the exam before you can change your job to Swordman."
        )
        |> next()
        |> mes("[Swordman]")
        |> mes(
          "Enter the room to my right so that you can take the test. You'll need to speak to my right so you can enter the examination area."
        )
        |> close()
        |> halt()

      quest_state == 4 ->
        ctx
        |> mes(
          "Hahaha! Congratulations! Now you are fully qualified to be a real Swordman! I will transform you right away!"
        )
        |> next()
        |> jobchange(:swordman)
        |> set_char_var(:job_sword_q, 0)
        |> completequest(1014)
        |> mes("[Swordman]")
        |> mes(
          "Once again, congratulations. I expect that you will be a good representative of the Swordman Association."
        )
        |> close()
        |> halt()

      true ->
        ctx
    end
  end

  # The reference reaches this description from the `About Swordman.` menu entry, and also by
  # falling through from `Job change` when the review closes no branch.
  defp describe_job(ctx) do
    ctx
    |> mes("[Swordman]")
    |> mes("So you wish to know more about the mighty Swordman job? Well, then...")
    |> next()
    |> mes("[Swordman]")
    |> mes(
      "Amongst the First Class jobs, the Swordman is the best melee fighter for three reasons."
    )
    |> mes("There are 3 reasons why Swordy is the best to approch a fight!")
    |> next()
    |> mes("[Swordman]")
    |> mes(
      "First, Swordman has the benefit of additional HP. Second, Swordman generally have access to a wider selection fo weapons than the other First Class jobs."
    )
    |> next()
    |> mes("[Swordman]")
    |> mes(
      "And third, most of the Swordman skills are crushing physical attacks! In my opinion, being a Swordman is the best job ever!"
    )
    |> close()
  end

  defp list_requirements(ctx) do
    ctx = ctx |> mes("[Swordman]") |> mes("Hmmm...")
    job = Rathena.job_id(base_job(ctx))

    ctx =
      cond do
        job == Rathena.job_id(:swordman) ->
          mes(
            ctx,
            "But there's no need to tell you the requirements. You've met them and already became a Swordman! Well, anyway..."
          )

        job != Rathena.job_id(:novice) ->
          mes(
            ctx,
            "It's too late for you to become a Swordman. You already have another job. Still, there's no harm in telling you..."
          )

        true ->
          ctx
      end

    ctx
    |> next()
    |> mes("[Swordman]")
    |> mes(
      "First, you must learn all 9 of the Basic Skills. If you can't complete this requirement, you won't be able to change to any job."
    )
    |> next()
    |> mes("[Swordman]")
    |> mes(
      "Second, you must pass the Swordman Test. Inquire the Test Manager located in the waiting room of the Swordman Test."
    )
    |> next()
    |> mes("[Swordman]")
    |> mes(
      "If you can complete these 2 requirements, you can change to a Swordman anytime you want."
    )
    |> close()
  end

  defp halt(ctx), do: throw({:script_end, ctx})
end
