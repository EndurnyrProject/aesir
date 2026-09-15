defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbech.BulletinBoard180136 do
  @moduledoc """
  Marks Einbech’s tool shop.

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
        x: 180,
        y: 136,
        dir: 5,
        sprite: 858,
        name: "Bulletin Board",
        scope: :shared,
        unique_name: "Bulletin Board#einbech44"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx |> mes(" ") |> mes(" Tool Shop ") |> mes(" ") |> close()
  end
end
