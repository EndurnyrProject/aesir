defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.ThorVolcanoSoldier98213 do
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
        x: 98,
        y: 213,
        dir: 5,
        sprite: 939,
        name: "Thor Volcano Soldier",
        scope: :shared,
        unique_name: "Thor Volcano Soldier#vo8"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Soldier]")
    |> mes("Aren't you the one from")
    |> mes("the geological research")
    |> mes("center? There's nothing")
    |> mes("for you here, we're just")
    |> mes("performing maintenance")
    |> mes("on these guardians.")
    |> close()
  end
end
