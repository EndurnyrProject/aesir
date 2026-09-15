defmodule Aesir.ZoneServer.Content.Npc.Cities.Rachel.FollowerAkarna do
  @moduledoc """
  Expresses hope of witnessing Freya descend at Cheshrumnir.

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
        map: "ra_temple",
        x: 148,
        y: 91,
        dir: 3,
        sprite: 916,
        name: "Follower Akarna",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Follower Akarna]")
    |> mes("Cheshrumnir...")
    |> mes("It is said that one")
    |> mes("day, our goddess Freya")
    |> mes("will descend to this place")
    |> mes("in all of her glory. I hope")
    |> mes("that I live to see that.")
    |> close()
  end
end
