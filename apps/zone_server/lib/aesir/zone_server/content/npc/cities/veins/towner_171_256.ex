defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Towner171256 do
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
        x: 171,
        y: 256,
        dir: 3,
        sprite: 943,
        name: "Towner",
        scope: :shared,
        unique_name: "Towner#ve9"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Towner]")
    |> mes("Don't get me wrong:")
    |> mes("I'd give my life in Freya's")
    |> mes("name, but that so-called")
    |> mes("temple just looks so strange")
    |> mes("and suspicious. How can it")
    |> mes("be a place of worship?")
    |> close()
  end
end
