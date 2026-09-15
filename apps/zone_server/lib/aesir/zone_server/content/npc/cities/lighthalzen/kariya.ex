defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Kariya do
  @moduledoc """
  Shares Kariya's remarks with visitors to Lighthalzen.

  ## Credits

  - Original from rAthena, authors and Contributors
    - erKURITA
    - Au{R}oN (Translated by Alan)
    - $ephiroth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lighthalzen",
        x: 233,
        y: 121,
        dir: 3,
        sprite: 72,
        name: "Kariya",
        scope: :shared,
        unique_name: "Kariya#li_01"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Kariya]")
    |> mes("I think ''Lighthalzen'' is")
    |> mes("supposed to mean ''crest of")
    |> mes("light,'' though I hear that this")
    |> mes("city was actually named after")
    |> mes("somebody. Who knows for sure?")
    |> next()
    |> mes("[Kariya]")
    |> mes("Still, it's a fitting")
    |> mes("name for the wealthiest")
    |> mes("and most luxurious city in")
    |> mes("all the Schwarzwald Republic.")
    |> mes("So how do you like this place?")
    |> close()
  end
end
