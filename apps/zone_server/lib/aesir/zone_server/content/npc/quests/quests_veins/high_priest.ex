defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.HighPriest do
  @moduledoc """
  The player notices a high priest at Thor Volcano Camp.

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
        map: "thor_camp",
        x: 49,
        y: 97,
        dir: 3,
        sprite: 933,
        name: "High Priest",
        scope: :shared,
        unique_name: "High Priest#vol"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("^3355FFYou'd better not")
    |> mes("do anything too")
    |> mes("conspicuous in")
    |> mes("front of him.^000000")
    |> close()
  end
end
