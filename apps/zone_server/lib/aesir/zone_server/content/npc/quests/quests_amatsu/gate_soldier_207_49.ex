defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.GateSoldier20749 do
  @moduledoc """
  Discusses the lord and his recent troubles.

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
        y: 49,
        dir: 6,
        sprite: 767,
        name: "Gate Soldier",
        scope: :shared,
        unique_name: "Gate Soldier#ama4"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Gate Soldier]")
    |> mes("The lord is really nice guy.")
    |> mes("Who would know that our town was")
    |> mes("once a small village?")
    |> next()
    |> mes("[Gate Soldier]")
    |> mes("I thank him for hiring me.")
    |> mes("These days, he seems to have")
    |> mes("troubles on his mind.")
    |> mes("Lately, he's been looking pretty gloomy.")
    |> mes(" ")
    |> close()
  end
end
