defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.Employee76181 do
  @moduledoc """
  Welcomes inn guests and watches for soup pot thieves.

  ## Behavior

  - Greets guests according to the time of day.
  - May catch thieves depending on the hour and reset their quest progress.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Paradox924X
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lou_in02",
        x: 76,
        y: 181,
        dir: 3,
        sprite: 822,
        name: "Employee",
        scope: :shared,
        unique_name: "Employee#2",
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_talk(ctx) do
    if gettime(ctx, 3) >= 10 and gettime(ctx, 3) < 22 do
      ctx
      |> mes("[Huang Jia Xian]")
      |> mes("Welcome~")
      |> mes("Sorry for making you wait. If you wish to rest, please go upstairs.")
      |> next()
      |> mes("[Huang Jia Xian]")
      |> mes(
        "Recently, many tourists are visiting Luoyang and although business is great, we're now"
      )
      |> mes("busier than ever.")
      |> next()
      |> mes("[Huang Jia Xian]")
      |> mes("^666666*Sigh...*^000000")
      |> mes("I don't even")
      |> mes("have time to eat.")
      |> mes("I'm starving...!")
      |> close()
    else
      ctx
      |> mes("[Huang Jia Xian]")
      |> mes("Ehhhh...")
      |> mes("Forgive me...")
      |> mes("....................")
      |> mes("...Zzzzz...Zzzz...")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_event("OnTouch_", ctx) do
    if get_char_var(ctx, :ch_tre, 0) == 2 or get_char_var(ctx, :ch_tre, 0) == 3 do
      cond do
        gettime(ctx, 3) >= 10 and gettime(ctx, 3) < 14 -> detect(ctx, 9, :awake)
        gettime(ctx, 3) >= 14 and gettime(ctx, 3) < 17 -> detect(ctx, 10, :awake)
        gettime(ctx, 3) >= 17 and gettime(ctx, 3) < 22 -> detect(ctx, 6, :awake)
        true -> detect(ctx, 5, :sleepy)
      end
    else
      ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp detect(ctx, threshold, mood) do
    if Enum.random(1..10) < threshold do
      ctx
      |> warn_thief(mood)
      |> mes("^3131FFYou have failed^000000")
      |> mes("^3131FFto steal the pot.^000000")
      |> set_char_var(:ch_tre, 1)
      |> close()
    else
      ctx
    end
  end

  defp warn_thief(ctx, :awake) do
    ctx
    |> mes("[Huang Jia Xian]")
    |> mes("What the...?")
    |> mes("Hey, what")
    |> mes("are you doing?")
    |> mes("Get out of here!")
    |> next()
  end

  defp warn_thief(ctx, :sleepy) do
    ctx
    |> mes("[Huang Jia Xian]")
    |> mes("*Yawn...*")
    |> mes("So very tired...")
    |> next()
    |> mes("[Huang Jia Xian]")
    |> mes("Hey, what are you")
    |> mes("doing here? Are you")
    |> mes("a Thief?! Somebody help!")
    |> mes("There's a Thief!")
    |> next()
  end
end
