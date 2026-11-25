defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.ALittleBoy do
  @moduledoc """
  Vasili shares thoughts about the weather.

  ## Behavior

  - During the winter quest, a successful conversation records a resident’s wish.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moscovia",
        x: 255,
        y: 203,
        dir: 3,
        sprite: 962,
        name: "A Little Boy",
        scope: :shared,
        unique_name: "A Little Boy#mos4"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Vasili]")
      |> mes("Wow, he is")
      |> mes("an adventurer, an adventurer!!")
      |> next()

    if get_char_var(ctx, :mos_nowinter, 0) == 10 and get_char_var(ctx, :mos_kid, 0) == 0 do
      ask_about_winter(ctx)
    else
      ctx
      |> mes("[Vasili]")
      |> mes("Tell me your exciting story.")
      |> mes("Have you fought a dragon?")
      |> mes("Where is your gold-shining sword and shield?")
      |> mes("Where?")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp ask_about_winter(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Vasili]")
      |> mes("Why did you come here?")
      |> mes("Don't you have any colleague?")
      |> mes("I heard that the heroes in epics were tall,")
      |> mes("but, why are you so small?")
      |> mes("Where is your gold-shining sword?")
      |> mes("I heard that the armor glittered white,")
      |> mes("but, why don't you have on the armor?")
      |> mes("Won't you go for another adventure?")
      |> mes("How can you do it in the cold and snowy winter?")
      |> next()
      |> select(["I will go if it gets warm."])

    ctx = mes(ctx, "[Vasili]")

    if Enum.random(1..100) > 70 do
      ctx =
        ctx
        |> mes("Will you? I will also")
        |> mes("go out for adventures")
        |> mes("with shining armor and")
        |> mes("a long and heavy sword")
        |> mes("some day.")
        |> next()
        |> specialeffect2(:summonslave)
        |> mes("[Vasili]")
        |> mes("If winter is gone,")
        |> mes("it is much easier to go on adventures.")
        |> set_char_var(:mos_kid, 1)

      ctx =
        if get_char_var(ctx, :mos_middle, 0) == 1 and get_char_var(ctx, :mos_elder, 0) == 1 do
          ctx |> set_char_var(:mos_nowinter, 11) |> changequest(18075, 18076)
        else
          ctx
        end

      close(ctx)
    else
      ctx
      |> mes("Ah, when are you leaving?")
      |> mes("Where are you going this time?")
      |> next()
      |> mes("[Vasili]")
      |> mes("Will you go to slay the dragon,")
      |> mes("that breathes fire and can")
      |> mes("exterminates 10 men by flapping")
      |> mes("its wings once?")
      |> close()
    end
  end
end
