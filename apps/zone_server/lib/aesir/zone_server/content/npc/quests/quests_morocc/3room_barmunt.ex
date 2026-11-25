defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.M3roomBarmunt do
  @moduledoc """
  A burning room reveals the escape of Eva and her companion.

  ## Behavior

  - Players before quest stage 4 return to the library; others witness the escape.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Gepard
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
        map: "que_ba",
        x: 102,
        y: 56,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#3room_barmunt",
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnTouch", ctx) do
    enter_room(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    enter_room(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp enter_room(ctx) do
    if get_char_var(ctx, :barmunt_crow, 0) < 4 do
      warp(ctx, "yuno_in04", 100, 3)
    else
      ctx =
        ctx
        |> mes(
          "^660000You walked through the flame engulfed hallway and ended at a room that was about to collapse, just like everywhere else in this place.^000000"
        )
        |> next()
        |> mes(
          "^660000You could not clearly see what was inside the room because of all the smoke, but you knew there was something there.^000000"
        )
        |> next()
        |> mes(
          "^660000You squinted your eyes, and listened. You could hear human voices, but their silhouettes of whomever was talking were not human shaped.^000000"
        )
        |> next()
        |> mes("[Female]")
        |> mes("Cough! Fire... Cough!")
        |> mes("Goddamn humans... Cough, cough!")
        |> next()
        |> mes(
          "^660000Her coughing grew worse as the roaring of the flames grew stronger.^000000"
        )
        |> next()
        |> mes("[Male]")
        |> mes("They ran away, and left us behind to die!")
        |> next()
        |> mes("[Female]")
        |> mes("...Are we going to die?")
        |> next()
        |> mes("[Male]")
        |> mes("Die? ...Haha.")
        |> mes("^3131FF'Eva'^000000, we won't die... We were never exactly alive to begin with.")
        |> next()
        |> mes("- Crumbling -")
        |> next()
        |> mes("[Male]")
        |> mes("Argh!")
        |> next()
        |> mes(
          "^660000The only exit was blocked by steel bars; no one could get out of the room enveloped in flames. Then, a corner of a wall crumbled by the heat from the fire.^000000"
        )
        |> next()
        |> mes(
          "^660000The male silhouette quickly approached the wall, and started to dig at the crumbled corner.^000000"
        )
        |> next()
        |> mes("[Male]")
        |> mes("...It's done!")
        |> next()
        |> mes("[Male]")
        |> mes("Let's go, Eva!")
        |> next()
        |> mes("[Eva]")
        |> mes("Wait, we have to take the children with us.")
        |> next()
        |> mes(
          "^660000The female silhouette called Eva approached the test tubes standing in a row against a wall.^000000"
        )
        |> next()
        |> mes("[Male]")
        |> mes("Eva!! We don't have time to save all of them! Come here!")

      ctx =
        if get_char_var(ctx, :barmunt_crow, 0) == 4 do
          set_char_var(ctx, :barmunt_crow, 5)
        else
          ctx
        end

      ctx |> sc_start(:sc_blind, 600_000, 0) |> close2() |> warp("que_ba", 53, 232)
    end
  end
end
