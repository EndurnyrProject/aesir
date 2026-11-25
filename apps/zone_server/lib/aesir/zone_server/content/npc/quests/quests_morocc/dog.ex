defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.Dog do
  @moduledoc """
  A dog barks at the player.

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
        map: "yuno",
        x: 335,
        y: 208,
        dir: 5,
        sprite: 81,
        name: "Dog",
        scope: :shared,
        unique_name: "Dog#garas"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx |> mes("[Dog]") |> mes("Bowwow!") |> close()
  end
end
