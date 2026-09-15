defmodule Aesir.ZoneServer.Content.Npc.Airports.Airships.Exit do
  @moduledoc """
  Marks the north and south exits of the domestic airship.

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
        x: 240,
        y: 64,
        dir: 5,
        sprite: 857,
        name: "Exit",
        scope: :shared,
        unique_name: "ExitAirplane"
      },
      %{
        map: "airplane",
        x: 247,
        y: 64,
        dir: 5,
        sprite: 857,
        name: "Exit",
        scope: :shared,
        unique_name: "Exit#airplane1b"
      },
      %{
        map: "airplane",
        x: 240,
        y: 40,
        dir: 1,
        sprite: 857,
        name: "Exit",
        scope: :shared,
        unique_name: "Exit#airplane2a"
      },
      %{
        map: "airplane",
        x: 247,
        y: 40,
        dir: 1,
        sprite: 857,
        name: "Exit",
        scope: :shared,
        unique_name: "Exit#airplane2b"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
