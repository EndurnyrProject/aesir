defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Towner234105 do
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
        x: 234,
        y: 105,
        dir: 3,
        sprite: 946,
        name: "Towner",
        scope: :shared,
        unique_name: "Towner#ve29"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Towner]")
    |> mes("Man, the world is just...")
    |> mes("It's just desires...!")
    |> mes("Faith? It helps, you")
    |> mes("know? Cuz-cuz desires")
    |> mes("are all just nothing!")
    |> mes("They're nooooooothing!")
    |> next()
    |> mes("[Towner]")
    |> mes("Argh! What is life?!")
    |> mes("I don't know what to")
    |> mes("believe anymore! Freya!")
    |> mes("Freya looooves you!")
    |> close()
  end
end
