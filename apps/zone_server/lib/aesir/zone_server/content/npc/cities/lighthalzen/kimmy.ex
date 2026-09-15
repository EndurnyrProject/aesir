defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Kimmy do
  @moduledoc """
  Shares Kimmy's remarks with visitors to Lighthalzen.

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
        x: 176,
        y: 65,
        dir: 5,
        sprite: 862,
        name: "Kimmy",
        scope: :shared,
        unique_name: "Kimmy#zen3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Kimmy]")
    |> mes("Unlike most places,")
    |> mes("Lighthalzen has many")
    |> mes("beautiful clothing and")
    |> mes("accessory shops. This")
    |> mes("place is heaven to a")
    |> mes("trend-setter like me~!")
    |> next()
    |> mes("[Kimmy]")
    |> mes("I don't know if you")
    |> mes("adventurers are interested")
    |> mes("in fashion, but you can trash")
    |> mes("your old clothes and get some")
    |> mes("new, unique and trendy gear")
    |> mes("over here in Lighthalzen~")
    |> close()
  end
end
