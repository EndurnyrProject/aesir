defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbech.Gushenmu do
  @moduledoc """
  Describes the worsening dangers and hardships faced by Einbech’s miners.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "einbech",
        x: 105,
        y: 218,
        dir: 5,
        sprite: 848,
        name: "Gushenmu",
        scope: :shared,
        unique_name: "Gushenmu#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Gushenmu]")
    |> mes("I've lived here a long time")
    |> mes("and, believe it or not, things")
    |> mes("weren't as tough in the past")
    |> mes("as they are right now.")
    |> next()
    |> mes("[Gushenmu]")
    |> mes("For lots of different reasons,")
    |> mes("the work is more dangerous")
    |> mes("and we're running real low on")
    |> mes("manpower. And the factories in")
    |> mes("Einbroch make so much smog,")
    |> mes("we can't even see sunlight here.")
    |> next()
    |> mes("[Gushenmu]")
    |> mes("The sad reality of mining")
    |> mes("life right now is that we")
    |> mes("wake up, go to work, and at")
    |> mes("the end of the day, some of us")
    |> mes("are injured while a few others never come to work the next day.")
    |> next()
    |> mes("[Gushenmu]")
    |> mes("And as Einbech and Einbroch")
    |> mes("have grown, I hear more and")
    |> mes("more rumors that unfamiliar")
    |> mes("monsters are beginning to")
    |> mes("swarm outside of town. This")
    |> mes("is really Einbech's worst time...")
    |> close()
  end
end
