defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Desk do
  @moduledoc """
  The cottage desk supplies a blank sheet bearing the Kiel Hyre Foundation seal.

  ## Behavior

  - Records the discovery on the first search and describes the books on later visits.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "kh_vila",
        x: 118,
        y: 144,
        dir: 0,
        sprite: 111,
        name: "Desk",
        scope: :shared,
        unique_name: "Desk#khp1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :KHCottagePoem2, 0) < 1 do
      discover_paper(ctx)
    else
      ctx
      |> mes("^3355FFThere are piles of papers")
      |> mes("and books, covering various")
      |> mes("scientific and magic topics,")
      |> mes("stacked on top of this desk.^000000")
      |> close()
    end
  end

  defp discover_paper(ctx) do
    ctx
    |> mes("^3355FFThere are piles of papers")
    |> mes("and books stacked on top")
    |> mes("of the desk covering topics")
    |> mes("like artificial power, Sage")
    |> mes("Varmundt's research, factory")
    |> mes("robotization, and magic scrolls...^000000")
    |> next()
    |> mes("^3355FFWhile rummaging through")
    |> mes("the books and papers, you")
    |> mes("find a piece of paper with")
    |> mes("the Kiel Hyre Foundation's")
    |> mes("official seal. You decide that")
    |> mes("it might come in handy someday.^000000")
    |> next()
    |> mes("^3355FFYou've obtained")
    |> mes("a blank piece of")
    |> mes("paper with the Kiel")
    |> mes("Hyre Foundation seal.^000000")
    |> set_char_var(:KHCottagePoem2, 1)
    |> close()
  end
end
