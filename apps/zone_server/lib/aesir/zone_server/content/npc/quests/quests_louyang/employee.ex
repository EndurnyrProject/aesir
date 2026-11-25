defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.Employee do
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
        x: 53,
        y: 174,
        dir: 7,
        sprite: 822,
        name: "Employee",
        scope: :shared,
        unique_name: "Employee#1",
        trigger: {6, 62}
      }
    ]

  @impl true
  def on_talk(ctx) do
    if gettime(ctx, 3) >= 10 and gettime(ctx, 3) < 22 do
      ctx
      |> mes("[Chang Pai]")
      |> mes("Welcome, welcome!")
      |> mes("We are ready to serve you~!")
      |> mes("Now, go ahead and go upstairs~!")
      |> close()
    else
      ctx |> mes("[Chang Pai]") |> mes("^666666*Yawn...*^000000") |> close()
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
        gettime(ctx, 3) >= 17 and gettime(ctx, 3) < 21 -> detect(ctx, 6, :awake)
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
    |> mes("[Chang Pai]")
    |> mes("Wait, who are you?!")
    |> mes("Put that down and get")
    |> mes("of out here right now!")
    |> next()
  end

  defp warn_thief(ctx, :sleepy) do
    ctx
    |> mes("[Chang Pai]")
    |> mes("^666666*Yawn...*^000000")
    |> mes("So...")
    |> mes("Sleepy...")
    |> next()
    |> mes("[Chang Pai]")
    |> mes("Huh...?")
    |> mes("Who are you!?")
    |> mes("Hey, I got a thief here!")
    |> next()
  end
end
