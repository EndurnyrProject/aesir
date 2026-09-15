defmodule Aesir.ZoneServer.Content.Npc.Cities.Morocc.VolunteerMorocc37287 do
  @moduledoc """
  Describes the disaster’s psychological toll on Morocc’s survivors.

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
        x: 37,
        y: 287,
        dir: 0,
        sprite: 79,
        name: "Volunteer - Morocc",
        scope: :shared,
        unique_name: "Volunteer - Morocc#05"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Morocc Volunteer]")
    |> mes("The town's all shattered, but the real problem is the towners.")
    |> next()
    |> mes("[Morocc Volunteer]")
    |> mes(
      "It's a real pity to see those victims of the destroyed town, but the witnesses of the disaster are so much shocked. They're simply not normal now."
    )
    |> next()
    |> mes("[Morocc Volunteer]")
    |> mes(
      "People are scared to death, but those are fortunate at least.. cause.. many others got mentally ill and stuff.."
    )
    |> close()
  end
end
