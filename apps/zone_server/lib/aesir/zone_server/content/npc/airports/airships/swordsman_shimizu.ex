defmodule Aesir.ZoneServer.Content.Npc.Airports.Airships.SwordsmanShimizu do
  @moduledoc """
  Travels aboard the international airship while pursuing a long-awaited revenge.

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
        x: 71,
        y: 31,
        dir: 2,
        sprite: 106,
        name: "Swordsman Shimizu",
        scope: :shared,
        unique_name: "Swordsman Shimizu#air_01"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Swordsman Shimizu]")
    |> mes("Finally, after five")
    |> mes("years of waiting...")
    |> mes("I can have my revenge!")
    |> next()
    |> mes("[Swordsman Shimizu]")
    |> mes("I just...")
    |> mes("Have to make sure that")
    |> mes("I don't keep missing my")
    |> mes("stop. But soon, very soon,")
    |> mes("vengeance will be mine!")
    |> close()
  end
end
