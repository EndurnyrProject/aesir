defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbech.BulletinBoard77105 do
  @moduledoc """
  Welcomes visitors and lists directions to landmarks in Einbech.

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
        map: "einbech",
        x: 77,
        y: 105,
        dir: 5,
        sprite: 858,
        name: "Bulletin Board",
        scope: :shared,
        unique_name: "Bulletin Board#einbech01"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("Welcome to 'Einbech'.")
    |> next()
    |> mes("East - Tavern, Tool Shop")
    |> mes("North - Train Station, Mine Dungeon")
    |> close()
  end
end
