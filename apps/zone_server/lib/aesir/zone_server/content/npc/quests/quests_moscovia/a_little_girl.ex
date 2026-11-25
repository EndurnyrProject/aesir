defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.ALittleGirl do
  @moduledoc """
  Yosefina shares thoughts about the weather.

  ## Behavior

  - During the winter quest, a successful conversation records a resident’s wish.

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
        x: 252,
        y: 203,
        dir: 5,
        sprite: 958,
        name: "A Little Girl",
        scope: :shared,
        unique_name: "A Little Girl#mos1"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :mos_nowinter, 0) == 10 and get_char_var(ctx, :mos_kid, 0) == 0 do
      ask_about_winter(ctx)
    else
      ctx
      |> mes("[Yosefina]")
      |> mes("Baba Yaga, the Horrible Cannibal")
      |> mes("is living outside the town.")
      |> next()
      |> mes("[Yosefina]")
      |> mes("My mom told me.")
      |> mes("that she is real.")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp ask_about_winter(ctx) do
    {ctx, _} =
      ctx
      |> set_local(:kid, Enum.random(1..100))
      |> select(["Do you like the warm weather, little girl?"])

    ctx = mes(ctx, "[Yosefina]")

    if get_local(ctx, :kid, 0) > 70 do
      ctx =
        ctx
        |> mes("Yes, I like it very much~")
        |> mes("I never want it to leave. I don't want winter to come.")
        |> specialeffect2(:summonslave)
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
      |> mes("Yes, I like it very much~")
      |> mes("But, as soon as the sun sets I must go back home.")
      |> next()
      |> mes("[Yosefina]")
      |> mes("Baba Yaga kidnaps")
      |> mes("bad kids wandering")
      |> mes("in the night, I heard.")
      |> close()
    end
  end
end
