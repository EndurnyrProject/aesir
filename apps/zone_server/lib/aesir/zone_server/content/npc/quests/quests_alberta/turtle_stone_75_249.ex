defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAlberta.TurtleStone75249 do
  @moduledoc """
  The second Turtle Stone hides a clue and a yellow bead.

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
        map: "tur_dun02",
        x: 75,
        y: 249,
        dir: 4,
        sprite: 111,
        name: "Turtle stone",
        scope: :shared,
        unique_name: "Turtle stone#tur2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :TURTLE, 0) == 10 ->
        ctx
        |> mes("^3355FFOn top of the stone")
        |> mes("is a small keyhole")
        |> mes("with the turtle mark.^000000")
        |> next()
        |> mes("^3355FFYou used the")
        |> mes("Security Key")
        |> mes("in the keyhole.^000000")
        |> next()
        |> mes("^3355FF*Click! Click!*^000000")
        |> next()
        |> mes("^3355FFThe back of the stone")
        |> mes("split into two parts")
        |> mes("revealing some hidden")
        |> mes("words along the inside.^000000")
        |> next()
        |> mes("[Turtle Stone]")
        |> mes(
          "The one who dreams to be a star of serenity must first hold the comet and three rays of light as one."
        )
        |> next()
        |> mes("[Turtle Stone]")
        |> mes(
          "You already possess the comet and the first light, so I now grant you the second light."
        )
        |> next()
        |> mes("[Turtle stone]")
        |> mes("- Light of the third stage -")
        |> mes("^FF3355B3 . X : 118 . Y : 233^000000")
        |> next()
        |> mes("At the bottom of the stone")
        |> mes("beneath the line of words,")
        |> mes("rests a brilliant yellow bead.")
        |> next()
        |> set_char_var(:TURTLE, 11)
        |> changequest(11035, 11036)
        |> mes("^3355FFYou set the yellow bead")
        |> mes("into the Security key, fitting it")
        |> mes("within one of three tiny holes.^000000")
        |> close()

      true ->
        ctx
        |> mes("^3355FFIt is just a")
        |> mes("normal turtle")
        |> mes("stone. But")
        |> mes("on the top,")
        |> mes("the words")
        |> mes("'2nd stage'")
        |> mes("are written.^000000")
        |> close()
    end
  end
end
