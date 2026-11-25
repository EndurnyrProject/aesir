defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.ALittleBoy202102 do
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
        x: 202,
        y: 102,
        dir: 3,
        sprite: 962,
        name: "A Little Boy",
        scope: :shared,
        unique_name: "A Little Boy#mos7"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :mos_nowinter, 0) == 10 and
         get_char_var(ctx, :mos_kid, 0) == 0 do
      discuss_winter(ctx)
    else
      ctx
      |> mes("[Feliks]")
      |> mes("This is the story")
      |> mes("about a terrible dragon.")
      |> next()
      |> mes("[Feliks]")
      |> mes("It is sleeping")
      |> mes("in its lair,")
      |> mes("but, it destroys everything")
      |> mes("around it when it awakes.")
      |> next()
      |> mes("[Feliks]")
      |> mes("This came from my grandma's")
      |> mes("grandma's grandma's")
      |> mes("grandma's grandma's")
      |> mes("grandma's grandma.")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp discuss_winter(ctx) do
    {ctx, _} = select(ctx, ["Do you like mysterious stories?"])
    ctx = mes(ctx, "[Feliks]")

    if Enum.random(1..100) > 70 do
      ctx =
        ctx
        |> mes("Yes, I love them.")
        |> mes("But, in winter,")
        |> mes("nobody comes out of their homes.")
        |> mes("So it's not very fun.")
        |> next()
        |> specialeffect2(:summonslave)
        |> mes("[Feliks]")
        |> mes("If winter never comes")
        |> mes("I can have")
        |> mes("fun all the time...")
        |> set_char_var(:mos_kid, 1)

      finish_quest_if_ready(ctx)
      |> close()
    else
      ctx
      |> mes("Yes, my Grandma told me")
      |> mes("fairy-tales.")
      |> mes("The winter is cold, but")
      |> mes("it is fun to hear them.")
      |> close()
    end
  end

  defp finish_quest_if_ready(ctx) do
    if get_char_var(ctx, :mos_middle, 0) == 1 and get_char_var(ctx, :mos_elder, 0) == 1 do
      ctx |> set_char_var(:mos_nowinter, 11) |> changequest(18075, 18076)
    else
      ctx
    end
  end
end
