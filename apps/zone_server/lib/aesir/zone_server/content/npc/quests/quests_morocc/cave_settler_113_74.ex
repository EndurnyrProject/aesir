defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.CaveSettler11374 do
  @moduledoc """
  A cave settler threatens unwelcome visitors.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Gepard
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "cave",
        x: 113,
        y: 74,
        dir: 5,
        sprite: 401,
        name: "Cave Settler",
        scope: :shared,
        unique_name: "Cave Settler#f_cave4"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Cave Settler]")
    |> mes("No one in this village welcomes you. Go back.")
    |> next()
    |> mes("[Cave Settler]")
    |> mes("Your eyes are so tempting... I wanna eat them! Heh heh!")
    |> close()
  end
end
