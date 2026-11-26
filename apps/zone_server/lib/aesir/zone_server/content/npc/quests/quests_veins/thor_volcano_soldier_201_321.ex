defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.ThorVolcanoSoldier201321 do
  @moduledoc """
  A Thor Volcano soldier is stationed at the camp.

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
        x: 201,
        y: 321,
        dir: 1,
        sprite: 939,
        name: "Thor Volcano Soldier",
        scope: :shared,
        unique_name: "Thor Volcano Soldier#vo6"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx |> mes("[Soldier]") |> mes("Yo-ho! Yo-ho!") |> close()
  end
end
