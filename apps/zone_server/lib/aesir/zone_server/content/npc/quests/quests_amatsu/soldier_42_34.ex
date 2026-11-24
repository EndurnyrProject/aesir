defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.Soldier4234 do
  @moduledoc """
  Welcomes guests to the palace.

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
        x: 42,
        y: 34,
        dir: 2,
        sprite: 767,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#ama7"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Shichiro]")
    |> mes("Have a good time.")
    |> mes("My lord prepared some")
    |> mes("guest rooms.")
    |> next()
    |> mes("[Shichiro]")
    |> mes("If you have any problems,")
    |> mes("please call me. Also, try not to disturb the other guests.")
    |> mes(" ")
    |> next()
    |> mes("[Shichiro]")
    |> mes("Have a good day.")
    |> close()
  end
end
