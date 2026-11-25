defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.AMan234168 do
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
        x: 234,
        y: 168,
        dir: 5,
        sprite: 964,
        name: "A Man",
        scope: :shared,
        unique_name: "A Man#mos15"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Gavrel]")
      |> mes("Don't you think that the castle is magnificent?")
      |> mes("It was built by my great great grandfather.")

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
    {ctx, _} =
      ctx
      |> next()
      |> mes("[Gavrel]")
      |> mes("It is very strong and")
      |> mes("it is warm inside of it.")
      |> mes("I am very proud of it.")
      |> next()
      |> select(["Is it cold much in winter?"])

    ctx = mes(ctx, "[Gavrel]")

    if Enum.random(1..100) > 70 do
      ctx =
        ctx
        |> mes("Yes, it is very cold.")
        |> mes("If you didn't prepare,")
        |> mes("it would be hard for you.")
        |> next()
        |> specialeffect2(:summonslave)
        |> mes("[Gavrel]")
        |> mes("It would be a lot better")
        |> mes("if winter never came again.")
        |> mes("But, design of coldness is")
        |> mes("winter itself, isn't it?")
        |> set_char_var(:mos_elder, 1)

      finish_quest_if_ready(ctx)
      |> close()
    else
      ctx
      |> mes("Yes, it is very cold.")
      |> mes("If you didn't prepare,")
      |> mes("it would be hard for you.")
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
