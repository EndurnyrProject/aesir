defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Towner222122 do
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
        x: 222,
        y: 122,
        dir: 1,
        sprite: 940,
        name: "Towner",
        scope: :shared,
        unique_name: "Towner#ve25"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Towner]")
    |> mes("I heard all that...")
    |> mes("Gosh, he's so clueless.")
    |> mes("I don't hate him, but he")
    |> mes("should show a bit more")
    |> mes("backbone if he wants")
    |> mes("to impress me. Hmmm...")
    |> close()
  end
end
