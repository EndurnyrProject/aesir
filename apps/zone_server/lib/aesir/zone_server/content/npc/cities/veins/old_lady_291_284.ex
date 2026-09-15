defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.OldLady291284 do
  @moduledoc """
  Shares an elderly resident's observations about life in Veins.

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
        x: 291,
        y: 284,
        dir: 3,
        sprite: 942,
        name: "Old Lady",
        scope: :shared,
        unique_name: "Old Lady#ve3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Old Lady]")
    |> mes("I wonder what my")
    |> mes("standing with Freya")
    |> mes("is like. Hopefully, she")
    |> mes("will take mercy upon me")
    |> mes("when I leave this world.")
    |> mes("My days here are numbered...")
    |> close()
  end
end
