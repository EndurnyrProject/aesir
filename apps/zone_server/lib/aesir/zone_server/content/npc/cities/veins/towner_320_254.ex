defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Towner320254 do
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
        map: "veins",
        x: 320,
        y: 254,
        dir: 5,
        sprite: 943,
        name: "Towner",
        scope: :shared,
        unique_name: "Towner#ve6"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Towner]")
    |> mes("What do you want?")
    |> mes("Sorry, but I'm just")
    |> mes("a normal guy with normal")
    |> mes("problems. Nothing that")
    |> mes("I can't solve on my own.")
    |> next()
    |> mes("[Towner]")
    |> mes("Unless... You can do my")
    |> mes("taxes? Pay off my mortgage?")
    |> mes("No? Heh. Didn't think so.")
    |> close()
  end
end
