defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Towner232135 do
  @moduledoc """
  Shares a resident's observations about life in Veins.

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
        map: "ve_in",
        x: 232,
        y: 135,
        dir: 5,
        sprite: 946,
        name: "Towner",
        scope: :shared,
        unique_name: "Towner#ve26"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Towner]")
    |> mes("If you enjoy a good,")
    |> mes("stiff drink, then you have")
    |> mes("to stop by Veins Tavern~")
    |> next()
    |> mes("[Towner]")
    |> mes("If you don't love")
    |> mes("drinking, then Veins")
    |> mes("Tavern is the perfect")
    |> mes("place to learn! ...To")
    |> mes("love... drinking...")
    |> close()
  end
end
