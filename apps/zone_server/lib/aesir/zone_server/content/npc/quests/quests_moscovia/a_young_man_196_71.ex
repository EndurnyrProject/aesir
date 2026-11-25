defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.AYoungMan19671 do
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
        x: 196,
        y: 71,
        dir: 3,
        sprite: 968,
        name: "A Young Man",
        scope: :shared,
        unique_name: "A Young Man#mos14"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Fredek]")
      |> mes("The men here grow up")
      |> mes("after going through tough waves in")
      |> mes("the vast sea")

    if get_char_var(ctx, :mos_nowinter, 0) == 10 and
         get_char_var(ctx, :mos_middle, 0) == 0 do
      discuss_winter(ctx)
    else
      ctx |> next() |> mes("[Fredek]") |> mes("Do you like") |> mes("sailing?") |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp discuss_winter(ctx) do
    {ctx, _} = ctx |> next() |> select(["However, if winter comes..."])
    ctx = mes(ctx, "[Fredek]")

    if Enum.random(1..100) > 70 do
      ctx =
        ctx
        |> mes("Yes, in winter the")
        |> mes("sea is frozen, so it")
        |> mes("is impossible to sail.")
        |> next()
        |> specialeffect2(:summonslave)
        |> mes("[Fredek]")
        |> mes("I hope that winter never comes.")
        |> mes("It is my dream.")
        |> set_char_var(:mos_middle, 1)

      finish_quest_if_ready(ctx)
      |> close()
    else
      ctx
      |> mes("Although I won't be able")
      |> mes("to sail, my passion is not")
      |> mes("cooled down from winter.")
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
