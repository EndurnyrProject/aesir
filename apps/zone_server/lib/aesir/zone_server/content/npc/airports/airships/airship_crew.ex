defmodule Aesir.ZoneServer.Content.Npc.Airports.Airships.AirshipCrew do
  @moduledoc """
  Explains how passengers leave the domestic airship at their destination.

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
        x: 100,
        y: 69,
        dir: 3,
        sprite: 852,
        name: "Airship Crew",
        scope: :shared,
        unique_name: "Airship Crew#ein-1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Airship Crew]")
    |> mes("If we've landed at")
    |> mes("your destination and")
    |> mes("you'd like to leave the")
    |> mes("Airship, please use the")
    |> mes("stairs up ahead. Thank")
    |> mes("you for your patronage.")
    |> close()
  end
end
