defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.M11.Acolyte.Ascetic208218 do
  @moduledoc """
  Father Yosuke guides Acolyte applicants through their assigned pilgrimage.

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
        map: "prt_fild00",
        x: 208,
        y: 218,
        dir: 6,
        sprite: 98,
        name: "Ascetic",
        scope: :pre_renewal,
        unique_name: "Ascetic#3aco"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FFatheryos
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Father Yosuke]")

    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:novice) ->
        applicant(ctx)

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:acolyte) ->
        {ctx, _} = FFatheryos.call(ctx, [])
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
      8 -> awaiting_return(ctx)
      4 -> confirm_visit(ctx)
      0 -> unassigned(ctx)
      _other -> wrong_destination(ctx)
    end
  end

  defp awaiting_return(ctx) do
    ctx
    |> mes("What?")
    |> next()
    |> mes("[Father Yosuke]")
    |> mes("Have you any more business with me?! You don't! Go back to the Sanctuary now!")
    |> close()
  end

  defp confirm_visit(ctx) do
    ctx
    |> mes("Hey.")
    |> mes("Whatever you are,")
    |> mes("you look like an")
    |> mes("Acolyte applicant.")
    |> mes("Right?")
    |> next()
    |> mes("[Father Yosuke]")
    |> mes("Not bad, not bad. You withstood the penance trial pretty well.")
    |> mes("So what's your name?")
    |> next()
    |> mes("[Father Yosuke]")
    |> mes("#{char_name(ctx, 0)}, huh?")
    |> next()
    |> mes("[Father Yosuke]")
    |> mes(
      "Okay. I'll send a message to the Sanctuary that you, #{char_name(ctx, 0)}, came to visit me."
    )
    |> next()
    |> mes("[Father Yosuke]")
    |> mes("Now go back to the Santuary and finish becoming an Acolyte, kid.")
    |> close()
    |> savepoint("prt_fild00", 206, 230)
    |> set_char_var(:job_acolyte_q, 8)
  end

  defp wrong_destination(ctx) do
    ctx
    |> mes("Hey.")
    |> mes("You look like an Acolyte Applicant. Am I right?")
    |> next()
    |> mes("[Father Yosuke]")
    |> mes(
      "Not bad at all, you've made it all the way here from Prontera. So what's your name, kid?"
    )
    |> next()
    |> mes("[Father Yosuke]")
    |> mes("#{char_name(ctx, 0)}, huh? Why isn't your name on my list?")
    |> next()
    |> mes("[Father Yosuke]")
    |> mes("You probably made a mistake. Go back to the Santuary, and check with the Bishop.")
    |> close()
  end

  defp unassigned(ctx) do
    ctx
    |> mes("You...")
    |> mes("Novice.")
    |> mes("There something")
    |> mes("you wanna tell me?")
    |> close()
  end

  defp greet_priest(ctx) do
    ctx
    |> mes("Hey...")
    |> next()
    |> mes("[Father Yosuke]")
    |> mes(
      "If you like, come sit here with me and meditate the great truths. God's majesty is truly inspiring..."
    )
    |> close()
  end

  defp greet_visitor(ctx) do
    ctx
    |> mes("Do you have anything to say? Because unfortunately for you,")
    |> mes("I don't any replies.")
    |> close()
  end
end
