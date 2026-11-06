defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.M11.Merchant.MerchantGuildsman do
  @moduledoc """
  Manages packages and receipts for the Merchant License test.

  ## Behavior

  - Issues packages after applicants choose a destination and confirm a serial number.
  - Records lost packages, cancels delivery records, and checks returned receipts.

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
        map: "alberta_in",
        x: 28,
        y: 29,
        dir: 2,
        sprite: 83,
        name: "Merchant Guildsman",
        scope: :pre_renewal,
        unique_name: "Merchant Guildsman#mer"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:merchant) ->
        ctx |> mes("[Union Staff Kay]") |> mes("Heya pal.") |> mes("How ya doin'?") |> close()

      Rathena.job_id(base_job(ctx)) != Rathena.job_id(:merchant) and
          Rathena.job_id(base_job(ctx)) != Rathena.job_id(:novice) ->
        ctx
        |> mes("[Union Staff Kay]")
        |> mes(
          "Hey you. We don't have any open positions for part time work. If you wanna earn some zeny, you'll hafta look elsewhere."
        )
        |> close()

      get_char_var(ctx, :job_merchant_q, 0) == 9 ->
        ctx
        |> mes("[Union Staff Kay]")
        |> mes("Hey you. Yeah, you.")
        |> mes(
          "If you wanna restart the test, go visit Mahnsoo in the other room. Then we can talk."
        )
        |> close()

      get_char_var(ctx, :job_merchant_q, 0) == 8 or get_char_var(ctx, :job_merchant_q, 0) == 7 ->
        ctx
        |> mes("[Union Staff Kay]")
        |> mes(
          "Alright! Everything looks perfect! I'll report your success to the guildmaster. Now go talk to Chief Mahnsoo, yeah?"
        )
        |> close()

      get_char_var(ctx, :job_merchant_q, 0) == 6 or get_char_var(ctx, :job_merchant_q, 0) == 5 ->
        accept_receipt(ctx)

      get_char_var(ctx, :job_merchant_q, 0) == 4 or
          (get_char_var(ctx, :job_merchant_q, 0) == 3 and count_item(ctx, 1081) == 0 and
             count_item(ctx, 1082) == 0 and count_item(ctx, 1091) == 0) ->
        ask_about_delivery(ctx)

      get_char_var(ctx, :job_merchant_q, 0) == 4 or
        (get_char_var(ctx, :job_merchant_q, 0) == 3 and count_item(ctx, 1081) != 0) or
        count_item(ctx, 1082) != 0 or count_item(ctx, 1091) != 0 ->
        offer_replacement(ctx)

      get_char_var(ctx, :job_merchant_q, 0) == 0 or get_char_var(ctx, :job_merchant_q, 0) == 1 or
          get_char_var(ctx, :job_merchant_q, 0) == 2 ->
        offer_storehouse_services(ctx)

      true ->
        ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp accept_receipt(ctx) do
    ctx = mes(ctx, " [Union Staff Kay] ")

    ctx =
      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat(
            "Oh, yeah? Okay, lemme check. Your name is ",
            char_name(ctx, 0)
          ),
          "? Alright, your destination was..."
        )
      )
      |> next()
      |> mes("[Union Staff Kay]")

    ctx =
      cond do
        get_char_var(ctx, :job_merchant_q2, 0) == 1 or get_char_var(ctx, :job_merchant_q2, 0) == 2 ->
          mes(
            ctx,
            "Wow! You met the Kafra babe in Prontera?! Lucky you~ ...Receipt?"
          )

        get_char_var(ctx, :job_merchant_q2, 0) == 3 or get_char_var(ctx, :job_merchant_q2, 0) == 4 ->
          mes(ctx, "Geffen Magic Academy. Okay, receipt?")

        get_char_var(ctx, :job_merchant_q2, 0) == 5 or get_char_var(ctx, :job_merchant_q2, 0) == 6 ->
          mes(ctx, "The dyemaker in Morocc. Not bad. Receipt?")

        get_char_var(ctx, :job_merchant_q2, 0) == 7 or get_char_var(ctx, :job_merchant_q2, 0) == 8 ->
          mes(
            ctx,
            "Oh hohohoho~! The Kafra Babe on Byalan Island?! Awesome! Anyway, did you bring the receipt?"
          )

        true ->
          ctx
      end

    cond do
      get_char_var(ctx, :job_merchant_q2, 0) == 1 and count_item(ctx, 1073) != 0 ->
        ctx |> delitem(1073, 1) |> complete_test()

      get_char_var(ctx, :job_merchant_q2, 0) == 2 and count_item(ctx, 1074) != 0 ->
        ctx |> delitem(1074, 1) |> complete_test()

      get_char_var(ctx, :job_merchant_q2, 0) == 3 and count_item(ctx, 1075) != 0 ->
        ctx |> delitem(1075, 1) |> complete_test()

      get_char_var(ctx, :job_merchant_q2, 0) == 4 and count_item(ctx, 1076) != 0 ->
        ctx |> delitem(1076, 1) |> complete_test()

      get_char_var(ctx, :job_merchant_q2, 0) == 5 and count_item(ctx, 1077) != 0 ->
        ctx |> delitem(1077, 1) |> complete_test()

      get_char_var(ctx, :job_merchant_q2, 0) == 6 and count_item(ctx, 1078) != 0 ->
        ctx |> delitem(1078, 1) |> complete_test()

      get_char_var(ctx, :job_merchant_q2, 0) == 7 and count_item(ctx, 1079) != 0 ->
        ctx |> delitem(1079, 1) |> complete_test()

      get_char_var(ctx, :job_merchant_q2, 0) == 8 and count_item(ctx, 1080) != 0 ->
        ctx |> delitem(1080, 1) |> complete_test()

      true ->
        ctx
        |> next()
        |> set_char_var(:job_merchant_q, 9)
        |> mes(" [Union Staff Kay] ")
        |> mes("Wait a sec.")
        |> mes("Where's the receipt?")
        |> mes("What happened?")
        |> next()
        |> mes(" [Union Staff Kay] ")
        |> mes(
          "If you don't have the receipt, you fail the test! You better talk to Mahnsoo if you wanna retake it, alright? Pay attention next time!"
        )
        |> close()
    end
  end

  defp ask_about_delivery(ctx) do
    {ctx, delivery_choice} =
      ctx
      |> mes(" [Union Staff Kay] ")
      |> mes("Huh?")
      |> mes("You're back?")
      |> mes("So how did")
      |> mes("the delivery go?")
      |> next()
      |> select(["*Sob* I lost the package.", "Fine."])

    if delivery_choice == 1 do
      ctx
      |> set_char_var(:job_merchant_q, 9)
      |> mes("[Union Staff Kay]")
      |> mes("Are you kidding me? You'll fail the test if you lose the package!")
      |> next()
      |> mes("[Union Staff Kay]")
      |> mes(
        "Awwww man. Well, if you wanna restart the test, talk to Mahnsoo, okay? You're lucky you're getting another chance!"
      )
      |> close()
    else
      acknowledge_delivery(ctx)
    end
  end

  defp offer_replacement(ctx) do
    {ctx, replacement_choice} =
      ctx
      |> mes("[Union Staff Kay]")
      |> mes("Hey, what are you still doing here? Shouldn't you be on your way already?")
      |> next()
      |> select(["I need a new package.", "Oh, yeah. You're right!"])

    if replacement_choice == 1 do
      if count_item(ctx, 1081) == 0 and count_item(ctx, 1082) == 0 and count_item(ctx, 1083) == 0 and
           count_item(ctx, 1091) == 0 do
        {ctx, missing_package_choice} =
          ctx
          |> mes("[Union Staff Kay]")
          |> mes("Wha--?")
          |> mes("So where did")
          |> mes("the package go?")
          |> mes("Where is it?!")
          |> next()
          |> select(["*Sob* I lost it!", "I have it right here."])

        if missing_package_choice == 1 do
          ctx
          |> set_char_var(:job_merchant_q, 9)
          |> mes("[Union Staff Kay]")
          |> mes("You...")
          |> mes("Lost it?!")
          |> mes("You failed the test!")
          |> next()
          |> mes("[Union Staff Kay]")
          |> mes(
            "*Sigh* If you want to restart the test, go visit Mahnsoo in the other room, alright?"
          )
          |> close()
        else
          keep_existing_package(ctx)
        end
      else
        cancel_delivery_record(ctx)
      end
    else
      decline_replacement(ctx)
    end
  end

  defp offer_storehouse_services(ctx) do
    {ctx, service_choice} =
      ctx
      |> set_char_var(:where_village, 0)
      |> mes("[Union Staff Kay]")
      |> mes("Hey there.")
      |> mes("what brings")
      |> mes("you here?")
      |> next()
      |> select(["My Merchant License test.", "I'm looking for part time work.", "Nothing."])

    case service_choice do
      1 ->
        ctx =
          ctx
          |> mes("[Union Staff Kay]")
          |> mes("I see.")
          |> mes("Alright.")
          |> mes("So what's")
          |> mes("your name?")

        ctx =
          ctx
          |> mes(
            Rathena.concat(
              Rathena.concat("", char_name(ctx, 0)),
              "...?"
            )
          )
          |> next()

        if get_char_var(ctx, :job_merchant_q, 0) == 0 do
          ctx
          |> mes("[Union Staff Kay]")
          |> mes(
            "Huh. Your name's not on my list. Did you apply for the job change quest or what?"
          )
          |> next()
          |> mes("[Union Staff Kay]")
          |> mes("You gotta apply first by talking to Chief Mahnsoo in the center")
          |> mes("of this building, okay?")
          |> close()
        else
          issue_package(ctx)
        end

      2 ->
        ctx
        |> mes("[Union Staff Kay]")
        |> mes(
          "Part time job? Sorry pal, no jobs yet. The Paymaster's department can never balance our budget..."
        )
        |> close()

      3 ->
        ctx
        |> mes("[Union Staff Kay]")
        |> mes("Nothing, eh?")
        |> mes("I guess you enjoy")
        |> mes("bothering people for")
        |> mes("no reason then, yeah?")
        |> close()

      _ ->
        ctx
    end
  end

  defp input_serial_number(ctx) do
    {ctx, serial_number} = input(ctx, :int)
    ctx = set_local(ctx, :input, serial_number)

    cond do
      get_local(ctx, :input, 0) == 0 ->
        {ctx, cancellation_choice} =
          ctx
          |> mes("[Union Staff Kay]")
          |> mes("Are you sure that you wanna cancel?")
          |> select(["Yes.", "Let me try again."])

        if cancellation_choice == 1 do
          ctx = ctx |> mes("Alright, we'll cancel for now.") |> close()
          throw({:script_end, ctx})
        else
          ctx |> next() |> input_serial_number()
        end

      get_local(ctx, :input, 0) < 1_000_000 or get_local(ctx, :input, 0) > 5_000_000 ->
        ctx
        |> mes("[Union Staff Kay]")
        |> mes("Hey hey. That number's not valid! Enter a value from 1000000 to 5000000. got it?")
        |> next()
        |> input_serial_number()

      true ->
        ctx
    end
  end

  defp confirm_serial_number(ctx) do
    ctx = ctx |> input_serial_number() |> mes("[Union Staff Kay]")

    {ctx, confirmation_choice} =
      cond do
        get_local(ctx, :where_village, 0) == 1 ->
          mes(
            ctx,
            Rathena.concat(
              Rathena.concat(
                "Destination is Prontera. The Serial Number is ",
                get_local(ctx, :input, 0)
              ),
              ". Are you positive?"
            )
          )

        get_local(ctx, :where_village, 0) == 2 ->
          mes(
            ctx,
            Rathena.concat(
              Rathena.concat(
                "Destination is Geffen. Phew! That's really far! The Serial Number is ",
                get_local(ctx, :input, 0)
              ),
              ". Are you positive?"
            )
          )

        get_local(ctx, :where_village, 0) == 3 ->
          mes(
            ctx,
            Rathena.concat(
              Rathena.concat(
                "Destination is Morocc. That's pretty far away! The Serial Number is ",
                get_local(ctx, :input, 0)
              ),
              ". Are you positive?"
            )
          )

        true ->
          mes(
            ctx,
            Rathena.concat(
              Rathena.concat(
                "Lucky you! Your destination is Byalan Island. The Serial Number is ",
                get_local(ctx, :input, 0)
              ),
              ". Are you positive?"
            )
          )
      end
      |> next()
      |> select(["Positive.", "Whoops! Wrong number!"])

    if confirmation_choice == 1 do
      ctx
    else
      confirm_serial_number(ctx)
    end
  end

  defp complete_test(ctx) do
    ctx =
      ctx
      |> next()
      |> mes(" [Union Staff Kay] ")
      |> mes(
        "...Great! Everything's perfect! I'll report your success to the Guildmaster. You should talk to Chief Mahnsoo now, alright?"
      )
      |> close()

    cond do
      get_char_var(ctx, :job_merchant_q, 0) == 6 -> set_char_var(ctx, :job_merchant_q, 8)
      get_char_var(ctx, :job_merchant_q, 0) == 5 -> set_char_var(ctx, :job_merchant_q, 7)
      true -> ctx
    end
  end

  defp acknowledge_delivery(ctx) do
    ctx |> mes("[Union Staff Kay]") |> mes("Huh...") |> mes("Okay...") |> close()
  end

  defp decline_replacement(ctx) do
    ctx |> mes("[Union Staff Kay]") |> mes("What a bummer...") |> close()
  end

  defp cancel_delivery_record(ctx) do
    ctx =
      ctx
      |> mes("[Union Staff Kay]")
      |> mes(
        "*Sigh* Man, you're starting to become a pain in the ass. Hold on, lemme cancel your record..."
      )

    ctx =
      cond do
        count_item(ctx, 1081) != 0 -> delitem(ctx, 1081, 1)
        count_item(ctx, 1082) != 0 -> delitem(ctx, 1082, 1)
        count_item(ctx, 1091) != 0 -> delitem(ctx, 1091, 1)
        true -> ctx
      end

    cond do
      get_char_var(ctx, :job_merchant_q, 0) == 4 -> set_char_var(ctx, :job_merchant_q, 2)
      get_char_var(ctx, :job_merchant_q, 0) == 3 -> set_char_var(ctx, :job_merchant_q, 1)
      true -> ctx
    end
    |> next()
    |> mes("[Union Staff Kay]")
    |> mes("I need some time to get everything in order, so come back later.")
    |> close()
  end

  defp keep_existing_package(ctx) do
    ctx
    |> mes("[Union Staff Kay]")
    |> mes("Huh.")
    |> mes("I thought")
    |> mes("you lost it.")
    |> mes("You don't")
    |> mes("need a new one.")
    |> close()
  end

  defp issue_package(ctx) do
    {ctx, destination_choice} =
      ctx
      |> mes("[Union Staff Kay]")
      |> mes(
        "Alright, there you go. Lemme give you the package. Now, choose the destination of the delivery."
      )
      |> next()
      |> select(["Prontera.", "Geffen.", "Morocc.", "Byalan Island."])

    ctx =
      case destination_choice do
        1 -> set_local(ctx, :where_village, 1)
        2 -> set_local(ctx, :where_village, 2)
        3 -> set_local(ctx, :where_village, 3)
        4 -> set_local(ctx, :where_village, 4)
        _ -> ctx
      end
      |> mes("[Union Staff Kay]")
      |> mes(
        "Okay, now you need to give me the package's Serial Number. If you wanna cancel, just enter '0', alright?"
      )
      |> next()
      |> confirm_serial_number()

    ctx =
      cond do
        get_local(ctx, :where_village, 0) == 1 ->
          cond do
            get_char_var(ctx, :job_merchant_q2, 0) == 1 and get_local(ctx, :input, 0) == 2_485_741 ->
              give_item(ctx, 1081, 1)

            get_char_var(ctx, :job_merchant_q2, 0) == 2 and get_local(ctx, :input, 0) == 2_328_137 ->
              give_item(ctx, 1082, 1)

            true ->
              give_item(ctx, 1091, 1)
          end

        get_local(ctx, :where_village, 0) == 2 ->
          cond do
            get_char_var(ctx, :job_merchant_q2, 0) == 3 and get_local(ctx, :input, 0) == 2_989_396 ->
              give_item(ctx, 1081, 1)

            get_char_var(ctx, :job_merchant_q2, 0) == 4 and get_local(ctx, :input, 0) == 2_191_737 ->
              give_item(ctx, 1082, 1)

            true ->
              give_item(ctx, 1091, 1)
          end

        get_local(ctx, :where_village, 0) == 3 ->
          cond do
            get_char_var(ctx, :job_merchant_q2, 0) == 5 and get_local(ctx, :input, 0) == 3_012_685 ->
              give_item(ctx, 1081, 1)

            get_char_var(ctx, :job_merchant_q2, 0) == 6 and get_local(ctx, :input, 0) == 3_487_372 ->
              give_item(ctx, 1082, 1)

            true ->
              give_item(ctx, 1091, 1)
          end

        get_char_var(ctx, :job_merchant_q2, 0) == 7 and get_local(ctx, :input, 0) == 3_318_702 ->
          give_item(ctx, 1081, 1)

        get_char_var(ctx, :job_merchant_q2, 0) == 8 and get_local(ctx, :input, 0) == 3_543_625 ->
          give_item(ctx, 1082, 1)

        true ->
          give_item(ctx, 1091, 1)
      end

    cond do
      get_char_var(ctx, :job_merchant_q, 0) == 2 -> set_char_var(ctx, :job_merchant_q, 4)
      get_char_var(ctx, :job_merchant_q, 0) == 1 -> set_char_var(ctx, :job_merchant_q, 3)
      true -> ctx
    end
    |> mes("[Union Staff Kay]")
    |> mes(
      "Alright. Take this package and guard it with your life until it's safely delivered to the customer. Don't lose this thing, got it?"
    )
    |> next()
    |> mes("[Union Staff Kay]")
    |> mes("Well then, I wish you luck. Remember, you gotta bring me")
    |> mes("a receipt once you finish the delivery, okay?")
    |> close()
  end
end
