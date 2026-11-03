defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuMerchant.Kellion do
  @moduledoc """
  Kellion, a Prontera vendor who sells Red Potions to Merchant trainees.

  ## Behavior

  - During the Merchant price-research task (quest step 6, 7 or 8) sells 10 Red Potions
    for 400, 390 and 340 Zeny respectively; buying sets the quest step to 9 for the fair
    cheapest offer or to 10 when the player overpaid or was scammed.
  - Refuses the sale when the player lacks the Zeny or the weight room.
  - Outside the task, he shares a rumor about deaths in the royal family.

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
    spawn: [
      %{map: "prontera", x: 93, y: 330, dir: 3, sprite: 97, name: "Kellion", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Kellion]")

    case get_char_var(ctx, :tu_merchant, 0) do
      6 -> sell_potions(ctx, 400, 10)
      7 -> sell_potions(ctx, 390, 9)
      8 -> sell_potions(ctx, 340, 10)
      _ -> small_talk(ctx)
    end
  end

  defp small_talk(ctx) do
    ctx
    |> mes("Recently, I hear that something")
    |> mes("has happened to the royal family.")
    |> next()
    |> mes("[Kellion]")
    |> mes(
      "It's probably not even a reliable rumor, but I've heard that members of the royal family have been dying from some unknown cause."
    )
    |> next()
    |> mes("[Kellion]")
    |> mes("Huh.")
    |> mes("Now that's some morbid news!")
    |> mes("Well, hopefully, there's no truth to it whatsoever. None at all...")
    |> close()
  end

  defp sell_potions(ctx, cost, next_step) do
    {ctx, choice} =
      ctx
      |> mes("I'm selling sets of")
      |> mes("10 Red Potions for #{cost} Zeny.")
      |> mes("Would you like some?")
      |> next()
      |> select(["Buy", "Cancel"])

    case choice do
      1 ->
        ctx =
          ctx
          |> mes("[Kellion]")
          |> mes("Good choice~")
          |> mes("Thank you for")
          |> mes("using my shop.")

        cond do
          zeny(ctx) < cost ->
            ctx
            |> next()
            |> mes("[Kellion]")
            |> mes("Ooops!")
            |> mes(
              "I'm sorry, but you don't have enough Zeny. I've got to stay in business somehow, you know?"
            )
            |> close()

          get_char_var(ctx, :MaxWeight, 0) - weight(ctx) < 71 ->
            ctx
            |> next()
            |> mes("[Kellion]")
            |> mes("...Huh?")
            |> mes(
              "You better put some of your stuff in Kafra Storage, you can't carry much else!"
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
        |> mes("[Kellion]")
        |> mes("Well, I'm sorry")
        |> mes("to hear that. But")
        |> mes("I guess I'll see")
        |> mes("you later.")
        |> close()

      _ ->
        small_talk(ctx)
    end
  end
end
