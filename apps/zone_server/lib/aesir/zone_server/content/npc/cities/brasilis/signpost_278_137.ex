defmodule Aesir.ZoneServer.Content.Npc.Cities.Brasilis.Signpost278137 do
  @moduledoc """
  Marks a local destination for visitors in Brasilis.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "brasilis",
        x: 278,
        y: 137,
        dir: 3,
        sprite: 858,
        name: "Signpost",
        scope: :shared,
        unique_name: "Signpost#bra5"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx |> mes(":: Brasilis Hotel ::") |> close()
  end
end
