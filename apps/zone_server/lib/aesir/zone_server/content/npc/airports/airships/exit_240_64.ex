defmodule Aesir.ZoneServer.Content.Npc.Airports.Airships.Exit24064 do
  @moduledoc """
  Marks the north and south exits of the international airship.

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
        x: 240,
        y: 64,
        dir: 5,
        sprite: 857,
        name: "Exit",
        scope: :shared,
        unique_name: "ExitAirplane01"
      },
      %{
        map: "airplane_01",
        x: 247,
        y: 64,
        dir: 5,
        sprite: 857,
        name: "Exit",
        scope: :shared,
        unique_name: "Exit#airplane_011b"
      },
      %{
        map: "airplane_01",
        x: 240,
        y: 40,
        dir: 1,
        sprite: 857,
        name: "Exit",
        scope: :shared,
        unique_name: "Exit#airplane_012a"
      },
      %{
        map: "airplane_01",
        x: 247,
        y: 40,
        dir: 1,
        sprite: 857,
        name: "Exit",
        scope: :shared,
        unique_name: "Exit#airplane_012b"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
