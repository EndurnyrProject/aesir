defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.CorporateFigure168274 do
  @moduledoc """
  A corporate figure checks the party preparations.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ein_in01",
        x: 168,
        y: 274,
        dir: 0,
        sprite: 109,
        name: "Corporate Figure",
        scope: :shared,
        unique_name: "Corporate Figure#sch"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[????]")
    |> mes("Hmm... Good.")
    |> mes("Everything looks")
    |> mes("ready to me.")
    |> close()
  end
end
