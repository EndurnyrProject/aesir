defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.Soldier203156 do
  @moduledoc """
  Invites visitors to greet the lord.

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
        x: 203,
        y: 156,
        dir: 4,
        sprite: 767,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#ama8"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Hachiro]")
    |> mes("My lord is inside.")
    |> mes("If you'd like to greet him, feel free to enter.")
    |> next()
    |> mes("[Hachiro]")
    |> mes("Don't be rude in front of him.")
    |> mes("He is somehow not feeling well.")
    |> mes("Usually, he greets people from")
    |> mes("other continents gladly, but...")
    |> mes("What could have happened to him...?")
    |> close()
  end
end
