defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.Bed do
  @moduledoc """
  A bed can be examined while searching for Mikhail.

  ## Behavior

  - At the relevant quest stage, the player can look over the bed.

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
        map: "mosk_in",
        x: 136,
        y: 279,
        dir: 3,
        sprite: 111,
        name: "Bed",
        scope: :shared,
        unique_name: "Bed#mos1"
      },
      %{
        map: "mosk_in",
        x: 161,
        y: 279,
        dir: 3,
        sprite: 111,
        name: "Bed",
        scope: :shared,
        unique_name: "Bed#mos2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx =
      mes(
        ctx,
        "- There are sheets and a pillow which seem so neat and soft that I'll probably fall asleep as soon as I lie down on them. -"
      )

    if get_char_var(ctx, :mos_swan, 0) == 11 do
      {ctx, choice} = ctx |> next() |> select(["Check other things", "Look it over "])

      if choice == 1 do
        ctx |> mes("- You'll examine the bed later -") |> close()
      else
        examine_bed(ctx)
      end
    else
      close(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp examine_bed(ctx) do
    ctx
    |> mes("- You come near the bed to look it over. -")
    |> next()
    |> mes(" .............. ")
    |> mes(" .............. ")
    |> mes(" .............. ")
    |> mes(" .............. ")
    |> next()
    |> mes(" .............. ")
    |> mes(" .............. ")
    |> mes(" .............. ")
    |> mes(" .............. ")
    |> mes(" .............. ")
    |> next()
    |> mes("- You didn't find anything -")
    |> close()
  end
end
