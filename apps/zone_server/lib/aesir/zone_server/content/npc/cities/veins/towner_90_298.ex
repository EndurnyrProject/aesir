defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Towner90298 do
  @moduledoc """
  Shares a resident's observations about life in Veins.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ve_in",
        x: 90,
        y: 298,
        dir: 3,
        sprite: 849,
        name: "Towner",
        scope: :shared,
        unique_name: "Towner#ve17"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Towner]")
    |> mes("It's too hot...")
    |> next()
    |> mes("[Towner]")
    |> mes("So sweaty...")
    |> close()
  end
end
