defmodule Aesir.ZoneServer.Content.Npc.Cities.Rachel.FreyaSFollower228303 do
  @moduledoc """
  Describes a sleepless vigil for Freya's second coming.

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
        map: "ra_temin",
        x: 228,
        y: 303,
        dir: 5,
        sprite: 926,
        name: "Freya's Follower",
        scope: :shared,
        unique_name: "Freya's Follower#in1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Freya's Follower]")
    |> mes("Once again, I didn't get")
    |> mes("any sleep yesterday... I'm")
    |> mes("praying so hard for Freya's")
    |> mes("second coming. I'm exhausted,")
    |> mes("but I feel pretty good about")
    |> mes("making that small sacrifice.")
    |> close()
  end
end
