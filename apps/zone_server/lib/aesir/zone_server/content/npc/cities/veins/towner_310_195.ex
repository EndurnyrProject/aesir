defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Towner310195 do
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
        x: 310,
        y: 195,
        dir: 1,
        sprite: 946,
        name: "Towner",
        scope: :shared,
        unique_name: "Towner#ve5"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Towner]")
    |> mes("Cacti are wonderful,")
    |> mes("they're the most beautiful")
    |> mes("plants in the desert. Yes, we")
    |> mes("must cherish and nurture them~")
    |> next()
    |> mes("[Towner]")
    |> mes("Regular cacti are ")
    |> mes("pretty uncommon, but")
    |> mes("I hear there's a kind of")
    |> mes("cactus that roams the desert")
    |> mes("and makes loud, obnoxious")
    |> mes("noises. How can that be true?")
    |> close()
  end
end
