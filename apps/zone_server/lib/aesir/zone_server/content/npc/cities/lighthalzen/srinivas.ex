defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Srinivas do
  @moduledoc """
  Shares Srinivas' remarks with visitors to Lighthalzen.

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
        x: 258,
        y: 223,
        dir: 3,
        sprite: 866,
        name: "Srinivas",
        scope: :shared,
        unique_name: "Srinivas#zen4"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Srinivas]")
    |> mes("Those rundown buildings")
    |> mes("in the slums are an eyesore")
    |> mes("that offend the entire city!")
    |> mes("I just wish they would wreck")
    |> mes("them down. What do I care")
    |> mes("about the poor and needy?")
    |> close()
  end
end
