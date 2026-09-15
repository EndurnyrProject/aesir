defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbech.BulletinBoard181127 do
  @moduledoc """
  Lists directions to landmarks in Einbech.

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
        x: 181,
        y: 127,
        dir: 5,
        sprite: 858,
        name: "Bulletin Board",
        scope: :shared,
        unique_name: "Bulletin Board#einbech03"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("Northwest - Train Station")
    |> mes("South - Tavern")
    |> mes("North - Tool Shop, Mine Dungeon")
    |> close()
  end
end
