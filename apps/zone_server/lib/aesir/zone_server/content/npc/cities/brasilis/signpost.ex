defmodule Aesir.ZoneServer.Content.Npc.Cities.Brasilis.Signpost do
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
        x: 155,
        y: 165,
        dir: 3,
        sprite: 858,
        name: "Signpost",
        scope: :shared,
        unique_name: "Signpost#bra1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx |> mes(":: Art Museum ::") |> close()
  end
end
