defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.CaveSettler13462 do
  @moduledoc """
  A cave settler laments a missing accessory.

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
        x: 134,
        y: 62,
        dir: 1,
        sprite: 981,
        name: "Cave Settler",
        scope: :shared,
        unique_name: "Cave Settler#m_cave3"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Cave Settler]")
    |> mes("Accessory!")
    |> mes("My pretty accessory!")
    |> mes("Waaah!")
    |> mes("My accessory is gone!")
    |> close()
  end
end
