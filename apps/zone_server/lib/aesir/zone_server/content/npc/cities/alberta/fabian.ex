defmodule Aesir.ZoneServer.Content.Npc.Cities.Alberta.Fabian do
  @moduledoc """
  Questions rumors that monster cards contain their powers.

  ## Credits

  - Original from rAthena, authors and Contributors
    - DZeroX

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "alberta", x: 97, y: 51, dir: 0, sprite: 84, name: "Fabian", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Fabian]")
    |> mes("Man... When you travel all around the world, you'll hear of some crazy things.")
    |> next()
    |> mes("[Fabian]")
    |> mes(
      "Once, I heard that there are Cards which contain the power of monsters. If someone happens to get their hands on a card, they'll be able to use that monster's power."
    )
    |> next()
    |> mes("[Fabian]")
    |> mes(
      "I'm guessing it's some sort of fad or scam, where they make you collect all the cards or whatever. I mean, how can a card really hold the power of a monster?!"
    )
    |> next()
    |> mes("[Fabian]")
    |> mes("Seriously...")
    |> close()
  end
end
