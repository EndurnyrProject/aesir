defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Towner do
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
        x: 162,
        y: 34,
        dir: 5,
        sprite: 943,
        name: "Towner",
        scope: :shared,
        unique_name: "Towner#ve1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Towner]")
    |> mes("I love cacti. They're")
    |> mes("the most beautiful plants")
    |> mes("in the desert. Sometimes,")
    |> mes("they're the only signs of")
    |> mes("life in a barren land.")
    |> next()
    |> mes("[Towner]")
    |> mes("If you feel a stirring")
    |> mes("in your heart when you")
    |> mes("look at a cactus, you")
    |> mes("must appreciate the")
    |> mes("desert's true beauty.")
    |> next()
    |> mes("[Towner]")
    |> mes("Well, I don't know if")
    |> mes("I can find anyone that")
    |> mes("finds the desert as")
    |> mes("wonderful and enchanting")
    |> mes("as I do. It's a pity, really.")
    |> close()
  end
end
