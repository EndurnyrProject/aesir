defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuArcher.Sign do
  @moduledoc """
  Signpost pointing toward the Archer Job Change Office and Icarus.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - L0ne_W0lf
    - SinSloth
    - Capuche
    - Euphy
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "pay_arche",
        x: 127,
        y: 154,
        dir: 4,
        sprite: 835,
        name: "Sign",
        scope: :shared,
        unique_name: "Sign#arc"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes(" ")
    |> mes(" Archer Job Change Office ---> ")
    |> mes(" <--- Icarus ")
    |> mes(" ")
    |> close()
  end
end
