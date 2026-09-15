defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.SafwatFahmy do
  @moduledoc """
  Shares Safwat Fahmy's remarks with visitors to Lighthalzen.

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
        x: 201,
        y: 181,
        dir: 7,
        sprite: 853,
        name: "Safwat Fahmy",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Safwat Fahmy]")
    |> mes("This hotel is nice")
    |> mes("and comfortable, but")
    |> mes("to be quite frank, the")
    |> mes("drinks here are horrible.")
    |> mes("They're unfit for drinking")
    |> mes("men such as myself.")
    |> next()
    |> mes("[Safwat Fahmy]")
    |> mes("If this is the best hotel,")
    |> mes("I expect them to provide me")
    |> mes("with the best alcohol. When")
    |> mes("I stay at a hotel, that's what")
    |> mes("I want. To spend the entire")
    |> mes("day not being sober.")
    |> next()
    |> mes("[Safwat Fahmy]")
    |> mes("It looks like that")
    |> mes("today I'll be heading")
    |> mes("out to the bar again...")
    |> mes("I just wish there were")
    |> mes("someplace quieter to drink.")
    |> close()
  end
end
