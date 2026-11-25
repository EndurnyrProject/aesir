defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.ALady168135 do
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
        x: 168,
        y: 135,
        dir: 3,
        sprite: 961,
        name: "A Lady",
        scope: :shared,
        unique_name: "A Lady#mos10"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Kyra]")
      |> mes("I've seen many people")
      |> mes("from other provinces recently.")
      |> next()
      |> mes("[Kyra]")
      |> mes("This used to not")
      |> mes("be a tourist town.")
      |> mes("What happened...?")

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
    {ctx, _} = ctx |> next() |> select(["Here it is warm and good."])
    ctx = mes(ctx, "[Kyra]")

    if Enum.random(1..100) > 70 do
      ctx =
        ctx
        |> mes("Hohoho, that may be true now.")
        |> mes("But, you don't even know how cold it gets here in winter.")
        |> mes("You wouldn't even want to go outside.")
        |> next()
        |> specialeffect2(:summonslave)
        |> mes("[Kyra]")
        |> mes("It is good to stay with my family, but")
        |> mes("nobody likes the cold winter.")
        |> set_char_var(:mos_elder, 1)

      finish_quest_if_ready(ctx)
      |> close()
    else
      ctx
      |> mes("Hohoho, that may be true now.")
      |> mes("But, you don't even know how cold it gets here in winter.")
      |> mes("You wouldn't even want to go outside.")
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
