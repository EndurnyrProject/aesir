defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.Soldier134309 do
  @moduledoc """
  A Thor Volcano Camp soldier anticipates dinner.

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
        x: 134,
        y: 309,
        dir: 5,
        sprite: 939,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#vol2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Thor Volcano Camp Soldier]")
    |> mes("I hear we'll be eating")
    |> mes("chicken salad, fried chicken,")
    |> mes("and Kunlun style chicken for")
    |> mes("dinner tonight! I wonder who")
    |> mes("was rich enough to donate")
    |> mes("so much chicken to us?")
    |> next()
    |> mes("[Thor Volcano Camp Soldier]")
    |> mes("Heheh...")
    |> mes("I can't wait for dinner!")
    |> close()
  end
end
