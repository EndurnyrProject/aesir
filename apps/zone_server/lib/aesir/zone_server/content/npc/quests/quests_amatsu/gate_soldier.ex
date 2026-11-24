defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.GateSoldier do
  @moduledoc """
  Welcomes foreign visitors to the palace.

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
        x: 112,
        y: 164,
        dir: 4,
        sprite: 767,
        name: "Gate Soldier",
        scope: :shared,
        unique_name: "Gate Soldier#ama1"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Gate Soldier]")
    |> mes("This is the great palace,")
    |> mes("Toukoujyo.")
    |> mes("Locals are prohibited")
    |> mes("from entering...")
    |> next()
    |> mes("[Gate Soldier]")
    |> mes("Your attire looks unfamiliar.")
    |> mes("Are you from another continent?")
    |> mes("The lord has granted entrance to")
    |> mes("tourists, so you can go in.")
    |> mes(" ")
    |> close()
  end
end
