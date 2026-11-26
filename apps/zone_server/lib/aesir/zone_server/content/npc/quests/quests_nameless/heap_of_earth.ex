defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.HeapOfEarth do
  @moduledoc """
  A disturbed patch of earth hides a lost wallet.

  ## Behavior

  - The player digs up the wallet over two visits during the quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "cmd_fild01",
        x: 55,
        y: 160,
        dir: 0,
        sprite: 844,
        name: "Heap of Earth",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :diamond_edq, 0) do
      1 -> dig_spot(ctx)
      2 -> recover_wallet(ctx)
      progress when progress > 3 -> already_dug(ctx)
      _ -> inspect_spot(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp dig_spot(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFIt looks like someone")
      |> mes("dug a hole in the ground,")
      |> mes("and then covered it again.^000000")
      |> next()
      |> select(["Dig Up the Spot", "Cancel"])

    case choice do
      1 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("There must be something")
        |> mes("in the ground. I better")
        |> mes("dig it up and check...")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Ergh...! Ugh!")
        |> mes("This would be a lot")
        |> mes("easier with a shovel!")
        |> mes("Only a little more to go...")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Hm? I hit something?")
        |> mes("Let's--Yucky! It's so")
        |> mes("wet and--Ugh! Nasty")
        |> mes("little thing. Now what?")
        |> mes("I dropped it! I have to")
        |> mes("try to dig it up again...")
        |> changequest(3100, 3101)
        |> set_char_var(:diamond_edq, 2)
        |> close()

      2 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Something isn't quite")
        |> mes("kosher about all this.")
        |> mes("Nope, this time, I'm")
        |> mes("not going to do this.")
        |> close()

      _ ->
        ctx
    end
  end

  defp recover_wallet(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Here we are... It's...")
    |> mes("A soggy wallet? This")
    |> mes("must be the one Muff")
    |> mes("lost. Oh, and the bond")
    |> mes("of debt is inside... Mm...")
    |> mes("Ugh, it's really soaked...")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Well, I've done all")
    |> mes("I can for now. I should")
    |> mes("bring this back to Muff.")
    |> changequest(3101, 3102)
    |> set_char_var(:diamond_edq, 4)
    |> close()
  end

  defp already_dug(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("This is the same spot")
    |> mes("I dug up from before.")
    |> mes("It's useless to me now!")
    |> close()
  end

  defp inspect_spot(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Huh. There's a weird")
    |> mes("bump in the ground. Well,")
    |> mes("I can't just go looking at")
    |> mes("anything that's slightly")
    |> mes("out of the ordinary. Heh.")
    |> mes("I'm not weird like that.")
    |> close()
  end
end
