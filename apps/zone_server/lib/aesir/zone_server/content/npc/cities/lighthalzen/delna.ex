defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Delna do
  @moduledoc """
  Celebrates sunbathing as one of life's simple pleasures.

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
        x: 70,
        y: 227,
        dir: 4,
        sprite: 102,
        name: "Delna",
        scope: :shared,
        unique_name: "Delna#li_reken"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Delna]")
    |> mes("Sometimes the simple")
    |> mes("pleasures can give you")
    |> mes("the most happiness. For me,")
    |> mes("going outside and basking in")
    |> mes("the sun is the greatest thing~")
    |> next()
    |> mes("[Delna]")
    |> mes("Yes, sunbathing in a quiet")
    |> mes("and relaxing place can be")
    |> mes("so refreshing. And if you're")
    |> mes("careful about not getting a")
    |> mes("sunburn or a tan, a little sun")
    |> mes("can be really good for you.")
    |> close()
  end
end
