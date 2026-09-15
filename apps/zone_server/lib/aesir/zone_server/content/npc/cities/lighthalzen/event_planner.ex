defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.EventPlanner do
  @moduledoc """
  Shows Jellarin searching for an ambitious new event idea.

  ## Credits

  - Original from rAthena, authors and Contributors
    - erKURITA
    - Au{R}oN (Translated by Alan)
    - $ephiroth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in02",
        x: 40,
        y: 280,
        dir: 6,
        sprite: 833,
        name: "Event Planner",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Jellarin]")
    |> mes("I don't like this.")
    |> mes("But I don't like that")
    |> mes("idea either. What will")
    |> mes("I do for a new event, eh?")
    |> next()
    |> mes("[Jellarin]")
    |> mes("I need something")
    |> mes("major, something that'll")
    |> mes("really shake up the world,")
    |> mes("something epochal, but what?")
    |> mes("Hey, do you have any ideas?")
    |> close()
  end
end
