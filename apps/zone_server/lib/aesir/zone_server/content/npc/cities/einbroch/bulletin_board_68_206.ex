defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbroch.BulletinBoard68206 do
  @moduledoc """
  Labels the Einbroch airship airport.

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
        x: 68,
        y: 206,
        dir: 5,
        sprite: 858,
        name: "Bulletin Board",
        scope: :shared,
        unique_name: "Bulletin Board#ein3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx |> mes(" ") |> mes(" Airship Airport ") |> mes(" ") |> close()
  end
end
