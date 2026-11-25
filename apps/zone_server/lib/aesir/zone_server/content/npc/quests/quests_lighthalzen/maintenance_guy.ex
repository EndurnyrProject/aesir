defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.MaintenanceGuy do
  @moduledoc """
  A maintenance worker complains about the dust.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in02",
        x: 19,
        y: 274,
        dir: 2,
        sprite: 851,
        name: "Maintenance Guy",
        scope: :shared
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Kudiuu]")
    |> mes("Holy...!")
    |> mes("Will this place")
    |> mes("ever get cleaned up?!")
    |> mes("^333333*Cough cough*^000000 There's")
    |> mes("so much dust here, it's")
    |> mes("almost a health hazard!")
    |> close()
  end
end
