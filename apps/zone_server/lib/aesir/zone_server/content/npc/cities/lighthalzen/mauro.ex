defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Mauro do
  @moduledoc """
  Shares Mauro's remarks with visitors to Lighthalzen.

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
        x: 138,
        y: 50,
        dir: 7,
        sprite: 847,
        name: "Mauro",
        scope: :shared,
        unique_name: "Mauro#zen3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Mauro]")
    |> mes("The youth in this city")
    |> mes("have no appreciation for")
    |> mes("their elders. I've worked")
    |> mes("so hard to help build this")
    |> mes("city for so many years and")
    |> mes("this is the thanks I get?")
    |> next()
    |> mes("[Mauro]")
    |> mes("Bah! If it weren't for")
    |> mes("us, Lighthalzen wouldn't")
    |> mes("be as prosperous as it is")
    |> mes("today! Those kids don't")
    |> mes("know that they owe their")
    |> mes("lives of luxury to us...")
    |> close()
  end
end
