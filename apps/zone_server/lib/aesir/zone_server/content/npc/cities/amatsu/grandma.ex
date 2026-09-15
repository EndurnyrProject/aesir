defmodule Aesir.ZoneServer.Content.Npc.Cities.Amatsu.Grandma do
  @moduledoc """
  Worries that her frightened husband has gone drinking again.

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
        map: "amatsu",
        x: 217,
        y: 179,
        dir: 1,
        sprite: 760,
        name: "Grandma",
        scope: :shared,
        unique_name: "Grandma#ama"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Hatsue]")
    |> mes("I'm worried about my husband.")
    |> mes("He lost a lot of money in some distant town today.")
    |> next()
    |> mes("[Hatsue]")
    |> mes("I got so mad at him, he ran off in")
    |> mes("fear! I'm worried...what if he")
    |> mes(
      "went to the bar and starts drinking again? The man just doesn't have any backbone. *Phew*"
    )
    |> close()
  end
end
