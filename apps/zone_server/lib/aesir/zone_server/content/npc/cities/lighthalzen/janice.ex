defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Janice do
  @moduledoc """
  Shows Janice lost in Lighthalzen despite living there for years.

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
        x: 45,
        y: 59,
        dir: 7,
        sprite: 863,
        name: "Janice",
        scope: :shared,
        unique_name: "Janice#zen03"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Janice]")
    |> mes("Oh no, I think I got")
    |> mes("lost again. The roads")
    |> mes("here are so confusing!")
    |> mes("I've lived here for such")
    |> mes("a long time and I still")
    |> mes("can't find my way around...")
    |> close()
  end
end
