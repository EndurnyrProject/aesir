defmodule Aesir.ZoneServer.Content.Npc.Cities.Prontera.AnOldMan2631 do
  @moduledoc """
  Recounts an old man's encounter with a glowing Thief Bug in the Culvert Sewers.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_in",
        x: 26,
        y: 31,
        dir: 0,
        sprite: 54,
        name: "An Old Man",
        scope: :shared,
        unique_name: "An Old Man#2pront"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Old Man]")
    |> mes(
      "I dunno if you'll believe me, but I saw the weirdest thing down in the ^000077Culvert Sewers^000000..."
    )
    |> next()
    |> mes("[Old Man]")
    |> mes(
      "I've been training in the 3rd level for so long that there isn't anything that I don't know about in that area. But when I finally went to the 4th level..."
    )
    |> next()
    |> mes("[Old Man]")
    |> mes(
      "There, I saw a shimmering light. I was completely captivated and went to approach it. It must have been some sort of beautiful fairy..."
    )
    |> next()
    |> mes("[Old Man]")
    |> mes("But when I got")
    |> mes("close enough,")
    |> mes("I saw it was")
    |> mes("a ^000077Thief Bug^000000!")
    |> next()
    |> mes("[Old Man]")
    |> mes(
      "I've never seen a Thief Bug shining with light before! Man, just when you think you've seen it all..."
    )
    |> close()
  end
end
