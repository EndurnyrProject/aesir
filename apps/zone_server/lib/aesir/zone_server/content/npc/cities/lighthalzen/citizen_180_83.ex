defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Citizen18083 do
  @moduledoc """
  Reflects on the common experiences that connect people.

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
        map: "lhz_in03",
        x: 180,
        y: 83,
        dir: 6,
        sprite: 86,
        name: "Citizen",
        scope: :shared,
        unique_name: "Citizen#amano03"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Mitchell]")
    |> mes("You know, everyone")
    |> mes("is different, but I think")
    |> mes("humans are similar enough")
    |> mes("that we can all meaningfully")
    |> mes("connect on some level, right?")
    |> next()
    |> mes("[Mitchell]")
    |> mes("Sure, a rich person might")
    |> mes("have different problems than")
    |> mes("a poor person, but the point")
    |> mes("is, they've both got problems!")
    |> mes("Pain, pleasure, sadness, joy.")
    |> mes("Those link us all together.")
    |> next()
    |> mes("[Mitchell]")
    |> mes("So try not to be picky")
    |> mes("about who's your pal and")
    |> mes("who's not. We all need")
    |> mes("somebody to be with, right?")
    |> close()
  end
end
