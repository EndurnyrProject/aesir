defmodule Aesir.ZoneServer.Content.Npc.Cities.Aldebaran.KafraService do
  @moduledoc """
  Refunds obsolete Kafra Passes and welcomes visitors to Kafra headquarters.

  ## Behavior

  - Offers 2,000 zeny for each Kafra Pass held when the refund begins.
  - Rechecks that at least one pass remains before deleting all current passes and issuing the cached refund.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "aldeba_in",
        x: 84,
        y: 166,
        dir: 4,
        sprite: 117,
        name: "Kafra Service",
        scope: :shared,
        unique_name: "Kafra Service#alde"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("kafra_01", 2)
      |> mes("[Kafra Pavianne]")
      |> mes("Welcome! I'm Pavianne,")
      |> mes(
        "one of the senior Kafra Employees. The Kafra Corporation Service is always trying to satisfy 100 % of our customers' expectations."
      )
      |> next()
      |> mes("[Kafra Pavianne]")
      |> mes(
        "Due to a change in customer support policy, we no longer accept Kafra Passes. However, we are offering refunds for our customers who still possess these passes."
      )
      |> next()
      |> select(["Sell Kafra Pass", "Alright, bye~"])

    if choice == 1 do
      offer_refund(ctx)
    else
      farewell(ctx)
    end
  end

  defp offer_refund(ctx) do
    pass_count = count_item(ctx, 1084)

    if pass_count == 0 do
      no_passes(ctx)
    else
      refund = pass_count * 2000

      ctx
      |> describe_refund(refund)
      |> confirm_refund(refund)
    end
  end

  defp describe_refund(ctx, refund) do
    ctx =
      ctx
      |> mes("[Kafra Pavianne]")
      |> mes("Let's see...")

    if count_item(ctx, 1084) == 1 do
      ctx
      |> mes("You have 1 Kafra Pass.")
      |> mes(
        "You can sell that pass to us for 2000 zeny. Would you like to sell this Kafra Pass back to the Kafra Corporation?"
      )
    else
      ctx
      |> mes("You have #{count_item(ctx, 1084)} Kafra Passes.")
      |> mes(
        "If you want to sell them to us, you will receive #{refund} zeny. Would you like to sell these back to the Kafra Corporation?"
      )
    end
  end

  defp confirm_refund(ctx, refund) do
    {ctx, choice} = ctx |> next() |> select(["Yes", "No"])

    if choice == 1 do
      refund_passes(ctx, refund)
    else
      ctx |> close() |> cutin("", 255)
    end
  end

  defp refund_passes(ctx, refund) do
    if count_item(ctx, 1084) == 0 do
      ctx
      |> mes("[Kafra Pavianne]")
      |> mes("I'm sorry, but you don't have any Kafra Passes.")
      |> close()
      |> cutin("", 255)
    else
      ctx
      |> delitem(1084, count_item(ctx, 1084))
      |> credit_zeny(refund)
      |> mes("[Kafra Pavianne]")
      |> mes("Thank you.")
      |> close()
      |> cutin("", 255)
    end
  end

  defp no_passes(ctx) do
    ctx
    |> mes("[Kafra Pavianne]")
    |> mes("I'm sorry,")
    |> mes("but you don't")
    |> mes("have any Kafra Passes.")
    |> close()
    |> cutin("", 255)
  end

  defp farewell(ctx) do
    ctx
    |> mes("[Kafra Pavianne]")
    |> mes("Thank you,")
    |> mes("have a good day.")
    |> close()
    |> cutin("", 255)
  end
end
