defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.PileOfSkeletons do
  @moduledoc """
  A pile of skeletons hides a magic bottle.

  ## Behavior

  - At the relevant quest stage, approaching the pile lets players search for the bottle.

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
        map: "mosk_dun03",
        x: 225,
        y: 233,
        dir: 0,
        sprite: 111,
        name: "Pile of skeletons",
        scope: :shared,
        unique_name: "Pile of skeletons#Magic",
        trigger: {5, 5}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTouch", ctx) do
    if get_char_var(ctx, :mos_nowinter, 0) == 8 do
      search_bottle(ctx)
    else
      ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :mos_nowinter, 0) == 8 do
      ctx
      |> mes("-There are ugly skulls")
      |> mes("all over here but, ")
      |> mes("this is the only place that I can stay.-")
      |> next()
      |> mes("-Get closer to see")
      |> mes("more carefully.-")
      |> close()
    else
      ctx |> mes("-The ugly skulls are gathered.-") |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp search_bottle(ctx) do
    ctx =
      ctx
      |> mes("-She said that the Magic Gourd Bottle that")
      |> mes("can hold people's speech")
      |> mes("is around here.-")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("This is probably the only place")
      |> mes("where the bottle is hidden,")
      |> mes("but there are bones all over.")
      |> next()

    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Anyway, why am I here?")
      |> mes("It would be trouble if")
      |> mes("the dragon came back...")
      |> next()
      |> select(["Look for it.", "I will try next time."])

    cond do
      choice != 1 ->
        try_later(ctx)

      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:thief) ->
        found_bottle(ctx, "Here it is.", "That was easy to find.")

      Enum.random(1..20) > 14 ->
        found_bottle(ctx, "Ah, I got it!", "I better get out of here quickly.")

      true ->
        ctx = ctx |> mes("............") |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Where the hell is it?!")
          |> mes("It has to be in here somewhere!")
          |> next()

        try_later(ctx)
    end
  end

  defp found_bottle(ctx, first_line, second_line) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes(first_line)
    |> mes(second_line)
    |> set_char_var(:mos_nowinter, 9)
    |> give_item(7761, 1)
    |> changequest(18073, 18074)
    |> close()
  end

  defp try_later(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("I will try later.")
    |> close()
  end
end
