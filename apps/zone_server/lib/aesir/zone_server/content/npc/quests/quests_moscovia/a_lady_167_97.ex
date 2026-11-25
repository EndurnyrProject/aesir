defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.ALady16797 do
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
        x: 167,
        y: 97,
        dir: 3,
        sprite: 961,
        name: "A Lady",
        scope: :shared,
        unique_name: "A Lady#mos6"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :mos_nowinter, 0) == 10 and
         get_char_var(ctx, :mos_elder, 0) == 0 do
      discuss_winter(ctx)
    else
      ctx
      |> mes("[Roza]")
      |> mes("Naughty children get too")
      |> mes("excited in the warm days.")
      |> next()
      |> mes("[Roza]")
      |> mes("Where is the sun?")
      |> mes("Where is it hiding?")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp discuss_winter(ctx) do
    {ctx, _} = select(ctx, ["The weather is getting warmer."])
    ctx = mes(ctx, "[Roza]")

    if Enum.random(1..100) > 70 do
      ctx =
        ctx
        |> mes("Yes, kids like it and")
        |> mes("flowers are blooming.")
        |> next()
        |> specialeffect2(:summonslave)
        |> mes("[Roza]")
        |> mes("Whoever likes the cold and dark winter?")
        |> mes("I hope this weather last forever.")
        |> set_char_var(:mos_elder, 1)

      finish_quest_if_ready(ctx)
      |> close()
    else
      ctx
      |> mes("In the warm days,")
      |> mes("I'm in trouble.")
      |> mes("It's too hard to control")
      |> mes("the children.")
      |> next()
      |> mes("[Roza]")
      |> mes("I think")
      |> mes("I need winter again.")
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
