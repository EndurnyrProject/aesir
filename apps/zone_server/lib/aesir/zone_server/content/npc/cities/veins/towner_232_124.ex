defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Towner232124 do
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
        y: 124,
        dir: 5,
        sprite: 943,
        name: "Towner",
        scope: :shared,
        unique_name: "Towner#ve28"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Towner]")
    |> mes("A lone wolf of the desert.")
    |> mes("That's me. Well, that's why")
    |> mes("I'm drinking here alone.")
    |> next()
    |> mes("[Towner]")
    |> mes("Sweet Freya, these")
    |> mes("drinks are so good.")
    |> mes("I could drink all day.")
    |> close()
  end
end
