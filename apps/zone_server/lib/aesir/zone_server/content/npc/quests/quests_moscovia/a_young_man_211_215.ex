defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.AYoungMan211215 do
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
        x: 211,
        y: 215,
        dir: 5,
        sprite: 967,
        name: "A Young Man",
        scope: :shared,
        unique_name: "A Young Man#mos12"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Izlof]")
      |> mes("There is a old saying,")
      |> mes("'an opportunity is a chance.'")
      |> next()
      |> mes("[Izlof]")
      |> mes("It is best to confess")
      |> mes("to ladies in the warm weather,")
      |> mes("when their minds wander")
      |> mes("right now!")

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
    {ctx, _} = ctx |> next() |> select(["It's good to have warm weather."])
    ctx = mes(ctx, "[Izlof]")

    if Enum.random(1..100) > 70 do
      ctx =
        ctx
        |> mes("Of course.")
        |> mes("From now on, it is my golden age of opportunity!")
        |> next()
        |> specialeffect2(:summonslave)
        |> mes("[Izlof]")
        |> mes("If it is the summer all the time,")
        |> mes("my life will be in an amorous mood.")
        |> mes("Hahaha!")
        |> mes("I don't want winter to come.")
        |> set_char_var(:mos_middle, 1)

      finish_quest_if_ready(ctx)
      |> close()
    else
      ctx
      |> mes("Of course.")
      |> mes("The cold winter has gone.")
      |> mes("From now on, it is my golden age!")
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
