defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsProntera.Dog do
  @moduledoc """
  A dog greets passing adventurers.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Silent
    - Evera
    - Samuray22
    - SinSloth
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mjolnir_01",
        x: 312,
        y: 269,
        dir: 5,
        sprite: 81,
        name: "Dog",
        scope: :shared,
        unique_name: "Dog#prt"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx |> mes("[Dog]") |> mes("Bow Wow!") |> close()
  end
end
