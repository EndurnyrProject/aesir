defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.M11.Merchant.Student do
  @moduledoc """
  Receives the dyemaker's delivery for Merchant License applicants.

  ## Behavior

  - Exchanges the correct package for a receipt and advances the delivery record.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script pre-re/jobs/1-1/merchant.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "morocc_in",
        x: 140,
        y: 102,
        dir: 4,
        sprite: 86,
        name: "Student",
        scope: :pre_renewal,
        unique_name: "Student#mer"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :job_merchant_q, 0) == 4 or get_char_var(ctx, :job_merchant_q, 0) == 3 ->
        receive_delivery(ctx)

      get_char_var(ctx, :job_merchant_q, 0) == 6 or
        (get_char_var(ctx, :job_merchant_q, 0) == 5 and
           get_char_var(ctx, :job_merchant_q2, 0) == 6) or
          get_char_var(ctx, :job_merchant_q2, 0) == 5 ->
        ctx
        |> mes("[Dyer's Student]")
        |> mes("Oh...")
        |> mes("You're gonna")
        |> mes("go back? Okay")
        |> mes("then, take care!")
        |> close()

      true ->
        ctx
        |> mes("[Dyer's Student]")
        |> mes(
          "Mr. Java Dullihan is the one and only, the best dye maker on the Midgard continent."
        )
        |> next()
        |> mes("[Dyer's Student]")
        |> mes(
          "Aaaand I'm proud to say that I'm his student! Someday, I'll be able to make really beautiful dyes too!"
        )
        |> next()
        |> mes("[Dyer's Student]")
        |> mes("Of course, I'm still learning the basics right now, but someday...")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp receive_delivery(ctx) do
    ctx =
      ctx
      |> mes("[Dyer's Student]")
      |> mes("You're from")
      |> mes("the Merchant Guild?")
      |> mes("Yes! You've come to")
      |> mes("the right place.")
      |> next()
      |> mes("[Dyer's Student]")

    if count_item(ctx, 1081) == 1 or count_item(ctx, 1082) == 1 or count_item(ctx, 1091) == 1 do
      ctx
      |> mes("Okay~")
      |> mes("Please set the")
      |> mes("package down")
      |> mes("over there.")
      |> check_serial_number()
    else
      ctx
      |> mes("But...")
      |> mes("Where's the")
      |> mes("package I ordered?")
      |> mes("That's strange...")
      |> close()
    end
  end

  defp check_serial_number(ctx) do
    ctx =
      ctx
      |> next()
      |> mes("[Dyer's Student]")
      |> mes("Let me check the Serial Number of the package so I can give you the receipt, okay?")
      |> next()
      |> mes("[Dyer's Student]")

    cond do
      get_char_var(ctx, :job_merchant_q2, 0) == 5 and count_item(ctx, 1081) != 0 ->
        ctx
        |> mes("3012685...")
        |> mes("That's right.")
        |> mes("Here's your")
        |> mes("receipt.")
        |> delitem(1081, 1)
        |> give_item(1077, 1)
        |> complete_delivery()

      get_char_var(ctx, :job_merchant_q2, 0) == 6 and count_item(ctx, 1082) != 0 ->
        ctx
        |> mes("3487372...")
        |> mes("That's right.")
        |> mes("Here's your")
        |> mes("receipt.")
        |> delitem(1082, 1)
        |> give_item(1078, 1)
        |> complete_delivery()

      true ->
        ctx = mes(ctx, "Excuse me, but...")

        cond do
          get_char_var(ctx, :job_merchant_q2, 0) == 5 ->
            mes(
              ctx,
              "I don't think this is the package we ordered. The Serial Number should be 3012685. See?"
            )

          get_char_var(ctx, :job_merchant_q2, 0) == 6 ->
            mes(
              ctx,
              "I don't think this is the package we ordered. The Serial Number should be 3487372. See?"
            )

          true ->
            mes(
              ctx,
              "I don't think this is the package we ordered. The Serial Number should be 3012685 or 3487372. Well, one of those two..."
            )
        end
        |> close()
    end
  end

  defp complete_delivery(ctx) do
    cond do
      get_char_var(ctx, :job_merchant_q, 0) == 4 -> set_char_var(ctx, :job_merchant_q, 6)
      get_char_var(ctx, :job_merchant_q, 0) == 3 -> set_char_var(ctx, :job_merchant_q, 5)
      true -> ctx
    end
    |> next()
    |> mes("[Dyer's Student]")
    |> mes("Thanks a lot!")
    |> mes("See you again")
    |> mes("sometime!")
    |> close()
  end
end
