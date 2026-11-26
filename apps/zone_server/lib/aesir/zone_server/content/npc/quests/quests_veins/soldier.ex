defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.Soldier do
  @moduledoc """
  A hungry Thor Volcano Camp soldier complains about his rations.

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
        x: 124,
        y: 314,
        dir: 1,
        sprite: 939,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#vol1"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Thor Volcano Camp Soldier]")
    |> mes("Freya, I'm so exhausted!")
    |> mes("I'm starving to death too!")
    |> mes("When will we get more rations?")
    |> close()
  end
end
