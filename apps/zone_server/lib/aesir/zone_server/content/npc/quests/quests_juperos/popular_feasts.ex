defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.PopularFeasts do
  @moduledoc """
  Offers recipes from the Popular Feasts cookbook.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - L0ne_W0lf
    - Zephyrus
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_in04",
        x: 102,
        y: 106,
        dir: 1,
        sprite: 111,
        name: "Popular Feasts",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^8B6914*Popular Feasts*")
      |> mes("By Cabbage Pickle Community")
      |> mes(" ")
      |> mes(" ")
      |> mes(" ")
      |> mes("Publisher:")
      |> mes("Muha Books, Co.^000000")
      |> next()
      |> select([" 1. Fried Yoyo Tails", " 14. Poring Salad", " 252. Beak Soup"])

    case choice do
      1 ->
        ctx =
          ctx
          |> mes("^8B6914...")
          |> mes("If possible, try")
          |> mes("to use tails cut")
          |> mes("from live Yoyos.")
          |> mes("Now, as for skinning...^000000")
          |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Um...")
        |> mes("Barf?")
        |> close()

      2 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Hey, this page is gone!")
        |> mes("I guess Poring Salad is")
        |> mes("the most popular feast")
        |> mes("in this entire book.")
        |> close()

      3 ->
        ctx =
          ctx
          |> mes("^8B6914...")
          |> mes("Fry the cut beaks")
          |> mes("using herbal oil until")
          |> mes("crisp. Then, pour the")
          |> mes("feathers into a blender...^000000")
          |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Hmm...")
        |> mes("Sounds a little")
        |> mes("too gourmet for my")
        |> mes("taste. And by ''gourmet,''")
        |> mes("I mean, ''totally gross.''")
        |> close()

      _ ->
        ctx
    end
  end
end
