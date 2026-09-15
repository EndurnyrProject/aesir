defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Towner137179 do
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
        x: 137,
        y: 179,
        dir: 5,
        sprite: 943,
        name: "Towner",
        scope: :shared,
        unique_name: "Towner#ve3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Towner]")
    |> mes("Geez, why is our weapon")
    |> mes("shop so boring? Nothing")
    |> mes("there but the same ol'")
    |> mes("regular junk. Sad to say,")
    |> mes("there's nothing special.")
    |> next()
    |> mes("[Towner]")
    |> mes("Wouldn't it be great")
    |> mes("if there was a shop that")
    |> mes("sold the legendary godly")
    |> mes("weapons? Of course, that's")
    |> mes("asking a bit too much.")
    |> close()
  end
end
