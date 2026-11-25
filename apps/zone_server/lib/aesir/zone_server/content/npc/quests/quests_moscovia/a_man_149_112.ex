defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.AMan149112 do
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
        x: 149,
        y: 112,
        dir: 3,
        sprite: 964,
        name: "A Man",
        scope: :shared,
        unique_name: "A Man#mos13"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Lev]")
      |> mes("I was once like you,")
      |> mes("with a hot heart and cool reason,")
      |> mes("adventuring everywhere and")
      |> mes("coping with all the troubles...")

    if get_char_var(ctx, :mos_nowinter, 0) == 10 and
         get_char_var(ctx, :mos_elder, 0) == 0 do
      discuss_winter(ctx)
    else
      close(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp discuss_winter(ctx) do
    {ctx, _} = ctx |> next() |> select(["You need to take a rest."])
    ctx = mes(ctx, "[Lev]")

    if Enum.random(1..100) > 70 do
      ctx =
        ctx
        |> mes("Yes, under the warm sunlight,")
        |> mes("I like to rest.")
        |> next()
        |> specialeffect2(:summonslave)
        |> mes("[Lev]")
        |> mes("I hope that this warm weather")
        |> mes("will last forever.")
        |> mes("I hate the cold winter.")
        |> set_char_var(:mos_elder, 1)

      finish_quest_if_ready(ctx)
      |> close()
    else
      ctx
      |> mes("Yes, under the warm sunlight,")
      |> mes("I like to rest.")
      |> next()
      |> mes("[Lev]")
      |> mes("But, I am still alive!")
      |> mes("I don't want to hear talk")
      |> mes("like that from you.")
      |> close()
    end
  end

  defp finish_quest_if_ready(ctx) do
    if get_char_var(ctx, :mos_kid, 0) == 1 and get_char_var(ctx, :mos_middle, 0) == 1 do
      ctx |> set_char_var(:mos_nowinter, 11) |> changequest(18075, 18076)
    else
      ctx
    end
  end
end
