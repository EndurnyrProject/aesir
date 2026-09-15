defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Towner16691 do
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
        x: 166,
        y: 91,
        dir: 5,
        sprite: 946,
        name: "Towner",
        scope: :shared,
        unique_name: "Towner#ve4"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Towner]")
    |> mes("Though we're in the")
    |> mes("middle of the desert,")
    |> mes("our enemies continue")
    |> mes("to threaten us. Fools!")
    |> mes("Goddess Freya will")
    |> mes("always protect us!")
    |> next()
    |> mes("[Towner]")
    |> mes("So long as we continue to")
    |> mes("train, Freya will watch over")
    |> mes("us and bless us with victory")
    |> mes("over our foes. That, friend,")
    |> mes("is the power of faith.")
    |> close()
  end
end
