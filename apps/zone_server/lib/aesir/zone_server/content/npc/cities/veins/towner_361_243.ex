defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Towner361243 do
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
        x: 361,
        y: 243,
        dir: 5,
        sprite: 849,
        name: "Towner",
        scope: :shared,
        unique_name: "Towner#ve18"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Towner]")
    |> mes("...............")
    |> mes("...............")
    |> mes("...............")
    |> next()
    |> mes("[Towner]")
    |> mes("...............")
    |> mes("...............")
    |> mes("...............")
    |> next()
    |> mes("[Towner]")
    |> mes("Tricked you!")
    |> mes("Thought I was dead,")
    |> mes("didn't you? Hahaha~")
    |> close()
  end
end
