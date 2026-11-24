defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.GateSoldier20740 do
  @moduledoc """
  Welcomes foreign guests to the palace.

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
        map: "ama_in02",
        x: 207,
        y: 40,
        dir: 6,
        sprite: 767,
        name: "Gate Soldier",
        scope: :shared,
        unique_name: "Gate Soldier#ama3"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Gate Soldier]")
    |> mes("Welcome. The lord of the palace")
    |> mes("has specially allowed guests")
    |> mes("from other continents.")
    |> next()
    |> mes("[Gate Soldier]")
    |> mes("Look around and take your time.")
    |> mes("Please enjoy your stay.")
    |> close()
  end
end
