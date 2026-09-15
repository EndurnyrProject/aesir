defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Towner157123 do
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
        x: 157,
        y: 123,
        dir: 3,
        sprite: 946,
        name: "Towner",
        scope: :shared,
        unique_name: "Towner#ve15"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Towner]")
    |> mes("You know what's good")
    |> mes("about the desert? No?")
    |> next()
    |> mes("[Towner]")
    |> mes("The desert makes you")
    |> mes("stronger. Understand")
    |> mes("what I mean? Heh, you'll")
    |> mes("know as you spend more")
    |> mes("time here in the desert.")
    |> close()
  end
end
