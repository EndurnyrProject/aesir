defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22e.Soullinker.AlchemistSpirit do
  @moduledoc """
  Alchemist spirit met inside a Soul Linker candidate's mind during the job quest.

  ## Behavior

  - Defers to Maia while the candidate has just arrived.
  - Once Maia has explained the ceremony, tells of its fatal arrogance and marks the candidate
    ready to become a Soul Linker, advancing the quest log.

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
        x: 25,
        y: 30,
        dir: 5,
        sprite: 744,
        name: "Alchemist Spirit",
        scope: :shared,
        unique_name: "Alchemist Spirit#link7"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    soul_quest = get_char_var(ctx, :SOUL_Q, 0)

    cond do
      soul_quest == 2 -> defer_to_maia(ctx)
      soul_quest > 2 -> plead_for_help(ctx)
      true -> ctx |> mes("[Alchemist Spirit]") |> mes("...") |> close()
    end
  end

  defp defer_to_maia(ctx) do
    ctx
    |> mes("[Alchemist Spirit]")
    |> mes("Oh! I really want to")
    |> mes("speak to you, but what")
    |> mes("I have to say won't make")
    |> mes("much sense unless you")
    |> mes("talk to Maia first. But yes,")
    |> mes("I really need your help.")
    |> close()
  end

  defp plead_for_help(ctx) do
    ctx
    |> mes("[Alchemist Spirit]")
    |> mes("Without exagerrating, I was")
    |> mes("the fastest Alchemist in my")
    |> mes("time. In fact, I may even be")
    |> mes("the fastest Alchemist ever.")
    |> mes("But then I grew arrogant, and")
    |> mes("killed myself in an accident.")
    |> next()
    |> mes("[Alchemist Spirit]")
    |> mes("But death would not stifle")
    |> mes("my skill. In fact, I've even")
    |> mes("improved my skill since I've")
    |> mes("passed away. I cannot go")
    |> mes("on to the next world until I've")
    |> mes("passed on my techniques...")
    |> mark_ready_for_ceremony()
    |> next()
    |> mes("[Alchemist Spirit]")
    |> mes("I'm powerless as a spirit,")
    |> mes("but with your help, I can")
    |> mes("influence the Alchemists of")
    |> mes("today and help them refine")
    |> mes("their skills. I beseech you,")
    |> mes("please give me this chance...")
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
