defmodule Aesir.ZoneServer.Content.Npc.Cities.Payon.YoungMan17382 do
  @moduledoc """
  Wonders whether a forbidden amulet could summon his dead grandfather.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad Dib
    - Darkchild
    - DracoRPG
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "payon",
        x: 173,
        y: 82,
        dir: 0,
        sprite: 88,
        name: "Young Man",
        scope: :shared,
        unique_name: "Young Man#2payon"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Young Man]")
    |> mes("I remember the story my dearly departed grandfather has told me.")
    |> next()
    |> mes("[Young Man]")
    |> mes("It's about this Amulet that possesses an Evil Power.")
    |> mes("With it, you could awaken")
    |> mes("the Dead from the Grave.")
    |> next()
    |> mes("[Young Man]")
    |> mes(
      "Well, I'm not sure if it's true or not. But, I wonder, what would happen if I used it to summon"
    )
    |> mes("my grandfather from the other realm....")
    |> next()
    |> mes("[?]")
    |> mes("^3299CCNever think")
    |> mes("of such a thing...")
    |> mes("My son.^000000")
    |> next()
    |> mes("[Young Man]")
    |> mes("EEEEEEK-!")
    |> mes("What was that?!")
    |> mes("G-grandpa...?")
    |> next()
    |> mes("...")
    |> next()
    |> mes("...")
    |> mes("......")
    |> mes("[Young Man]")
    |> mes("...")
    |> mes("G-God...?")
    |> close()
  end
end
