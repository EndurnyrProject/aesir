defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.M11.Acolyte.Ascetic41355 do
  @moduledoc """
  Mother Mathilda guides Acolyte applicants through their assigned pilgrimage.

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
        map: "moc_fild07",
        x: 41,
        y: 355,
        dir: 4,
        sprite: 95,
        name: "Ascetic",
        scope: :pre_renewal,
        unique_name: "Ascetic#2aco"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FMothermart
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Mother Mathilda]")

    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:novice) ->
        applicant(ctx)

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:acolyte) ->
        {ctx, _} = FMothermart.call(ctx, [])
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
      7 -> awaiting_return(ctx)
      3 -> confirm_visit(ctx)
      0 -> unassigned(ctx)
      _other -> wrong_destination(ctx)
    end
  end

  defp awaiting_return(ctx) do
    ctx
    |> mes(
      "I will send a carrier pigeon to the Prontera Sanctuary. When you return, the Priest there should already have received my message."
    )
    |> next()
    |> mes("[Mother Mathilda]")
    |> mes("I will pray to God, and hope that you become an Acolyte soon.")
    |> close()
  end

  defp confirm_visit(ctx) do
    ctx
    |> mes("Ah, you must be one of the Acolyte applicants. I sincerely welcome you.")
    |> next()
    |> mes("[Mother Mathilda]")
    |> mes("What is your name? #{char_name(ctx, 0)}? Let's see... Ah, you're on my list.")
    |> next()
    |> mes("[Mother Mathilda]")
    |> mes(
      "I will send a message to the Sanctuary confirming that you, #{char_name(ctx, 0)} visited me and completed your penance."
    )
    |> next()
    |> mes("[Mother Mathilda]")
    |> mes("Please return to the Prontera Sanctuary and speak to the Priest in charge.")
    |> close()
    |> savepoint("moc_fild07", 35, 355)
    |> set_char_var(:job_acolyte_q, 7)
  end

  defp wrong_destination(ctx) do
    ctx
    |> mes("Ah...!")
    |> mes("You must be one")
    |> mes("of the Acolyte applicants.")
    |> mes("I sincerely welcome you.")
    |> next()
    |> mes("[Mother Mathilda]")
    |> mes("Now, what is your name?")
    |> mes("#{char_name(ctx, 0)}? Let's see...")
    |> next()
    |> mes("[Mother Mathilda]")
    |> mes("Hmm...")
    |> mes("It seems your name")
    |> mes("is not on my list...")
    |> next()
    |> mes("[Mother Mathilda]")
    |> mes(
      "Perhaps you should return to the Prontera Sanctuary and check the destination for your penance trial once again."
    )
    |> close()
  end

  defp unassigned(ctx) do
    ctx
    |> mes("...")
    |> close()
  end

  defp greet_priest(ctx) do
    ctx
    |> mes("Hello there~")
    |> next()
    |> mes("[Mother Mathilda]")
    |> mes(
      "How is your practice coming along? I certainly hope you're enjoying living in the grace of God."
    )
    |> close()
  end

  defp greet_visitor(ctx) do
    ctx
    |> mes("May God")
    |> mes("be with you...")
    |> close()
  end
end
