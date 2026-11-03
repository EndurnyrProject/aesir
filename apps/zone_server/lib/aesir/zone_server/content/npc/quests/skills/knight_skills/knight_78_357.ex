defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.KnightSkills.Knight78357 do
  @moduledoc """
  Jiya, an unambitious Knight training in Prontera who mentions Essofeit during the Charge
  Attack skill quest.

  ## Behavior

  - At quest steps 5 and 6, singles out Essofeit as the division's only standout and sets the
    quest step to 6.
  - Otherwise is too busy training to talk.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - DracoRPG
    - Samuray22
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prontera",
        x: 78,
        y: 357,
        dir: 3,
        sprite: 734,
        name: "Knight",
        scope: :shared,
        unique_name: "Knight#sasword"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Jiya]")

    if get_char_var(ctx, :KNGT_SK, 0) in [5, 6] do
      mention_essofeit(ctx)
    else
      too_busy(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp mention_essofeit(ctx) do
    ctx
    |> mes("Man, this division of")
    |> mes("the chivalry doesn't seem")
    |> mes("to have too much potential.")
    |> mes("Most of us here are pretty")
    |> mes("second rate, except maybe")
    |> mes("for that one guy, Essofeit.")
    |> next()
    |> set_char_var(:KNGT_SK, 6)
    |> mes("[Jiya]")
    |> mes("As for me, I don't have too")
    |> mes("much in the way of ambition.")
    |> mes("As long as I do what I'm told,")
    |> mes("they'll pay me. And as long")
    |> mes("as I get paid, I'm happy.")
    |> close()
  end

  defp too_busy(ctx) do
    ctx
    |> mes("D-don't talk to me!")
    |> mes("Gotta... muster up the...")
    |> mes("Strength to... f-finish all")
    |> mes("these... training exercises!")
    |> mes("Alright man, c-concentrate...")
    |> close()
  end
end
