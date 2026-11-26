defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.ThorVolcanoSoldier20692 do
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
        x: 206,
        y: 92,
        dir: 3,
        sprite: 939,
        name: "Thor Volcano Soldier",
        scope: :shared,
        unique_name: "Thor Volcano Soldier#vo5"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Soldier]")
    |> mes("Ah, time to")
    |> mes("go to work.")
    |> next()
    |> mes("[Soldier]")
    |> mes("What th-?!")
    |> mes("Something smells")
    |> mes("like sweaty socks that")
    |> mes("haven't been washed!")
    |> close()
  end
end
