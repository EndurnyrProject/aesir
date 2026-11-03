defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuMerchant.Aigie do
  @moduledoc """
  Aigie, a young street vendor in Prontera who sells Red Potions to Merchant trainees.

  ## Behavior

  - During the Merchant price-research task (quest step 6, 7 or 8) sells 10 Red Potions
    for 340, 420 and 390 Zeny respectively; buying sets the quest step to 9 for the fair
    cheapest offer or to 10 when the player overpaid or was scammed.
  - Refuses the sale when the player lacks the Zeny or the weight room.
  - Outside the task, she muses that money is more dependable than people.

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
    spawn: [%{map: "prt_in", x: 169, y: 11, dir: 3, sprite: 92, name: "Aigie", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Aigie]")

    case get_char_var(ctx, :tu_merchant, 0) do
      6 -> sell_potions(ctx, 340, 10)
      7 -> sell_potions(ctx, 420, 10)
      8 -> sell_potions(ctx, 390, 9)
      _ -> small_talk(ctx)
    end
  end

  defp small_talk(ctx) do
    ctx
    |> mes(
      "It's true that money isn't everything. I'm sure other things are important to have in order to be happy."
    )
    |> next()
    |> mes("[Aigie]")
    |> mes(
      "However, money can be much more dependable than some people I know. You can rely on money more than anything else in this world."
    )
    |> close()
  end

  defp sell_potions(ctx, cost, next_step) do
    {ctx, choice} =
      ctx
      |> mes("Welcome to my shop.")
      |> mes(
        "I'm just a young girl who's a victim of circumstance, forced to sell potions on the street for dirt cheap prices."
      )
      |> next()
      |> mes("[Aigie]")
      |> mes("Would you like")
      |> mes("to buy 10 Red Potions")
      |> mes("for #{cost} Zeny, kind adventurer?")
      |> next()
      |> select(["Buy", "Cancel"])

    case choice do
      1 ->
        ctx =
          ctx
          |> mes("[Aigie]")
          |> mes("Thank you so much.")
          |> mes("Now I can finally")
          |> mes("afford food again...")

        cond do
          zeny(ctx) < cost ->
            ctx
            |> next()
            |> mes("[Aigie]")
            |> mes("Wait, wait!")
            |> mes(
              "I am sorry, but you don't have enough money. Would you please get some more Zeny before coming back?"
            )
            |> close()

          get_char_var(ctx, :MaxWeight, 0) - weight(ctx) < 71 ->
            ctx
            |> next()
            |> mes("[Aigie]")
            |> mes("Wait, wait!")
            |> mes(
              "You can't possibly carry any more items. Why don't you put your things in Kafra Storage first?"
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
        |> mes("[Aigie]")
        |> mes("I understand.")
        |> mes("But I hope you")
        |> mes("see that I'm offering")
        |> mes("you a really good price.")
        |> mes("^666666*Sniff Sniff*^000000")
        |> close()

      _ ->
        small_talk(ctx)
    end
  end
end
