defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.AYoungMan220172 do
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
        x: 220,
        y: 172,
        dir: 3,
        sprite: 968,
        name: "A Young Man",
        scope: :shared,
        unique_name: "A Young Man#mos8"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Ilyav]")
      |> mes("I am going to adventure")
      |> mes("to experience new worlds")
      |> mes("as you do.")

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
    {ctx, _} = ctx |> next() |> select(["When do you feel good?"])
    ctx = mes(ctx, "[Ilyav]")

    if Enum.random(1..100) > 70 do
      ctx =
        ctx
        |> mes("When the weather is as good as recently")
        |> mes("I feel an impulse to adventure")
        |> mes("many times a day.")
        |> next()
        |> specialeffect2(:summonslave)
        |> mes("[Ilyav]")
        |> mes("But, I don't want to in the cold winter.")
        |> mes("Hu, if the weather everday was as good as lately,")
        |> mes("I would like to go out a lot more.")
        |> mes("I hate winter...")
        |> set_char_var(:mos_middle, 1)

      finish_quest_if_ready(ctx)
      |> close()
    else
      ctx
      |> mes("Well...")
      |> mes("I don't know.")
      |> mes("I just am sometimes.")
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
