defmodule Aesir.ZoneServer.Content.Npc.Cities.Niflheim.Keedz do
  @moduledoc """
  Warns living visitors away from Niflheim.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Fyrien
    - Dizzy
    - PKGINGO
    - Celest

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "niflheim",
        x: 52,
        y: 147,
        dir: 3,
        sprite: 796,
        name: "Keedz",
        scope: :shared,
        unique_name: "Keedz#nif"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Keedz]")
    |> mes("I don't allow any living person")
    |> mes("to come in this place!")
    |> close()
  end
end
