defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Towner242124 do
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
        x: 242,
        y: 124,
        dir: 3,
        sprite: 849,
        name: "Towner",
        scope: :shared,
        unique_name: "Towner#ve19"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Towner]")
    |> mes("The drinks in this")
    |> mes("town are so... They're...")
    |> mes("They're so damn strong!")
    |> next()
    |> mes("[Towner]")
    |> mes("Why...")
    |> mes("Why does the ground")
    |> mes("keep wobbling?! It's...")
    |> mes("It's like it's trying to")
    |> mes("betray me! Every time!")
    |> next()
    |> mes("[Towner]")
    |> mes("^333333*Hiccup*^000000")
    |> close()
  end
end
