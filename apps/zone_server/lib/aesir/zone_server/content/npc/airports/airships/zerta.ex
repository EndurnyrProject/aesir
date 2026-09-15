defmodule Aesir.ZoneServer.Content.Npc.Airports.Airships.Zerta do
  @moduledoc """
  Travels aboard the domestic airship while praying for the Midgard continent.

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
        map: "airplane",
        x: 80,
        y: 71,
        dir: 2,
        sprite: 834,
        name: "Zerta",
        scope: :shared,
        unique_name: "Zerta#01airplane"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Zerta]")
    |> mes("Oh, hello adventurer.")
    |> mes("I am currently on a")
    |> mes("sacred journey, offering")
    |> mes("prayer for the sake of the")
    |> mes("Midgard continent.")
    |> close()
  end
end
