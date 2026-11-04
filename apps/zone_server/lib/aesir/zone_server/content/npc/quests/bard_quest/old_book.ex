defmodule Aesir.ZoneServer.Content.Npc.Quests.BardQuest.OldBook do
  @moduledoc """
  A fragile book containing the original lyrics sought in the bard quest.

  ## Behavior

  Players with access can search for the lyrics and advance the quest.

  ## Credits

  Original rAthena authors: Riotblade and L0ne_W0lf.
  Contributors: Lupus, SinSloth, and Euphy.

  ## Adaptation

  Transpiled by `mix aesir.import.npcs` and refactored with LLM assistance.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_in01",
        x: 163,
        y: 101,
        dir: 0,
        sprite: 111,
        name: "Old Book",
        scope: :shared,
        unique_name: "Old Book#bq"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = set_temp_var(ctx, :"name$", char_name(ctx, 0))

    if get_char_var(ctx, :gef_bard_q, 0) > 11 and get_char_var(ctx, :gef_bard_q, 0) < 14 do
      if not Rathena.truthy?(:rand.uniform(5) - 1) do
        ctx =
          ctx
          |> mes(
            "^3355FFYou opened the book. There's a crisp brittleness to the pages, and the letters are faded and barely readable. You can't even identify the author's name.^000000"
          )
          |> next()
          |> mes("[Collection of Eddas]")
          |> mes(
            "This is a love song. Everyone suffers from unrequited love at least once in their lifetime."
          )
          |> next()
          |> mes("[Collection of Eddas]")
          |> mes("At One, I fall in love.")
          |> mes("At Two, you give me your smile.")
          |> mes("At Three, I adore your touch.")
          |> mes("At Four, a tender kiss...")
          |> next()
          |> mes("[Collection of Eddas]")
          |> mes("At Five, we change our minds.")
          |> mes("A petal scatters through the air.")
          |> mes("At Six, I fall in love~")
          |> mes("At Seven, you fall in love...")
          |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", get_temp_var(ctx, :"name$", "")), "]"))
        |> mes("I think this is it...!")
        |> mes("I better write it down.")
        |> next()
        |> mes("[Collection of Eddas]")
        |> mes("At Eight, we're both in love.")
        |> mes("At Nine, you know my heart.")
        |> mes("At Ten, I know you've")
        |> mes("been waiting for me.")
        |> next()
        |> mes("[Collection of Eddas]")
        |> mes("At Eleven, a precious")
        |> mes("Whisper: 'Will you marry me?'")
        |> mes("At Twelve, our two hearts")
        |> mes("Are one. 12 petals, our")
        |> mes("Love finally blossoms.")
        |> next()
        |> mes(
          "^3355FFYou copy down the final lines, and keep them in a note inside your pocket."
        )
        |> set_char_var(:gef_bard_q, 15)
        |> close()
      else
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", get_temp_var(ctx, :"name$", "")), "]"))
        |> mes(
          "*Sigh* I can barely read this book. Maybe I should try flipping through another one."
        )
        |> close()
      end
    else
      ctx
      |> mes("[Sketzi Bundin]")
      |> mes(
        "I'm sorry, but that book is too fragile for handling. Only special customers can peruse these books."
      )
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
