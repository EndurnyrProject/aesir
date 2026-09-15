defmodule Aesir.ZoneServer.Content.Npc.Airports.Airships.Mendel do
  @moduledoc """
  Complains about the quality of meals aboard the international airship.

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
        map: "airplane_01",
        x: 69,
        y: 63,
        dir: 2,
        sprite: 55,
        name: "Mendel",
        scope: :shared,
        unique_name: "Mendel#01airplane_01"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Mendel]")
    |> mes("As I expected, the")
    |> mes("in-flight meals are")
    |> mes("three star quality at best.")
    |> mes("*Harrrumph* I really should")
    |> mes("have brought my chef so that")
    |> mes("I could enjoy a real meal.")
    |> close()
  end
end
