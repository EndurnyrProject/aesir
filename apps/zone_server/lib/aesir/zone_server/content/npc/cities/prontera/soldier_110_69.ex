defmodule Aesir.ZoneServer.Content.Npc.Cities.Prontera.Soldier11069 do
  @moduledoc """
  Warns against risking one's life to gather herbs in the maze.

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
        x: 110,
        y: 69,
        dir: 0,
        sprite: 105,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#2pront"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Soldier]")
    |> mes(
      "*Sigh...* The last guy that entered this place haven't come back at all. He didn't listen to me and went in to gather Herbs or something dumb like that..."
    )
    |> next()
    |> mes("[Soldier]")
    |> mes(
      "Whaaaat a stupid guy. Why would anyone want to throw his life away just to collect some silly Herbs?"
    )
    |> close()
  end
end
