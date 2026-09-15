defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Helen do
  @moduledoc """
  Shares Helen's aspiration to become a bank clerk.

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
        map: "lhz_in02",
        x: 28,
        y: 39,
        dir: 3,
        sprite: 703,
        name: "Helen",
        scope: :shared,
        unique_name: "Helen#zen6"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Helen]")
    |> mes("You know, maybe when")
    |> mes("I grow up, I'll be a bank")
    |> mes("clerk. That sounds like a")
    |> mes("really nice job, don't you")
    |> mes("think? It's laid back and posh...")
    |> close()
  end
end
