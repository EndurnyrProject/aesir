defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.M11.Mage.MageGuildsman do
  @moduledoc """
  Administers the Mage guild application and solution test.

  ## Behavior

  - Assigns a solution, checks submissions, and changes successful applicants into Mages.
  - Restores eligible reborn applicants to the High Mage job.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - massdriller
    - Samuray22
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script pre-re/jobs/1-1/mage.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "geffen_in",
        x: 164,
        y: 124,
        dir: 4,
        sprite: 123,
        name: "Mage Guildsman",
        scope: :pre_renewal
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FClearjobvar
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if upper(ctx) == 1, do: greet_reborn(ctx), else: offer_services(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp greet_reborn(ctx) do
    cond do
      get_char_var(ctx, :ADVJOB, 0) != Rathena.job_id(:high_wizard) and
          get_char_var(ctx, :ADVJOB, 0) != Rathena.job_id(:professor) ->
        ctx
        |> mes("[Mage Guildsman]")
        |> mes(
          "What, are you interested in the Mage guild? I didn't want to tell you this, but you don't belong here."
        )
        |> next()
        |> mes("[Mage Guildsman]")
        |> mes(
          "I am not sure why you're still standing in front of me, but I can tell that you're not meant to be a Mage."
        )
        |> close()

      Rathena.job_id(class(ctx)) == Rathena.job_id(:novice_high) ->
        restore_magic(ctx)

      true ->
        ctx
        |> mes("[Mage Guildsman]")
        |> mes(
          "Is there anything more I can help you with? If not, why don't you go test your skills? The world is waiting for you~!"
        )
        |> close()
    end
  end

  defp restore_magic(ctx) do
    ctx =
      ctx
      |> mes("[Mage Guildsman]")
      |> mes("Whoa, long time no see! But weren't you supposed to be dead?")
      |> next()
      |> mes("[Mage Guildsman]")
      |> mes("Ah, you must have been reborn. Well, I'm glad to have you back.")
      |> next()

    if Rathena.truthy?(can_change_job?(ctx)) do
      ctx
      |> mes("[Mage Guildsman]")
      |> mes(
        "Well, since you have passed the Mage test once, I will not question your qualification. You want to have your magic skills back immediately, don't you?"
      )
      |> next()
      |> skill(143, 0, :permanent)
      |> jobchange(:mage_high)
      |> skill(157, 1, :permanent)
      |> mes("[Mage Guildsman]")
      |> mes(
        "Wow, for some reason, you look way better than you did before. Anyway, I believe you will do a better job being a Mage as well."
      )
      |> close()
    else
      ctx
      |> mes("[Mage Guildsman]")
      |> mes(
        "I'm sorry, but I don't think you're ready to learn magic yet. Why don't you go finish learning the Basic Skills first?"
      )
      |> next()
      |> mes("[Mage Guildsman]")
      |> mes("Take your time. The more you learn, the more ready you'll be to learn magic again.")
      |> close()
    end
  end

  defp offer_services(ctx) do
    {ctx, service} =
      ctx
      |> mes("[Mage Guildsman]")
      |> mes("Yo. What's up?")
      |> next()
      |> select(["I want to be a Mage.", "Tell me the Requirements.", "Pretty much nothing."])

    case service do
      1 -> apply_for_test(mes(ctx, "[Mage Guildsman]"))
      2 -> explain_requirements(ctx)
      3 -> ctx |> mes("[Mage Guildsman]") |> mes("Nothing...?") |> close()
      _ -> ctx
    end
  end

  defp apply_for_test(ctx) do
    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:mage) ->
        ctx
        |> mes("Hey, haven't you realized? You're aleady a Mage, silly!")
        |> next()
        |> mes("[Mage Guildsman]")
        |> mes(
          "One of these days you'll realize the power inside of you when you can make Fire with your mind!"
        )
        |> close()

      Rathena.job_id(base_job(ctx)) != Rathena.job_id(:novice) ->
        ctx
        |> mes(
          "Hey~ C'mon. Quit playing games. You can't be a Mage because you already have another Job."
        )
        |> close()

      get_char_var(ctx, :job_magician_q, 0) == 0 ->
        offer_application(ctx)

      true ->
        check_applicant(ctx)
    end
  end

  defp offer_application(ctx) do
    ctx = mes(ctx, "Wanna be a Mage, eh...?")

    ctx =
      if sex(ctx) == 1 do
        mes(ctx, "Hey, look at you! You're kinda cute~! Not my type though...")
      else
        ctx |> mes("Oooh, you're such a hot babe~!") |> mes("I like girls like you~")
      end

    {ctx, application} =
      ctx
      |> next()
      |> mes("[Mage Guildsman]")
      |> mes(
        "Right, you said that you wanna be a Mage? Alright then, please sign the Mage Application."
      )
      |> next()
      |> select(["Sign Up.", "Quit."])

    if application == 1 do
      assign_solution(ctx)
    else
      ctx
      |> mes("[Mage Guildsman]")
      |> mes(
        "Whaaaaat~?! Right after you tell me that you wanna become a Mage, you change your mind?! Be a bit more decisive!"
      )
      |> close()
    end
  end

  defp assign_solution(ctx) do
    ctx =
      ctx
      |> mes("[Mage Guildsman]")
      |> mes(
        "Okay. Sign right there. Oh, you're very good at spelling. Alright. So your name is... #{char_name(ctx, 0)}."
      )
      |> next()
      |> mes("[Mage Guildsman]")
      |> mes("Now it's time for")
      |> mes("me to give you the test.")

    solution =
      case Enum.random(0..3) do
        1 -> 1
        2 -> 2
        3 -> 3
        _ -> 4
      end

    ctx
    |> mes("Make me a ^3355FFMixed Solution No. #{solution}^000000")
    |> mes("and bring it back to me.")
    |> set_char_var(:job_magician_q, solution)
    |> next()
    |> give_item(1092, 1)
    |> mes("[Mage Guildsman]")
    |> mes(
      "You can find the necessary ingredients inside the Guide Book in this Guild. So you better look up what you need before you go."
    )
    |> next()
    |> mes("[Mage Guildsman]")
    |> mes(
      "Once you collect all the ingredients you, use the machine in the center of the room to mix the solution. Good luck!"
    )
    |> close()
  end

  defp check_applicant(ctx) do
    ctx = mes(ctx, "Yeah? Ready...?")

    if Rathena.truthy?(can_change_job?(ctx)) do
      check_solution(ctx)
    else
      ctx
      |> mes("Oh, what a bummer. You haven't met the requirements yet.")
      |> next()
      |> mes("[Mage Guildsman]")
      |> mes(
        "Go back and reach Novice Job level 9 first. Don't forget that you also have to learn all of the Basic Skills before you come back."
      )
      |> close()
    end
  end

  defp solution_number(ctx) do
    case get_char_var(ctx, :job_magician_q, 0) do
      1 -> 1
      2 -> 2
      3 -> 3
      _ -> 4
    end
  end

  defp check_solution(ctx) do
    ctx =
      ctx
      |> mes("#{char_name(ctx, 0)}'s test was...")
      |> mes("Making Mixed Solution No. #{solution_number(ctx)}.")
      |> next()
      |> mes("[Mage Guildsman]")
      |> mes("Okay, let me")
      |> mes("check if you made your")
      |> mes("solution accurately...")
      |> next()
      |> mes("[Mage Guildsman]")

    cond do
      count_item(ctx, 1071) == 0 and count_item(ctx, 1085) == 0 and
        count_item(ctx, 1086) == 0 and count_item(ctx, 1087) == 0 and
          count_item(ctx, 1090) == 0 ->
        ctx
        |> mes("Hey, where's the Solution")
        |> mes("I asked for...? I can't check it if you don't show it to me, right?")
        |> close()

      (get_char_var(ctx, :job_magician_q, 0) == 1 and count_item(ctx, 1071) == 0) or
        (get_char_var(ctx, :job_magician_q, 0) == 2 and count_item(ctx, 1085) == 0) or
        (get_char_var(ctx, :job_magician_q, 0) == 3 and count_item(ctx, 1086) == 0) or
          (get_char_var(ctx, :job_magician_q, 0) == 4 and count_item(ctx, 1087) == 0) ->
        ctx
        |> mes("Wait.")
        |> mes("This isn't the")
        |> mes("Solution I asked for!")
        |> next()
        |> mes("[Mage Guildsman]")
        |> mes(
          "You're supposed to make Mixed Solution No. #{solution_number(ctx)} and bring it back to me. Now go and try it again."
        )
        |> take_solution()
        |> close()

      true ->
        ctx |> take_solution() |> graduate()
    end
  end

  defp take_solution(ctx) do
    cond do
      count_item(ctx, 1071) != 0 -> delitem(ctx, 1071, 1)
      count_item(ctx, 1085) != 0 -> delitem(ctx, 1085, 1)
      count_item(ctx, 1086) != 0 -> delitem(ctx, 1086, 1)
      count_item(ctx, 1087) != 0 -> delitem(ctx, 1087, 1)
      true -> delitem(ctx, 1090, 1)
    end
  end

  defp graduate(ctx) do
    {ctx, _} =
      ctx
      |> mes(
        "Hmm. I can see that you tried really hard. For a beginner's attempt, this is really good."
      )
      |> mes("Great work!")
      |> next()
      |> mes("[Mage Guildsman]")
      |> mes(
        "Alright! I'm pleased to say that you've passed the Mage Test. I will transform you right away!"
      )
      |> next()
      |> mes("[Mage Guildsman]")
      |> mes("*Ahem*")
      |> mes("Congratulations!")
      |> mes("You are now a Mage!")
      |> next()
      |> set_local(:quest_id, 1005)
      |> complete_test_quests()
      |> jobchange(:mage)
      |> FClearjobvar.call([])

    ctx
    |> credit_zeny(50)
    |> mes("[Mage Guildsman]")
    |> mes("'Welcome to My World~'")
    |> mes("Heh heh, I just wanted to say that. You know, it's a quote from a well-known movie~")
    |> next()
    |> mes("[Mage Guildsman]")
    |> mes("Now that you're a Mage just like us, let's be friends, okay?")
    |> close()
  end

  defp complete_test_quests(ctx) do
    if get_local(ctx, :quest_id, 0) <= 1008 do
      ctx =
        if isbegin_quest(ctx, get_local(ctx, :quest_id, 0)) == 1 do
          completequest(ctx, get_local(ctx, :quest_id, 0))
        else
          ctx
        end

      ctx
      |> set_local(:quest_id, get_local(ctx, :quest_id, 0) + 1)
      |> complete_test_quests()
    else
      ctx
    end
  end

  defp explain_requirements(ctx) do
    ctx = ctx |> mes("[Mage Guildsman]") |> mes("Wanna be a Mage, eh?")

    ctx =
      if sex(ctx) == 1 do
        mes(ctx, "For a cutie like you, I'd be happy to explain the requirements!")
      else
        mes(ctx, "I'd be happy to explain the requirements for a pretty girl like you!")
      end

    ctx =
      ctx
      |> next()
      |> mes("[Mage Guildsman]")
      |> mes(
        "First of all, you have to reach Novice Job Level 10 and learn all of the Basic Skills. Then, you'll have to pass the Mage Test."
      )
      |> next()

    ctx =
      if get_char_var(ctx, :job_magician_q, 0) != 0 do
        ctx
        |> mes("[Mage Guildsman]")
        |> mes("Your test is to")
        |> explain_assignment()
        |> next()
        |> mes("[Mage Guildsman]")
        |> mes(
          "You can look up the ingredients you'll need to make the Solution inside the Guide Book in this Guild."
        )
      else
        ctx
        |> mes("[Mage Guildsman]")
        |> mes(
          "You will be informed as to which Mixed Solution you will need to create after signing the application form."
        )
      end

    ctx
    |> next()
    |> mes("[Mage Guildsman]")
    |> mes("Let me know when you are ready to become a Mage, alright?")
    |> close()
  end

  defp explain_assignment(ctx) do
    solution = solution_number(ctx)

    quest_id =
      case solution do
        1 -> 1005
        2 -> 1006
        3 -> 1007
        4 -> 1008
      end

    ctx =
      ctx
      |> mes("make me a")
      |> mes("^3355FFMixed Solution No. #{solution}^000000")
      |> mes("and bring it back to me.")

    if isbegin_quest(ctx, quest_id) == 0, do: setquest(ctx, quest_id), else: ctx
  end
end
