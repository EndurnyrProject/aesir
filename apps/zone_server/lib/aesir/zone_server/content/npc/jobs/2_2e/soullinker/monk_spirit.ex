defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22e.Soullinker.MonkSpirit do
  @moduledoc """
  Monk spirit met inside a Soul Linker candidate's mind during the job quest.

  ## Behavior

  - Defers to Maia while the candidate has just arrived.
  - Once Maia has explained the ceremony, shares its regrets and marks the candidate ready to
    become a Soul Linker, advancing the quest log.

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
        y: 35,
        dir: 6,
        sprite: 827,
        name: "Monk Spirit",
        scope: :shared,
        unique_name: "Monk Spirit#link4"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    soul_quest = get_char_var(ctx, :SOUL_Q, 0)

    cond do
      soul_quest == 2 -> defer_to_maia(ctx)
      soul_quest > 2 -> share_regrets(ctx)
      true -> ctx |> mes("[Monk Spirit]") |> mes("...") |> close()
    end
  end

  defp defer_to_maia(ctx) do
    ctx
    |> mes("[Monk Spirit]")
    |> mes("Who am I...?")
    |> mes("I think... I think")
    |> mes("it would be best if")
    |> mes("you spoke to Maya first...")
    |> mes("Who and what I am requires")
    |> mes("a complicated explanation...")
    |> close()
  end

  defp share_regrets(ctx) do
    ctx
    |> mes("[Monk Spirit]")
    |> mes("In life, my peers did")
    |> mes("their best to assure me")
    |> mes("that I accomplish all that")
    |> mes("I could as a Monk. Still...")
    |> mes("Still I would never be fully")
    |> mes("satisfied with my skills.")
    |> next()
    |> mes("[Monk Spirit]")
    |> mes("In death, I had many regrets,")
    |> mes("never having the chance to pass")
    |> mes("my skills down to future Monks.")
    |> mes("Lending my power to others ")
    |> mes("is the only chance that I can")
    |> mes("possibly have to do this.")
    |> next()
    |> mark_ready_for_ceremony()
    |> mes("[Monk Spirit]")
    |> mes("I beg of you...")
    |> mes("I need you to help")
    |> mes("me fully realize the")
    |> mes("true potential of the")
    |> mes("Monks of today.")
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
