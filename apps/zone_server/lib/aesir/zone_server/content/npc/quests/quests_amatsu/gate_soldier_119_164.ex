defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.GateSoldier119164 do
  @moduledoc """
  Welcomes visitors and praises the lord.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - MasterOfMuppets
    - L0ne_W0lf
    - Gepard
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "amatsu",
        x: 119,
        y: 164,
        dir: 4,
        sprite: 767,
        name: "Gate Soldier",
        scope: :shared,
        unique_name: "Gate Soldier#ama2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Gate Soldier]")
    |> mes("Are you from Midgard?")
    |> mes("Welcome to Amatsu.")
    |> mes("Visit our lord in Chun-Su-Gak")
    |> mes("when you go in.")
    |> mes(" ")
    |> next()
    |> mes("[Gate Soldier]")
    |> mes("He is really kind.")
    |> mes("He invested in various fields for")
    |> mes("Amatsu, and intercontinental trade was his idea.")
    |> close()
  end
end
