defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Joyce do
  @moduledoc """
  Shares Joyce's remarks with visitors to Lighthalzen.

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
        x: 190,
        y: 134,
        dir: 5,
        sprite: 862,
        name: "Joyce",
        scope: :shared,
        unique_name: "Joyce#zen"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Joyce]")
    |> mes("I can sense your")
    |> mes("longing look within")
    |> mes("the depths of my heart,")
    |> mes("beating faster and faster")
    |> mes("with a feverish passion~")
    |> close()
  end
end
