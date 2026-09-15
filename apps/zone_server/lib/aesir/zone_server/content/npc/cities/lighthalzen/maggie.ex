defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Maggie do
  @moduledoc """
  Shares Maggie's remarks with visitors to Lighthalzen.

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
        x: 34,
        y: 212,
        dir: 4,
        sprite: 91,
        name: "Maggie",
        scope: :shared,
        unique_name: "Maggie#05"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Maggie]")
    |> mes("Sure, I sell a lot")
    |> mes("of flowers here, but")
    |> mes("the lease that this city")
    |> mes("makes me pay cuts into")
    |> mes("my profits. It's almost not")
    |> mes("worth renting this property.")
    |> next()
    |> mes("[Maggie]")
    |> mes("I pay such a ridiculous")
    |> mes("amount for the lease and the")
    |> mes("laws here won't let me raise")
    |> mes("the price of my flowers. Why")
    |> mes("are the city officials so greedy?")
    |> close()
  end
end
