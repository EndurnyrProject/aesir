defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.ThorVolcanoSoldier143114 do
  @moduledoc """
  A Thor Volcano soldier is stationed at the camp.

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
        x: 143,
        y: 114,
        dir: 1,
        sprite: 939,
        name: "Thor Volcano Soldier",
        scope: :shared,
        unique_name: "Thor Volcano Soldier#vo4"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> emotion(:cry)
    |> mes("[Soldier]")
    |> mes("Oh Freya...")
    |> mes("Bless this Old Blue Box")
    |> mes("so that I don't get anything")
    |> mes("lame again. I am so tired")
    |> mes("of getting arrows from these...")
    |> close()
  end
end
