defmodule Aesir.ZoneServer.Content.Npc.Cities.Morocc.VolunteerMorocc202110 do
  @moduledoc """
  Reports on the effort to contain the cause of Morocc’s destruction.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "morocc",
        x: 202,
        y: 110,
        dir: 0,
        sprite: 730,
        name: "Volunteer - Morocc",
        scope: :shared,
        unique_name: "Volunteer - Morocc#03"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Morocc Volunteer]")
    |> mes("We're still unable to estimate the overall damage.")
    |> next()
    |> mes("[Morocc Volunteer]")
    |> mes(
      "Adventurers' Union and Prontera Kingdom are putting their efforts on restorations as well as restraints of the original cause of the disaster."
    )
    |> next()
    |> mes("[Morocc Volunteer]")
    |> mes(
      "Unless we settle the original cause, the damage will even spread out of Morocc. The only thing left is to get worse."
    )
    |> close()
  end
end
