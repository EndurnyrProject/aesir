defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Towner101314 do
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
        x: 101,
        y: 314,
        dir: 1,
        sprite: 943,
        name: "Towner",
        scope: :shared,
        unique_name: "Towner#ve16"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Towner]")
    |> mes("^333333*Pant Pant*^000000")
    |> mes("I must study as hard as I can")
    |> mes("for the grace of Goddess Freya.")
    |> next()
    |> mes("[Towner]")
    |> mes("I really believe that")
    |> mes("I can serve Freya one of")
    |> mes("these days if I can just")
    |> mes("expand my knowledge.")
    |> close()
  end
end
