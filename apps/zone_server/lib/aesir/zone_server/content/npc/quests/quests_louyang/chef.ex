defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.Chef do
  @moduledoc """
  A restaurant chef whose soup can be stolen.

  ## Behavior

  - Changes dialogue with the soup quest and may catch thieves.

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
        x: 62,
        y: 183,
        dir: 3,
        sprite: 820,
        name: "Chef",
        scope: :shared,
        unique_name: "Chef#1-2",
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :ch_tre, 0) > 0 and get_char_var(ctx, :ch_tre, 0) < 4 ->
        ctx
        |> mes("[Wang Shi Long]")
        |> mes("Hm? Aren't you a customer? I am Wang Shi Long, the chef of this restaurant.")
        |> next()
        |> mes("[Wang Shi Long]")
        |> mes(
          "My family has served food to Lord Bai Long for a long time. This restaurant is own by my family and I am the successor."
        )
        |> next()
        |> mes("[Wang Shi Long]")
        |> mes("Every dish my family cooks is counted among the most delicious food in Luoyang.")
        |> next()
        |> mes("[Wang Shi Long]")
        |> mes("Our Dragon Soup won especially high praise from our Lord Bai Long.")
        |> next()
        |> mes("[Wang Shi Long]")
        |> mes(
          "I'm also proud to tell you that my family only uses the freshest, highest quality ingredients for our dishes."
        )
        |> next()
        |> mes("[Wang Shi Long]")
        |> mes(
          "We have been popular in Luoyang for hundreds and hundreds of years because of the quality of our gourmet food."
        )
        |> next()
        |> mes("[Wang Shi Long]")
        |> mes(
          "Recently, though, I've had a bad feeling that someone is trying to take over our restaurant..."
        )
        |> next()
        |> mes("[Wang Shi Long]")
        |> mes(
          "Oh, well. Maybe I'm in a different mood because of some other reason. It's probably nothing."
        )
        |> close()

      get_char_var(ctx, :ch_tre, 0) > 3 and get_char_var(ctx, :ch_tre, 0) < 6 ->
        ctx
        |> mes("[Wang Shi Long]")
        |> mes("^666666*Moans and Cries*^000000")
        |> mes("I guess this is it...!")
        |> mes("The end of my family's glory.")
        |> mes("Someone stole the base broth")
        |> mes("of my Dragon Soup!")
        |> next()
        |> mes("[Wang Shi Long]")
        |> mes("What should I do, now?")
        |> mes(
          "Without Dragon Soup, my family's restaurant will now just be like all the others..."
        )
        |> close()

      true ->
        ctx
        |> mes("[Wang Shi Long]")
        |> mes("Hello, are you")
        |> mes("one of our customers?")
        |> mes("I am Wang Shi Long,")
        |> mes("the chef of this")
        |> mes("restaurant.")
        |> next()
        |> mes("[Wang Shi Long]")
        |> mes("My family has served food")
        |> mes(
          "to Lord Bai Long for a long time. This restaurant has been handed down the family line, and I am the successor~"
        )
        |> next()
        |> mes("[Wang Shi Long]")
        |> mes(
          "Our specialty dish, Dragon Soup, won especially high praise from Lord Bai Long, who is known for"
        )
        |> mes("his extremely discerning sense of taste.")
        |> next()
        |> mes("[Wang Shi Long]")
        |> mes(
          "I'm also proud to say that we cook with only the freshest and highest quality ingredients."
        )
        |> next()
        |> mes("[Wang Shi Long]")
        |> mes(
          "We've always been popular in Luoyang for hundreds and hundreds of years because of our high quality gourmet cuisine."
        )
        |> next()
        |> mes("[Wang Shi Long]")
        |> mes("In this dry and hot weather,")
        |> mes(
          "Dragon Soup is the best food for any appetite. I suggest that you try a bowl. You'll be quite pleased!"
        )
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :ch_tre, 0) == 2 or get_char_var(ctx, :ch_tre, 0) == 3 do
      {threshold, sleepy} =
        cond do
          gettime(ctx, 3) >= 10 and gettime(ctx, 3) < 14 -> {9, false}
          gettime(ctx, 3) >= 14 and gettime(ctx, 3) < 17 -> {10, false}
          gettime(ctx, 3) >= 17 and gettime(ctx, 3) < 22 -> {6, false}
          true -> {5, true}
        end

      if Enum.random(1..10) < threshold do
        ctx
        |> catch_thief(sleepy)
        |> next()
        |> mes("^3131FFYou have failed^000000")
        |> mes("^3131FFto steal the pot.^000000")
        |> set_char_var(:ch_tre, 1)
        |> warp("louyang", 280, 161)
        |> close()
      else
        ctx
      end
    else
      ctx
    end
  end

  defp catch_thief(ctx, true) do
    ctx
    |> mes("[Wang Shi Long]")
    |> mes("^666666*Yawn...*^000000")
    |> mes("Hm...?")
    |> mes("Who's that?")
    |> next()
    |> mes("[Wang Shi Long]")
    |> mes("Wait...!")
    |> mes("What are you doing?!")
    |> mes("G-Get out of here!")
  end

  defp catch_thief(ctx, false) do
    ctx
    |> mes("[Wang Shi Long]")
    |> mes("Hey, what do you")
    |> mes("think you're doing?!")
    |> mes("Let go of that, and")
    |> mes("get outta here!")
  end
end
