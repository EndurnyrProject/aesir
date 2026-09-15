defmodule Aesir.ZoneServer.Content.Npc.Cities.Brasilis.Signpost303309 do
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
        x: 303,
        y: 309,
        dir: 3,
        sprite: 858,
        name: "Signpost",
        scope: :shared,
        unique_name: "Signpost#bra4"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx |> mes(":: Jungle Cable ::") |> mes("- Not for the faint of heart -") |> close()
  end
end
