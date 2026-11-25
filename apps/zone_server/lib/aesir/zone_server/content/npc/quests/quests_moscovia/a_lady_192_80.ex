defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.ALady19280 do
  @moduledoc """
  A Moscovia resident shares their thoughts on winter.

  ## Behavior

  - During the quest, a conversation can reveal a wish for winter to end.

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
        x: 192,
        y: 80,
        dir: 3,
        sprite: 959,
        name: "A Lady",
        scope: :shared,
        unique_name: "A Lady#mos11"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Sabina]")
      |> mes("Sunflowers are squeezed for oil and")
      |> mes("their bodies are used for medicinal purposes.")
      |> mes("They are very useful.")

    if get_char_var(ctx, :mos_nowinter, 0) == 10 and
         get_char_var(ctx, :mos_middle, 0) == 0 do
      discuss_winter(ctx)
    else
      close(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp discuss_winter(ctx) do
    {ctx, _} = ctx |> next() |> select(["When do sunflowers bloom?"])
    ctx = mes(ctx, "[Sabina]")

    if Enum.random(1..100) > 70 do
      ctx =
        ctx
        |> mes("They start to bloom")
        |> mes("from the late summer.")
        |> mes("You cannot help being")
        |> mes("attracted to sunflowers,")
        |> mes("if you see the spectacular scene")
        |> mes("of a field filled up with them.")
        |> next()
        |> mes("[Sabina]")
        |> mes("If the summer continues to last,")
        |> mes("I can see them all the time...")
        |> specialeffect2(:summonslave)
        |> set_char_var(:mos_middle, 1)

      finish_quest_if_ready(ctx)
      |> close()
    else
      ctx
      |> mes("They start to bloom")
      |> mes("from the late summer.")
      |> mes("You cannot help being")
      |> mes("attracted to sunflowers,")
      |> mes("if you see the spectacular scene")
      |> mes("of a field filled up with them.")
      |> close()
    end
  end

  defp finish_quest_if_ready(ctx) do
    if get_char_var(ctx, :mos_kid, 0) == 1 and get_char_var(ctx, :mos_elder, 0) == 1 do
      ctx |> set_char_var(:mos_nowinter, 11) |> changequest(18075, 18076)
    else
      ctx
    end
  end
end
