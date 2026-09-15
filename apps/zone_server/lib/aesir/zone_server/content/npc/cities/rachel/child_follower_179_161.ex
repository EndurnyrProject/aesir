defmodule Aesir.ZoneServer.Content.Npc.Cities.Rachel.ChildFollower179161 do
  @moduledoc """
  Asks visitors not to reveal Zhikka's hiding place.

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
        x: 179,
        y: 161,
        dir: 7,
        sprite: 921,
        name: "Child Follower",
        scope: :shared,
        unique_name: "Child Follower#4"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Zhikka]")
    |> mes("Shh! I'm playing")
    |> mes("Hide-and-Seek. Would")
    |> mes("you leave me alone, please?")
    |> mes("I don't wanna get caught again!")
    |> mes("Maybe it's because I always")
    |> mes("use the same hiding place...")
    |> close()
  end
end
