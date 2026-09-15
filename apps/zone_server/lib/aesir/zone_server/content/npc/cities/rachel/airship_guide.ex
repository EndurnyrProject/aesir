defmodule Aesir.ZoneServer.Content.Npc.Cities.Rachel.AirshipGuide do
  @moduledoc """
  Directs travelers to Rachel's international airship service.

  ## Behavior

  - Marks the airport location on the visitor's mini-map.

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
        map: "ra_fild12",
        x: 45,
        y: 230,
        dir: 3,
        sprite: 934,
        name: "Airship Guide",
        scope: :shared,
        unique_name: "Airship Guide#Fild"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Airship Guide]")
    |> mes("The Schwarzwald Republic's")
    |> mes("international Airship service")
    |> mes("for Arunafeltz can only be")
    |> mes("accessed in Rachel. Please")
    |> mes("follow the mark on your")
    |> mes("Mini-Map to find the Airport.")
    |> viewpoint(1, 293, 208, 1, 16_711_680)
    |> close()
  end
end
