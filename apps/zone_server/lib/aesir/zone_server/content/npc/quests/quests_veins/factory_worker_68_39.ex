defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.FactoryWorker6839 do
  @moduledoc """
  A factory worker complains about the stones he processes.

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
        map: "ve_in02",
        x: 68,
        y: 39,
        dir: 7,
        sprite: 943,
        name: "Factory Worker",
        scope: :shared,
        unique_name: "Factory Worker#ve2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Worker]")
    |> mes("What the heck are these rocks?")
    |> mes("They're ordinary stones, aren't they?")
    |> mes("They don't pay me enough here...")
    |> close()
  end
end
