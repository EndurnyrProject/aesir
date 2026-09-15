defmodule Aesir.ZoneServer.Content.Npc.Cities.Comodo.Shalone do
  @moduledoc """
  Advises an unlucky casino patron to stop gambling.

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
        y: 92,
        dir: 4,
        sprite: 101,
        name: "Shalone",
        scope: :shared,
        unique_name: "Shalone#cmd"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Shalone]")
    |> mes("Oh, I'm sorry, sir,")
    |> mes("but it looks like you")
    |> mes("lost again. Maybe you")
    |> mes("should quit for now...")
    |> mes("You've been having quite")
    |> mes("a run of really bad luck...")
    |> close()
  end
end
