defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.Soldier32167 do
  @moduledoc """
  Discusses rumors about the lord and his mother.

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
        x: 32,
        y: 167,
        dir: 5,
        sprite: 767,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#ama6"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Rokuro]")
    |> mes("He always talks nonsense.")
    |> mes("He says that our lord")
    |> mes("is not real, but a fake.")
    |> mes("It's not even funny.")
    |> next()
    |> mes("[Rokuro]")
    |> mes("However, it is true that")
    |> mes("recently, weird things are")
    |> mes("happening. There were no")
    |> mes("prohibited places before...")
    |> next()
    |> mes("[Rokuro]")
    |> mes("I hear strange sounds sometimes.")
    |> mes("The mother of the lord has been")
    |> mes("visited by doctors several times.")
    |> mes("I guess her health hasn't")
    |> mes("improve after their visits...")
    |> close()
  end
end
