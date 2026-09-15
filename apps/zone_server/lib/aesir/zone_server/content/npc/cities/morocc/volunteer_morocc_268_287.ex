defmodule Aesir.ZoneServer.Content.Npc.Cities.Morocc.VolunteerMorocc268287 do
  @moduledoc """
  Describes the overwhelming scale of Morocc’s restoration effort.

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
        x: 268,
        y: 287,
        dir: 3,
        sprite: 727,
        name: "Volunteer - Morocc",
        scope: :shared,
        unique_name: "Volunteer - Morocc#04"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Morocc Volunteer]")
    |> mes("As bad as it seems, we can't even ask for more support.")
    |> mes("This sure must be the worst thing ever happened in Rune-Midgarts' history.")
    |> next()
    |> mes("[Morocc Volunteer]")
    |> mes(
      "I wish I knew how bad the damage is, but we can't even estimate it. It's like shovelling sand against the tide.."
    )
    |> close()
  end
end
