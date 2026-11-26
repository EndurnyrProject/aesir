defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.Bartender do
  @moduledoc """
  A bartender welcomes visitors to the tavern.

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
        map: "ve_in",
        x: 235,
        y: 135,
        dir: 5,
        sprite: 947,
        name: "Bartender",
        scope: :shared,
        unique_name: "Bartender#ve"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Bartender]")
    |> mes("Welcome to our tavern.")
    |> mes("Please, have a seat.")
    |> mes("Let me bring you a")
    |> mes("glass of ice water first.")
    |> close()
  end
end
