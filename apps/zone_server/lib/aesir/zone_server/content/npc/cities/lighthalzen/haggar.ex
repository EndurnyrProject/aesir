defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Haggar do
  @moduledoc """
  Shows Haggar angrily demanding whiskey instead of rum.

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
        map: "lhz_in03",
        x: 192,
        y: 19,
        dir: 3,
        sprite: 855,
        name: "Haggar",
        scope: :shared,
        unique_name: "Haggar#zen1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Haggar]")
    |> mes("Whiskey!")
    |> mes("I need me some")
    |> mes("hard liquor now!")
    |> next()
    |> mes("[Haggar]")
    |> mes("Wha--? I didn't")
    |> mes("order this stinkin'")
    |> mes("rum! I want a man's")
    |> mes("drink! Gimme whiskey!")
    |> close()
  end
end
