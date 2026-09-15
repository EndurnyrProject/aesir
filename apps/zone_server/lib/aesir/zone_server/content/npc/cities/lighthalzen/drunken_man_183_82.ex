defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.DrunkenMan18382 do
  @moduledoc """
  Shows Linus drinking after the end of his marriage.

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
        x: 183,
        y: 82,
        dir: 7,
        sprite: 870,
        name: "Drunken Man",
        scope: :shared,
        unique_name: "Drunken Man#amano02"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Linus]")
    |> mes("After ten years")
    |> mes("of marriage. My")
    |> mes("wife divorced me...")
    |> next()
    |> mes("[Linus]")
    |> mes("So I guess there's no")
    |> mes("place for me but here for")
    |> mes("now. I don't know what it is,")
    |> mes("but the rum is really good")
    |> mes("today. Like, it's the flavor")
    |> mes("of relaxing, joyous relief~")
    |> close()
  end
end
