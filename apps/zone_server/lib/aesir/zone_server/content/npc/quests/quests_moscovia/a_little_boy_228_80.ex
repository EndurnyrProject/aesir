defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.ALittleBoy22880 do
  @moduledoc """
  Rurik shares his thoughts about summer.

  ## Behavior

  - During the winter quest, his answer can advance the villagers’ survey.

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
        x: 228,
        y: 80,
        dir: 3,
        sprite: 962,
        name: "A Little Boy",
        scope: :shared,
        unique_name: "A Little Boy#mos16"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :mos_nowinter, 0) == 10 and get_char_var(ctx, :mos_kid, 0) == 0 do
      ask_about_summer(ctx)
    else
      ctx
      |> mes("[Rurik]")
      |> mes("It's hard to look up at you.")
      |> mes("Come lower so I can see your eyes.")
      |> next()
      |> mes("[Rurik]")
      |> mes("Hmm, that's better.")
      |> mes("Children are the future.")
      |> mes("I won't have a future if I fall")
      |> mes("back and hurt my neck")
      |> mes("while looking up at you.")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp ask_about_summer(ctx) do
    {ctx, _} = select(ctx, ["Do you like summer?"])
    ctx = mes(ctx, "[Rurik]")

    if Enum.random(1..100) > 70 do
      ctx =
        ctx
        |> mes("Ah, move a bit to the side.")
        |> mes("a bit more... Yes.")
        |> mes("Ah, stop there.")
        |> next()
        |> mes("[Rurik]")
        |> mes("I certainly like the summer.")
        |> mes("Unless the sunlight is too strong,")
        |> mes("it is much better than the cold winter.")
        |> next()
        |> specialeffect2(:summonslave)
        |> mes("[Rurik]")
        |> mes("By the way, what is this for?")
        |> mes("It is natural to like the summer.")
        |> mes("Do you think")
        |> mes("the winter should come again?")
        |> set_char_var(:mos_kid, 1)

      ctx =
        if get_char_var(ctx, :mos_middle, 0) == 1 and get_char_var(ctx, :mos_elder, 0) == 1 do
          ctx |> set_char_var(:mos_nowinter, 11) |> changequest(18075, 18076)
        else
          ctx
        end

      close(ctx)
    else
      ctx
      |> mes("Sure, I like the summer.")
      |> mes("Why are you asking")
      |> mes("such a question so suddenly?")
      |> close()
    end
  end
end
