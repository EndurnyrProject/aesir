defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAlberta.APileOfTurtleCrystal do
  @moduledoc """
  A pile of turtle crystals conceals a message and a key.

  ## Behavior

  - Reveals the crystal plate and advances the Turtle Island quest at the appropriate stage.

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
        x: 46,
        y: 125,
        dir: 4,
        sprite: 111,
        name: "A pile of turtle crystal",
        scope: :shared
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :TURTLE, 0) == 7 ->
        ctx
        |> mes("^3355FFAmong the Turtle Crystals,^000000")
        |> mes("^3355FFyou find a strange key hole.^000000")
        |> next()
        |> mes("^3355FFYou use the")
        |> mes("Turtle crystal key")
        |> mes("in the key hole.^000000")
        |> next()
        |> mes("^3355FF*Click! Click!*^000000")
        |> next()
        |> mes("^3355FFBetween the crystals,000000")
        |> mes("^3355FFa small crystal plate^000000")
        |> mes("^3355FFin which a message^000000")
        |> mes("^3355FFin engraved.^000000")
        |> next()
        |> mes("[Crystal Plate]")
        |> mes("^3355AAI, the swordsman,^000000")
        |> mes("^3355AA'One,' has succeeded.^000000")
        |> mes("^3355AAI've cut the turtle's shell.^000000")
        |> mes("^3355AANow I shall try to^000000")
        |> mes("^3355AAcut turtle crystal.^000000")
        |> next()
        |> mes("[Crystal Plate]")
        |> mes("^3355AAThe surface of turtle^000000")
        |> mes("^3355AAcrystal is so rough and^000000")
        |> mes("^3355AAirregular. I'll need^000000")
        |> mes("^3355AAto sharpen my skills.^000000")
        |> next()
        |> mes("[Crystal Plate]")
        |> mes("^3355AAIt's going to be tough,^000000")
        |> mes("^3355AAbut I will succeed...^000000")
        |> next()
        |> mes("[Crystal plate]")
        |> mes("^3355AAGo 5 steps east,^000000")
        |> mes("^3355AA30 steps south^000000")
        |> mes("^3355AAand 5 steps around^000000")
        |> mes("^3355AAthe turtle pillar.^000000")
        |> mes("^3355AAThere you will find^000000")
        |> mes("^3355AAthe end of sword art.^000000")
        |> next()
        |> mes("^3355FFAt the edge of the crystal^000000")
        |> mes("^3355FFplate, is a long key.^000000")
        |> set_char_var(:TURTLE, 8)
        |> changequest(11033, 11034)
        |> mes("^3355FFYou've gained the^000000")
        |> mes("^3355FFTurtle Pillar key.^000000")
        |> close()

      true ->
        ctx
        |> mes("^3355FFThere are so many Turtle^000000")
        |> mes("^3355FFCrystals that can only be^000000")
        |> mes("^3355FFfound on Turtle island.^000000")
        |> close()
    end
  end
end
