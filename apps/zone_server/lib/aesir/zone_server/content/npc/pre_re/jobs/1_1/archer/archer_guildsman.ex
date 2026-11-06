defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.M11.Archer.ArcherGuildsman do
  @moduledoc """
  Registers Archer applicants, appraises their trunks, and grants the Archer job.

  ## Behavior

  - Grades trunks toward the entrance test and awards a bow and arrows to successful applicants.
  - Promotes eligible reborn Novices and explains the normal admission requirements.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - massdriller

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script pre-re/jobs/1-1/archer.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "payon_in02",
        x: 64,
        y: 71,
        dir: 4,
        sprite: 85,
        name: "Archer Guildsman",
        scope: :pre_renewal,
        unique_name: "Archer Guildsman#archer"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FClearjobvar
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if upper(ctx) == 1 do
      greet_reborn(ctx)
    else
      {ctx, choice} =
        ctx
        |> mes("[Archer Guildsman]")
        |> mes("Good day. How may I help you?")
        |> next()
        |> select([
          "I want to be an Archer.",
          "I need the requirements, please.",
          "Nothing, thanks."
        ])

      case choice do
        1 -> apply_for_archer(ctx)
        2 -> explain_requirements(ctx)
        3 -> close(ctx)
        _ -> ctx
      end
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp greet_reborn(ctx) do
    if Rathena.job_id(class(ctx)) == Rathena.job_id(:novice_high) and
         (get_char_var(ctx, :ADVJOB, 0) == Rathena.job_id(:sniper) or
            get_char_var(ctx, :ADVJOB, 0) == Rathena.job_id(:clown) or
            get_char_var(ctx, :ADVJOB, 0) == Rathena.job_id(:gypsy)) do
      ctx =
        ctx
        |> mes("[Archer Guildsman]")
        |> mes("Hey, I know you.")
        |> mes("You took this test")
        |> mes("before, didn't you?")
        |> next()
        |> mes("[Archer Guildsman]")
        |> mes("Ah, you must have been")
        |> mes("to Valhalla and been reborn.")
        |> mes("Wow, that's so impressive!")
        |> next()

      if Rathena.truthy?(can_change_job?(ctx)) do
        ctx
        |> mes("[Archer Guildsman]")
        |> mes("Well then. I don't")
        |> mes("need to say anything else.")
        |> mes("I know you'll make a great Archer...")
        |> next()
        |> skill(143, 0, :permanent)
        |> jobchange(:archer_high)
        |> skill(147, 1, :permanent)
        |> skill(148, 1, :permanent)
        |> mes("[Archer Guildsman]")
        |> mes("Although there's no special")
        |> mes("reward for you this time, I hope you understand. Take care of yourself.")
        |> close()
      else
        ctx
        |> mes("[Archer Guildsman]")
        |> mes("Err...")
        |> mes("You'd better learn all the Basic Skills first before you can become an Archer.")
        |> next()
        |> mes("[Archer Guildsman]")
        |> mes("Alright, see you later.")
        |> close()
      end
    else
      ctx
      |> mes("[Archer Guildsman]")
      |> mes("Oh...?")
      |> mes("Hey, what are")
      |> mes("you doing here...?")
      |> next()
      |> mes("[Archer Guildsman]")
      |> mes(
        "I can tell that you're not cut out to be an Archer. It sort of feels like you're meant to do"
      )
      |> mes("something else...")
      |> close()
    end
  end

  defp apply_for_archer(ctx) do
    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:archer) ->
        ctx
        |> mes("[Archer Guildsman]")
        |> mes("You've already become an Archer...")
        |> close()

      Rathena.job_id(base_job(ctx)) != Rathena.job_id(:novice) ->
        ctx
        |> mes("[Archer Guildsman]")
        |> mes("Hmm...")
        |> mes("You don't look much like a Novice at all...")
        |> next()
        |> mes("[Archer Guildsman]")
        |> mes(
          "Anyway, whatever you are, you can't choose a job as an Archer because you have a job already."
        )
        |> close()

      true ->
        if get_char_var(ctx, :job_archer_q, 0) == 0 do
          register_applicant(ctx)
        else
          check_applicant(ctx)
        end
    end
  end

  defp register_applicant(ctx) do
    {ctx, application} =
      ctx
      |> mes("[Archer Guildsman]")
      |> mes("Do you want to be an Archer?")
      |> mes("If so, you need to fill out this application form.")
      |> next()
      |> select(["Apply.", "Cancel"])

    if application == 1 do
      {ctx, readiness} =
        ctx
        |> set_char_var(:job_archer_q, 1)
        |> setquest(1004)
        |> mes("[Archer Guildsman]")
        |> mes("Okay, sign here. Alright, um, I'll promote you once you meet the requirements.")
        |> next()
        |> mes("[Archer Guildsman]")
        |> mes("If you think you've met them already, we can check that now.")
        |> mes("Are you ready?")
        |> next()
        |> select(["Yes, I am.", "No, not yet."])

      if readiness == 1 do
        ctx
        |> mes("[Archer Guildsman]")
        |> mes("Alright, let me check.")
        |> next()
        |> check_applicant()
      else
        ctx
        |> mes("[Archer Guildsman]")
        |> mes("I understand. Be my guest if you want to look at the requirements.")
        |> close()
      end
    else
      ctx
      |> mes("[Archer Guildsman]")
      |> mes("Well, alright.")
      |> mes("See you next time.")
      |> close()
    end
  end

  defp check_applicant(ctx) do
    ctx =
      ctx
      |> mes("[Archer Guildsman]")
      |> mes("Are you...#{char_name(ctx, 0)}?")
      |> next()

    if Rathena.truthy?(can_change_job?(ctx)) do
      if get_char_var(ctx, :job_archer_q, 0) == 1 do
        appraise_trunks(ctx)
      else
        promote_archer(ctx)
      end
    else
      ctx
      |> mes("[Archer Guildsman]")
      |> mes("Well, you're not at the right job level. Please check the requirements again.")
      |> next()
      |> mes("[Archer Guildsman]")
      |> mes(
        "Your job level must be at least 10, and don't forget you should learn all of the Basic Skills. Once you've done that, come back."
      )
      |> close()
    end
  end

  defp appraise_trunks(ctx) do
    ctx =
      ctx
      |> set_local(:archer_item1, count_item(ctx, 1066) * 5)
      |> set_local(:archer_item2, count_item(ctx, 1067) * 3)
      |> set_local(:archer_item3, count_item(ctx, 1068) * 2)
      |> set_local(:archer_item4, count_item(ctx, 1019))

    ctx =
      set_local(
        ctx,
        :total_archer,
        get_local(ctx, :archer_item1, 0) + get_local(ctx, :archer_item2, 0) +
          get_local(ctx, :archer_item3, 0) + get_local(ctx, :archer_item4, 0)
      )

    ctx =
      ctx
      |> set_local(
        :total_archer2,
        (get_local(ctx, :archer_item2, 0) + get_local(ctx, :archer_item3, 0)) * 2 +
          get_local(ctx, :archer_item4, 0)
      )
      |> mes("[Archer Guildsman]")
      |> mes("Excellent!")
      |> mes("Now then,")
      |> mes("let's see...")
      |> next()
      |> mes("[Archer Guildsman]")
      |> mes(
        "I will appraise the value of the various types of Trunks, needed to produce a Bow, that you've brought."
      )
      |> next()

    if count_item(ctx, 1066) == 0 and count_item(ctx, 1067) == 0 and
         count_item(ctx, 1068) == 0 and count_item(ctx, 1019) == 0 do
      ctx
      |> mes("[Archer Guildsman]")
      |> mes("Um...")
      |> mes(
        "Unfortunately you didn't bring any of the required items. There's nothing for me to appraise."
      )
      |> close()
    else
      grade_trunks(ctx)
    end
  end

  defp grade_trunks(ctx) do
    ctx =
      ctx
      |> mes("[Archer Guildsman]")
      |> show_trunk_grade(1066, :archer_item1, " Grade S : ", " ea, Grade: ")
      |> show_trunk_grade(1067, :archer_item2, " Grade A : ", " ea, Grade : ")
      |> show_trunk_grade(1068, :archer_item3, " Grade B : ", " ea, Grade : ")
      |> show_trunk_grade(1019, :archer_item4, " Grade C : ", " ea, Grade : ")

    if get_local(ctx, :total_archer, 0) < 25 do
      ctx
      |> mes("Total Grades: ^FF0000#{get_local(ctx, :total_archer, 0)}^000000 / 40")
      |> next()
      |> mes("[Archer Guildsman]")
      |> mes("Less than 25!? You have to get a grade of at least 25! Come on, try harder!")
      |> close()
    else
      ctx =
        ctx
        |> mes("Total Grades: ^0000FF#{get_local(ctx, :total_archer, 0)}^000000 / 40")
        |> next()
        |> mes("[Archer Guildsman]")

      ctx =
        cond do
          get_local(ctx, :total_archer, 0) > 40 ->
            ctx |> mes("Wow! More than 40!") |> mes("Excellent! Congratulations!")

          get_local(ctx, :total_archer, 0) > 30 ->
            ctx |> mes("More than 30! Nice job!") |> mes("Congratulations!")

          true ->
            mes(ctx, "*Sigh* Well, you just barely passed... Anyway, well done.")
        end

      ctx
      |> next()
      |> mes("[Archer Guildsman]")
      |> mes(
        "I'll transfer these Trunks to our Bow Production Department. Now that you've met the requirements, let me promote you right away!"
      )
      |> take_trunks(1066)
      |> take_trunks(1067)
      |> take_trunks(1068)
      |> take_trunks(1019)
      |> promote_archer()
    end
  end

  defp show_trunk_grade(ctx, item_id, grade_key, label, separator) do
    if count_item(ctx, item_id) != 0 do
      mes(
        ctx,
        "#{label}#{count_item(ctx, item_id)}#{separator}#{get_local(ctx, grade_key, 0)} . "
      )
    else
      ctx
    end
  end

  defp take_trunks(ctx, item_id) do
    if count_item(ctx, item_id) != 0 do
      delitem(ctx, item_id, count_item(ctx, item_id))
    else
      ctx
    end
  end

  defp promote_archer(ctx) do
    {ctx, _} = ctx |> next() |> jobchange(:archer) |> FClearjobvar.call([])

    ctx =
      ctx
      |> completequest(1004)
      |> mes("[Archer Guildsman]")
      |> mes("Congratulations!")
      |> mes("You are now an Archer!")
      |> next()
      |> mes("[Archer Guildsman]")
      |> mes(
        "Of course, we expect that you will help contribute towards the future of the Archer Guild with your efforts."
      )
      |> next()
      |> mes("[Archer Guildsman]")
      |> mes(
        "Ah, your bow has arrived from the Bow Production Department. Here, take it! It's yours~"
      )
      |> give_item(1702, 1)

    ctx
    |> give_item(1750, get_local(ctx, :total_archer2, 0))
    |> next()
    |> mes("[Archer Guildsman]")
    |> mes("Now, off you go. Hunt with pride, knowing you were trained by one of the best!")
    |> close()
  end

  defp explain_requirements(ctx) do
    ctx =
      ctx
      |> mes("[Archer Guildsman]")
      |> mes("I will explain the requirements for being an Archer.")

    ctx =
      if Rathena.job_id(base_job(ctx)) != Rathena.job_id(:novice) do
        ctx =
          if Rathena.job_id(base_job(ctx)) == Rathena.job_id(:archer) do
            ctx
            |> next()
            |> mes("[Archer Guildsman]")
            |> mes("But...")
            |> mes("You're already an Archer. You should know these already...")
          else
            ctx
            |> next()
            |> mes("[Archer Guildsman]")
            |> mes(
              "Wait a second. You've chosen a different job already. You don't need to know this~"
            )
          end

        mes(ctx, "So...Yeah...no real reason to tell you the requirements...")
      else
        ctx
      end

    ctx
    |> next()
    |> mes("[Archer Guildsman]")
    |> mes(
      "First of all, you have to the Job Level 9 as a Novice, and know all of the Basic Skills."
    )
    |> next()
    |> mes("[Archer Guildsman]")
    |> mes(
      "An Archer needs extremely high concentration and reflexes, so we do not accept those who have little patience."
    )
    |> next()
    |> mes("[Archer Guildsman]")
    |> mes(
      "You also have to gather ^FF0000Trunks^000000. There are 4 different types of Trunks, each of differing quality. You'll be given different grades for your Trunks, depending on their quality."
    )
    |> next()
    |> mes("[Archer Guildsman]")
    |> mes(
      "In order to become an Archer, you must receive a grade of at least ^0000FF25^000000 points out of 40. You can get Trunks from 'Willow,' the tree. Be careful, though. They can be tough monsters."
    )
    |> close()
  end
end
