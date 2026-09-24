defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22e.Soullinker.SageSpirit do
  @moduledoc """
  Sage spirit met inside a Soul Linker candidate's mind during the job quest.

  ## Behavior

  - Defers to Maia while the candidate has just arrived.
  - Once Maia has explained the ceremony, asks to become the candidate's spirit ally and marks
    the candidate ready to become a Soul Linker, advancing the quest log.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Celestria
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
        map: "job_soul",
        x: 30,
        y: 25,
        dir: 7,
        sprite: 754,
        name: "Sage Spirit",
        scope: :shared,
        unique_name: "Sage Spirit#link5"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    soul_quest = get_char_var(ctx, :SOUL_Q, 0)

    cond do
      soul_quest == 2 -> defer_to_maia(ctx)
      soul_quest > 2 -> ask_for_alliance(ctx)
      true -> ctx |> mes("[Sage Spirit]") |> mes("...") |> close()
    end
  end

  defp defer_to_maia(ctx) do
    ctx
    |> mes("[Sage Spirit]")
    |> mes("Speak to Maia.")
    |> mes("I'm afraid I may")
    |> mes("confuse you if Maia")
    |> mes("doesn't first explain")
    |> mes("your present situation...")
    |> close()
  end

  defp ask_for_alliance(ctx) do
    ctx
    |> mes("[Sage Spirit]")
    |> mes("My pursuit of knowledge")
    |> mes("granted me incredible power:")
    |> mes("in life, I could have destroyed")
    |> mes("anything I wanted. Few Sages")
    |> mes("could even reach my level...")
    |> next()
    |> mes("[Sage Spirit]")
    |> mes("I died, but I was never able")
    |> mes("to pass on to the next world.")
    |> mes("I still want to use my abilities.I want to use my knowledge")
    |> mes("to build what pleases me,")
    |> mes("and to destroy as I please.")
    |> next()
    |> mes("[Sage Spirit]")
    |> mes("It is enough if I can")
    |> mes("lend my power to a Sage")
    |> mes("that is worthy of receiving")
    |> mes("it. But to do that, I shall")
    |> mes("require your help. I beg you,")
    |> mes("let me become your spirit ally.")
    |> mark_ready_for_ceremony()
    |> next()
    |> mes("[Sage Spirit]")
    |> mes("I believe that you")
    |> mes("are the only one who")
    |> mes("has a chance of bringing")
    |> mes("rest to my troubled soul...")
    |> close()
  end

  defp mark_ready_for_ceremony(ctx) do
    ctx = set_char_var(ctx, :SOUL_Q, 4)

    if checkquest(ctx, 6008) == -1 do
      changequest(ctx, 6007, 6008)
    else
      ctx
    end
  end
end
