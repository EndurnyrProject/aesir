defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Towner11150 do
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
        x: 111,
        y: 50,
        dir: 3,
        sprite: 943,
        name: "Towner",
        scope: :shared,
        unique_name: "Towner#ve11"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Towner]")
    |> mes("People cherish water")
    |> mes("around here, but I've")
    |> mes("something even more")
    |> mes("precious to me. Yes, even")
    |> mes("more precious than water...")
    |> mes("You guessed it--true love.")
    |> next()
    |> mes("[Towner]")
    |> mes("We actually started dating")
    |> mes("here, so this place really")
    |> mes("means a lot to me. It's my")
    |> mes("favorite spot for spending")
    |> mes("time with my girl. Hahaha~")
    |> close()
  end
end
