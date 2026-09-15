defmodule Aesir.ZoneServer.Content.Npc.Cities.Rachel.FreyaSFollower230303 do
  @moduledoc """
  Praises a fellow worshiper's devotion to Freya.

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
        x: 230,
        y: 303,
        dir: 3,
        sprite: 926,
        name: "Freya's Follower",
        scope: :shared,
        unique_name: "Freya's Follower#in2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Freya's Follower]")
    |> mes("You have done well,")
    |> mes("my brother. I am certain")
    |> mes("that Freya would be proud")
    |> mes("of all your effots.")
    |> close()
  end
end
