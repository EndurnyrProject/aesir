defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAlberta.TurtleStone118233 do
  @moduledoc """
  The third Turtle Stone hides a clue and a blue bead.

  ## Behavior

  - Advances the Turtle Island quest and reveals the final destination.

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
        map: "tur_dun03",
        x: 118,
        y: 233,
        dir: 4,
        sprite: 111,
        name: "Turtle Stone",
        scope: :shared,
        unique_name: "Turtle Stone#tur3"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :TURTLE, 0) == 11 ->
        ctx
        |> mes("^3355FFOn top of the stone")
        |> mes("is a small key hole")
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
          "You already possess the comet, and the first two lights. The final light is now yours."
        )
        |> next()
        |> mes("[Turtle Stone]")
        |> mes("- Star of Serenity -")
        |> mes("^FF3355B4 . X : 113 . Y : 178^000000")
        |> next()
        |> mes("^3355FFAt the bottom of the stone")
        |> mes("beneath the line of words,")
        |> mes("rests a brilliant blue bead.^000000")
        |> next()
        |> set_char_var(:TURTLE, 12)
        |> changequest(11036, 11037)
        |> mes("^3355FFYou set the blue bead to the")
        |> mes("into the Security Key, fitting it")
        |> mes("within one of three tiny holes.^000000")
        |> close()

      true ->
        ctx
        |> mes("^3355FFIt is just a")
        |> mes("normal turtle")
        |> mes("stone. But")
        |> mes("on the top,")
        |> mes("the words,")
        |> mes("'3rd stage,'")
        |> mes("are written.^000000")
        |> close()
    end
  end
end
