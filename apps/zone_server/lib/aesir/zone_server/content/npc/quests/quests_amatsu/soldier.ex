defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.Soldier do
  @moduledoc """
  Welcomes travelers to the palace guest rooms.

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
        x: 187,
        y: 57,
        dir: 2,
        sprite: 767,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#ama1"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Ichiro]")
    |> mes("Welcome.")
    |> mes("Our lord prepared guest rooms")
    |> mes("for travelers like you.")
    |> next()
    |> mes("[Ichiro]")
    |> mes("If you are having any problems,")
    |> mes("tell me. I would appreciate it if you talk to our lord of the")
    |> mes("palace. This is all provided by him.")
    |> close()
  end
end
