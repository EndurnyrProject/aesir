defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.M11.Merchant.KafraEmployee do
  @moduledoc """
  Receives Merchant License deliveries and offers travel to Izlude.

  ## Behavior

  - Exchanges the correct package for a receipt and advances the delivery record.
  - Charges 600 zeny for travel to Izlude and awards Kafra reserve points.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script pre-re/jobs/1-1/merchant.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "prontera",
        x: 248,
        y: 42,
        dir: 0,
        sprite: 116,
        name: "Kafra Employee",
        scope: :pre_renewal,
        unique_name: "Kafra Employee#mer"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = cutin(ctx, "kafra_02", 2)

    cond do
      (get_char_var(ctx, :job_merchant_q, 0) == 6 or get_char_var(ctx, :job_merchant_q, 0) == 5) and
          (get_char_var(ctx, :job_merchant_q2, 0) == 2 or
             get_char_var(ctx, :job_merchant_q2, 0) == 1) ->
        ctx
        |> mes("[Kafra Employee]")
        |> mes("Oh! Thank you for")
        |> mes("traveling such a long")
        |> mes("way to come over here~")
        |> close_dialogue()

      get_char_var(ctx, :job_merchant_q, 0) == 4 or get_char_var(ctx, :job_merchant_q, 0) == 3 ->
        receive_delivery(ctx)

      true ->
        {ctx, teleport_choice} =
          ctx
          |> mes("[Kafra Employee]")
          |> mes("Welcome to the")
          |> mes("Kafra Corportation,")
          |> mes("where the service is")
          |> mes("always on your side~")
          |> next()
          |> mes("[Kafra Employee]")
          |> mes("As you can see, the")
          |> mes("Swordman Assocation")
          |> mes("has moved to Izlude, a")
          |> mes("satellite city of Prontera.")
          |> mes("Currently, we offer a Teleport")
          |> mes("Service to Izlude for 600 zeny.")
          |> next()
          |> select(["Use", "Cancel"])

        cond do
          teleport_choice != 1 ->
            close_dialogue(ctx)

          zeny(ctx) < 600 ->
            ctx
            |> mes("[Kafra Employee]")
            |> mes("I'm sorry, but you")
            |> mes("don't have enough zeny")
            |> mes("for this Teleport Service.")
            |> close_dialogue()

          true ->
            teleport_to_izlude(ctx)
        end
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp receive_delivery(ctx) do
    ctx =
      ctx
      |> mes("[Kafra Employee]")
      |> mes("A delivery from")
      |> mes("the Merchant Guild?")
      |> mes("Oh, yes, please set")
      |> mes("it down right over there...")

    if count_item(ctx, 1081) == 1 or count_item(ctx, 1082) == 1 or count_item(ctx, 1091) == 1 do
      ctx
      |> mes("You must be really tired")
      |> mes("after carrying it for so long!")
      |> check_serial_number()
    else
      ctx
      |> mes("W-wait. Didn't you bring it?")
      |> mes("Where's the package?")
      |> close_dialogue()
    end
  end

  defp close_dialogue(ctx) do
    ctx |> close() |> cutin("", 255)
  end

  defp teleport_to_izlude(ctx) do
    ctx = pay_zeny(ctx, 600)

    ctx
    |> set_char_var(:RESRVPTS, get_char_var(ctx, :RESRVPTS, 0) + 37)
    |> cutin("", 255)
    |> warp("izlude", 94, 103)
  end

  defp check_serial_number(ctx) do
    ctx =
      ctx
      |> next()
      |> mes("[Kafra Employee]")
      |> mes("Now, let me check")
      |> mes("the serial number...")

    cond do
      get_char_var(ctx, :job_merchant_q2, 0) == 1 and count_item(ctx, 1081) != 0 ->
        ctx
        |> mes("2485741. Right, this is")
        |> mes("the one we ordered. Oh,")
        |> mes("and don't forget this receipt!")
        |> next()
        |> delitem(1081, 1)
        |> give_item(1073, 1)
        |> complete_delivery()

      get_char_var(ctx, :job_merchant_q2, 0) == 2 and count_item(ctx, 1082) != 0 ->
        ctx
        |> mes("2328137. Right, this is")
        |> mes("the one we ordered. Oh,")
        |> mes("and don't forget this receipt!")
        |> next()
        |> delitem(1082, 1)
        |> give_item(1074, 1)
        |> complete_delivery()

      true ->
        ctx = ctx |> mes("Mmmm? Hold on. This is") |> mes("the wrong package. What we")

        cond do
          get_char_var(ctx, :job_merchant_q2, 0) == 1 ->
            mes(ctx, "ordered had the serial number 2485741. I'm sure it's not this.")

          get_char_var(ctx, :job_merchant_q2, 0) == 2 ->
            mes(ctx, "ordered had the serial number 2328137. I'm sure it's not this.")

          true ->
            mes(ctx, "ordered had the serial number 2485741 or 2328137.")
        end
        |> next()
        |> mes("[Kafra Employee]")
        |> mes("I'm afraid there")
        |> mes("must be some kind")
        |> mes("of mistake. Perhaps")
        |> mes("you should go back to")
        |> mes("the Merchant Guild to")
        |> mes("clear up this situation?")
        |> close_dialogue()
    end
  end

  defp complete_delivery(ctx) do
    cond do
      get_char_var(ctx, :job_merchant_q, 0) == 4 -> set_char_var(ctx, :job_merchant_q, 6)
      get_char_var(ctx, :job_merchant_q, 0) == 3 -> set_char_var(ctx, :job_merchant_q, 5)
      true -> ctx
    end
    |> mes("[Kafra Employee]")
    |> mes("Thanks again")
    |> mes("for going through")
    |> mes("all of that trouble~")
    |> close_dialogue()
  end
end
