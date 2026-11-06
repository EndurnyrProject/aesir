defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.M11.Thief.Comrade do
  @moduledoc """
  Grades the Thief test mushrooms and welcomes successful applicants to the guild.

  ## Behavior

  - Awards the Thief job and a mushroom-based zeny subsidy after a passing score.
  - Directs applicants at earlier quest stages back to the guide or the test.

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
        x: 42,
        y: 133,
        dir: 2,
        sprite: 118,
        name: "Comrade",
        scope: :pre_renewal
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FClearjobvar
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:thief) ->
        ctx
        |> mes("[Brad]")
        |> mes(
          "We don't have any special events yet. Come some other time when there's news, alright?"
        )
        |> close()

      Rathena.job_id(base_job(ctx)) != Rathena.job_id(:novice) ->
        ctx
        |> mes("[Comrade]")
        |> mes("Um...")
        |> mes("You don't look")
        |> mes("like a Thief.")
        |> next()
        |> mes("[Comrade]")
        |> mes("What the heck are")
        |> mes("you doing here anyway?")
        |> close()

      get_char_var(ctx, :job_thief_q, 0) == 0 or get_char_var(ctx, :job_thief_q, 0) == 1 ->
        ctx
        |> mes("[Comrade]")
        |> mes("What's the matter? If you want to be a Thief, speak to the girl beside me.")
        |> close()

      get_char_var(ctx, :job_thief_q, 0) == 2 ->
        ctx
        |> mes("[Comrade]")
        |> mes("Did you pass the interview?")
        |> mes("Then what are you waiting for?")
        |> close()

      get_char_var(ctx, :job_thief_q, 0) == 3 ->
        grade_mushrooms(ctx)

      true ->
        ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp grade_mushrooms(ctx) do
    ctx =
      ctx
      |> mes("[Comrade]")
      |> mes("Ah, the guide told me about you. So, let me check your mushrooms...")

    if count_item(ctx, 1069) == 0 and count_item(ctx, 1070) == 0 do
      ctx
      |> next()
      |> mes("[Comrade]")
      |> mes("What the hell...")
      |> mes(
        "You don't have any Mushrooms at all! Go back and get them. Otherwise, you won't pass the test and become a Thief!"
      )
      |> close()
    else
      appraise_mushrooms(ctx)
    end
  end

  defp appraise_mushrooms(ctx) do
    ctx =
      ctx
      |> next()
      |> set_local(:thief_item1, count_item(ctx, 1069) * 3)
      |> set_local(:thief_item2, count_item(ctx, 1070))

    ctx =
      set_local(
        ctx,
        :total_thief,
        get_local(ctx, :thief_item1, 0) + get_local(ctx, :thief_item2, 0)
      )

    ctx =
      ctx
      |> set_local(
        :money_thief,
        get_local(ctx, :thief_item1, 0) * 5 + get_local(ctx, :thief_item2, 0) * 2 + 200
      )
      |> mes("[Comrade]")

    ctx =
      if count_item(ctx, 1069) != 0 do
        ctx
        |> mes("First, let me check the Orange Net Mushrooms you got.")
        |> mes("Huh, #{count_item(ctx, 1069)} of them.")
      else
        ctx
      end

    ctx =
      if count_item(ctx, 1070) != 0 do
        mes(
          ctx,
          "Now I'll just check your Orange Gooey Mushrooms. That's #{count_item(ctx, 1070)} you gathered."
        )
      else
        ctx
      end

    ctx =
      ctx
      |> next()
      |> mes("[Comrade]")
      |> mes("So that would")
      |> mes("bring your total to...")
      |> next()
      |> mes("[Comrade]")
      |> mes(
        "Hmmm. #{get_local(ctx, :total_thief, 0)} degrees, multiplied by the speed of light, divided by the integral of pi times height plus the absolute value of politics..."
      )
      |> next()
      |> mes("[Comrade]")
      |> mes("Okay!")
      |> mes("I got it.")
      |> next()
      |> mes("[Comrade]")

    cond do
      get_local(ctx, :total_thief, 0) > 25 ->
        ctx |> mes("You got more") |> mes("than 25 points!") |> mes("Awesome!") |> promote_thief()

      get_local(ctx, :total_thief, 0) == 25 ->
        ctx |> mes("Exactly 25 points!") |> mes("You did it! Badass!") |> promote_thief()

      true ->
        ctx
        |> mes(
          "Definitely less than the 25 points you need to pass. Go out there and get me more Mushrooms!"
        )
        |> close()
    end
  end

  defp promote_thief(ctx) do
    ctx =
      ctx
      |> next()
      |> mes("[Comrade]")
      |> mes("#{char_name(ctx, 0)}...")
      |> mes("You have passed the official Thief Test. You are now one of us.")
      |> take_mushrooms(1069)
      |> take_mushrooms(1070)

    {ctx, _} = ctx |> jobchange(:thief) |> FClearjobvar.call([])

    ctx
    |> completequest(1013)
    |> next()
    |> mes("[Comrade]")
    |> mes(
      "Congratulations on becoming a Thief! From now, be an honorable representative of the Thief's Guild."
    )
    |> next()
    |> mes("[Comrade]")
    |> mes(
      "If you bring disgrace to our guild, you will be killed. I expect you to bring our comrades pride."
    )
    |> next()
    |> mes("[Brad]")
    |> mes(
      "*Ahem* Welcome to the Guild, comrade! I'm Brad, and I'm in charge of human resources here."
    )
    |> next()
    |> mes("[Brad]")
    |> mes(
      "Here is a small subsidy for a Newbie like you. Spend it whereever you want. Alright then, I'll see you around~"
    )
    |> credit_zeny(get_local(ctx, :money_thief, 0))
    |> close()
  end

  defp take_mushrooms(ctx, item_id) do
    if count_item(ctx, item_id) != 0 do
      delitem(ctx, item_id, count_item(ctx, item_id))
    else
      ctx
    end
  end
end
