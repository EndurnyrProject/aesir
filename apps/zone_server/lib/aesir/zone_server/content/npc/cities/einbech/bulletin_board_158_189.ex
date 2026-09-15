defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbech.BulletinBoard158189 do
  @moduledoc """
  Marks Einbech’s freight train station.

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
        x: 158,
        y: 189,
        dir: 4,
        sprite: 858,
        name: "Bulletin Board",
        scope: :shared,
        unique_name: "Bulletin Board#einbech33"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx |> mes(" ") |> mes(" Freight Train Station ") |> mes(" ") |> close()
  end
end
