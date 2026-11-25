defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.AMan do
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
        x: 253,
        y: 175,
        dir: 3,
        sprite: 964,
        name: "A Man",
        scope: :shared,
        unique_name: "A Man#mos9"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :mos_nowinter, 0) == 10 and
         get_char_var(ctx, :mos_elder, 0) == 0 do
      discuss_winter(ctx)
    else
      ctx
      |> mes("[Orek]")
      |> mes("The present Csar is a bit strict and")
      |> mes("terrible, but")
      |> mes("he actually loves")
      |> mes("his people.")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp discuss_winter(ctx) do
    {ctx, _} = select(ctx, ["What do you usually do in winter?"])
    ctx = mes(ctx, "[Orek]")

    if Enum.random(1..100) > 70 do
      ctx =
        ctx
        |> mes("It is too cold in winter so I don't go outside.")
        |> mes("There's so much snow that it makes it hard to go")
        |> mes("around here and there.")
        |> next()
        |> specialeffect2(:summonslave)
        |> mes("[Orek]")
        |> mes("In winter, fishing is more difficult,")
        |> mes("anyway, it is bad for us.")
        |> mes("I think it would be ok if we never had winter again.")
        |> set_char_var(:mos_elder, 1)

      finish_quest_if_ready(ctx)
      |> close()
    else
      ctx
      |> mes("It snows a lot in winter and")
      |> mes("gets too cold.")
      |> mes("So, we don't go outside")
      |> mes("without a particular reason.")
      |> next()
      |> mes("[Orek]")
      |> mes("My family just sits beside the pechka and talks,")
      |> mes("hoping that winter passes by soon.")
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
