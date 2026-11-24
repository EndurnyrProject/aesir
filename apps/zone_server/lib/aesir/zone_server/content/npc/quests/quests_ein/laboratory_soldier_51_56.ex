defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.LaboratorySoldier5156 do
  @moduledoc """
  A laboratory soldier complains about the dust.

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
        y: 56,
        dir: 5,
        sprite: 852,
        name: "Laboratory Soldier",
        scope: :shared,
        unique_name: "Laboratory Soldier#ein-2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Laboratory Soldier]")
    |> mes("Yuck...!")
    |> mes("There's this")
    |> mes("nasty dusty taste")
    |> mes("right inside my mouth")
    |> mes("that I can't get rid of!")
    |> next()
    |> mes("[Laboratory Soldier]")
    |> mes("^333333*Sigh*^000000")
    |> mes("I want to go home.")
    |> mes("Get some mouthwash.")
    |> mes("You know. Something.")
    |> close()
  end
end
