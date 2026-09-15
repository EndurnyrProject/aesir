defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.SilentLaphine do
  @moduledoc """
  Shows an exhausted Laphine dozing while holding a drink.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "spl_in01",
        x: 167,
        y: 207,
        dir: 7,
        sprite: 445,
        name: "Silent Laphine",
        scope: :shared,
        unique_name: "Silent Laphine#ep13"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes(
      "- He is almost sleeping but he is still managing to hold a cup with a drink in it. He must be really tired-"
    )
    |> close()
  end
end
