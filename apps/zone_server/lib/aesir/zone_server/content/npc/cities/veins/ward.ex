defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Ward do
  @moduledoc """
  Shares a guard's observations about life in Veins.

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
        x: 111,
        y: 379,
        dir: 8,
        sprite: 946,
        name: "Ward",
        scope: :shared,
        unique_name: "Ward#ve1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Ward]")
    |> mes("This place ensures that")
    |> mes("dangerous criminals aren't")
    |> mes("threatening the publi--")
    |> mes("Wait. Why are you even")
    |> mes("here?! This place isn't")
    |> mes("safe for you! Leave!")
    |> close()
  end
end
