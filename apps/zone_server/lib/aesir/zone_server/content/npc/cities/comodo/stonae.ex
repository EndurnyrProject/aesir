defmodule Aesir.ZoneServer.Content.Npc.Cities.Comodo.Stonae do
  @moduledoc """
  Shows Stonae refusing to quit after another gambling loss.

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
        map: "cmd_in02",
        x: 178,
        y: 86,
        dir: 4,
        sprite: 98,
        name: "Stonae",
        scope: :shared,
        unique_name: "Stonae#cmd"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Stonae]")
    |> mes("N-no...")
    |> mes("I lost again?!")
    |> mes("But I can't quit like")
    |> mes("this! I'm gonna keep")
    |> mes("going, and I'm gonna")
    |> mes("leave this place a winner!")
    |> close()
  end
end
