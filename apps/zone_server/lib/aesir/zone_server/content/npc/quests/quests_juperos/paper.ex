defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.Paper do
  @moduledoc """
  Offers a personal letter from Fayruz to read.

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
      %{map: "yuno_in04", x: 118, y: 116, dir: 4, sprite: 111, name: "Paper", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFIt's a piece of")
      |> mes("paper that looks")
      |> mes("like a personal letter.^000000")
      |> next()
      |> select(["Read it.", "Leave it alone."])

    case choice do
      1 ->
        if get_char_var(ctx, :yuno_hist, 0) > 7 do
          ctx
          |> mes("^8B6914P.S.")
          |> mes("Please...")
          |> mes("Come back to me.")
          |> mes(" ")
          |> mes(" ")
          |> mes("Love,")
          |> mes("Fayruz^000000")
          |> close()
        else
          ctx =
            ctx
            |> mes("^8B6914...")
            |> mes("I can't forget your smile.")
            |> mes("No matter what, even if you")
            |> mes("hate me, I'll always have these")
            |> mes("feelings just for you. You are")
            |> mes("the one who is most special,")
            |> mes("who means the most to my heart.^000000")
            |> next()
            |> mes("^8B6914I know we've had our")
            |> mes("differences, but please")
            |> mes("don't refuse my love. By")
            |> mes("your hands, I hope that")
            |> mes("you can forgive me for us.")
            |> mes("- Love, Fayruz^000000")
            |> next()

          if Rathena.truthy?(getpartnerid(ctx)) do
            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("Ahhhhhh~")
            |> mes("Love sure is nice!")
            |> close()
          else
            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("What th--?!")
            |> mes("Booooooooo!")
            |> mes("Love stinks!")
            |> close()
          end
        end

      2 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("I guess I better")
        |> mes("not look at this.")
        |> mes("I mean, I might")
        |> mes("regret reading it.")
        |> close()

      _ ->
        ctx
    end
  end
end
