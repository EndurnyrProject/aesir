defmodule Aesir.ZoneServer.Content.Npc.PreRe.Functions.FMerckafra do
  @moduledoc """
  Receives the Merchant Guild delivery at the Alberta Kafra.

  ## Behavior

  A merchant carrying a delivery box for the Kafra hears the serial number checked against the
  order, hands the box over and receives the matching voucher. Delivering the Merchant Guild
  letter from Mahnsoo then earns three Bananas. Other quest states, a missing or wrong box, and
  completed deliveries each get their own response.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - kobra_k88

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script pre-re/jobs/1-1/merchant.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Script.Ctx

  @boxes [1081, 1082, 1091]
  @box_one 1081
  @box_two 1082
  @voucher_one 1079
  @voucher_two 1080
  @letter 1072
  @bananas 513

  @doc "Callable rAthena global function `F_MercKafra`; returns `{ctx, nil}`."
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), nil} | no_return()
  def call(ctx, _args) do
    quest = get_char_var(ctx, :job_merchant_q, 0)
    step = get_char_var(ctx, :job_merchant_q2, 0)

    cond do
      quest in [5, 6] and step in [7, 8] -> halt(already_delivered(ctx))
      quest in [3, 4] -> halt(deliver(ctx, quest, step))
      true -> {ctx, nil}
    end
  end

  defp already_delivered(ctx) do
    ctx
    |> mes("[Kafra Employee]")
    |> mes("Oh hello~")
    |> mes("Um, is there")
    |> mes("some special reason")
    |> mes("as to why you're here?")
    |> close()
    |> cutin("", 255)
  end

  defp deliver(ctx, quest, step) do
    ctx
    |> mes("[Kafra Employee]")
    |> mes("A delivery from")
    |> mes("the Merchant Guild?")
    |> mes("Oh, yes, please set")
    |> mes("it down right over there...")
    |> check_package()
    |> next()
    |> mes("[Kafra Employee]")
    |> mes("Now, let me check")
    |> mes("the serial number...")
    |> check_serial(step)
    |> advance_quest(quest)
    |> next()
    |> hand_letter()
    |> close()
    |> cutin("", 255)
  end

  defp check_package(ctx) do
    if Enum.any?(@boxes, &(count_item(ctx, &1) == 1)) do
      ctx
      |> mes("You must be really tired")
      |> mes("after carrying it for so long!")
    else
      ctx
      |> mes("W-wait. Didn't you bring it?")
      |> mes("Where's the package?")
      |> close()
      |> cutin("", 255)
      |> halt()
    end
  end

  defp check_serial(ctx, 7) do
    if count_item(ctx, @box_one) != 0 do
      take_delivery(ctx, @box_one, "3318702", @voucher_one)
    else
      wrong_package(ctx, "ordered had the serial number 3318702. I'm sure it's not this.")
    end
  end

  defp check_serial(ctx, 8) do
    if count_item(ctx, @box_two) != 0 do
      take_delivery(ctx, @box_two, "3543625", @voucher_two)
    else
      wrong_package(ctx, "ordered had the serial number 3543625. I'm sure it's not this.")
    end
  end

  defp check_serial(ctx, _step) do
    wrong_package(ctx, "ordered had the serial number 3318702 or 3543625.")
  end

  defp take_delivery(ctx, box, serial, voucher) do
    ctx
    |> mes("#{serial}. Right, this is")
    |> mes("the one we ordered. Oh,")
    |> mes("and don't forget this receipt!")
    |> delitem(box, 1)
    |> give_item(voucher, 1)
  end

  defp wrong_package(ctx, detail) do
    ctx
    |> mes("Mmmm? Hold on. This is")
    |> mes("the wrong package. What we")
    |> mes(detail)
    |> close()
    |> cutin("", 255)
    |> halt()
  end

  defp advance_quest(ctx, 4), do: set_char_var(ctx, :job_merchant_q, 6)
  defp advance_quest(ctx, 3), do: set_char_var(ctx, :job_merchant_q, 5)
  defp advance_quest(ctx, _quest), do: ctx

  defp hand_letter(ctx) do
    if count_item(ctx, @letter) != 0 and get_char_var(ctx, :quest_alb_01, 0) == 0 do
      {ctx, _choice} = select(ctx, ["This is from Chief Mahnsoo of the Merchant Guild..."])

      ctx
      |> delitem(@letter, 1)
      |> set_char_var(:quest_alb_01, 1)
      |> mes("[Kafra Employee]")
      |> mes("Oh~! A letter from")
      |> mes("Mahnsoo! Thank you")
      |> mes("so much, I've been dying")
      |> mes("to hear from him. How is")
      |> mes("he doing, is he alright?")
      |> mes("I can't wait to read it...")
      |> next()
      |> mes("[Kafra Employee]")
      |> mes("Oh, thank you for")
      |> mes("going through all the")
      |> mes("trouble of delivering all")
      |> mes("of this. This isn't anything")
      |> mes("special, but please take it.")
      |> mes("Well, see you again~")
      |> give_item(@bananas, 3)
    else
      ctx
      |> mes("[Kafra Employee]")
      |> mes("Thanks again")
      |> mes("for going through")
      |> mes("all of that trouble~")
    end
  end

  defp halt(ctx), do: throw({:script_end, ctx})
end
