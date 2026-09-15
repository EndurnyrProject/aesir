defmodule Aesir.ZoneServer.Content.Npc.Cities.Rachel.CheshrumnirGuardChesguard do
  @moduledoc """
  Welcomes visitors to the sacred grounds of Cheshrumnir.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Tsuyuki and Harp
    - L0ne_W0lf
    - Lupus
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "rachel",
        x: 144,
        y: 243,
        dir: 5,
        sprite: 934,
        name: "Cheshrumnir Guard::ChesGuard",
        scope: :shared,
        unique_name: "ChesGuard"
      },
      %{
        map: "rachel",
        x: 155,
        y: 243,
        dir: 3,
        sprite: 934,
        name: "Cheshrumnir Guard",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Cheshrumnir Guard]")
    |> mes("You are at Cheshrumnir,")
    |> mes("the hallowed grounds occupied")
    |> mes("by our pope, Freya's mortal")
    |> mes("incarnation. In respect for")
    |> mes("her Excellency, I expect you")
    |> mes("to enter with a pious heart.")
    |> close()
  end
end
