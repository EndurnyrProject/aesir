defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.OldLady do
  @moduledoc """
  Shares an elderly resident's observations about life in Veins.

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
        map: "veins",
        x: 232,
        y: 169,
        dir: 5,
        sprite: 942,
        name: "Old lady",
        scope: :shared,
        unique_name: "Old lady#ve1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Old Lady]")
    |> mes("When I look down on")
    |> mes("Veins from here, I've")
    |> mes("come to realize many things.")
    |> mes("I don't think you'd understand")
    |> mes("no matter how much I explained.")
    |> next()
    |> mes("[Old Lady]")
    |> mes("I suppose it's one of those")
    |> mes("things that you learn with age.")
    |> mes("Yes, there's no substitute for")
    |> mes("experience when it comes to")
    |> mes("some things. You'll see.")
    |> mes("^FFFFFFYes, like secret knowledge.^000000")
    |> close()
  end
end
