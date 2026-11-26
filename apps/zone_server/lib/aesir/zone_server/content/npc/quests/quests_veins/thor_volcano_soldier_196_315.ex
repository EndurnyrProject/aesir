defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.ThorVolcanoSoldier196315 do
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
        x: 196,
        y: 315,
        dir: 7,
        sprite: 939,
        name: "Thor Volcano Soldier",
        scope: :shared,
        unique_name: "Thor Volcano Soldier#vo7"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Soldier]")
    |> mes("I guess I need to go")
    |> mes("on Guardian polishing")
    |> mes("duty. Those things are")
    |> mes("so huge, and I gotta")
    |> mes("clean up about twenty...")
    |> close()
  end
end
