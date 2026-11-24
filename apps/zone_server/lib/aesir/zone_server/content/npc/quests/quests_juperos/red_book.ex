defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.RedBook do
  @moduledoc """
  Offers a red-bound Shakespeare coloring book to read.

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
      %{map: "yuno_in04", x: 167, y: 127, dir: 1, sprite: 111, name: "Red Book", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFYou find a book")
      |> mes("with red binding.^000000")
      |> next()
      |> select(["Read.", "Leave it alone."])

    case choice do
      1 ->
        ctx =
          ctx
          |> mes("^8B6914...^000000")
          |> next()
          |> mes("^8B6914...")
          |> mes("......^000000")
          |> next()
          |> mes("^8B6914...")
          |> mes("......")
          |> mes(".........^000000")
          |> next()
          |> mes("^8B6914...")
          |> mes("......")
          |> mes(".........")
          |> mes("............^000000")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("This is...")
          |> mes("A compilation of")
          |> mes("Shakespeare in ")
          |> mes("coloring book format?")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Wait...")
          |> mes("Why would fans of")
          |> mes("Shakespeare even")
          |> mes("want a coloring book?")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Hmm... Well...")
          |> mes("I suppose little kids who")
          |> mes("read Shakespeare would")
          |> mes("appreciate something like that.")
          |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Hold on...")
        |> mes("Do little kids who")
        |> mes("are able to read the")
        |> mes("works of Shakespeare")
        |> mes("even exist? I hope not...")
        |> close()

      2 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("What a strange")
        |> mes("and mysterious book.")
        |> mes("I'll never know what's")
        |> mes("inside unless I read it!")
        |> mes("Come on! Doesn't the red")
        |> mes("binding mean something?")
        |> close()

      _ ->
        ctx
    end
  end
end
