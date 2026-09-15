defmodule Aesir.ZoneServer.Content.Npc.Cities.Rachel.FollowerLekua do
  @moduledoc """
  Tends flowers as an expression of Freya's will.

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
        x: 287,
        y: 88,
        dir: 7,
        sprite: 926,
        name: "Follower Lekua",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Follower Lekua]")
    |> mes("Look at these flowers.")
    |> mes("Aren't they so beautiful?")
    |> mes("I've spent a lot of time")
    |> mes("cultivating this flower garden.")
    |> next()
    |> mes("[Follower Lekua]")
    |> mes("I think it's Freya's")
    |> mes("will for us to")
    |> mes("bring as much beauty into")
    |> mes("the world as we can. What")
    |> mes("do you think about that?")
    |> close()
  end
end
