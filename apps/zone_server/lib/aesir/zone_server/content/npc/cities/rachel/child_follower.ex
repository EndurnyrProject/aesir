defmodule Aesir.ZoneServer.Content.Npc.Cities.Rachel.ChildFollower do
  @moduledoc """
  Mourns Mingming and hopes Rachel's pope can revive the bird.

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
        x: 138,
        y: 64,
        dir: 5,
        sprite: 921,
        name: "Child Follower",
        scope: :shared,
        unique_name: "Child Follower#in1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Child Follower]")
      |> mes("No! My Mingming is dead!")
      |> next()
      |> select(["Mingming?"])

    ctx
    |> mes("[Child Follower]")
    |> mes("Mingming is a sick bird")
    |> mes("I found on the street, and")
    |> mes("I really wanted it to just")
    |> mes("rest and be healthy again")
    |> mes("but it died! Waaaaah!")
    |> emotion(:cry)
    |> next()
    |> mes("[Child Follower]")
    |> mes("I... I'm going to")
    |> mes("try to ask the pope!")
    |> mes("M-maybe she can bring")
    |> mes("Mingming back to life!")
    |> mes("Do you know how I can")
    |> mes("find our pope?")
    |> close()
  end
end
