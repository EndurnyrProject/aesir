defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.Larissa do
  @moduledoc """
  Larissa rewards a completed quest and makes pancakes from supplied ingredients.

  ## Behavior

  - Gives quest rewards and later trades ingredients for a chosen pancake.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mosk_in",
        x: 211,
        y: 259,
        dir: 5,
        sprite: 960,
        name: "Larissa",
        scope: :shared,
        unique_name: "Larissa#mos_01"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      max_weight(ctx) - weight(ctx) < 2000 ->
        ctx
        |> mes("- Please stop here !! -")
        |> mes("- You're carrying too many items -")
        |> mes("- Please try again -")
        |> mes("- after using the kafra service -")
        |> close()

      get_char_var(ctx, :mos_swan, 0) == 100 ->
        ctx
        |> mes("[Larissa]")
        |> mes("Oh, you're the adventurer that Madame told me about.")
        |> mes("Did you find her son?")
        |> mes("I'm so glad. He's a good kid.")
        |> next()
        |> mes("[Larissa]")
        |> mes("Here you are. This special pancake is for you.")
        |> mes("It will be very delicious.")
        |> set_char_var(:mos_swan, 101)
        |> give_item(592, 5)
        |> give_item(593, 5)
        |> next()
        |> mes("[Larissa]")
        |> mes("Whenever you'd like to eat these pancake, you come on by.")
        |> mes("I'll bake you the most delicious one.")
        |> close()

      get_char_var(ctx, :mos_swan, 0) > 100 ->
        offer_pancake(ctx)

      true ->
        ctx
        |> mes("[Larissa]")
        |> mes("Young lady is a practical joker and her brother is tenderhearted.")
        |> mes("By the way, I haven't seen him for quite some time.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp offer_pancake(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Larissa]")
      |> mes("Did the pancake taste good?")
      |> mes("Would you like another pancake?")
      |> next()
      |> select(["Yes", "No"])

    cond do
      choice != 1 ->
        ctx
        |> mes("[Larissa]")
        |> mes("Ok we can bake it next time.")
        |> mes("I'm always available.")
        |> close()

      Rathena.truthy?(count_item(ctx, 7031)) and count_item(ctx, 519) > 1 and
        count_item(ctx, 504) > 1 and Rathena.truthy?(count_item(ctx, 548)) and
        Rathena.truthy?(count_item(ctx, 1019)) and Rathena.truthy?(count_item(ctx, 518)) ->
        bake_pancake(ctx)

      true ->
        ctx
        |> mes("[Larissa]")
        |> mes("That's good. I have ingredients and several toppings but...")
        |> mes("It's still not enough. You need to get all of the things that we don't have now.")
        |> next()
        |> mes("[Larissa]")
        |> mes(
          "I need ^4d4dff1 old frying pan , 2 bottles of milk , 2 white potion, 1 cheese, 1 Trunk, 1 Honey ^000000."
        )
        |> mes("We can bake our pancake when we get all of those.")
        |> close()
    end
  end

  defp bake_pancake(ctx) do
    {ctx, sieve_choice} =
      ctx
      |> mes("[Larissa]")
      |> mes("Let me check if you have all the ingredients.")
      |> mes("A frying pan, milk... potion that softens the dough, cheese..honey..and firewood.")
      |> mes("Perfect!")
      |> next()
      |> mes("[Larissa]")
      |> mes("Let us begin by kneading the dough.")
      |> mes("I'll add sugar and baking powder.")
      |> mes("It can be mixed well with this sieve.")
      |> next()
      |> mes("[Larissa]")
      |> mes("What should I do with the wheat flour?")
      |> next()
      |> select([
        "Turn it down.",
        "Pass it through a sieve.",
        "Press it with your fist."
      ])

    if sieve_choice in 1..3 do
      ctx =
        case sieve_choice do
          1 ->
            ctx
            |> mes("[Larissa]")
            |> mes("Oh, my! What are you doing now?")
            |> mes("I'm going to do that from the beginning.")
            |> mes("Look, pass it through a sieve.")

          2 ->
            ctx
            |> mes("[Larissa]")
            |> mes(
              "There you go. Just do it slowly while tapping the sides, sifting the sugar and baking powder through the sieve together."
            )

          3 ->
            ctx
            |> mes("[Larissa]")
            |> mes(
              "If we don't have the sieve, we can use our fist but we've got one. So we might as well use it right?"
            )

          _ ->
            ctx
        end

      finish_baking(ctx)
    else
      ctx
    end
  end

  defp finish_baking(ctx) do
    {ctx, stir_choice} =
      ctx
      |> next()
      |> mes("[Larissa]")
      |> mes("That way, it will mix well.")
      |> mes("And then I'm adding an egg, some milk and a white potion.")
      |> mes("What next?")
      |> next()
      |> select(["Stir it up with great speed.", "Do the same as she said."])

    ctx =
      if stir_choice == 1 do
        ctx
        |> mes("[Larissa]")
        |> mes(
          "No, you don't have to do that way. It won't rise properly if you stir it too fast."
        )
      else
        ctx |> mes("[Larissa]") |> mes("You're very good at this!")
      end

    {ctx, heat_choice} =
      ctx
      |> next()
      |> mes("[Larissa]")
      |> mes("It'll rise while baking if you stir it properly")
      |> mes("Ok, let me bake now. Let's pour it on our pan and spread it around.")
      |> next()
      |> mes("[Larissa]")
      |> mes("Cook in low temperature. It'll rise and have bubbles on it.")
      |> mes("When you see the bubbles, you can turn it over.")
      |> next()
      |> select(["Cook in high temperature.", "Can I turn it over now?"])

    ctx =
      if heat_choice == 1 do
        ctx
        |> mes("[Larissa]")
        |> mes("No, you don't do that.")
        |> mes("You'll burn it up.")
        |> mes("Wait for a while.")
      else
        ctx
        |> mes("[Larissa]")
        |> mes("Hmm let's see. It's good.")
        |> mes("You were good at it.")
      end

    {ctx, topping_choice} =
      ctx
      |> next()
      |> mes("[Larissa]")
      |> mes("Ok, turn it over. Oh it looks delicious")
      |> mes("What should I top it with? First I put some cheese but the rest is up to you...")
      |> next()
      |> select(["Caviar", "Mushrooms", "Honey", "Strawberry jam", "Sour cream"])

    if topping_choice in 1..5 do
      ctx =
        case topping_choice do
          1 ->
            ctx
            |> mes("[Larissa]")
            |> mes("Ok. you want caviar. Fortunately, I still have a little left.")
            |> mes("Hoohoo, this'll be luxurious..")
            |> mes("Here we go. It's all done!")
            |> set_local(:n, [591, 1])

          2 ->
            ctx
            |> mes("[Larissa]")
            |> mes("Ok. you want mushrooms.. It has an earthly flavor.")
            |> mes("Here we go. It's all done!")
            |> set_local(:n, [595, 1])

          3 ->
            ctx
            |> mes("[Larissa]")
            |> mes("Ok, honey syrup goes perfectly with pancakes.")
            |> mes("Here we go. It's all done!")
            |> set_local(:n, [593, 1])

          4 ->
            ctx
            |> mes("[Larissa]")
            |> mes("Who could get sick of pancakes with strawberry jam?")
            |> mes("Hoohoo it tastes sweet too.")
            |> mes("Here we go. It's all done!")
            |> set_local(:n, [592, 1])

          5 ->
            ctx
            |> mes("[Larissa]")
            |> mes("You want sour cream.. you will feel as if you fly in the sky.")
            |> mes("It can help reduce stress.")
            |> mes("Here we go. It's all done!")
            |> set_local(:n, [594, 1])

          _ ->
            ctx
        end

      ctx =
        ctx
        |> set_local(:di, [7031, 1, 519, 2, 504, 2, 548, 1, 1019, 1, 518, 1])
        |> set_local(:i, 0)
        |> consume_ingredients()

      ctx
      |> give_item(
        Enum.at(get_local(ctx, :n, []), 0, 0),
        Enum.at(get_local(ctx, :n, []), 1, 0)
      )
      |> close()
    else
      ctx
    end
  end

  defp consume_ingredients(ctx) do
    if get_local(ctx, :i, 0) < length(get_local(ctx, :di, [])) do
      ctx =
        delitem(
          ctx,
          Enum.at(get_local(ctx, :di, []), get_local(ctx, :i, 0), 0),
          Enum.at(get_local(ctx, :di, []), get_local(ctx, :i, 0) + 1, 0)
        )

      ctx |> set_local(:i, get_local(ctx, :i, 0) + 2) |> consume_ingredients()
    else
      ctx
    end
  end
end
