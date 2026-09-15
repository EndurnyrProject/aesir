defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.Fairy121259 do
  @moduledoc """
  A fairy comments on the icy eastern side of Splendide.

  ## Behavior

  - Speaks intelligibly while the Ring of the Ancient Wise King is equipped; otherwise responds in untranslated language.

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
        map: "splendide",
        x: 121,
        y: 259,
        dir: 3,
        sprite: 436,
        name: "Fairy",
        scope: :shared,
        unique_name: "Fairy#ep13bs1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 do
      ctx
      |> mes("[Fairy]")
      |> mes("Have you ever gone to the East side?")
      |> mes("Theres lots of ice~")
      |> mes("How cold...")
      |> close()
    else
      ctx
      |> mes("[nes]")
      |> mes("VaFuloDor An ")
      |> mes("WosNuffremu Ha TurAshTi")
      |> mes("VilTiRini O ")
      |> close()
    end
  end
end
