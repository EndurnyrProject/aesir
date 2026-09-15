defmodule Aesir.ZoneServer.Content.Npc.Cities.Prontera.Soldier do
  @moduledoc """
  Warns travelers about the demon living in the forest maze.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_maze02",
        x: 100,
        y: 69,
        dir: 0,
        sprite: 105,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#pront"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Soldier]")
    |> mes("H-hey!")
    |> mes("What are")
    |> mes("you doing here?!")
    |> next()
    |> mes("[Soldier]")
    |> mes("Don't you know there's a Demon living in this forest?! I can't guarantee your safety")
    |> mes("if you go in!")
    |> close()
  end
end
