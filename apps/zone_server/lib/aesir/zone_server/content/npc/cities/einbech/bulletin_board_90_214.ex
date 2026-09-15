defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbech.BulletinBoard90214 do
  @moduledoc """
  Marks Einbech’s train station.

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
        x: 90,
        y: 214,
        dir: 5,
        sprite: 858,
        name: "Bulletin Board",
        scope: :shared,
        unique_name: "Bulletin Board#einbech22"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx |> mes(" ") |> mes(" Train Station ") |> mes(" ") |> close()
  end
end
