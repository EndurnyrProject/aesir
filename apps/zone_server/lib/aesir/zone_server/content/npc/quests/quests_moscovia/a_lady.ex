defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.ALady do
  @moduledoc """
  Katya shares thoughts about the weather.

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
        x: 204,
        y: 188,
        dir: 5,
        sprite: 959,
        name: "A Lady",
        scope: :shared,
        unique_name: "A Lady#mos5"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :mos_nowinter, 0) == 10 and get_char_var(ctx, :mos_middle, 0) == 0 do
      ask_about_winter(ctx)
    else
      ctx
      |> mes("[Katya]")
      |> mes("The spring has come~")
      |> next()
      |> mes("[Katya]")
      |> mes("A million sunflowers are blooming~")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp ask_about_winter(ctx) do
    {ctx, _} = select(ctx, ["You look good today."])
    ctx = mes(ctx, "[Katya]")

    if Enum.random(1..100) > 70 do
      ctx =
        ctx
        |> mes("Yes, I feel good.")
        |> mes("When it gets warm, sunflowers bloom.")
        |> mes("The sunflower is the symbol")
        |> mes("of this province.")
        |> next()
        |> specialeffect2(:summonslave)
        |> mes("[Katya]")
        |> mes("I wish that winter never comes back and")
        |> mes("I could see sunflowers everyday.")
        |> set_char_var(:mos_middle, 1)

      ctx =
        if get_char_var(ctx, :mos_kid, 0) == 1 and get_char_var(ctx, :mos_elder, 0) == 1 do
          ctx |> set_char_var(:mos_nowinter, 11) |> changequest(18075, 18076)
        else
          ctx
        end

      close(ctx)
    else
      ctx
      |> mes("Yes, I feel good.")
      |> mes("When it gets warm, sunflowers bloom.")
      |> mes("The sunflower is the symbol")
      |> mes("of this province.")
      |> close()
    end
  end
end
