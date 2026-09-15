defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Ninjose do
  @moduledoc """
  Shares Ninjose's remarks with visitors to Lighthalzen.

  ## Credits

  - Original from rAthena, authors and Contributors
    - erKURITA
    - Au{R}oN (Translated by Alan)
    - $ephiroth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in01",
        x: 116,
        y: 53,
        dir: 7,
        sprite: 841,
        name: "Ninjose",
        scope: :shared,
        unique_name: "Ninjose#nina"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Ninjose]")
    |> mes("At long last, I've finally")
    |> mes("bought my own home. You")
    |> mes("should invest your money for")
    |> mes("your future too! Read this,")
    |> mes("''Anybody Can Be Rich!''")
    |> mes("It's such a great book!")
    |> close()
  end
end
