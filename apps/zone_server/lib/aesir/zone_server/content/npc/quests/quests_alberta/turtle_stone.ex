defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAlberta.TurtleStone do
  @moduledoc """
  The first Turtle Stone hides a clue and a red bead.

  ## Behavior

  - Advances the Turtle Island quest and reveals the next stone.

  ## Credits

  - Original from rAthena, authors and contributors:
    - kobra_k88
    - Lupus
    - Evera
    - DZeroX
    - L0ne_W0lf
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "tur_dun01",
        x: 203,
        y: 155,
        dir: 4,
        sprite: 111,
        name: "Turtle stone",
        scope: :shared,
        unique_name: "Turtle stone#tur"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :TURTLE, 0) == 4 ->
        ctx
        |> mes("^3355FFOn top of the stone")
        |> mes("is a small key hole")
        |> mes("with the turtle mark.^000000")
        |> next()
        |> mes("^3355FFYou used the")
        |> mes("Security Key")
        |> mes("in that hole.^000000")
        |> next()
        |> mes("^3355FF*Tat tat tat tat*^000000")
        |> next()
        |> mes("^3355FFThe back of the stone")
        |> mes("split into two parts")
        |> mes("revealing some hidden")
        |> mes("words engraved inside.^000000")
        |> next()
        |> mes("[Turtle Stone]")
        |> mes(
          "The one who dreams to be a star of serenity must first hold the comet and three rays of light as one."
        )
        |> next()
        |> mes("[Turtle Stone]")
        |> mes("You already possess the comet, so I grant you the first light...")
        |> next()
        |> mes("[Turtle Stone]")
        |> mes("- Light of the second stage -")
        |> mes("^FF3355B2 , X : 75 , Y : 249^000000")
        |> next()
        |> mes("^3355FFAt the bottom of the stone")
        |> mes("beneath the line of words,")
        |> mes("rests a brilliant red bead.^000000")
        |> next()
        |> set_char_var(:TURTLE, 10)
        |> changequest(11032, 11035)
        |> mes("^3355FFYou set the red bead to the")
        |> mes("Security key, fitting it")
        |> mes("within one of three tiny holes.^000000")
        |> close()

      true ->
        ctx
        |> mes("^3355FFIt is just a")
        |> mes("normal turtle")
        |> mes("stone. But")
        |> mes("on the top")
        |> mes("is written")
        |> mes("the words,")
        |> mes("'1st stage.'^000000")
        |> close()
    end
  end
end
