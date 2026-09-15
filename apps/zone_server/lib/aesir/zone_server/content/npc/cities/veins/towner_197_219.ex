defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Towner197219 do
  @moduledoc """
  Shares a resident's observations about life in Veins.

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
        x: 197,
        y: 219,
        dir: 5,
        sprite: 943,
        name: "Towner",
        scope: :shared,
        unique_name: "Towner#ve10"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Towner]")
    |> mes("I guess you can tell")
    |> mes("from this withered tree")
    |> mes("that our town is short")
    |> mes("on water. I guess that's")
    |> mes("a natural consequence of")
    |> mes("living here in the desert...")
    |> close()
  end
end
