defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbroch.LittleToby do
  @moduledoc """
  Asks passersby for help after losing his parents near the airport.

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
        x: 228,
        y: 121,
        dir: 5,
        sprite: 855,
        name: "Little Toby",
        scope: :shared,
        unique_name: "Little Toby#ein-1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Little Toby]")
    |> mes("Excuse me...")
    |> mes("But I'm lost!")
    |> mes("I can't find my")
    |> mes("mom or dad!")
    |> next()
    |> mes("[Little Toby]")
    |> mes("A-am I at the Airport?!")
    |> mes("My parents are supposed")
    |> mes("to come get me, but I still")
    |> mes("haven't found them! We just")
    |> mes("moved here, so I don't know")
    |> mes("where anything is!")
    |> next()
    |> mes("[Little Toby]")
    |> mes("W-wait!")
    |> mes("Where are you")
    |> mes("going?! Don't leave")
    |> mes("me, I'm all alone...!")
    |> close()
  end
end
