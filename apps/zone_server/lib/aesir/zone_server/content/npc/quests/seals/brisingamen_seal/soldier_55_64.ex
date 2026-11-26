defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.BrisingamenSeal.Soldier5564 do
  @moduledoc """
  A soldier guards an entrance during the Brisingamen seal quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Toms
    - L0ne_W0lf
    - Samuray22
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
        map: "que_god02",
        x: 55,
        y: 64,
        dir: 4,
        sprite: 105,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#2_brising",
        trigger: {1, 1}
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Soldier]")
    |> mes("Please back away.")
    |> mes("You are not permitted")
    |> mes("to enter!")
    |> close()
  end
end
