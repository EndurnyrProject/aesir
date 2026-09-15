defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbroch.BulletinBoard162256 do
  @moduledoc """
  Displays directions to Einbroch landmarks.

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
        x: 162,
        y: 256,
        dir: 5,
        sprite: 858,
        name: "Bulletin Board",
        scope: :shared,
        unique_name: "Bulletin Board#ein33"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("East - Train Station")
    |> mes("Southeast - Hotel")
    |> mes("South - Weapon Shop, Factory")
    |> mes("Southwest - Airport, Airship Repair Shop, Laboratory")
    |> close()
  end
end
