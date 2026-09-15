defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Towner333318 do
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
        map: "veins",
        x: 333,
        y: 318,
        dir: 3,
        sprite: 940,
        name: "Towner",
        scope: :shared,
        unique_name: "Towner#ve7"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Towner]")
    |> mes("What's an adventurer")
    |> mes("doing here in such an")
    |> mes("isolated, dreary town?")
    |> mes("Shouldn't you be looking")
    |> mes("for adventures? Take it from")
    |> mes("me, this place if bo-ring.")
    |> close()
  end
end
