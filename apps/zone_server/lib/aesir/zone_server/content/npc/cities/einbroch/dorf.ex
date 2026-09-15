defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbroch.Dorf do
  @moduledoc """
  Praises the convenience of Einbroch's factory machinery.

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
        x: 49,
        y: 202,
        dir: 3,
        sprite: 851,
        name: "Dorf",
        scope: :shared,
        unique_name: "Dorf#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Dorf]")
    |> mes("Machines are sooo")
    |> mes("convenient. Just look")
    |> mes("at this contraption easily")
    |> mes("do tasks that'd be tough")
    |> mes("for me to finish alone.")
    |> next()
    |> mes("[Dorf]")
    |> mes("Now this is what")
    |> mes("I call technology!")
    |> mes("Sure, it takes effort and")
    |> mes("money to make one of")
    |> mes("these, but what do I care?")
    |> next()
    |> mes("[Dorf]")
    |> mes("I've got no problems,")
    |> mes("so long as this freaking")
    |> mes("thing keeps working the")
    |> mes("way I want it to!")
    |> close()
  end
end
