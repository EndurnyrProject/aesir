defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbech.TrainStationManager do
  @moduledoc """
  Directs passengers to the Einbech train station staff.

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
        map: "einbech",
        x: 157,
        y: 215,
        dir: 3,
        sprite: 852,
        name: "Train Station Manager",
        scope: :shared,
        unique_name: "Train Station Manager#ei"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Train Station Manager]")
    |> mes("This train station")
    |> mes("is strictly for trains")
    |> mes("running from Einbech")
    |> mes("to Einbroch. Please speak")
    |> mes("to the staff in the 11 'o clock direction if you'd like to board.")
    |> close()
  end
end
