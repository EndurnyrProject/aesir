defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.Pot do
  @moduledoc """
  A restaurant pot involved in the soup quest.

  ## Behavior

  - The pot can be stolen during the soup quest, with its surroundings varying by time.

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
        x: 50,
        y: 185,
        dir: 5,
        sprite: 111,
        name: "Pot",
        scope: :shared,
        unique_name: "Pot#1"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :ch_tre, 0) == 1 ->
        offer_pot(ctx)

      get_char_var(ctx, :ch_tre, 0) > 3 and get_char_var(ctx, :ch_tre, 0) < 6 ->
        ctx
        |> mes("^3131FFYou found a pot.^000000")
        |> mes("^3131FFHowever, it's empty.^000000")
        |> close()

      gettime(ctx, 3) >= 10 and gettime(ctx, 3) < 22 ->
        ctx
        |> mes("[Chef]")
        |> mes("Ah...!")
        |> mes("Please, do not")
        |> mes("touch the pots!")
        |> close()

      true ->
        ctx
        |> mes("^3131FFBeneath the shadows,")
        |> mes("you find a large pot filled with dark, red liquid.^000000 ")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp offer_pot(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3131FFBeneath the shadows,")
      |> mes("you find a large pot filled with dark, red liquid. What do you")
      |> mes("want to do?^000000 ")
      |> next()
      |> select(["Take the pot.", "Look for another pot."])

    if choice == 1 do
      take_pot(ctx)
    else
      ctx
      |> mes("^3131FFYou decide to^000000")
      |> mes("^3131FFlook for another pot.^000000")
      |> close()
    end
  end

  defp take_pot(ctx) do
    ctx =
      ctx
      |> mes("^3131FFYou take a careful look around.")
      |> mes("It wouldn't be wise to steal this now if anyone is watching.^000000")
      |> next()
      |> describe_restaurant()
      |> next()
      |> mes("^3131FFYou carefully lift the pot, and although it's heavy, you think")
      |> mes("you can carry it.^000000")
      |> next()
      |> mes("^3131FFAll you have")
      |> mes("to do now is get")
      |> mes("away from this restaurant")
      |> mes("without getting caught...^000000")

    outcome = if Enum.random(1..4) < 4, do: 2, else: 3
    ctx |> set_char_var(:ch_tre, outcome) |> close()
  end

  defp describe_restaurant(ctx) do
    cond do
      gettime(ctx, 3) >= 10 and gettime(ctx, 3) < 14 ->
        mes(
          ctx,
          "^3131FFThe restaurant doesn't seem busy right now, so there's only a few employees and customers.^000000"
        )

      gettime(ctx, 3) >= 14 and gettime(ctx, 3) < 17 ->
        ctx
        |> mes("^3131FFOnly the restaurant")
        |> mes("employees are around,")
        |> mes("and they busy chatting")
        |> mes("amongst each other.^000000")

      gettime(ctx, 3) >= 17 and gettime(ctx, 3) < 22 ->
        ctx
        |> mes("^3131FFThe restaurant is filled")
        |> mes("with customers, and the")
        |> mes("hustle and bustle of the")
        |> mes("restaurant employees.^000000")
        |> next()
        |> mes("^3131FFEveryone seems so busy")
        |> mes("and preoccupied that they don't")
        |> mes("notice you approach the pot.^000000")

      true ->
        ctx
        |> mes("^3131FFSince the restaurant")
        |> mes("is closed, the whole place")
        |> mes("is completely quiet. The")
        |> mes("employees are all asleep.^000000")
    end
  end
end
