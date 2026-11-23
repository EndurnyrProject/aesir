defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAlberta.TurtleTreeRoots do
  @moduledoc """
  The Turtle Tree Roots reveal the next clue in a treasure hunt.

  ## Behavior

  - Advances the treasure hunt from the roots key to the crystal key.

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
        x: 132,
        y: 251,
        dir: 4,
        sprite: 111,
        name: "Turtle Tree Roots",
        scope: :shared,
        unique_name: "Turtle Tree Roots#tur"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :TURTLE, 0) == 3 do
      ctx
      |> mes("^3355FFUnder the tree roots^000000")
      |> mes("^3355FFis a tiny key hole^000000")
      |> mes("^3355FFmarked with a root insignia.^000000")
      |> mes("^3355FFYou used the Roots key^000000")
      |> mes("^3355FFin that key hole.^000000")
      |> next()
      |> mes("^3355FF*Swishy swashy!*^000000")
      |> next()
      |> mes("^3355FFBetween the roots^000000")
      |> mes("^3355FFa little door opens,^000000")
      |> mes("^3355FFrevealing an^000000")
      |> mes("^3355FFold scroll.^000000")
      |> next()
      |> mes("[Old scroll]")
      |> mes("^FF3355Following the^000000")
      |> mes("^FF3355legend from^000000")
      |> mes("^FF3355my village,^000000")
      |> mes("^FF3355I've come^000000")
      |> mes("^FF3355to improve my^000000")
      |> mes("^FF3355swordmanship...^000000")
      |> next()
      |> mes("[Old scroll]")
      |> mes("^FF3355Only one who^000000")
      |> mes("^FF3355cuts the shell^000000")
      |> mes("^FF3355of a turtle^000000")
      |> mes("^FF3355can become a^000000")
      |> mes("^FF3355grand master^000000")
      |> mes("^FF3355of the sword...^000000")
      |> next()
      |> mes("[Old scroll]")
      |> mes("^FF3355To fufill this^000000")
      |> mes("^FF3355legend, I have^000000")
      |> mes("^FF3355come. I, 'One,'^000000")
      |> mes("^FF3355will cut the^000000")
      |> mes("^FF3355turtle's shell!!^000000")
      |> next()
      |> mes("[Old scroll]")
      |> mes("^FF3355Go...^000000")
      |> mes("^FF3355tur_dun02^000000")
      |> mes("^FF3355X : 46 , Y : 125^000000")
      |> next()
      |> mes("^3355FFInside the pile of turtle^000000")
      |> mes("^3355FFcrystals, a scroll is hidden.^000000")
      |> set_char_var(:TURTLE, 7)
      |> changequest(11031, 11033)
      |> mes("^3355FFYou've gained a^000000")
      |> mes("^3355FFTurtle Crystal key.^000000")
      |> close()
    else
      ctx
      |> mes("^3355FFThere are old,^000000")
      |> mes("^3355FFthick tree roots^000000")
      |> mes("^3355FFanchored into^000000")
      |> mes("^3355FFthe ground here.^000000")
      |> close()
    end
  end
end
