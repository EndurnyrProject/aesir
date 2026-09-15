defmodule Aesir.ZoneServer.Content.Npc.Cities.Alberta.Phelix do
  @moduledoc """
  Exchanges Jellopies for Red Potions or Carrots aboard Alberta's ship.

  ## Behavior

  - Introduces the exchange on the first interaction and remembers it for the session.
  - Trades ten Jellopies per Red Potion or three per Carrot.
  - Supports trading the maximum possible amount or a requested amount up to 100.

  ## Credits

  - Original from rAthena, authors and Contributors
    - DZeroX

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "alberta", x: 190, y: 173, dir: 4, sprite: 85, name: "Phelix", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Phelix]")

    cond do
      get_char_var(ctx, :MaxWeight, 0) - weight(ctx) < 10_000 ->
        reject_overloaded_visitor(ctx)

      get_temp_var(ctx, :event_zelopy, 0) == 0 ->
        introduce_exchange(ctx)

      true ->
        offer_exchange(ctx)
    end
  end

  defp reject_overloaded_visitor(ctx) do
    ctx
    |> mes("Wait a moment!!")
    |> mes("You have brought too many things!")
    |> mes("You cannot accept any more items!")
    |> mes("Please reduce the amount of items,")
    |> mes("then come see me again.")
    |> close()
  end

  defp introduce_exchange(ctx) do
    ctx
    |> mes("The hell are you doing here?")
    |> mes(
      "There is nothing you can get for free on this ship, if you want somethin', work for it!!"
    )
    |> next()
    |> mes("[Phelix]")
    |> mes(
      "Hmm, so why don't you bring me 10 Jellopies and I will give 1 potion. How's that sound?"
    )
    |> mes("Or if that's too hard for your pansy ass, 3 Jellopies for 1 Carrot.")
    |> next()
    |> mes("[Phelix]")
    |> mes("If you're interested in my offer, get me the stuff I mentioned.")
    |> set_temp_var(:event_zelopy, 1)
    |> close()
  end

  defp offer_exchange(ctx) do
    {ctx, choice} =
      ctx
      |> mes(
        "Hmm.. you want to exchange Jellopies for Red Potions or some Carrots eh? Well.. which one?"
      )
      |> next()
      |> select(["Red Potions please.", "Carrots please."])

    case choice do
      1 -> exchange_red_potions(ctx)
      2 -> exchange_carrots(ctx)
      _ -> ctx
    end
  end

  defp exchange_red_potions(ctx) do
    ctx =
      ctx
      |> mes("[Phelix]")
      |> mes("Alright...")
      |> mes("Let's see")
      |> mes("what'cha got...")
      |> next()
      |> mes("[Phelix]")

    if count_item(ctx, 909) < 10 do
      ctx
      |> mes("Hey! Weren't you listening? I said 10 Jellopies for 1 Red Potion.. are ya deaf?")
      |> close()
    else
      choose_red_potion_amount(ctx, div(count_item(ctx, 909), 10))
    end
  end

  defp choose_red_potion_amount(ctx, maximum) do
    {ctx, choice} =
      ctx
      |> mes("Hmm, not bad...")
      |> mes("How many potions")
      |> mes("do you want to get?")
      |> next()
      |> select([
        "As many as I can, please.",
        "I want this many.",
        "Never mind, I like my jellopy."
      ])

    case choice do
      1 ->
        ctx
        |> delitem(909, maximum * 10)
        |> give_item(501, maximum)
        |> finish_red_potion_exchange()

      2 ->
        request_red_potion_amount(ctx, maximum)

      3 ->
        ctx
        |> mes("[Phelix]")
        |> mes("No problem,")
        |> mes("see you next time.")
        |> close()

      _ ->
        finish_red_potion_exchange(ctx)
    end
  end

  defp request_red_potion_amount(ctx, maximum) do
    {ctx, amount} =
      ctx
      |> mes("[Phelix]")
      |> mes(
        "I'm not giving you more than 100 at a time so don't bother, OK? If you don't want any, just say '0'."
      )
      |> mes(
        "Right now, the most you can get is #{maximum} but remember, 100 at most, you want to break my back?."
      )
      |> input(:int)

    ctx =
      ctx
      |> next()
      |> mes("[Phelix]")

    cond do
      amount <= 0 ->
        ctx
        |> mes("Much obliged, come again anytime.")
        |> close()

      amount > 100 ->
        ctx
        |> mes("Hey, what'd I say? 100 at a time at most, you're trying to kill me aren't you!")
        |> close()

      count_item(ctx, 909) < amount * 10 ->
        ctx
        |> mes(
          "Hmm, it looks like you don't have enough. Go get more Jellopies if you want anything else from me."
        )
        |> close()

      true ->
        ctx
        |> delitem(909, amount * 10)
        |> give_item(501, amount)
        |> finish_red_potion_exchange()
    end
  end

  defp finish_red_potion_exchange(ctx) do
    ctx
    |> mes("[Phelix]")
    |> mes("There you go! As I promised. Don't go suckin' them all down at once.")
    |> close()
  end

  defp exchange_carrots(ctx) do
    ctx =
      ctx
      |> mes("[Phelix]")
      |> mes("Alright, let's see what ya got...")
      |> next()
      |> mes("[Phelix]")

    if count_item(ctx, 909) < 3 do
      ctx
      |> mes("Hmm, look pansy ass, I said 3 Jellopies for 1 Carrot.. got it?")
      |> close()
    else
      choose_carrot_amount(ctx, div(count_item(ctx, 909), 3))
    end
  end

  defp choose_carrot_amount(ctx, maximum) do
    {ctx, choice} =
      ctx
      |> mes("Not too bad pansy...")
      |> mes("How many do you want?")
      |> next()
      |> select([
        "As many as I can get, please",
        "I want this many.",
        "Never mind, I like my jellopy."
      ])

    case choice do
      1 ->
        ctx
        |> delitem(909, maximum * 3)
        |> give_item(515, maximum)
        |> finish_carrot_exchange()

      2 ->
        request_carrot_amount(ctx)

      3 ->
        ctx
        |> mes("[Phelix]")
        |> mes("Catch'ya later.")
        |> close()

      _ ->
        finish_carrot_exchange(ctx)
    end
  end

  defp request_carrot_amount(ctx) do
    {ctx, amount} =
      ctx
      |> mes("[Phelix]")
      |> mes(
        "Right I'm not giving you more than 100 at a time so don't bother, okay? If you don't want any, just say '0'."
      )
      |> input(:int)

    ctx =
      ctx
      |> next()
      |> mes("[Phelix]")

    cond do
      amount == 0 ->
        ctx
        |> mes("Alright then, see you next time.")
        |> close()

      amount > 100 ->
        ctx
        |> mes(
          "Hey pansy ass, I said 100 at most, no more than that! I'm not going to break my back for the likes of you!"
        )
        |> close()

      count_item(ctx, 909) < amount * 3 ->
        ctx
        |> mes("Seems you don't have enough. Go get some more if you want anything else.")
        |> close()

      true ->
        ctx
        |> delitem(909, amount * 3)
        |> give_item(515, amount)
        |> finish_carrot_exchange()
    end
  end

  defp finish_carrot_exchange(ctx) do
    ctx
    |> mes("[Phelix]")
    |> mes("There you go~! As I promised. Try not to stuff yer face.")
    |> close()
  end
end
