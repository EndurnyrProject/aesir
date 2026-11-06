defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.M11.Acolyte.Ascetic do
  @moduledoc """
  Father Rubalkabara guides Acolyte applicants through their assigned pilgrimage.

  ## Behavior

  - Confirms the assigned visit, saves the checkpoint and sends the applicant back to the Sanctuary.
  - Offers Priest pilgrimage dialogue to Acolytes and greetings to other visitors.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script pre-re/jobs/1-1/acolyte.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "prt_fild03",
        x: 365,
        y: 255,
        dir: 2,
        sprite: 89,
        name: "Ascetic",
        scope: :pre_renewal,
        unique_name: "Ascetic#aco"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FFatherrub
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Father Rubalkabara]")

    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:novice) ->
        applicant(ctx)

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:acolyte) ->
        {ctx, _} = FFatherrub.call(ctx, [])
        ctx

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:priest) ->
        greet_priest(ctx)

      true ->
        greet_visitor(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp applicant(ctx) do
    case get_char_var(ctx, :job_acolyte_q, 0) do
      6 -> awaiting_return(ctx)
      2 -> confirm_visit(ctx)
      0 -> unassigned(ctx)
      _other -> wrong_destination(ctx)
    end
  end

  defp awaiting_return(ctx) do
    ctx
    |> mes(
      "Please take care. They should know that you've met me by the time you arrive at the Prontera Sanctuary."
    )
    |> next()
    |> mes("[Father Rubalkabara]")
    |> mes("I've sent a carrier pigeon with a message. I hope it will arrive there safely...")
    |> close()
  end

  defp confirm_visit(ctx) do
    ctx
    |> mes(
      "Oh...? You must be the one who aspires to become an Acolyte. I've already received news from the Sanctuary that you might be coming."
    )
    |> next()
    |> mes("[Father Rubalkabara]")
    |> mes(
      "Now, your name was #{char_name(ctx, 0)}, right? Excellent, thank you for visiting me."
    )
    |> next()
    |> mes("[Father Rubalkabara]")
    |> mes(
      "I believe you've been told much about Acolytes from Friar Mareusis. Plus, there's plenty of helpful people in the Prontera Sanctuary."
    )
    |> next()
    |> mes("[Father Rubalkabara]")
    |> mes(
      "I guess there's really no need for me to teach you much. Besides, I'm sure your someone from your generation may have trouble listening to an old man like me. Hahaha~"
    )
    |> next()
    |> mes("[Father Rubalkabara]")
    |> mes(
      "Still, lessons may come from the places you'd least expect. God loves to teach his children in strange ways. You'll see."
    )
    |> next()
    |> mes("[Father Rubalkabara]")
    |> mes(
      "Well, I'll send the message telling them that you've come to visit me. So, you may now return to the Prontera Sanctuary."
    )
    |> next()
    |> mes("[Father Rubalkabara]")
    |> mes("Farewell.")
    |> close()
    |> savepoint("prt_fild03", 361, 255)
    |> set_char_var(:job_acolyte_q, 6)
  end

  defp wrong_destination(ctx) do
    ctx
    |> mes("Oh...")
    |> mes("Are you one of the")
    |> mes("Acolyte applicants...?")
    |> mes("Let's see...")
    |> next()
    |> mes("[Father Rubalkabara]")
    |> mes("Your name is #{char_name(ctx, 0)}?")
    |> mes("I don't think your name")
    |> mes("is on my list. Hmmm...")
    |> next()
    |> mes("[Father Rubalkabara]")
    |> mes("Why don't you go back to the Prontera Sanctuary and check again?")
    |> close()
  end

  defp unassigned(ctx) do
    ctx
    |> mes(
      "Huh? What brings you here? This is a very dangerous place for a Novice like yourself!"
    )
    |> close()
  end

  defp greet_priest(ctx) do
    ctx
    |> mes("Greetings.")
    |> next()
    |> mes("[Father Rubalkabara]")
    |> mes(
      "Welcome to the Deep. Feel free to sit and contemplate God's message with me. This place is beautiful, even if danger accompanies its sense of serenity..."
    )
    |> close()
  end

  defp greet_visitor(ctx) do
    ctx
    |> mes("Oh ho...")
    |> mes("Have you come into the Deep here for training? Or are you just a Wanderer?")
    |> next()
    |> mes("[Father Rubalkabara]")
    |> mes(
      "Whoever you are, please take care of yourself. The monsters in here are shockingly strong, contrary to their cute appearance."
    )
    |> close()
  end
end
