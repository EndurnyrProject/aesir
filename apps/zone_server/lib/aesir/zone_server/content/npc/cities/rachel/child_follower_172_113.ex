defmodule Aesir.ZoneServer.Content.Npc.Cities.Rachel.ChildFollower172113 do
  @moduledoc """
  Searches for other children during Hide-and-Seek.

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
        x: 172,
        y: 113,
        dir: 5,
        sprite: 921,
        name: "Child Follower",
        scope: :shared,
        unique_name: "Child Follower#6"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Harse]")
    |> mes("Where are yoooou~")
    |> mes("Come out, come out")
    |> mes("wherever you are~")
    |> next()
    |> mes("[Harse]")
    |> mes("What the Freya?")
    |> mes("What's a grown-up")
    |> mes("doing around here?")
    |> mes("Can't you see I'm")
    |> mes("playing Hide-and-Go-Seek?")
    |> close()
  end
end
