defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Towner14841 do
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
        x: 148,
        y: 41,
        dir: 3,
        sprite: 940,
        name: "Towner",
        scope: :shared,
        unique_name: "Towner#ve2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Towner]")
    |> mes("Welcome to Veins, the")
    |> mes("town near the Temple of")
    |> mes("Cheshrumnir. You may think")
    |> mes("this is a dreary desert town,")
    |> mes("but you'll find that it's as")
    |> mes("lively as any other place.")
    |> next()
    |> mes("[Towner]")
    |> mes("Sure, there are a few")
    |> mes("characters in town, like")
    |> mes("that cactus loving loony")
    |> mes("over there, but not everyone's")
    |> mes("like him. There's lots of nice,")
    |> mes("kind people that you can meet.")
    |> next()
    |> mes("[Towner]")
    |> mes("Well then, I hope that")
    |> mes("you enjoy your stay~")
    |> close()
  end
end
