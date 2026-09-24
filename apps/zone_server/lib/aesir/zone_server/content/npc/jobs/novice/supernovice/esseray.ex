defmodule Aesir.ZoneServer.Content.Npc.Jobs.Novice.Supernovice.Esseray do
  @moduledoc """
  Esseray, the self-proclaimed first member of the Novice Society in Aldebaran.

  ## Behavior

  - Congratulates Expanded Super Novices and Expanded Super Babies.
  - With renewal content enabled, hands Super Novices to the Expanded Super Novice quest
    before the usual Novice Society greeting.
  - Invites plain Novices to join the society and dismisses everyone else as too special.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Darkchild
    - Samuray22
    - L0ne_W0lf
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "aldeba_in",
        x: 216,
        y: 169,
        dir: 5,
        sprite: 86,
        name: "Esseray",
        scope: :shared,
        unique_name: "Esseray#sn"
      }
    ]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Content.Npc.Re.Functions.EsserayEx
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      Rathena.job_id(class(ctx)) == Rathena.job_id(:super_novice_e) or
          Rathena.job_id(class(ctx)) == Rathena.job_id(:super_baby_e) ->
        ctx
        |> mes("[Esseray]")
        |> mes("You! Stronger than before.")
        |> mes("I knew you could pass the test~")
        |> close()

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:super_novice) ->
        ctx
        |> maybe_expanded_quest()
        |> society_member_greeting()

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:novice) and upper(ctx) != 1 ->
        ctx
        |> mes("[Esseray]")
        |> mes("Hah~ you don't know anything")
        |> mes("about being a normal person yet!")
        |> mes("Why don't you join our Novice")
        |> mes("Society? This club is the best in the world~")
        |> next()
        |> mes("[Esseray]")
        |> mes("Yup, Super Novices")
        |> mes("are the best characters!")
        |> mes("Hahahahahahahaha!")
        |> close()

      true ->
        ctx
        |> mes("[Esseray]")
        |> mes("Bah~! You're better than")
        |> mes("average...Hell, you may")
        |> mes("even be 'special.'")
        |> mes("What a shame! Well...")
        |> mes("I hope you still live")
        |> mes("your life positively.")
        |> close()
    end
  end

  # EsserayEx ends the script by throwing `{:script_end, ctx}` when it takes over the
  # dialogue; Script.Interaction catches that, and a `nil` return continues here.
  defp maybe_expanded_quest(ctx) do
    if Rathena.truthy?(checkre(ctx, 0)) do
      {ctx, _} =
        case GameMode.mode() do
          :renewal ->
            EsserayEx.call(ctx, [])

          :pre_renewal ->
            raise "NPC helper Esseray_Ex called from jobs/novice/supernovice.txt:331 (Esseray#sn) has no pre_renewal target"
        end

      ctx
    else
      ctx
    end
  end

  defp society_member_greeting(ctx) do
    ctx
    |> mes("[Esseray]")
    |> mes("Hm? Hey, you're a member")
    |> mes("of our great Novice Society,")
    |> mes("aren't you? Isn't this the")
    |> mes("best club ever?!")
    |> next()
    |> mes("[Essaray]")
    |> mes("Living life mundanely,")
    |> mes("according to the principles")
    |> mes("of Mister Kimu-Shaun...")
    |> mes("It's great to be ordinary!")
    |> next()
    |> mes("[Esseray]")
    |> mes("Let's try to lead our lives")
    |> mes("as normally as we can!")
    |> mes("For your reference, I am")
    |> mes("the number one member,")
    |> mes("under Mister Tzerero of")
    |> mes("course!")
    |> close()
  end
end
