defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuMerchant.Jayon do
  @moduledoc """
  Jayon, a Prontera vendor who sells Red Potions to Merchant trainees.

  ## Behavior

  - During the Merchant price-research task (quest step 6, 7 or 8) sells 10 Red Potions
    for 410, 400 and 410 Zeny respectively; buying sets the quest step to 9 for the fair
    cheapest offer or to 10 when the player overpaid or was scammed.
  - Refuses the sale when the player lacks the Zeny or the weight room.
  - Outside the task, he talks about sightseeing in the Schwarzwald Republic.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - L0ne_W0lf
    - SinSloth
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "prontera", x: 247, y: 129, dir: 3, sprite: 85, name: "Jayon", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Jayon]")

    case get_char_var(ctx, :tu_merchant, 0) do
      6 -> sell_potions(ctx, 410, 10)
      7 -> sell_potions(ctx, 400, 10)
      8 -> sell_potions(ctx, 410, 10)
      _ -> small_talk(ctx)
    end
  end

  defp small_talk(ctx) do
    ctx
    |> mes("The Schwarzwald Republic...")
    |> mes(
      "It's a really interesting country. There's Juno and a few other places worth looking around. "
    )
    |> next()
    |> mes("[Jayon]")
    |> mes("They may not be the best places")
    |> mes(
      "for sight seeing, but I'm sure they'll offer something of interest to you adventurers."
    )
    |> close()
  end

  defp sell_potions(ctx, cost, next_step) do
    {ctx, choice} =
      ctx
      |> mes(
        "If you've checked out the market for Red Potions, you know that my price is the best. I'm offering 10 Red Potions for only #{cost} Zeny!"
      )
      |> next()
      |> select(["Buy", "Cancel"])

    case choice do
      1 ->
        ctx =
          ctx
          |> mes("[Jayon]")
          |> mes("Heh heh...!")
          |> mes("It looks like")
          |> mes("you know your")
          |> mes("stuff. You're a")
          |> mes("Merchant yourself,")
          |> mes("aren't you?")

        cond do
          zeny(ctx) < cost ->
            ctx
            |> next()
            |> mes("[Jayon]")
            |> mes("But sorry buddy.")
            |> mes("Rules are rules.")
            |> mes("You gotta meet my price")
            |> mes("if you want these potions.")
            |> close()

          get_char_var(ctx, :MaxWeight, 0) - weight(ctx) < 71 ->
            ctx
            |> next()
            |> mes("[Jayon]")
            |> mes("But sorry buddy. I can't let you carry more than you can handle.")
            |> mes("You ought to free up some of your inventory space when you get the chance.")
            |> close()

          true ->
            ctx
            |> pay_zeny(cost)
            |> set_char_var(:tu_merchant, next_step)
            |> give_item(501, 10)
            |> close()
        end

      2 ->
        ctx
        |> mes("[Jayon]")
        |> mes("Just looking")
        |> mes("around, eh?")
        |> mes("I understand.")
        |> mes("But you better take")
        |> mes("advantage of a real")
        |> mes("deal when you see one!")
        |> close()

      _ ->
        small_talk(ctx)
    end
  end
end
