defmodule Aesir.ZoneServer.Content.Npc.Quests.CookingQuest.Servant do
  @moduledoc """
  Chulsoo, Sir Charles's runaway apprentice, who sells Rice Cakes in Payon and closes the
  cooking quest by accepting the Bundle of Food that Madeleine Chu prepares.

  ## Behavior

  - Turns the player away while a Rice Cake would not fit in their inventory.
  - Sells Rice Cakes for 200 zeny.
  - Recounts why he left Prontera once the quest reaches step 8.
  - At step 9, accepts Madeleine Chu's Bundle of Food, reads her letter and trades the bundle
    for a Rice Cake while advancing the quest to step 10.
  - From step 10 on, only asks the player to pass his thanks on to Madeleine.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Reddozen
    - L0ne_W0lf
    - Lupus
    - Samuray22
    - ultramage
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "payon", x: 209, y: 127, dir: 3, sprite: 88, name: "Servant", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @rice_cake 555
  @food_package 12_111
  @rice_cake_price 200

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if Rathena.truthy?(checkweight(ctx, [{@rice_cake, 1}])) do
      talk(ctx, get_char_var(ctx, :cooking_q, 0))
    else
      too_heavy(ctx)
    end
  end

  defp talk(ctx, 10) do
    ctx
    |> mes("[Chulsoo]")
    |> mes("When you get the chance,")
    |> mes("please give Madeline my")
    |> mes("thanks. I'll visit Prontera")
    |> mes("soon to see her, as well as")
    |> mes("make amends with Sir Charles.")
    |> close()
  end

  defp talk(ctx, 9) do
    {ctx, choice} =
      ctx
      |> mes("[Chulsoo]")
      |> mes("How would you like")
      |> mes("to buy a Rice Cake?")
      |> mes("It's only 200 zeny, but")
      |> mes("it's oh-so-delicious~")
      |> next()
      |> select(["Sure, I'll buy one!", "No, thanks.", "Actually, Madeleine sent me..."])

    case choice do
      1 -> buy_rice_cake(ctx)
      2 -> decline_rice_cake(ctx)
      3 -> deliver_bundle(ctx)
      _ -> ctx
    end
  end

  defp talk(ctx, 8), do: tell_his_story(ctx)

  defp talk(ctx, _step) do
    {ctx, choice} =
      ctx
      |> mes("[Chulsoo]")
      |> mes("How would you like")
      |> mes("to buy a Rice Cake?")
      |> mes("It's only 200 zeny, but")
      |> mes("it's oh-so-delicious~")
      |> next()
      |> select(["Sure, I'll buy one!", "No, thanks."])

    case choice do
      1 -> buy_rice_cake(ctx)
      _ -> decline_rice_cake(ctx)
    end
  end

  defp too_heavy(ctx) do
    ctx
    |> mes("[Chulsoo]")
    |> mes("Hold on, you're carrying")
    |> mes("too many items with you.")
    |> mes("Why don't you put some of")
    |> mes("your stuff in Kafra Storage")
    |> mes("before coming back to me?")
    |> close()
  end

  defp buy_rice_cake(ctx) do
    if zeny(ctx) < @rice_cake_price do
      not_enough_zeny(ctx)
    else
      ctx
      |> pay_zeny(@rice_cake_price)
      |> give_item(@rice_cake, 1)
      |> mes("[Chulsoo]")
      |> mes("Thank you very")
      |> mes("much! I hope you")
      |> mes("enjoy your Rice Cake~")
      |> close()
    end
  end

  defp not_enough_zeny(ctx) do
    ctx
    |> mes("[Chulsoo]")
    |> mes("Oh, I'm sorry, but")
    |> mes("you don't have enough")
    |> mes("money to buy a Rice Cake...")
    |> mes("Still, it should be easy to")
    |> mes("raise 200 zeny, right?")
    |> close()
  end

  defp decline_rice_cake(ctx) do
    ctx
    |> mes("[Chulsoo]")
    |> mes("Are you sure about")
    |> mes("that? You won't get")
    |> mes("the chance to have a")
    |> mes("Rice Cake this delicious")
    |> mes("anywhere else. Oh well,")
    |> mes("that means more for me~")
    |> close()
  end

  defp deliver_bundle(ctx) do
    if count_item(ctx, @food_package) > 0 do
      accept_bundle(ctx)
    else
      empty_handed(ctx)
    end
  end

  defp accept_bundle(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Actually, Madeleine")
    |> mes("sent me here to find")
    |> mes("you. She said that you'd")
    |> mes("be willing to taste test")
    |> mes("the food in this bundle...")
    |> next()
    |> mes("[Chulsoo]")
    |> mes("Madeleine? You mean")
    |> mes("Madeleine Chu? Oh, I haven't")
    |> mes("heard from her in such a long")
    |> mes("time! Great, let me see the")
    |> mes("bundle that she sent me. Ah, everything here looks appetizing!")
    |> next()
    |> mes("[Chulsoo]")
    |> mes("Oh, wait. She even")
    |> mes("included a message")
    |> mes("inside this bundle.")
    |> mes("Let's see, here...")
    |> next()
    |> mes("^333333Dear Chulsoo,")
    |> mes(" It's been a long time.")
    |> mes("I know you left Prontera on")
    |> mes("bad terms with Sir Charles,")
    |> mes("but please understand that")
    |> mes("he was only trying his best to")
    |> mes("help improve your cooking.^000000")
    |> next()
    |> mes("^333333 Sir Charles always wished")
    |> mes("that you'd expand your repetoire, and that you'd make these kinds")
    |> mes("of foods someday. The person")
    |> mes("that delivered this food also")
    |> mes("cooked it. Please try it...^000000")
    |> next()
    |> mes("^333333 Hopefully, you'll be")
    |> mes("able to understand Sir ")
    |> mes("Charles a little better ")
    |> mes("after tasting this food.")
    |> mes(" ")
    |> mes(" Your friend, Madeleine^000000")
    |> next()
    |> mes("[Chulsoo]")
    |> mes("Now I get it...")
    |> mes("These are the recipes")
    |> mes("that Sir Charles tried")
    |> mes("to teach me. But I refused")
    |> mes("to learn them because I had")
    |> mes("thought they were too gross...")
    |> next()
    |> mes("[Chulsoo]")
    |> mes("......")
    |> mes(".........")
    |> mes("It's so delicious... Are")
    |> mes("you sure you're just a")
    |> mes("beginner? No... This must")
    |> mes("be what I've been missing...")
    |> next()
    |> mes("[Chulsoo]")
    |> mes("It's what my master")
    |> mes("always tried to teach me,")
    |> mes("but I was too impatient to")
    |> mes("properly learn it. The greatest")
    |> mes("ingredient of them all... ^D02090heart^000000. After all this time, I understand.")
    |> next()
    |> mes("[Chulsoo]")
    |> mes("Thank you for bringing")
    |> mes("this food to me. I will enjoy")
    |> mes("it thoroughly, and reflect upon")
    |> mes("what my old teacher was trying")
    |> mes("to tell me. In return, please have one of my humble Rice Cakes.")
    |> next()
    |> delitem(@food_package, 1)
    |> set_char_var(:cooking_q, 10)
    |> give_item(@rice_cake, 1)
    |> mes("[Chulsoo]")
    |> mes("I better visit Prontera")
    |> mes("again soon. It's been a long")
    |> mes("time since I've seen Madeleine.")
    |> mes("More importantly, I think that")
    |> mes("I should apologize to Sir Charles. ")
    |> close()
  end

  defp empty_handed(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Actually, Madeleine")
    |> mes("sent me here to find")
    |> mes("you. She said that you'd")
    |> mes("be willing to taste test")
    |> mes("the food in this bundle...")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Wait, wait...")
    |> mes("I don't have it!")
    |> mes("Where did I put")
    |> mes("that Bundle of Food?")
    |> close()
  end

  defp tell_his_story(ctx) do
    ctx
    |> mes("[Chulsoo]")
    |> mes("Lately, it seems that")
    |> mes("no one wants to buy my")
    |> mes("Rice Cakes. It's been like")
    |> mes("that ever since I left Prontera... ")
    |> next()
    |> mes("[Chulsoo]")
    |> mes("You see, I used to study")
    |> mes("in that city as one of Sir")
    |> mes("Charles's apprentices. It")
    |> mes("was only a few months, but")
    |> mes("I was very excited to get the")
    |> mes("chance to learn under him.")
    |> next()
    |> mes("[Chulsoo]")
    |> mes("At least, I was excited")
    |> mes("at first. Sir Charles really")
    |> mes("frustrated me: he would")
    |> mes("only teach me to make these")
    |> mes("really gross sounding recipes! Like Grasshopper Legs and-- ugh!")
    |> next()
    |> mes("[Chulsoo]")
    |> mes("He kept insisting that")
    |> mes("I was forgetting the most")
    |> mes("important ingredient, and that")
    |> mes("it was possible to make things")
    |> mes("like Fried Monkey Tails delicious. But I can't believe that nonsense!")
    |> next()
    |> mes("[Chulsoo]")
    |> mes("In the end, I ran away.")
    |> mes("For some reason, I feel")
    |> mes("a little ashamed and regret")
    |> mes("what I did. Still, I don't see")
    |> mes("what Sir Charles meant...")
    |> close()
  end
end
