defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Ward126378 do
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
        x: 126,
        y: 378,
        dir: 3,
        sprite: 946,
        name: "Ward",
        scope: :shared,
        unique_name: "Ward#ve2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Ward]")
    |> mes("I'm grateful that our")
    |> mes("town is relatively peaceful.")
    |> mes("If it were any other place,")
    |> mes("that tiny cell would be")
    |> mes("crammed full of criminals.")
    |> next()
    |> mes("[Ward]")
    |> mes("Thank Freya that I've")
    |> mes("been assigned to such")
    |> mes("a peaceful, quiet place.")
    |> close()
  end
end
