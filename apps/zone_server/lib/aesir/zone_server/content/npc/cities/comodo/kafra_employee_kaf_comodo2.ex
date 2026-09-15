defmodule Aesir.ZoneServer.Content.Npc.Cities.Comodo.KafraEmployeeKafComodo2 do
  @moduledoc """
  Welcomes visitors on behalf of the Kafra Corporation's Western Division.

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
        x: 146,
        y: 180,
        dir: 4,
        sprite: 721,
        name: "Kafra Employee::kaf_comodo2",
        scope: :shared,
        unique_name: "kaf_comodo2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> cutin("kafra_07", 2)
    |> mes("[Kafra Misty]")
    |> mes("Welcome to the")
    |> mes("Kafra Corporation.")
    |> mes("You know that our")
    |> mes("service is always")
    |> mes("on your side~")
    |> next()
    |> mes("[Kafra Misty]")
    |> mes("The Kafra Corporation")
    |> mes("Western Division promises")
    |> mes("the best quality service that")
    |> mes("emphasizes reliability, and")
    |> mes("total consumer satisfaction.")
    |> mes("Thank you for your patronage~")
    |> close()
    |> cutin("", 255)
  end
end
