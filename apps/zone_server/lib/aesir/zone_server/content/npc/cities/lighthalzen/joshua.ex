defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Joshua do
  @moduledoc """
  Shows Joshua waiting for his ideal woman to appear.

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
        map: "lhz_in01",
        x: 116,
        y: 45,
        dir: 7,
        sprite: 704,
        name: "Joshua",
        scope: :shared,
        unique_name: "Joshua#aya"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Joshua]")
    |> mes("What am I doing here?")
    |> mes("Waiting for my dream")
    |> mes("woman to fall into my lap,")
    |> mes("what else does it look like?")
    |> next()
    |> mes("[Joshua]")
    |> mes("Tall, blond, creamy")
    |> mes("complexion and smooth")
    |> mes("skin. That's right. Come")
    |> mes("right to Joshua, babes.")
    |> mes("I got my pheromone spray")
    |> mes("on and I'm ready to cruise~")
    |> close()
  end
end
