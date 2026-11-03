defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuMagician01.Sign do
  @moduledoc """
  Signpost marking the Mage job change area in Geffen.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - L0ne_W0lf
    - SinSloth
    - Capuche
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "geffen",
        x: 61,
        y: 174,
        dir: 4,
        sprite: 111,
        name: "Sign",
        scope: :shared,
        unique_name: "Sign#M"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("- Mage Job Change -")
    |> close()
  end
end
