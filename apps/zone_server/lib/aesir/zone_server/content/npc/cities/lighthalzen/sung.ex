defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Sung do
  @moduledoc """
  Shares Sung's remarks with visitors to Lighthalzen.

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
        y: 82,
        dir: 5,
        sprite: 716,
        name: "Sung",
        scope: :shared,
        unique_name: "Sung#A"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Sung]")
    |> mes("When I grow up, I want")
    |> mes("to become such a great")
    |> mes("person that they'll make")
    |> mes("a statue of me, just like")
    |> mes("those statues over there.")
    |> next()
    |> mes("[Sung]")
    |> mes("Then people would be like,")
    |> mes("''Hey yo. That statue. That")
    |> mes("guy must have been great!''")
    |> mes("Just thinking about that")
    |> mes("makes me feel so good!")
    |> next()
    |> mes("[Sung]")
    |> mes("That's it. I'm gonna")
    |> mes("grow up as soon as I can.")
    |> mes("Ooh, and I better grow tall")
    |> mes("and handsome so my statue")
    |> mes("will be even more awesome.")
    |> mes("Yeah. Yeah, good idea, Sung...")
    |> close()
  end
end
