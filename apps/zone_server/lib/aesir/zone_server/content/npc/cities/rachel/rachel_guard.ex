defmodule Aesir.ZoneServer.Content.Npc.Cities.Rachel.RachelGuard do
  @moduledoc """
  Welcomes visitors to Rachel and directs them to the city guide.

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
        x: 268,
        y: 120,
        dir: 1,
        sprite: 934,
        name: "Rachel Guard",
        scope: :shared,
        unique_name: "RaGuard"
      },
      %{
        map: "rachel",
        x: 125,
        y: 33,
        dir: 5,
        sprite: 934,
        name: "Rachel Guard",
        scope: :shared,
        unique_name: "Rachel Guard#2aru"
      },
      %{
        map: "rachel",
        x: 31,
        y: 130,
        dir: 3,
        sprite: 934,
        name: "Rachel Guard",
        scope: :shared,
        unique_name: "Rachel Guard#3aru"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Rachel Guard]")
    |> mes("Welcome to Rachel")
    |> mes("the capital of Arunafeltz.")
    |> mes("Please ask our guide")
    |> mes("at the center of the city")
    |> mes("for information and")
    |> mes("guest services.")
    |> close()
  end
end
