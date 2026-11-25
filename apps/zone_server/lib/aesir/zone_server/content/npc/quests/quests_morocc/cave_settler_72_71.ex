defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.CaveSettler7271 do
  @moduledoc """
  A cave settler shows the player Monster's Feed.

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
        x: 72,
        y: 71,
        dir: 5,
        sprite: 981,
        name: "Cave Settler",
        scope: :shared,
        unique_name: "Cave Settler#m_cave2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Cave Settler]")
    |> mes("Heh...")
    |> mes("You want... This?")
    |> next()
    |> mes("- She showed you Monster's Feed. -")
    |> close()
  end
end
