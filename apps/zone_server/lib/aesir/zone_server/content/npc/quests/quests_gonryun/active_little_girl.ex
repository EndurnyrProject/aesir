defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsGonryun.ActiveLittleGirl do
  @moduledoc """
  Hisa talks about life in Juno and its doctor.

  ## Behavior

  - Advances the Broken Sword quest by directing adventurers to Cylrnel.

  ## Credits

  - Original from rAthena, authors and Contributors
    - KarLaeda
    - L0ne_W0lf
    - Paradox924X

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno",
        x: 208,
        y: 164,
        dir: 4,
        sprite: 101,
        name: "Active little girl",
        scope: :shared,
        unique_name: "Active little girl#gnbs"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :b_sword, 0) < 21 do
      ctx
      |> mes("[Hisa]")
      |> mes(".....")
      |> mes("This town is so boring.")
      |> mes("No events, no festivals...")
      |> mes("All people do all day is stay at")
      |> mes("at home and study. How dull!")
      |> close()
    else
      continue_story(ctx)
    end
  end

  defp continue_story(ctx) do
    ctx =
      ctx
      |> mes("[Hisa]")
      |> mes("There's one person in Juno that")
      |> mes("I still respect. Her name is ^FF5500Cylrnel^000000.")
      |> next()
      |> mes("[Hisa]")
      |> mes("She's an expert in medical")
      |> mes("treatment. Whenever someone falls")
      |> mes("ill in this town, she comes to")
      |> mes("cure that person right away...")
      |> next()
      |> mes("[Hisa]")
      |> mes("She also tells me lots of")
      |> mes("interesting stories about")
      |> mes("her experiences. She's even")
      |> mes("made a journey around the")
      |> mes("world... It's so interesting!")
      |> next()
      |> mes("[Hisa]")
      |> mes("She's probably at home after")
      |> mes("coming back from some trip.")
      |> mes("Haha~")

    ctx =
      if get_char_var(ctx, :b_sword, 0) == 21 do
        set_char_var(ctx, :b_sword, 22)
      else
        ctx
      end

    ctx =
      if Enum.random(1..2) == 2 do
        ctx
        |> next()
        |> mes("[Hisa]")
        |> mes("Oh right~!")
        |> mes("She's also known to be a fickle")
        |> mes("and forgetful woman. So you'd better watch out, hehe~")
      else
        ctx
      end

    close(ctx)
  end
end
