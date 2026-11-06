defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.M11.Acolyte.Cleric do
  @moduledoc """
  Father Mareusis oversees the Acolyte job quest and welcomes returning High Novices.

  ## Behavior

  - Assigns one of three pilgrimage destinations and checks returning applicants before changing their job.
  - Explains the requirements and completes the matching quest log entry after the job change.
  - Changes eligible High Novices directly into High Acolytes and grants Holy Light.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - massdriller
    - Samuray22
    - Crashy
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script pre-re/jobs/1-1/acolyte.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "prt_church",
        x: 184,
        y: 41,
        dir: 4,
        sprite: 60,
        name: "Cleric",
        scope: :pre_renewal,
        unique_name: "Cleric#aco"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FClearjobvar
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if upper(ctx) == 1 do
      reborn_visitor(ctx)
    else
      main_menu(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp reborn_visitor(ctx) do
    cond do
      get_char_var(ctx, :ADVJOB, 0) != Rathena.job_id(:high_priest) and
          get_char_var(ctx, :ADVJOB, 0) != Rathena.job_id(:champion) ->
        ctx
        |> mes("[Father Mareusis]")
        |> mes(
          "I sense that you have endured a past life experience. You must have learned many things before entering Valhalla."
        )
        |> next()
        |> mes("[Father Mareusis]")
        |> mes(
          "However, I can tell that you are not suited to be an Acolyte. Please remember who you were in your past life and find your path."
        )
        |> close()

      Rathena.job_id(class(ctx)) == Rathena.job_id(:novice_high) ->
        high_novice(ctx)

      true ->
        ctx
        |> mes("[Father Mareusis]")
        |> mes(
          "Now, venture forth to seek people who need your help. May God enlighten your way."
        )
        |> close()
    end
  end

  defp high_novice(ctx) do
    ctx =
      ctx
      |> mes("[Father Mareusis]")
      |> mes("Ah, I sense you have endured")
      |> mes(
        "a past life experience. You must have learned many things before entering Valhalla."
      )
      |> next()

    if Rathena.truthy?(can_change_job?(ctx)) do
      ctx
      |> mes("[Father Mareusis]")
      |> mes("Well, I welcome you")
      |> mes("back from Valhalla and")
      |> mes("wish you luck on your")
      |> mes("new life's journey.")
      |> next()
      |> skill(143, 0, :permanent)
      |> jobchange(:acolyte_high)
      |> skill(156, 1, :permanent)
      |> mes("[Father Mareusis]")
      |> mes("Now, venture forth and seek those who need your help. May God light your path.")
      |> close()
    else
      ctx
      |> mes("[Father Mareusis]")
      |> mes(
        "Unfortunately, I don't think you're ready to become an Acolyte yet. Please finish learning all of the Basic Skills first."
      )
      |> next()
      |> mes("[Father Mareusis]")
      |> mes("In the meantime,")
      |> mes("I will wait until")
      |> mes("you are ready.")
      |> mes("May God be")
      |> mes("with you.")
      |> close()
    end
  end

  defp main_menu(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Father Mareusis]")
      |> mes("What is it that you seek?")
      |> next()
      |> select([
        "Father, I want to be a Acolyte.",
        "Acolyte Requirements.",
        "Just looking around."
      ])

    case choice do
      1 -> apply_for_job(mes(ctx, "[Father Mareusis]"))
      2 -> explain_requirements(ctx)
      3 -> close(ctx)
      _other -> ctx
    end
  end

  defp apply_for_job(ctx) do
    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:acolyte) ->
        ctx
        |> mes(
          "Are you feeling okay today? I can tell by your attire that you are already an Acolyte. You're not joking around, are you?"
        )
        |> close()

      Rathena.job_id(base_job(ctx)) != Rathena.job_id(:novice) ->
        ctx
        |> mes(
          "I'm sorry, but we can only accept Novices as applicants for the job change to Acolyte."
        )
        |> close()

      get_char_var(ctx, :job_acolyte_q, 0) == 0 ->
        offer_pilgrimage(ctx)

      true ->
        returning_applicant(ctx)
    end
  end

  defp offer_pilgrimage(ctx) do
    {ctx, answer} =
      ctx
      |> mes("Do you truly")
      |> mes("wish to become")
      |> mes("a servant of God?")
      |> next()
      |> select(["Yes Father, I do.", "Nope, I lied."])

    if answer == 1 do
      assign_pilgrimage(ctx)
    else
      ctx
      |> mes("[Father Mareusis]")
      |> mes("You lied?")
      |> mes("It is good that you")
      |> mes("have confessed your")
      |> mes("wrongdoing. Go in")
      |> mes("peace, my son.")
      |> close()
    end
  end

  defp assign_pilgrimage(ctx) do
    ctx =
      ctx
      |> mes("[Father Mareusis]")
      |> mes(
        "Good. I accept #{char_name(ctx, 0)}'s will to become an Acolyte. You understand that you must do penance before you can become a servant of God, right?"
      )
      |> next()
      |> mes("[Father Mareusis]")
      |> mes("Well, I will")
      |> mes("give you a mission...")

    ctx =
      case :rand.uniform(3) - 1 do
        1 ->
          ctx
          |> set_char_var(:job_acolyte_q, 3)
          |> mes(
            "Please visit ^000077Mother Mathilda^000000 and then return to me. She has been practicing asceticism near ^000077Morocc Town, SouthWest of Prontera City^000000."
          )
          |> setquest(1002)

        2 ->
          ctx
          |> set_char_var(:job_acolyte_q, 4)
          |> mes(
            "Please visit ^000077Father Yosuke^000000 and return here. He has been practicing asceticism around ^000077a bridge somewhere NorthWest of Prontera^000000."
          )
          |> setquest(1003)

        _ ->
          ctx
          |> set_char_var(:job_acolyte_q, 2)
          |> mes(
            "Please visit ^000077Father Rubalkabara^000000, a member of the Prontera Parish, and return here. He has been practicing asceticism in the ^000077Relics NorthEast of Prontera City^000000."
          )
          |> setquest(1001)
      end

    ctx
    |> next()
    |> mes("[Father Mareusis]")
    |> mes("May the grace of God light your path and guide you during your journey of penance.")
    |> close()
  end

  defp returning_applicant(ctx) do
    ctx =
      ctx
      |> mes(
        "Oh, you've come back. Let me check and see if you are ready to serve God. Let's see..."
      )
      |> next()
      |> mes("[Father Mareusis]")

    cond do
      not Rathena.truthy?(can_change_job?(ctx)) ->
        ctx
        |> mes(
          "Good Lord! Haven't you accomplished the Basic Training yet?! It's important that you finish that!"
        )
        |> next()
        |> mes("[Father Mareusis]")
        |> mes(
          "You should have trained more! Go back and make sure you reach Novice Job Level 9 and learn all of the Basic Skills!"
        )
        |> close()

      get_char_var(ctx, :job_acolyte_q, 0) < 5 ->
        remind_pilgrimage(ctx)

      true ->
        become_acolyte(ctx)
    end
  end

  defp remind_pilgrimage(ctx) do
    ctx = ctx |> mes("Oh? I can't find your name on the Registration List.") |> next()

    ctx =
      case get_char_var(ctx, :job_acolyte_q, 0) do
        2 ->
          ctx
          |> mes("[Father Mareusis]")
          |> mes(
            "Please visit ^000077Father Rubalkabara^000000, a member of the Prontera Parish, and return here."
          )
          |> next()
          |> mes("[Father Mareusis]")
          |> mes(
            "He has been practicing asceticism in the ^000077Relics at the NorthEast of Prontera City^000000."
          )

        3 ->
          ctx
          |> mes("[Father Mareusis]")
          |> mes("Please Visit ^000077Mother Mathilda^000000 and return here to me.")
          |> next()
          |> mes("[Father Mareusis]")
          |> mes(
            "She has been practicing asceticism near ^000077Morocc Town, located SouthWest of Prontera City^000000."
          )

        4 ->
          ctx
          |> mes("[Father Mareusis]")
          |> mes("Please visit ^000077 Father Yosuke ^000000 and return here to me.")
          |> next()
          |> mes("[Father Mareusis]")
          |> mes(
            "He has been practicing asceticism near a ^000077bridge somewhere to the NorthWest of Prontera^000000."
          )

        _ ->
          ctx
      end

    ctx
    |> next()
    |> mes("[Father Mareusis]")
    |> mes("May the grace of God brighten your path and guide you on your journey of penance.")
    |> close()
  end

  defp become_acolyte(ctx) do
    {ctx, _} =
      ctx
      |> mes("Hmm...")
      |> mes("Your name is on the list and you've proven your qualification.")
      |> next()
      |> mes("[Father Mareusis]")
      |> mes("I am proud to say that you are now ready to become an Acolyte!")
      |> next()
      |> skill(143, 0, :permanent)
      |> jobchange(:acolyte)
      |> FClearjobvar.call([])

    ctx =
      cond do
        checkquest(ctx, 1001) != -1 -> completequest(ctx, 1001)
        checkquest(ctx, 1002) != -1 -> completequest(ctx, 1002)
        true -> completequest(ctx, 1003)
      end

    ctx
    |> mes("[Father Mareusis]")
    |> mes("Always remember to be thankful to God, who is taking care of us all the time.")
    |> next()
    |> mes("[Father Mareusis]")
    |> mes(
      "Always use your gifts to serve Him by helping others. In chaos and times of difficulty, face your hardships with unwavering faith."
    )
    |> next()
    |> mes("[Father Mareusis]")
    |> mes(
      "Lastly, I want to sincerely congratulate you on persevering through your trial of penance."
    )
    |> close()
  end

  defp explain_requirements(ctx) do
    ctx =
      ctx
      |> mes("[Father Mareusis]")
      |> mes("Do you wish to become an Acolyte? You must fulfill two requirements.")
      |> next()
      |> mes("[Father Mareusis]")
      |> mes(
        "First, you have to reach at least Novice Job Level 9 and learn all of the Basic Skills. Second, you will be given a trial of penance to overcome."
      )
      |> next()
      |> mes("[Father Mareusis]")

    ctx
    |> explain_destination()
    |> next()
    |> mes("[Father Mareusis]")
    |> mes(
      "Please come back after fulfilling the two requirements I've asked of you. As long as your desire to serve God and others is sincere, you will be able to make it."
    )
    |> close()
  end

  defp explain_destination(ctx) do
    if get_char_var(ctx, :job_acolyte_q, 0) != 0 do
      ctx =
        case get_char_var(ctx, :job_acolyte_q, 0) do
          2 ->
            ctx
            |> mes(
              "For your trial, please visit ^000077Father Rubalkabara ^000000 and then return here to me."
            )
            |> next()
            |> mes("[Father Mareusis]")
            |> mes(
              "He is practicing asceticism in the ^000077Relics at the NorthEast of Prontera City^000000."
            )

          3 ->
            ctx
            |> mes(
              "For your trial, please visit ^000077Mother Mathilda^000000 and return here to me."
            )
            |> next()
            |> mes("[Father Mareusis]")
            |> mes(
              "She has been practicing asceticism near ^000077Morocc, located to the SouthWest of Prontera City^000000."
            )

          _ ->
            ctx
            |> mes(
              "For your trial, please visit ^000077Father Yosuke^000000 and return here to me."
            )
            |> next()
            |> mes("[Father Mareusis]")
            |> mes(
              "He has been practicing asceticism around a bridge somewhere ^000077NorthWest of Prontera^000000."
            )
        end

      ctx
      |> next()
      |> mes("[Father Mareusis]")
      |> mes("May the grace of God light your path and guide you on your journey of penance.")
    else
      ctx
      |> mes("The destination for this trial will be decided once you fill the application form.")
    end
  end
end
