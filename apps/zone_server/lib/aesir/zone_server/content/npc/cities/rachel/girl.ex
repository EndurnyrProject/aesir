defmodule Aesir.ZoneServer.Content.Npc.Cities.Rachel.Girl do
  @moduledoc """
  Shares a child's understanding of Rachel's pope.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Tsuyuki and Harp
    - L0ne_W0lf
    - Lupus
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "rachel",
        x: 74,
        y: 150,
        dir: 7,
        sprite: 914,
        name: "Girl",
        scope: :shared,
        unique_name: "Girl#1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Girl]")
    |> mes("I've never seen our pope")
    |> mes("before, I hear that she has")
    |> mes("silver blond hair and really")
    |> mes("white skin. Daddy says that")
    |> mes("only one girl is like that")
    |> mes("in every generation.")
    |> next()
    |> mes("[Girl]")
    |> mes("My daddy says the pope is")
    |> mes("very special to us because")
    |> mes("she's Freya. I mean, Freya")
    |> mes("is a goddess, but she also")
    |> mes("becomes people like us to talk")
    |> mes("to us. Well, just the priests...")
    |> next()
    |> mes("[Girl]")
    |> mes("I don't get it all,")
    |> mes("but it sounds like")
    |> mes("she's a secret princess.")
    |> mes("Doesn't that sound so nice?")
    |> mes("But when I tell that to Daddy,")
    |> mes("he gets so mad at me! Oh, well.")
    |> close()
  end
end
