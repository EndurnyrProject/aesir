defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.M11.Merchant.GuildStaff do
  @moduledoc """
  Receives the Geffen delivery for Merchant License applicants.

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
        map: "geffen_in",
        x: 155,
        y: 122,
        dir: 4,
        sprite: 47,
        name: "Guild Staff",
        scope: :pre_renewal,
        unique_name: "Guild Staff#mer"
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
           get_char_var(ctx, :job_merchant_q2, 0) == 4) or
          get_char_var(ctx, :job_merchant_q2, 0) == 3 ->
        ctx
        |> mes("[Guild Staff]")
        |> mes("Hello,")
        |> mes("Merchant Guildsman~")
        |> mes("I give you my thanks.")
        |> close()

      true ->
        ctx
        |> mes("[Guild Staff]")
        |> mes(
          "My package should have arrived by now. Huh. I guess the Merchant Guild might be running a little late..."
        )
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp receive_delivery(ctx) do
    ctx =
      ctx
      |> mes("[Guild Staff]")
      |> mes(
        "Ah, you must be with the Merchant Guild. Finally, my package has arrived! Alright...!"
      )
      |> next()
      |> mes("[Guild Staff]")

    if count_item(ctx, 1081) == 1 or count_item(ctx, 1082) == 1 or count_item(ctx, 1091) == 1 do
      ctx
      |> mes("You must be very tired")
      |> mes("from having to travel")
      |> mes("in this kind")
      |> mes("of weather...")
      |> check_serial_number()
    else
      ctx |> mes("Wait...") |> mes("Where's the") |> mes("package?") |> close()
    end
  end

  defp check_serial_number(ctx) do
    ctx =
      ctx
      |> next()
      |> mes("[Guild Staff]")
      |> mes("Alright, let me")
      |> mes("check the Serial Number...")

    cond do
      get_char_var(ctx, :job_merchant_q2, 0) == 3 and count_item(ctx, 1081) != 0 ->
        ctx
        |> mes("2989396. Yes, this is what we ordered. Here is your receipt.")
        |> delitem(1081, 1)
        |> give_item(1075, 1)
        |> complete_delivery()

      get_char_var(ctx, :job_merchant_q2, 0) == 4 and count_item(ctx, 1082) != 0 ->
        ctx
        |> mes("2191737. Yes, this is what we ordered. Here is your receipt.")
        |> delitem(1082, 1)
        |> give_item(1076, 1)
        |> complete_delivery()

      true ->
        ctx =
          ctx
          |> mes("Uh oh, this is the wrong number. This isn't what we ordered...")
          |> next()
          |> mes("[Guild Staff]")

        cond do
          get_char_var(ctx, :job_merchant_q2, 0) == 3 ->
            ctx |> mes("The Serial Number") |> mes("should be 2989396.")

          get_char_var(ctx, :job_merchant_q2, 0) == 4 ->
            ctx |> mes("The Serial Number") |> mes("should be 2191737.")

          true ->
            ctx
            |> mes("The Serial Number")
            |> mes("should be 2989396")
            |> mes("or 2191737, one of")
            |> mes("those two.")
        end
        |> mes("Look here!")
        |> mes("Don't you see")
        |> mes("something")
        |> mes("is wrong?")
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
    |> mes("[Guild Staff]")
    |> mes("Heh heh~")
    |> mes("Thank you!")
    |> mes("Bye bye!")
    |> close()
  end
end
