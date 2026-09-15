defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Kid do
  @moduledoc """
  Shares a child's observations about life in Veins.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "veins",
        x: 138,
        y: 71,
        dir: 5,
        sprite: 941,
        name: "Kid",
        scope: :shared,
        unique_name: "Kid#ve1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Kid]")
    |> mes("Whoa, get out of here!")
    |> mes("Can't you see that I'm")
    |> mes("playing hide and go seek?!")
    |> mes("Move before they find me!")
    |> close()
  end
end
