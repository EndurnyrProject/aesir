defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Grinnel do
  @moduledoc """
  Recounts Grinnel's questioning by men in black suits and frustration with slum life.

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
        x: 326,
        y: 249,
        dir: 5,
        sprite: 870,
        name: "Grinnel",
        scope: :shared,
        unique_name: "Grinnel#zen6"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Grinnel]")
    |> mes("You know the men in")
    |> mes("black suits? Boy, did")
    |> mes("I get a scare! They actually")
    |> mes("tracked me down to ask me")
    |> mes("all these weird questions!")
    |> next()
    |> mes("[Grinnel]")
    |> mes("They kept wanting to")
    |> mes("know if I had ever met")
    |> mes("anyone from the Rekenber")
    |> mes("Corporation, if I've ever been")
    |> mes("Uptown, that sort of thing. They")
    |> mes("really scared the crap out of me.")
    |> next()
    |> mes("[Grinnel]")
    |> mes("Man, living in the")
    |> mes("slums is such a drag.")
    |> mes("Not only is life rough,")
    |> mes("but all sorts of people")
    |> mes("think they can push you")
    |> mes("around. I hate Lighthalzen...")
    |> close()
  end
end
