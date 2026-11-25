defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.AMiddleAgedMan do
  @moduledoc """
  Viktor shares thoughts about the weather.

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
        x: 219,
        y: 229,
        dir: 5,
        sprite: 964,
        name: "A Middle-Aged Man",
        scope: :shared,
        unique_name: "A Middle-Aged Man#mos3"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :mos_nowinter, 0) == 10 and get_char_var(ctx, :mos_elder, 0) == 0 do
      ask_about_winter(ctx)
    else
      ctx
      |> mes("[Viktor]")
      |> mes("Our people are very, very")
      |> mes("proud of their strength and")
      |> mes("invincible spirits.")
      |> next()
      |> mes("[Viktor]")
      |> mes("It doesn't matter to us")
      |> mes("how cold the winter is!")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp ask_about_winter(ctx) do
    {ctx, _} = select(ctx, ["Whoever likes the winter?"])
    ctx = mes(ctx, "[Viktor]")

    if Enum.random(1..100) > 70 do
      ctx =
        ctx
        |> mes("Tell me about it!")
        |> mes("Everyone will be sad")
        |> mes("when it comes again.")
        |> mes("I don't want winter to come.")
        |> specialeffect2(:summonslave)
        |> set_char_var(:mos_elder, 1)

      ctx =
        if get_char_var(ctx, :mos_kid, 0) == 1 and get_char_var(ctx, :mos_middle, 0) == 1 do
          ctx |> set_char_var(:mos_nowinter, 11) |> changequest(18075, 18076)
        else
          ctx
        end

      close(ctx)
    else
      ctx
      |> mes("Hmm, do you think so...")
      |> mes("I am too familiar with both")
      |> mes("summer and winter to care much for")
      |> mes("one over the other.")
      |> close()
    end
  end
end
