defmodule Aesir.ZoneServer.Content.Npc.Floating.MadeleineChu do
  @moduledoc """
  Madeleine Chu guides beginning cooks through Sir Charles's lessons and sells cooking kits.

  ## Behavior

  - Reminds apprentices of recipe ingredients and lends a basic cookbook with starter kits.
  - Bundles six practice dishes for delivery to Chulsoo and handles a missing food bundle.
  - Rewards the completed delivery with indoor cooking kits and unlocks their purchase.
  - Sells cooking kits in batches of up to 100 and shares stories about Sir Charles.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Reddozen
    - L0ne_W0lf
    - Lupus
    - Irmin
    - Samuray22
    - ultramage
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :MaxWeight, 0) - weight(ctx) < 2000 do
      ask_to_store_items(ctx)
    else
      continue_cooking_quest(ctx)
    end
  end

  defp ask_to_store_items(ctx) do
    ctx
    |> mes("[Madeleine Chu]")
    |> mes("I'm sorry, but right now")
    |> mes("you're carrying too many")
    |> mes("items. You should put your")
    |> mes("extra things in Kafra Storage,")
    |> mes("and then talk to me again, okay? ")
    |> close()
  end

  defp continue_cooking_quest(ctx) do
    case get_char_var(ctx, :cooking_q, 0) do
      0 -> introduce_apprenticeship(ctx)
      7 -> lend_cookbook(ctx)
      8 -> offer_beginner_help(ctx)
      9 -> check_food_delivery(ctx)
      10 -> reward_food_delivery(ctx)
      11 -> offer_trained_help(ctx)
      step when step in 1..6 -> remind_ingredients(ctx)
      _ -> report_error(ctx)
    end
  end

  defp introduce_apprenticeship(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Madeleine Chu]")
      |> mes("Oh, hello~")
      |> mes("I'm Madeleine Chu,")
      |> mes("chef apprentice to")
      |> mes("Sir Charles. May I help")
      |> mes("you with anything today?")
      |> next()
      |> select([
        "What do you do as a chef?",
        "Which foods can you make?",
        "I want to learn cooking too!"
      ])

    case choice do
      1 -> explain_apprenticeship(ctx)
      2 -> describe_recipes(ctx)
      3 -> explain_cooking_lessons(ctx)
      _ -> report_error(ctx)
    end
  end

  defp explain_apprenticeship(ctx) do
    ctx
    |> mes("[Madeleine Chu]")
    |> mes("What do I do as a chef?")
    |> mes("Well, I'm just an apprentice now, so I'm still learning how to cook.")
    |> mes("But someday, I want to become")
    |> mes("a great chef and have everybody")
    |> mes("recognize my culinary talents~")
    |> next()
    |> mes("[Madeleine Chu]")
    |> mes("There's a lot of grueling")
    |> mes("work that goes into cooking,")
    |> mes("as well as a lot of finesse.")
    |> mes("I have to control fire better")
    |> mes("tham a firefighter and craft")
    |> mes("my dishes like an artist.")
    |> next()
    |> mes("[Madeleine Chu]")
    |> mes("Well, I'm exaggerating")
    |> mes("a little bit, but cooking")
    |> mes("at a certain level is much")
    |> mes("more difficult than it appears.")
    |> close()
  end

  defp describe_recipes(ctx) do
    ctx
    |> mes("[Madeleine Chu]")
    |> mes("Well, I only know the basic")
    |> mes("recipes for now. Sir Charles")
    |> mes("says that even the best chef")
    |> mes("knows how to bring out the")
    |> mes("flavors of even common foods.")
    |> next()
    |> mes("[Madeleine Chu]")
    |> mes("He says that I need to develop")
    |> mes("my culinary skills until I can")
    |> mes("learn more advanced recipes.")
    |> mes("Someday, I'll advance and then")
    |> mes("I'll know enough to create my")
    |> mes("own unique, delicious dishes!")
    |> next()
    |> mes("[Madeleine Chu]")
    |> mes("Sir Charles may be harsh to")
    |> mes("his students, but his skills")
    |> mes("are unequaled. I tried one of")
    |> mes("his desserts once, and it was")
    |> mes("the most heavenly experience.")
    |> mes("I swear I saw winged hearts~!")
    |> next()
    |> mes("[Madeleine Chu]")
    |> mes("Sadly, I'm a still long way")
    |> mes("from learning how to make ")
    |> mes("his specialty, Handmade")
    |> mes("Chocolates. Before that, I need")
    |> mes("to master these strange recipes")
    |> mes("that he keeps teaching me...")
    |> close()
  end

  defp explain_cooking_lessons(ctx) do
    ctx
    |> mes("[Madeleine Chu]")
    |> mes("If you want to learn cooking,")
    |> mes("why don't you ask Sir Charles?")
    |> mes("He's fairly harsh to his students, but he does it out of tough love.")
    |> mes("He demands nothing less than")
    |> mes("absolute perfection, you know.")
    |> next()
    |> mes("[Madeleine Chu]")
    |> mes("If you manage to get")
    |> mes("Sir Charles to teach you")
    |> mes("a recipe, you should practice")
    |> mes("it over and over again to hone")
    |> mes("your skills. Then, you'll find")
    |> mes("yourself improving at cooking.")
    |> next()
    |> mes("[Madeleine Chu]")
    |> mes("Now, Sir Charles will only")
    |> mes("teach students that are truly")
    |> mes("committed to cooking. You")
    |> mes("might want to show your")
    |> mes("dedication with the proper")
    |> mes("attire... like a Chef Hat.")
    |> next()
    |> mes("[Madeleine Chu]")
    |> mes("But yes, Sir Charles")
    |> mes("has very little patience for")
    |> mes("beginners, meaning that")
    |> mes("you'll have to be patient")
    |> mes("with his teaching methods...")
    |> close()
  end

  defp remind_ingredients(ctx) do
    {ctx, recipe} =
      ctx
      |> mes("[Madeleine Chu]")
      |> mes("Hello, is there any")
      |> mes("way I can help you today?")
      |> mes("Oh, if you're studying cooking")
      |> mes("under Sir Charles, I can remind")
      |> mes("you of the ingredients you need")
      |> mes("if you've forgotten them~")
      |> next()
      |> select([
        "Fried Grasshopper Legs",
        "Grape Juice Herbal Tea",
        "Honey Grape Juice",
        "Frog Egg and Squid Ink Soup",
        "Steamed Crab Nippers",
        "Fried Monkey Tails"
      ])

    ctx
    |> describe_ingredients(recipe)
    |> next()
    |> mes("[Madeleine Chu]")
    |> mes("I know that Sir Charles")
    |> mes("is stubborn and won't tell")
    |> mes("you the ingredients again")
    |> mes("if you forget. Anyway, I hope")
    |> mes("you collect them and complete")
    |> mes("the recipe as soon as you can~")
    |> close()
  end

  defp describe_ingredients(ctx, 1) do
    ctx
    |> mes("[Madeleine Chu]")
    |> mes("Oh! You'll need")
    |> mes("^4D4DFF5 Grasshopper Legs^000000,")
    |> mes("^4D4DFF1 Cooking Oil^000000, and")
    |> mes("^4D4DFF1 Old Frying Pan^000000 to make")
    |> mes("fried Grasshopper Legs.")
  end

  defp describe_ingredients(ctx, 2) do
    ctx
    |> mes("[Madeleine Chu]")
    |> mes("Oh! You'll need")
    |> mes("^4D4DFF3 Grapes^000000, and")
    |> mes("^4D4DFF2 Red Potions^000000 for")
    |> mes("Grape Juice Herbal Tea.")
  end

  defp describe_ingredients(ctx, 3) do
    ctx
    |> mes("[Madeleine Chu]")
    |> mes("Oh! You'll need")
    |> mes("^4D4DFF1 Honey^000000,")
    |> mes("^4D4DFF2 Grapes^000000, and")
    |> mes("^4D4DFF1 Red Potion^000000.")
  end

  defp describe_ingredients(ctx, 4) do
    ctx
    |> mes("[Madeleine Chu]")
    |> mes("Oh! You'll need")
    |> mes("^4D4DFF1 Bag of Grain^000000,")
    |> mes("^4D4DFF10 Spawns^000000, and")
    |> mes("^4D4DFF1 Squid Ink^000000 for Frog")
    |> mes("Egg and Squid Ink soup.")
  end

  defp describe_ingredients(ctx, 5) do
    ctx
    |> mes("[Madeleine Chu]")
    |> mes("Oh! You'll need")
    |> mes("^4D4DFF10 Green Herbs^000000,")
    |> mes("^4D4DFF10 Nippers^000000, and")
    |> mes("^4D4DFF1 Yellow Potion^000000 for")
    |> mes("Steamed Crab Nippers.")
  end

  defp describe_ingredients(ctx, 6) do
    ctx
    |> mes("[Madeleine Chu]")
    |> mes("Oh! You'll need")
    |> mes("^4D4DFF1 Frying Pan^000000,")
    |> mes("^4D4DFF5 Yoyo Tails^000000, and")
    |> mes("^4D4DFF1 Cooking Oil^000000 for")
    |> mes("Fried Monkey Tails.")
  end

  defp describe_ingredients(ctx, _recipe), do: ctx

  defp lend_cookbook(ctx) do
    ctx
    |> mes("[Madeleine Chu]")
    |> mes("Sir Charles taught you")
    |> mes("a recipe? That's great!")
    |> mes("I hope you remember that the")
    |> mes("quality of your dishes mostly")
    |> mes("relies on your skills, so always remember to keep practicing.")
    |> next()
    |> mes("[Madeleine Chu]")
    |> mes("Ah, you know what might")
    |> mes("help you improve your")
    |> mes("culinary skills? Why don't")
    |> mes("you borrow this cookbook")
    |> mes("and try some of its recipes?")
    |> next()
    |> mes("[Madeleine Chu]")
    |> mes("Before you cook, make sure")
    |> mes("that you have enough of the")
    |> mes("ingredients. Oh, and keep the")
    |> mes("cookbook nearby while you are")
    |> mes("cooking. You'll probably need")
    |> mes("to refer to it pretty often...")
    |> next()
    |> mes("[Madeleine Chu]")
    |> mes("You might fail to make")
    |> mes("edible food during your")
    |> mes("first attempts, but you'll")
    |> mes("improve as you practice. ")
    |> mes("Please take this cookbook")
    |> mes("with the basic Level 1 recipes.")
    |> set_char_var(:cooking_q, 8)
    |> give_item(7472, 1)
    |> next()
    |> mes("[Madeleine Chu]")
    |> mes("Once you learn all the recipes,")
    |> mes("feel free to come back to me for more, okay? Also, you'll need")
    |> mes("these cooking kits to practice.")
    |> mes("You can have these for free, and you can buy more from me later~")
    |> give_item(12125, 10)
    |> close()
  end

  defp offer_beginner_help(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Madeleine Chu]")
      |> mes("So how has your cooking")
      |> mes("been coming along? You'll")
      |> mes("need to practice to develop")
      |> mes("your culinary skills. Now,")
      |> mes("can I help you with anything?")
      |> next()
      |> select([
        "I need some Cooking Kits.",
        "Will you try the food I cooked?",
        "How does the food I cooked look?"
      ])

    case choice do
      1 -> offer_beginner_kits(ctx)
      2 -> taste_practice_dishes(ctx)
      3 -> inspect_practice_dishes(ctx)
      _ -> report_error(ctx)
    end
  end

  defp offer_beginner_kits(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Madeleine Chu]")
      |> mes("Sure, which kind")
      |> mes("of Cooking Kits")
      |> mes("did you need?")
      |> next()
      |> select([
        "Outdoor Cooking Kit - 500z",
        "Home Cooking Kit - 1,000z",
        "Quit"
      ])

    case choice do
      1 -> sell_cooking_kits(ctx, 12125)
      2 -> require_more_practice(ctx)
      3 -> invite_kit_purchase(ctx)
      _ -> taste_practice_dishes(ctx)
    end
  end

  defp require_more_practice(ctx) do
    ctx
    |> mes("[Madeleine Chu]")
    |> mes("Oh, I'm sorry, but you")
    |> mes("don't have enough skills")
    |> mes("to use a Home Cooking Kit.")
    |> mes("Please practice some more")
    |> mes("with the Outdoor Cooking")
    |> mes("Kits first, alright?")
    |> close()
  end

  defp invite_kit_purchase(ctx) do
    ctx
    |> mes("[Madeleine Chu]")
    |> mes("Please come back and")
    |> mes("let me know if you need")
    |> mes("to purchase any Cooking")
    |> mes("Kits, alright? See you later~")
    |> close()
  end

  defp taste_practice_dishes(ctx) do
    if count_item(ctx, 12041) > 0 and count_item(ctx, 12046) > 0 and
         count_item(ctx, 12061) > 0 and count_item(ctx, 12056) > 0 and
         count_item(ctx, 12051) > 0 and count_item(ctx, 12066) > 0 do
      bundle_practice_dishes(ctx)
    else
      request_all_practice_dishes(ctx)
    end
  end

  defp bundle_practice_dishes(ctx) do
    ctx
    |> mes("[Madeleine Chu]")
    |> mes("Oh, you've made a sample")
    |> mes("of every recipe detailed in")
    |> mes("that basic cookbook, did you?")
    |> mes("That must have been very good training for your culinary skills.")
    |> next()
    |> mes("[Madeleine Chu]")
    |> mes("I'd love to taste your")
    |> mes("food and give my opinion,")
    |> mes("but do you mind if I ask")
    |> mes("you a favor first? I have")
    |> mes("a friend in Payon who used")
    |> mes("to study cooking in Prontera.")
    |> next()
    |> mes("[Madeleine Chu]")
    |> mes("However, he became frustrated")
    |> mes("with the culinary classes and")
    |> mes("moved back to Prontera. Would")
    |> mes("you mind asking him to taste")
    |> mes("them? Here, I'll wrap your")
    |> mes("food in this handy cloth...")
    |> next()
    |> delitem(12041, 1)
    |> delitem(12046, 1)
    |> delitem(12061, 1)
    |> delitem(12056, 1)
    |> delitem(12051, 1)
    |> delitem(12066, 1)
    |> set_char_var(:cooking_q, 9)
    |> give_item(12111, 1)
    |> mes("[Madeleine Chu]")
    |> mes("There you go, it's ready")
    |> mes("to be delivered. Now, make")
    |> mes("sure not to open this before")
    |> mes("giving it to my old friend,")
    |> mes("Chulsoo. You can find him")
    |> mes("somewhere around Payon...")
    |> next()
    |> mes("[Madeleine Chu]")
    |> mes("You should be able to")
    |> mes("find Chulsoo around the")
    |> mes("water mill or the pub in")
    |> mes("Payon. Oh, and don't")
    |> mes("forget to tell him that")
    |> mes("I sent you, okay? Thanks~")
    |> close()
  end

  defp request_all_practice_dishes(ctx) do
    ctx
    |> mes("[Madeleine Chu]")
    |> mes("Hmm... I think it'd")
    |> mes("be better if you tried")
    |> mes("to make every recipe in")
    |> mes("that basic cookbook I gave")
    |> mes("you first. That way, I can more")
    |> mes("accurately judge your skills.")
    |> next()
    |> mes("[Madeleine Chu]")
    |> mes("It's not bad to focus")
    |> mes("on just one recipe, but")
    |> mes("as a beginner, you need")
    |> mes("to cover all of the basics.")
    |> mes("Please read the cookbook that I gave you very carefully, okay?")
    |> close()
  end

  defp inspect_practice_dishes(ctx) do
    if count_item(ctx, 12041) > 0 or count_item(ctx, 12046) > 0 or
         count_item(ctx, 12061) > 0 or count_item(ctx, 12056) > 0 or
         count_item(ctx, 12051) > 0 or count_item(ctx, 12066) > 0 do
      ctx
      |> mes("[Madeleine Chu]")
      |> mes("Oh, I see that you've")
      |> mes("tried some recipes in that")
      |> mes("basic cookbook that I gave")
      |> mes("you. Everything you made looks")
      |> mes("delicious. All that's left now")
      |> mes("is for someone to taste it...")
      |> close()
    else
      ctx
      |> mes("[Madeleine Chu]")
      |> mes("Well... I don't know...")
      |> mes("I think you really should try")
      |> mes("to make every recipe listed")
      |> mes("in that basic cookbook that")
      |> mes("I gave to you first. Then, you")
      |> mes("can present your dishes~")
      |> close()
    end
  end

  defp check_food_delivery(ctx) do
    if count_item(ctx, 12111) > 0 do
      ctx
      |> mes("[Madeleine Chu]")
      |> mes("Please find my friend")
      |> mes("Chulsoo in Payon and")
      |> mes("give him the Bundle of")
      |> mes("Food so that he can taste")
      |> mes("the dishes you've made.")
      |> close()
    else
      ask_about_missing_bundle(ctx)
    end
  end

  defp ask_about_missing_bundle(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Madeleine Chu]")
      |> mes("Ah, hello~ oh, will you give me a second?")
      |> mes("Right now, I am frying something so, I need to focus on this work for a while.")
      |> mes("Hahahaha.")
      |> next()
      |> mes("[Madeleine Chu]")
      |> mes("Oh, so have you met")
      |> mes("my friend Chulsoo?")
      |> mes("You brought him the")
      |> mes("Bundle of Food, right?")
      |> mes("I'd be disappointed if")
      |> mes("you lost it or sold it...")
      |> next()
      |> select(["I did!", "I lost the Bundle of Food!"])

    if choice == 1 do
      ctx
      |> mes("[Madeleine Chu]")
      |> mes("Hahaha, I suppose you")
      |> mes("did. But even if you didn't")
      |> mes("yet, make sure that you do")
      |> mes("it soon, alright? See you~")
      |> close()
    else
      handle_lost_bundle(ctx)
    end
  end

  defp handle_lost_bundle(ctx) do
    if count_item(ctx, 7472) > 0 do
      ctx
      |> mes("[Madeleine Chu]")
      |> mes("You lost it? Oh, that's")
      |> mes("not good. How can you ")
      |> mes("disrespect the culinary")
      |> mes("arts in that way? I'm so")
      |> mes("very ashamed of you...")
      |> next()
      |> delitem(7472, 1)
      |> set_char_var(:cooking_q, 0)
      |> mes("[Madeleine Chu]")
      |> mes("First of all, I'd like")
      |> mes("you to return my cookbook.")
      |> mes("I want you to reflect on what")
      |> mes("you've done, and then learn")
      |> mes("cooking skills from Sir Charles, starting from the very beginning.")
      |> close()
    else
      ctx
      |> mes("[Madeleine Chu]")
      |> mes("Oh, you must be joking~")
      |> mes("I'm sure you must have")
      |> mes("hidden it somewhere.")
      |> mes("Anyway, please deliver that")
      |> mes("Bundle of Food to Chulsoo.")
      |> close()
    end
  end

  defp reward_food_delivery(ctx) do
    ctx
    |> mes("[Madeleine Chu]")
    |> mes("I just received a")
    |> mes("message from Chulsoo")
    |> mes("thanking me for having")
    |> mes("you send him that food.")
    |> mes("I'm guessing that he")
    |> mes("really liked it a lot.")
    |> next()
    |> mes("[Madeleine Chu]")
    |> mes("I think you're ready to use")
    |> mes("higher grade cooking tools now.")
    |> mes("But never forget that your own")
    |> mes("skills are the most important")
    |> mes("factor in quality cuisine.")
    |> next()
    |> set_char_var(:cooking_q, 11)
    |> give_item(12126, 10)
    |> mes("[Madeleine Chu]")
    |> mes("Please try these Indoor")
    |> mes("Cooking Kits to help you")
    |> mes("create more delicate dishes.")
    |> mes("When you run out, feel free to")
    |> mes("purchase more from me, okay?")
    |> next()
    |> mes("[Madeleine Chu]")
    |> mes("Also, if you want to")
    |> mes("learn some new recipes,")
    |> mes("why don't you talk to Sir")
    |> mes("Charles again? Okay then,")
    |> mes("good luck, and I'll see you later~ ")
    |> close()
  end

  defp offer_trained_help(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Madeleine Chu]")
      |> mes("How are you? I hope")
      |> mes("that you've been honing")
      |> mes("your cooking skills since")
      |> mes("the last time we've met.")
      |> mes("Now, can I help you with")
      |> mes("anything in particular?")
      |> next()
      |> select([
        "I need some Cooking Kits.",
        "How is Sir Charles?",
        "Um, who's that kid?"
      ])

    case choice do
      1 -> offer_trained_kits(ctx)
      2 -> discuss_sir_charles(ctx)
      3 -> discuss_child_with_cat(ctx)
      _ -> report_error(ctx)
    end
  end

  defp offer_trained_kits(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Madeleine Chu]")
      |> mes("Sure, which kind")
      |> mes("of Cooking Kits")
      |> mes("did you need?")
      |> next()
      |> select([
        "Outdoor Cooking Kit - 500z",
        "Home Cooking Kit - 1,000z",
        "Show me a different kit.",
        "Quit"
      ])

    case choice do
      1 -> sell_cooking_kits(ctx, 12125)
      2 -> sell_cooking_kits(ctx, 12126)
      3 -> describe_other_kits(ctx)
      4 -> invite_kit_purchase(ctx)
      _ -> discuss_sir_charles(ctx)
    end
  end

  defp describe_other_kits(ctx) do
    ctx
    |> mes("[Madeleine Chu]")
    |> mes("Well, I only have two")
    |> mes("types of cooking kits,")
    |> mes("although there is a superior")
    |> mes("Professional Cooking Kit that")
    |> mes("real experts, like Sir Charles,")
    |> mes("use. Amazing, isn't it?")
    |> next()
    |> mes("[Madeleine Chu]")
    |> mes("You're still a beginner, so")
    |> mes("my kits will serve you well. ")
    |> mes("You know, there's a rumor about a cooking kit that can perfectly")
    |> mes("make any recipe, so long as all of the ingredients are provided.")
    |> next()
    |> mes("[Madeleine Chu]")
    |> mes("Of course, it's only")
    |> mes("a rumor, probably just")
    |> mes("the result of someone's")
    |> mes("weird imagination. I still")
    |> mes("believe skill is the most")
    |> mes("important ingredient~")
    |> close()
  end

  defp discuss_sir_charles(ctx) do
    ctx =
      ctx
      |> mes("[Madeleine Chu]")
      |> mes("Hm? Sir Charles is")
      |> mes("fine, but lately he's been")
      |> mes("getting a little upset at")
      |> mes("even small things. Still,")
      |> mes("I guess it's understandable.")
      |> next()
      |> set_local(:talk_j, Enum.random(1..3))

    case get_local(ctx, :talk_j, 0) do
      1 -> discuss_charles_and_the_king(ctx)
      2 -> discuss_charles_and_women(ctx)
      _ -> discuss_charles_new_recipe(ctx)
    end
  end

  defp discuss_charles_and_the_king(ctx) do
    ctx
    |> mes("[Madeleine Chu]")
    |> mes("You know, when I first")
    |> mes("met him, I assumed he was")
    |> mes("only good at cooking sweets")
    |> mes("like chocolates and caramels.")
    |> mes("However, he is highly skilled")
    |> mes("at cooking almost everything!")
    |> next()
    |> mes("[Madeleine Chu]")
    |> mes("I suppose he's been focusing")
    |> mes("on foods other than desserts")
    |> mes("ever since our king disappeared. I wonder if King Tristram III's")
    |> mes("disappearance is related to Sir")
    |> mes("Charles's change in mood?")
    |> close()
  end

  defp discuss_charles_and_women(ctx) do
    ctx
    |> mes("[Madeleine Chu]")
    |> mes("I mean, Sir Charles seems")
    |> mes("to be the type that has trouble")
    |> mes("opening up to other people.")
    |> mes("That may explain why he's much")
    |> mes("nicer to women than to men.")
    |> mes("Doesn't that make sense?")
    |> close()
  end

  defp discuss_charles_new_recipe(ctx) do
    ctx
    |> mes("[Madeleine Chu]")
    |> mes("Maybe it's because he's")
    |> mes("been experimenting with")
    |> mes("a new recipe lately. I think he")
    |> mes("mentioned something about")
    |> mes("wanting to treat some woman")
    |> mes("to the finest food ever made.")
    |> next()
    |> mes("[Madeleine Chu]")
    |> mes("I've never seen Sir Charles")
    |> mes("so excited before. That woman")
    |> mes("must be very lucky: she has the")
    |> mes("chance to eat his cooking every")
    |> mes("day if she wanted! I'm almost")
    |> mes("jealous of her, you know that?")
    |> close()
  end

  defp discuss_child_with_cat(ctx) do
    ctx
    |> mes("[Madeleine Chu]")
    |> mes("Oh, you mean the")
    |> mes("child with the cat?")
    |> mes("I'm not sure, but I think")
    |> mes("I overheard that she might")
    |> mes("be the younger sister of")
    |> mes("Madam Wickebine.")
    |> next()
    |> mes("[Madeleine Chu]")
    |> mes("I wonder why Sir Charles")
    |> mes("gives Madam Wickebine such")
    |> mes("special treatment. Whenever")
    |> mes("I ask him about it, he gets so")
    |> mes("upset and doesn't say anything!")
    |> next()
    |> cutin("orleans_6", 0)
    |> mes("[Charles Orleans]")
    |> mes("Mince alors!")
    |> mes("I just felt a chill down my")
    |> mes("spine... Could someone")
    |> mes("be talking about me?")
    |> close()
    |> cutin("", 255)
  end

  defp report_error(ctx) do
    ctx |> mes("[Madeleine Chu]") |> mes("Error occurred.") |> close()
  end

  defp sell_cooking_kits(ctx, item_id) do
    ctx = set_local(ctx, :item_id, item_id)
    ctx = set_local(ctx, :item_cost, getiteminfo(ctx, get_local(ctx, :item_id, 0), 0))

    ctx
    |> set_local(:item_weight, getiteminfo(ctx, get_local(ctx, :item_id, 0), 6))
    |> mes("[Madeleine Chu]")
    |> mes("How many #{kit_kind(item_id)}")
    |> mes("Cooking Kits would")
    |> mes("you like to buy? If you")
    |> mes("want to cancel, please")
    |> mes("enter the number 0.")
    |> next()
    |> request_kit_quantity()
  end

  defp kit_kind(12_125), do: "Outdoor"
  defp kit_kind(_item_id), do: "Indoor"

  defp request_kit_quantity(ctx) do
    {ctx, quantity} = input(ctx, :int)
    ctx = set_local(ctx, :sell, quantity)

    cond do
      get_local(ctx, :sell, 0) == 0 ->
        cancel_kit_purchase(ctx)

      get_local(ctx, :sell, 0) > 100 ->
        ctx
        |> mes("[Madeleine Chu]")
        |> mes("Oh, I'm sorry, but")
        |> mes("I don't sell more than")
        |> mes("100 #{Rathena.getitemname(get_local(ctx, :item_id, 0))}")
        |> mes("at a time, just to be safe.")
        |> next()
        |> request_kit_quantity()

      true ->
        complete_kit_purchase(ctx)
    end
  end

  defp cancel_kit_purchase(ctx) do
    ctx
    |> mes("[Madeleine Chu]")
    |> mes("You've changed your")
    |> mes("mind? Well, if you need")
    |> mes("to buy #{Rathena.getitemname(get_local(ctx, :item_id, 0))}")
    |> mes("Kits later, just come back")
    |> mes("to me at anytime, alright?")
    |> close()
  end

  defp complete_kit_purchase(ctx) do
    ctx = set_local(ctx, :total_cost, get_local(ctx, :sell, 0) * get_local(ctx, :item_cost, 0))

    ctx =
      set_local(ctx, :total_weight, get_local(ctx, :sell, 0) * get_local(ctx, :item_weight, 0))

    cond do
      zeny(ctx) < get_local(ctx, :total_cost, 0) ->
        ctx
        |> mes("[Madeleine Chu]")
        |> mes("Oh, I'm sorry, but you")
        |> mes("can't afford this many")
        |> mes("#{Rathena.getitemname(get_local(ctx, :item_id, 0))}")
        |> mes("Please check your zeny")
        |> mes("before purchasing my kits~")
        |> close()

      not Rathena.truthy?(
        checkweight(ctx, [{get_local(ctx, :item_id, 0), get_local(ctx, :sell, 0)}])
      ) ->
        ctx
        |> mes("[Madeleine Chu]")
        |> mes("I'm sorry, but you don't")
        |> mes("have enough room in your")
        |> mes("Inventory for this many")
        |> mes("#{Rathena.getitemname(get_local(ctx, :item_id, 0))}...")
        |> close()

      true ->
        ctx
        |> pay_zeny(get_local(ctx, :total_cost, 0))
        |> give_item(get_local(ctx, :item_id, 0), get_local(ctx, :sell, 0))
        |> mes("[Madeleine Chu]")
        |> mes("Here you are~")
        |> mes("Best of luck with")
        |> mes("your culinary training!")
        |> close()
    end
  end
end
