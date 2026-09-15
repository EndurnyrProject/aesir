defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbroch.Khetine do
  @moduledoc """
  Shares rumors about a mysterious facility in downtown Einbroch.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - reddozen
    - Komurka
    - erKURITA
    - RockmanEXE
    - Dj-Yhn
    - Silent
    - Evera
    - Samuray22
    - DZeroX
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "einbroch",
        x: 143,
        y: 109,
        dir: 5,
        sprite: 855,
        name: "Khetine",
        scope: :shared,
        unique_name: "Khetine#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Khetine]")
    |> mes("Lately, there's been")
    |> mes("talk about this empty")
    |> mes("building downtown that's")
    |> mes("been converted into some")
    |> mes("sort of mysterious facility.")
    |> next()
    |> mes("[Khetine]")
    |> mes("It all seems pretty")
    |> mes("shady, but I guess it's")
    |> mes("not really my job to know")
    |> mes("about that. I mean, if it")
    |> mes("doesn't affect me, why")
    |> mes("should I be concerned?")
    |> close()
  end
end
