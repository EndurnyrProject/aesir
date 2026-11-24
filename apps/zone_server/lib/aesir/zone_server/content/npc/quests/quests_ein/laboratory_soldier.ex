defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.LaboratorySoldier do
  @moduledoc """
  A laboratory soldier warns visitors away from a restricted area.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - MasterOfMuppets
    - Lupus
    - KarLaeda
    - SinSloth
    - L0ne_W0lf
    - Yommy
    - Paradox924X
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
        map: "einbroch",
        x: 51,
        y: 46,
        dir: 5,
        sprite: 852,
        name: "Laboratory Soldier",
        scope: :shared,
        unique_name: "Laboratory Soldier#ein-1"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Laboratory Soldier]")
    |> mes("This area")
    |> mes("is off limits.")
    |> mes("Please leave")
    |> mes("immediately.")
    |> close()
  end
end
