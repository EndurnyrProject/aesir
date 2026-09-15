defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.OldMan191134 do
  @moduledoc """
  Shares an elderly resident's observations about life in Veins.

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
        x: 191,
        y: 134,
        dir: 3,
        sprite: 945,
        name: "Old Man",
        scope: :shared,
        unique_name: "Old Man#ve3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Old Man]")
    |> mes("Why don't you take")
    |> mes("a look at my goods?")
    |> mes("I've got many things")
    |> mes("that might interest you~")
    |> next()
    |> mes("[Old Man]")
    |> mes("Praise be to Freya,")
    |> mes("who watches over us,")
    |> mes("and blesses us with")
    |> mes("food and drink. Don't")
    |> mes("you think that's great,")
    |> mes("young adventurer?")
    |> close()
  end
end
