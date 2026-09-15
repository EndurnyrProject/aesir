defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Hinkley do
  @moduledoc """
  Shows Hinkley singing while extremely drunk.

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
        map: "lhz_in02",
        x: 157,
        y: 201,
        dir: 6,
        sprite: 870,
        name: "Hinkley",
        scope: :shared,
        unique_name: "Hinkley#06"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Hinkley]")
    |> mes("Meh heh heh...")
    |> mes("^333333*Hiccup*^000000 Believe")
    |> mes("it or notsh, I'm...")
    |> mes("walkin on a... Air...")
    |> mes("Nevah thought I could")
    |> mes("b-be sho freee-eeee-eee~")
    |> next()
    |> mes("^3355FFThis guy")
    |> mes("is completely")
    |> mes("hammered out")
    |> mes("of his mind!^000000")
    |> close()
  end
end
