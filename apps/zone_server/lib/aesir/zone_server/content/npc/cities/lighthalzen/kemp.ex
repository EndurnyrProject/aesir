defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Kemp do
  @moduledoc """
  Shares Kemp's remarks with visitors to Lighthalzen.

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
        x: 125,
        y: 68,
        dir: 5,
        sprite: 97,
        name: "Kemp",
        scope: :shared,
        unique_name: "Kemp#zen13"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Kemp]")
    |> mes("Have you ever seen the")
    |> mes("people who work in that big")
    |> mes("corporation over there? I think")
    |> mes("their employees are all a bit")
    |> mes("off kilter for some reason.")
    |> next()
    |> mes("[Kemp]")
    |> mes("I haven't been there")
    |> mes("myself, but something")
    |> mes("strange is happening with")
    |> mes("all the people who work there.")
    |> close()
  end
end
