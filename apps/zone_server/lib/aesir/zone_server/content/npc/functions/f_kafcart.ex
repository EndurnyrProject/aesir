defmodule Aesir.ZoneServer.Content.Npc.Functions.FKafcart do
  @moduledoc """
  Rents a pushcart to a Merchant class character.

  ## Behavior

  Refuses when the character is not a Merchant, already owns a cart or has not learnt Push Cart. A
  Free Cart Ticket skips the fee; otherwise the rental is charged after confirmation and awards
  Special Reserve Points. Returns `1` when the menu should continue, `0` when it should close.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script kafras/functions_kafras.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Script.Ctx

  @pushcart_skill 39
  @cart_ticket 7061
  @reserve_points 48

  @doc """
  Callable rAthena global function `F_KafCart(welcome, fee)`; returns `1` when the dialog continues
  and `0` when the player cancelled.
  """
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), 0 | 1}
  def call(ctx, args) do
    if base_class(ctx) == :merchant do
      rent(ctx, args)
    else
      {refuse(ctx), 1}
    end
  end

  defp refuse(ctx) do
    ctx =
      ctx
      |> mes("[Kafra Employee]")
      |> mes("I'm sorry, but the")
      |> mes("Pushcart rental service")

    if checkre(ctx, 0) == 1 do
      mes(ctx, "is only available to Merchant classes.")
    else
      ctx
      |> mes("is only available to Merchants,")
      |> mes("Blacksmiths, Master Smiths,")
      |> mes("Alchemists and Biochemists.")
    end
  end

  defp rent(ctx, args) do
    cond do
      checkcart(ctx) == 1 ->
        {already_rented(ctx), 1}

      getskilllv(ctx, @pushcart_skill) == 0 ->
        {no_pushcart_skill(ctx), 1}

      true ->
        charge(ctx, args)
    end
  end

  defp already_rented(ctx) do
    ctx
    |> mes("[Kafra Employee]")
    |> mes("You already have")
    |> mes("a Pushcart equipped.")
    |> mes("Unfortunately, we can't")
    |> mes("rent more than one to")
    |> mes("each customer at a time.")
  end

  defp no_pushcart_skill(ctx) do
    ctx
    |> mes("[Kafra Employee]")
    |> mes("You can only rent a cart after learning the \"Push Cart\" skill.")
  end

  defp charge(ctx, args) do
    if count_item(ctx, @cart_ticket) > 0 and Enum.at(args, 0, 0) != 2 do
      {ctx |> delitem(@cart_ticket, 1) |> setcart(), 1}
    else
      confirm(ctx, Enum.at(args, 1, 0))
    end
  end

  defp confirm(ctx, fee) do
    ctx =
      ctx |> set_local(:rental_fee, fee) |> mes("[Kafra Employee]") |> mes("The Pushcart rental")

    ctx = ctx |> mes("fee is #{fee} zeny. Would") |> mes("you like to rent a Pushcart?")
    {ctx, choice} = ctx |> next() |> select(["Rent a Pushcart.", "Cancel"])

    cond do
      choice == 2 ->
        {ctx, 0}

      zeny(ctx) < fee ->
        {not_enough_zeny(ctx, fee), 1}

      true ->
        ctx =
          ctx
          |> pay_zeny(fee)
          |> set_char_var(:RESRVPTS, get_char_var(ctx, :RESRVPTS, 0) + @reserve_points)
          |> setcart()

        {ctx, 1}
    end
  end

  defp not_enough_zeny(ctx, fee) do
    ctx
    |> mes("[Kafra Employee]")
    |> mes("I'm sorry, but you")
    |> mes("don't have enough")
    |> mes("zeny to pay the Pushcart")
    |> mes("rental fee of #{fee} zeny.")
  end
end
