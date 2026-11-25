defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.Employee61175 do
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
        x: 61,
        y: 175,
        dir: 3,
        sprite: 818,
        name: "Employee",
        scope: :shared,
        unique_name: "Employee#3",
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_talk(ctx) do
    if gettime(ctx, 3) >= 10 and gettime(ctx, 3) < 22 do
      soup_finished? = get_char_var(ctx, :ch_tre, 0) == 5

      ctx =
        ctx
        |> mes("[Ya Hua]")
        |> mes("Welcome, welcome!")
        |> mes("We have many rooms")
        |> mes("available! Why don't")
        |> mes("you go upstairs?")
        |> mes("Ha ha ha!")

      if soup_finished? do
        ctx
        |> next()
        |> emotion(:sweat)
        |> mes("[Ya Hua]")
        |> mes(
          "Oh, if by any chance you came to try the Dragon Soup, I'm sorry, but it's no longer availalbe."
        )
        |> next()
        |> mes("[Ya Hua]")
        |> mes(
          "But don't be too disappointed, we serve many other delicious foods that you can choose from!"
        )
        |> close()
      else
        close(ctx)
      end
    else
      ctx |> mes("[Ya Hua]") |> mes("^666666*Yawn...*^000000") |> close()
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
    |> mes("[Ya Hua]")
    |> mes("What do you think")
    |> mes("you're doing here?!")
    |> mes("Put that down and")
    |> mes("leave right now!")
    |> next()
  end

  defp warn_thief(ctx, :sleepy) do
    ctx
    |> mes("[Ya Hua]")
    |> mes("^666666*Yawn...*^000000")
    |> mes("Eyelids...")
    |> mes("Getting...")
    |> mes("Heavier...")
    |> next()
    |> mes("[Ya Hua]")
    |> mes("Wait a sec...")
    |> mes("Are you a Thief?!")
    |> mes("Get out of here!!")
    |> next()
  end
end
