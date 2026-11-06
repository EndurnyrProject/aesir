defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.M11.Mage.MixingMachine do
  @moduledoc """
  Mixes ingredients into solutions for the Mage guild admission test.

  ## Behavior

  - Accepts solvent, ingredient quantities, a magic powder serial code, and a catalyst.
  - Consumes the submitted ingredients and produces the matching solution or a failed mixture.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script pre-re/jobs/1-1/mage.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "geffen_in",
        x: 164,
        y: 112,
        dir: 4,
        sprite: 111,
        name: "Mixing Machine",
        scope: :pre_renewal
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, action} =
      ctx
      |> mes("[Mixing Machine]")
      |> mes(
        "This machine is the property of the Geffen Mage Guild and is used only for mixing solutions for magic purposes."
      )
      |> next()
      |> select(["Use Machine.", "Cancel."])

    if action == 1, do: use_machine(ctx), else: close(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp use_machine(ctx) do
    {ctx, solvent} =
      ctx
      |> mes("[Mixing Machine]")
      |> mes("Choose the")
      |> mes("Solvent for")
      |> mes("the Solution.")
      |> next()
      |> select(["Payon Solution.", "Morocc Solution.", "No Solvent."])

    with {:ok, ctx} <- choose_solvent(ctx, solvent),
         {:ok, ctx} <- prepare_mixture(ctx) do
      ctx
      |> mes("[Mixing Machine]")
      |> mes("Please enter the ")
      |> mes("Serial Number of")
      |> mes("the Magic Powder.")
      |> next()
      |> enter_serial_number()
      |> choose_catalyst()
      |> mix_solution()
    else
      {:halt, ctx} -> ctx
    end
  end

  defp choose_solvent(ctx, solvent) when solvent in [1, 2] do
    item_id = if solvent == 1, do: 1089, else: 1088

    if count_item(ctx, item_id) == 0 do
      ctx =
        ctx
        |> mes("[Mixing Machine]")
        |> mes("Error.")
        |> mes("Cannot find the item.")
        |> mes("Please check again.")
        |> mes("Process Halting.")
        |> close()

      {:halt, ctx}
    else
      {:ok, set_local(ctx, :mixitem2, solvent)}
    end
  end

  defp choose_solvent(ctx, 3), do: {:ok, set_local(ctx, :mixitem2, 0)}
  defp choose_solvent(ctx, _solvent), do: {:ok, ctx}

  defp prepare_mixture(ctx) do
    case get_local(ctx, :progress, 0) do
      2 ->
        with {:ok, ctx} <- review_mixture(ctx) do
          if get_local(ctx, :progress, 0) == 3 do
            {:ok, ctx}
          else
            select_ingredients(ctx)
          end
        end

      1 ->
        ctx
        |> mes("[Mixing Machine]")
        |> mes("Nothing found.")
        |> next()
        |> select_ingredients()

      _ ->
        select_ingredients(ctx)
    end
  end

  defp select_ingredients(ctx) do
    ctx
    |> mes("[Mixing Machine]")
    |> mes("Select items to mix.")
    |> enter_ingredients()
    |> prepare_mixture()
  end

  defp enter_ingredients(ctx) do
    {ctx, ingredient} = select(ctx, ["Jellopy.", "Fluff.", "Milk.", "Ready to Mix."])

    ctx =
      case ingredient do
        1 ->
          enter_amount(ctx, 909, :mixitem1_1)

        2 ->
          enter_amount(ctx, 914, :mixitem1_2)

        3 ->
          enter_amount(ctx, 519, :mixitem1_3)

        4 ->
          ctx =
            if get_local(ctx, :progress, 0) != 2 do
              set_local(ctx, :progress, 1)
            else
              ctx
            end

          ctx |> set_local(:continue, 1) |> next()

        _ ->
          ctx
      end

    if Rathena.truthy?(get_local(ctx, :continue, 0)), do: ctx, else: enter_ingredients(ctx)
  end

  defp enter_amount(ctx, item_id, quantity_key) do
    {ctx, quantity} = input(ctx, :int)
    ctx = set_local(ctx, :input, quantity)

    if get_local(ctx, :input, 0) > 10_000 do
      ctx
      |> next()
      |> mes("[Mixing Machine]")
      |> mes("Error: Item limit exceeded. Please enter values less than 10,000 try again.")
      |> next()
      |> enter_amount(item_id, quantity_key)
    else
      ctx =
        if count_item(ctx, item_id) > 0 do
          set_local(
            ctx,
            quantity_key,
            get_local(ctx, quantity_key, 0) + get_local(ctx, :input, 0)
          )
        else
          ctx
        end

      set_local(ctx, :progress, 2)
    end
  end

  defp review_mixture(ctx) do
    {ctx, action} =
      ctx
      |> mes("[Mixing Machine]")
      |> show_quantity(:mixitem1_1, "Jellopy")
      |> show_quantity(:mixitem1_2, "Fluff")
      |> show_quantity(:mixitem1_3, "Milk")
      |> show_solvent()
      |> next()
      |> mes("[Mixing Machine]")
      |> mes(
        "Please choose if you wish to begin mixing, or to re-enter the number of items to be mixed."
      )
      |> next()
      |> select(["Begin Mixing.", "Re-Enter Number of Items.", "Reset."])

    case action do
      1 -> confirm_mixing(ctx)
      2 -> {:ok, ctx |> set_local(:continue, 0) |> next()}
      3 -> reset_mixture(ctx)
      _ -> {:ok, ctx}
    end
  end

  defp show_quantity(ctx, quantity_key, name) do
    quantity = get_local(ctx, quantity_key, 0)
    if quantity != 0, do: mes(ctx, "#{name}: #{quantity} ea."), else: ctx
  end

  defp show_solvent(ctx) do
    case get_local(ctx, :mixitem2, 0) do
      0 -> mes(ctx, "Solvent: None.")
      1 -> mes(ctx, "Solvent: Payon Solution.")
      2 -> mes(ctx, "Solvent: Morocc Solution.")
      _ -> ctx
    end
  end

  defp reset_mixture(ctx) do
    {ctx, restart} =
      ctx
      |> set_local(:mixitem1_1, 0)
      |> set_local(:mixitem1_2, 0)
      |> set_local(:mixitem1_3, 0)
      |> set_local(:progress, 0)
      |> set_local(:continue, 0)
      |> mes("[Mixing Machine]")
      |> mes("Reset Complete.")
      |> mes("Initiate again?")
      |> next()
      |> select(["Yes.", "No."])

    if restart == 1 do
      {:ok, ctx}
    else
      ctx =
        ctx
        |> mes("[Mixing Machine]")
        |> mes("Process Halted.")
        |> mes("Thank you.")
        |> close()

      {:halt, ctx}
    end
  end

  defp confirm_mixing(ctx) do
    {ctx, action} =
      ctx
      |> mes("[Mixing Machine]")
      |> mes(
        "Please place the items into the Mixing Receptacle. Make sure the item amounts are correct."
      )
      |> next()
      |> mes("[Mixing Machine]")
      |> mes(
        "You cannot adjust or restore items once they are placed into the Mixing Receptacle."
      )
      |> next()
      |> mes("[Mixing Machine]")
      |> mes(
        "If everything is correct, press the 'Mix' button when you are ready. Otherwise, press the 'Cancel' button."
      )
      |> next()
      |> select(["Press 'Mix' Button.", "Press 'Cancel' Button."])

    if action == 1 do
      ctx
      |> mes("[Mixing Machine]")
      |> mes("Place items into the Mixing Receptacle now. Please wait.")
      |> next()
      |> mes("[Mixing Machine]")
      |> load_ingredients()
    else
      {:ok, ctx}
    end
  end

  defp load_ingredients(ctx) do
    cond do
      count_item(ctx, 909) < get_local(ctx, :mixitem1_1, 0) ->
        halt_loading(ctx, "Insufficient Jellopy.")

      count_item(ctx, 914) < get_local(ctx, :mixitem1_2, 0) ->
        halt_loading(ctx, "Insufficient Fluff.")

      count_item(ctx, 519) < get_local(ctx, :mixitem1_3, 0) ->
        halt_loading(ctx, "Insufficient Milk.")

      get_local(ctx, :mixitem2, 0) in [1, 2] and count_item(ctx, 1089) == 0 and
          count_item(ctx, 1088) == 0 ->
        halt_loading(ctx, "Solution not found.")

      true ->
        ctx =
          ctx
          |> take_ingredient(909, :mixitem1_1)
          |> take_ingredient(914, :mixitem1_2)
          |> take_ingredient(519, :mixitem1_3)
          |> take_solvent()
          |> mes("Items are Ready.")
          |> mes("Close the Lid.")
          |> set_local(:progress, 3)
          |> next()

        {:ok, ctx}
    end
  end

  defp halt_loading(ctx, message) do
    ctx =
      ctx
      |> mes(message)
      |> mes("Please Check again.")
      |> mes("Process Halted.")
      |> close()

    {:halt, ctx}
  end

  defp take_ingredient(ctx, item_id, quantity_key) do
    quantity = get_local(ctx, quantity_key, 0)
    if quantity != 0, do: delitem(ctx, item_id, quantity), else: ctx
  end

  defp take_solvent(ctx) do
    case get_local(ctx, :mixitem2, 0) do
      1 -> delitem(ctx, 1089, 1)
      2 -> delitem(ctx, 1088, 1)
      _ -> ctx
    end
  end

  defp enter_serial_number(ctx) do
    {ctx, serial_number} = input(ctx, :int)
    ctx = set_local(ctx, :input, serial_number)

    cond do
      get_local(ctx, :input, 0) == 0 ->
        {ctx, skip} =
          ctx
          |> mes("[Mixing Machine]")
          |> mes("Do you want to skip this Menu?")
          |> next()
          |> select(["Yes.", "No."])

        if skip == 1, do: ctx, else: enter_serial_number(ctx)

      get_local(ctx, :input, 0) < 1000 or get_local(ctx, :input, 0) > 9999 ->
        ctx
        |> mes("[Mixing Machine]")
        |> mes("Invalid Serial Number.")
        |> mes("Please try again.")
        |> next()
        |> enter_serial_number()

      true ->
        {ctx, confirmation} =
          ctx
          |> mes("[Mixing Machine]")
          |> mes("The Serial Number is ##{get_local(ctx, :input, 0)}, correct?")
          |> next()
          |> select(["Confirm.", "Cancel."])

        if confirmation == 1 do
          powder =
            case get_local(ctx, :input, 0) do
              8472 -> 1
              3735 -> 2
              2750 -> 3
              5429 -> 4
              _ -> 5
            end

          set_local(ctx, :magic_powder, powder)
        else
          ctx
        end
    end
  end

  defp choose_catalyst(ctx) do
    {ctx, catalyst} =
      ctx
      |> mes("[Mixing Machine]")
      |> mes("Choose a")
      |> mes("Catalyst Stone.")
      |> next()
      |> select([
        "Yellow Gemstone.",
        "Red Gemstone.",
        "Blue Gemstone.",
        "1carat Diamond.",
        "Skip."
      ])

    case catalyst do
      stone when stone in 1..4 -> set_local(ctx, :mixitem3, stone)
      _ -> ctx
    end
  end

  defp mix_solution(ctx) do
    ctx
    |> mes("[Mixing Machine]")
    |> mes("All Set.")
    |> mes("Initiating")
    |> mes("Mixing process.")
    |> mes("Please Wait.")
    |> next()
    |> mes("[Mixing Machine]")
    |> mes("- Proverb of the Day -")
    |> proverb()
    |> next()
    |> dispense_solution()
    |> mes("[Mixing Machine]")
    |> mes("Mixing Complete.")
    |> mes("Thank you.")
    |> close()
  end

  defp proverb(ctx) do
    case Enum.random(1..5) do
      1 ->
        mes(
          ctx,
          "An Eye for an Eye: When you take from a person, you must replace or repay in some way."
        )

      2 ->
        mes(
          ctx,
          "Credibility is a Man's Currency: There's a value in genuine trust that cannot be measured."
        )

      3 ->
        ctx
        |> mes(
          "What Goes Around Comes Around: Ultimately, you will be treated in the way you treat others."
        )
        |> mes(
          "It means 'When you harm Another you will be harmed by him in an unavoidable situation'."
        )

      4 ->
        mes(
          ctx,
          "A good neighbor is better than a distant brother: When you need help, you can count on those close to you."
        )

      _ ->
        mes(
          ctx,
          "Birds of a Feather Flock Together: You can look at a person's friends as an indicator of their character."
        )
    end
  end

  defp dispense_solution(ctx) do
    cond do
      get_local(ctx, :mixitem1_1, 0) == 2 and get_local(ctx, :mixitem1_2, 0) == 3 and
        get_local(ctx, :mixitem1_3, 0) == 1 and get_local(ctx, :mixitem2, 0) == 1 and
        get_local(ctx, :mixitem3, 0) == 1 and get_local(ctx, :magic_powder, 0) == 1 ->
        dispense_solution(ctx, 1, 1071)

      get_local(ctx, :mixitem1_1, 0) == 3 and get_local(ctx, :mixitem1_2, 0) == 1 and
        get_local(ctx, :mixitem1_3, 0) == 1 and get_local(ctx, :mixitem2, 0) == 0 and
        get_local(ctx, :mixitem3, 0) == 2 and get_local(ctx, :magic_powder, 0) == 2 ->
        dispense_solution(ctx, 2, 1085)

      get_local(ctx, :mixitem1_1, 0) == 6 and get_local(ctx, :mixitem1_2, 0) == 1 and
        get_local(ctx, :mixitem1_3, 0) == 0 and get_local(ctx, :mixitem2, 0) == 1 and
        get_local(ctx, :mixitem3, 0) == 3 and get_local(ctx, :magic_powder, 0) == 3 ->
        dispense_solution(ctx, 3, 1086)

      get_local(ctx, :mixitem1_1, 0) == 2 and get_local(ctx, :mixitem1_2, 0) == 3 and
        get_local(ctx, :mixitem1_3, 0) == 0 and get_local(ctx, :mixitem2, 0) == 2 and
        get_local(ctx, :mixitem3, 0) == 4 and get_local(ctx, :magic_powder, 0) == 4 ->
        dispense_solution(ctx, 4, 1087)

      true ->
        ctx
        |> mes("[Mixing Machine]")
        |> mes("Unexpected")
        |> mes("Error Occurred.")
        |> give_item(1090, 1)
        |> next()
    end
  end

  defp dispense_solution(ctx, solution, item_id) do
    ctx
    |> mes("[Mixing Machine]")
    |> mes("Mage Test Solution No. #{solution}.")
    |> give_item(item_id, 1)
    |> next()
  end
end
