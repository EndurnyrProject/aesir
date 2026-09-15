defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Towner11251 do
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
        x: 112,
        y: 51,
        dir: 3,
        sprite: 940,
        name: "Towner",
        scope: :shared,
        unique_name: "Towner#ve12"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Towner]")
    |> mes("Well, I'm actually")
    |> mes("a little tired of coming")
    |> mes("here all the time. I kind")
    |> mes("of want to try someplace")
    |> mes("else, but I also know he")
    |> mes("really loves coming here.")
    |> next()
    |> mes("[Towner]")
    |> mes("It would actually be")
    |> mes("kind of sad if we stopped")
    |> mes("coming here altogether.")
    |> mes("I'm just happy so long")
    |> mes("as he's with me~ Hoho~")
    |> close()
  end
end
