defmodule Aesir.ZoneServer.Content.Npc.Cities.Comodo.Daeguro do
  @moduledoc """
  Shares Daeguro's love of the beach and dream of visiting Alberta.

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
        map: "cmd_fild04",
        x: 267,
        y: 137,
        dir: 4,
        sprite: 703,
        name: "Daeguro",
        scope: :shared,
        unique_name: "Daeguro#cmd"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Daeguro]")
    |> mes("I love playing in")
    |> mes("the sand-- it's so soft")
    |> mes("and clean and pretty!")
    |> mes("But when I grow up,")
    |> mes("I wanna go to Alberta")
    |> mes("and see everything I can!")
    |> close()
  end
end
