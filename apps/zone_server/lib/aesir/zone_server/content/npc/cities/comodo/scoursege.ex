defmodule Aesir.ZoneServer.Content.Npc.Cities.Comodo.Scoursege do
  @moduledoc """
  Shows Scoursege realizing that he was conned out of his money.

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
        x: 48,
        y: 55,
        dir: 4,
        sprite: 51,
        name: "Scoursege",
        scope: :shared,
        unique_name: "Scoursege#cmd"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Scoursege]")
    |> mes("Damn it! Where did that")
    |> mes("guy go? He promised me that")
    |> mes("he'd easily double my money!")
    |> mes("Wait. Oh, wait. Oh... Oh no...")
    |> next()
    |> mes("[Scoursege]")
    |> mes("Don't tell me that I just got")
    |> mes("conned out of my money!")
    |> mes("Oh no! Still, I better report")
    |> mes("this to the proper authorities,")
    |> mes("no matter how ashamed I feel...")
    |> close()
  end
end
