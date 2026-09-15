defmodule Aesir.ZoneServer.Content.Npc.Cities.Amatsu.WellSideMaiden do
  @moduledoc """
  Warns of something eerie lurking at the bottom of Amatsu's well.

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
        x: 230,
        y: 160,
        dir: 3,
        sprite: 757,
        name: "Well-side Maiden",
        scope: :shared,
        unique_name: "Well-side Maiden#ama"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Yuuko]")
    |> mes("I usually come to this well to")
    |> mes("draw water, but never when it's")
    |> mes("foggy or rainy. For some reason")
    |> mes("whenever the weather is a")
    |> mes("certain way, I feel like...")
    |> next()
    |> mes("[Yuuko]")
    |> mes("...someone...or some thing is")
    |> mes("struggling to crawl out from")
    |> mes("the bottom of this well...")
    |> mes("It really gives me the creeps.")
    |> close()
  end
end
