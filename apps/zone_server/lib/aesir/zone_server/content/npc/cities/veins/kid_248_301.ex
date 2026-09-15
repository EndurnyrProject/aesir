defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Kid248301 do
  @moduledoc """
  Shares a child's observations about life in Veins.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "veins",
        x: 248,
        y: 301,
        dir: 3,
        sprite: 944,
        name: "Kid",
        scope: :shared,
        unique_name: "Kid#ve6"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Kid]")
    |> mes("Huh? You don't live here.")
    |> mes("Are you... Are you a traveler?")
    |> mes("You musta been to so many")
    |> mes("other places, huh? What")
    |> mes("do they look like? I want to")
    |> mes("travel too when I grow up~")
    |> next()
    |> mes("[Kid]")
    |> mes("I like this town, but I want")
    |> mes("to see how other people live.")
    |> mes("The grown-ups think it's a bad")
    |> mes("idea, though. They say Freya")
    |> mes("hates it. Is it that bad that")
    |> mes("I can't stop wondering?")
    |> close()
  end
end
