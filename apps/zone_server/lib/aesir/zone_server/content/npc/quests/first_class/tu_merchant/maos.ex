defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuMerchant.Maos do
  @moduledoc """
  Maos, a Prontera vendor who sells Red Potions to Merchant trainees.

  ## Behavior

  - During the Merchant price-research task (quest step 6, 7 or 8) sells 10 Red Potions
    for 400, 340 and 420 Zeny respectively; buying sets the quest step to 9 for the fair
    cheapest offer or to 10 when the player overpaid or was scammed.
  - Refuses the sale when the player lacks the Zeny or the weight room.
  - Outside the task, he preaches that money exists to be spent.

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
    spawn: [%{map: "prt_in", x: 251, y: 129, dir: 3, sprite: 709, name: "Maos", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Maos]")

    case get_char_var(ctx, :tu_merchant, 0) do
      6 -> sell_potions(ctx, 400, 10)
      7 -> sell_potions(ctx, 340, 10)
      8 -> sell_potions(ctx, 420, 10)
      _ -> small_talk(ctx)
    end
  end

  defp small_talk(ctx) do
    ctx
    |> mes(
      "I see too many people struggling to scrape every penny and put it all into their savings..."
    )
    |> next()
    |> mes("[Maos]")
    |> mes(
      "Now, don't get me wrong. It's a good idea to invest in the future. But money exists to be spent! Enjoy every moment, that's what I say~"
    )
    |> next()
    |> mes("[Maos]")
    |> mes("Besides...")
    |> mes("You can't take")
    |> mes("your money with you")
    |> mes("when your time's up,")
    |> mes("you know?")
    |> close()
  end

  defp sell_potions(ctx, cost, next_step) do
    {ctx, choice} =
      ctx
      |> mes("Don't say anything.")
      |> mes("I know what you want.")
      |> mes("10 Red Potions, right?")
      |> mes("I'll sell them to you")
      |> mes("for the low price of #{cost} Zeny~")
      |> next()
      |> select(["Buy", "Cancel"])

    case choice do
      1 ->
        ctx =
          ctx
          |> mes("[Maos]")
          |> mes("Excellent choice!")
          |> mes("Good products at affordable prices! That's my ethic as a merchant.")

        cond do
          zeny(ctx) < cost ->
            ctx
            |> next()
            |> mes("[Maos]")
            |> mes(
              "Ooh, but you don't even have enough Zeny to purchase these potions. I'm sorry, but I can't sell these just to lose money, you know?"
            )
            |> close()

          get_char_var(ctx, :MaxWeight, 0) - weight(ctx) < 71 ->
            ctx
            |> next()
            |> mes("[Maos]")
            |> mes(
              "Ooh, but it doesn't look like you've got enough inventory space to carry any more items."
            )
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
        |> mes("[Maos]")
        |> mes(
          "Well, I can't force you to buy these, but I'm telling you that you're passing up a real bargain!"
        )
        |> close()

      _ ->
        small_talk(ctx)
    end
  end
end
