defmodule Aesir.ZoneServer.Content.Npc.Cities.Morocc.VolunteerMorocc do
  @moduledoc """
  Explains the volunteer effort to restore Morocc after its destruction.

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
        y: 244,
        dir: 0,
        sprite: 745,
        name: "Volunteer - Morocc",
        scope: :shared,
        unique_name: "Volunteer - Morocc#01"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Morocc Volunteer]")
    |> mes(
      "After that terrible incident wiped out the entire Morocc, Rune-Midgarts Kingdom has gathered us volunteers to help restorations."
    )
    |> next()
    |> mes("[Morocc Volunteer]")
    |> mes(
      "As important as it seems, everyone's being careful but there are always some that really don't realize the situation, don't you think?"
    )
    |> close()
  end
end
