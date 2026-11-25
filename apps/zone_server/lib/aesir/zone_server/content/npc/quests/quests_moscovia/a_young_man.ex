defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.AYoungMan do
  @moduledoc """
  Fedor shares thoughts about the weather.

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
        x: 233,
        y: 204,
        dir: 3,
        sprite: 968,
        name: "A Young Man",
        scope: :shared,
        unique_name: "A Young Man#mos2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :mos_nowinter, 0) == 10 and get_char_var(ctx, :mos_middle, 0) == 0 do
      ask_about_winter(ctx)
    else
      ctx
      |> mes("[Fedor]")
      |> mes("Finally, winter is over.")
      |> mes("Spring is coming")
      |> mes("to my mind...")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp ask_about_winter(ctx) do
    {ctx, _} = select(ctx, ["You don't like winter, do you?"])
    ctx = ctx |> set_local(:kid, Enum.random(1..100)) |> mes("[Fedor]")

    if get_local(ctx, :kid, 0) > 70 do
      ctx =
        ctx
        |> mes("No, I don't like the cold winter.")
        |> mes("And I get angry when")
        |> mes("seeing couples.")
        |> specialeffect2(:summonslave)
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
      |> mes("Huuuu, I wish I could have a girlfriend")
      |> mes("I would be able to enjoy the warm sunlight better...")
      |> next()
      |> mes("[Fedor]")
      |> mes("Who are you?")
      |> mes("Don't make matters worse!")
      |> close()
    end
  end
end
