defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.ArunafeltzFigure170284 do
  @moduledoc """
  An Arunafeltz guest comments on the hotel party.

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
        x: 170,
        y: 284,
        dir: 4,
        sprite: 920,
        name: "Arunafeltz Figure",
        scope: :shared,
        unique_name: "Arunafeltz Figure#sch"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[??????]")
    |> mes("I've got to say, only")
    |> mes("Rekenber can host such")
    |> mes("a magnificent party in")
    |> mes("a city this polluted.")
    |> mes("What's going on...?")
    |> close()
  end
end
