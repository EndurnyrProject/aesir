defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbroch.Khashurantze do
  @moduledoc """
  Expels unauthorized visitors from a restricted factory area.

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
        map: "ein_in01",
        x: 68,
        y: 209,
        dir: 5,
        sprite: 852,
        name: "Khashurantze",
        scope: :shared,
        unique_name: "Khashurantze#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Khashurantze]")
    |> mes("I'm sorry, but you need")
    |> mes("special authority in order")
    |> mes("to enter this place. I'll have")
    |> mes("to ask you to leave right now.")
    |> close()
    |> warp("einbroch", 179, 63)
  end
end
