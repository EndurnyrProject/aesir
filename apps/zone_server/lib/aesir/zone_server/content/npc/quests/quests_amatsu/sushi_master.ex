defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.SushiMaster do
  @moduledoc """
  Amatsu sushi chef who sells Sushi and Fish Slices and hands out ingredient errands.

  ## Behavior

  - Refuses to talk to overweight players, and only gives advice once the knife quest is done.
  - Sells Sushi (700z a set of 10, 74z each) and Fish Slices (350z a set of 10, 37z each).
  - Non-novices asking to help get a random errand: 10 Candy, 10 Crab Shells, 10 Conches,
    10 Fish Tails, 1 China or, rarely, 100 Hearts of Mermaid.
  - Delivering an errand's items rewards Sushi and/or Fish Slices and clears the errand.
  - Delivering 100 Hearts of Mermaid turns all of them into food the first two times; the third
    time he takes them and passes on his Sashimi knife, ending the quest.
  - Without the requested items he repeats the request.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - MasterOfMuppets
    - L0ne_W0lf
    - Gepard
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ama_in01",
        x: 162,
        y: 17,
        dir: 1,
        sprite: 765,
        name: "Sushi Master",
        scope: :shared,
        unique_name: "Sushi Master#ama"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @sushi 551
  @fish_slice 544
  @candy 529
  @crab_shell 964
  @conch 961
  @fish_tail 1023
  @white_platter 736
  @heart_of_mermaid 950
  @sashimi 1144

  @impl true
  def on_talk(ctx) do
    cond do
      max_weight(ctx) - weight(ctx) < 5000 -> overweight(ctx)
      get_char_var(ctx, :ama_sushi, 0) == 4 -> master_advice(ctx)
      true -> errand(ctx, get_char_var(ctx, :fish_r, 0))
    end
  end

  defp overweight(ctx) do
    ctx
    |> say([
      "Hey. You look really heavy.",
      "Don't you have trouble walking?",
      "I'm sorry, but there is no space",
      "to put down your stuff in my shop."
    ])
    |> next()
    |> say([
      "Put some of your stuff away somewhere.",
      "Why are you carrying so much...?",
      "Huhuhu..."
    ])
    |> close()
  end

  defp master_advice(ctx) do
    ctx
    |> say([
      "Training to slice raw fish",
      "daily will make you a master sushi chef.",
      "So don't waste your time in here, and learn what you are good at.",
      " "
    ])
    |> close()
  end

  defp errand(ctx, 1) do
    if count_item(ctx, @candy) > 9 do
      ctx
      |> thank(
        "I really need them to make a dessert.",
        "Thanks. It's nothing, but",
        "I will give you my shop's special cuisine, Fish Slice, in return."
      )
      |> set_char_var(:fish_r, 0)
      |> erasequest(10_036)
      |> delitem(@candy, 10)
      |> give_item(@fish_slice, 15)
      |> say([
        "Here's 15 fish slices.",
        "Please enjoy this food with your friends.",
        "And come back whenever you miss the flavor of Amatsu cuisine."
      ])
      |> close()
    else
      remind(ctx, ["10 ^0000FFCandy^000000"], "Bring me these supplies, please.")
    end
  end

  defp errand(ctx, 2) do
    if count_item(ctx, @crab_shell) > 9 do
      ctx
      |> thank(
        "I need them to make a sauce.",
        "Thanks. It is nothing, but",
        "I will give you two sets of Sushi in return."
      )
      |> set_char_var(:fish_r, 0)
      |> erasequest(10_037)
      |> delitem(@crab_shell, 10)
      |> give_item(@sushi, 20)
      |> say(["Share it with your friends", "and family members.", "Please come again."])
      |> close()
    else
      remind(ctx, ["10 ^0000FFCrab Shells^000000..."], "Bring me these supplies, please.")
    end
  end

  defp errand(ctx, 3) do
    if count_item(ctx, @conch) > 9 do
      ctx
      |> thank(
        "I was preparing appetizers...",
        "Thanks. It is nothing but",
        "I will give you several sets of Sushi in return."
      )
      |> set_char_var(:fish_r, 0)
      |> erasequest(10_038)
      |> delitem(@conch, 10)
      |> give_item(@sushi, 30)
      |> say([
        "These are for three people,",
        "so share them with your friends.",
        "Come back again if you feel like helping out some more."
      ])
      |> close()
    else
      remind(ctx, ["10 ^0000FFConches^000000"], "Bring me these supplies, please.")
    end
  end

  defp errand(ctx, 4) do
    if count_item(ctx, @fish_tail) > 9 do
      ctx
      |> thank(
        "I was decorating a platter.",
        "Thanks. It is nothing but",
        "I will give you a large amount of food in return."
      )
      |> set_char_var(:fish_r, 0)
      |> erasequest(10_039)
      |> delitem(@fish_tail, 10)
      |> give_item(@fish_slice, 20)
      |> give_item(@sushi, 30)
      |> say(["You can feed your guild", "with this food.", "Come back with a friend."])
      |> close()
    else
      remind(ctx, ["10 ^0000FFFish Tails^000000"], "Bring me these supplies, please.")
    end
  end

  defp errand(ctx, 5) do
    if count_item(ctx, @white_platter) > 0 do
      ctx
      |> thank(
        "I didn't have a white platter.",
        "Thanks. It is nothing but",
        "I will give you two sets of Sushi in return."
      )
      |> delitem(@white_platter, 1)
      |> set_char_var(:fish_r, 0)
      |> erasequest(10_040)
      |> give_item(@sushi, 20)
      |> say(["Share it with your friends", "and family members.", "Please come again."])
      |> close()
    else
      remind(
        ctx,
        ["I need a white platter:", "1 ^0000FFChina^000000"],
        "Bring it to me, okay?"
      )
    end
  end

  defp errand(ctx, 6) do
    cond do
      count_item(ctx, @heart_of_mermaid) <= 99 ->
        remind(
          ctx,
          ["100 ^0000FFHearts of Mermaid^000000, okay?"],
          "Bring me the supplies, please."
        )

      get_char_var(ctx, :ama_sushi, 0) == 2 ->
        pass_on_knife(ctx)

      true ->
        mermaid_feast(ctx)
    end
  end

  defp errand(ctx, _fish_r), do: shop(ctx)

  defp pass_on_knife(ctx) do
    ctx
    |> say([".............................."])
    |> next()
    |> say([
      "You are a really kind person.",
      "You have brought everything",
      "that I've asked you..."
    ])
    |> next()
    |> say([
      "You are not the first foreigner",
      "I have encountered. Amatsu is getting more and more tourists.",
      "I just wanted to test you.",
      " "
    ])
    |> next()
    |> say([
      "Your job was just errands but",
      "I wanted to know...",
      "how you devote yourself,",
      "how serious you are about completing your job and not giving up."
    ])
    |> next()
    |> say([
      "I was thinking,",
      "'If there is a person like that,",
      "I would give that person everything about cooking that I have mastered"
    ])
    |> next()
    |> say(["And.....", "You...", "You are the one."])
    |> next()
    |> say([
      "I'm old now. No one knows how long I can hold this knife. You have been chosen to inherit my culinary art...",
      " "
    ])
    |> next()
    |> delitem(@heart_of_mermaid, 100)
    |> set_char_var(:ama_sushi, 4)
    |> completequest(10_041)
    |> give_item(@sashimi, 1)
    |> say([
      "Here, take my knife.",
      "From now on, make fine cuisine with that knife.",
      "...Learn how to slice a fish.",
      " ",
      " "
    ])
    |> next()
    |> say([
      "From now on, I will no longer ask you favors and give you fish slices in return....",
      "Practice your skill with that knife and teach mainlanders the pleasure of fine cuisine..."
    ])
    |> close()
  end

  defp mermaid_feast(ctx) do
    ctx =
      ctx
      |> say([
        "Wow...these are real hearts of",
        "mermaid. The legends saying",
        "that these could be found in another continent were true...",
        " "
      ])
      |> next()
      |> say([
        "Gathering all these must have been hard...Well, then.",
        "Today, I will use all of my",
        "ingredients to make a special cuisine for you!"
      ])
      |> next()
      |> say(["Give me a moment...", "I shall show you my ^0000FFtrue culinary skill^000000."])
      |> next()
      |> delitem(@heart_of_mermaid, 20)
      |> give_item(@sushi, 20)
      |> say(["Try these first.", "Made from the freshest ingredients."])
      |> next()
      |> delitem(@heart_of_mermaid, 20)
      |> give_item(@fish_slice, 20)
      |> say(["Try these too.", "My shop's fish slices are the best of the best!"])
      |> next()
      |> delitem(@heart_of_mermaid, 20)
      |> give_item(@sushi, 20)
      |> say(["Have some more. Don't say no...!", "Isn't it good? Huh? Isn't it good?"])
      |> next()
      |> delitem(@heart_of_mermaid, 20)
      |> give_item(@fish_slice, 20)
      |> say(["Haha~! Not done yet!", "It's okay, have some more!"])
      |> next()
      |> delitem(@heart_of_mermaid, 20)
      |> give_item(@fish_slice, 10)
      |> give_item(@sushi, 10)
      |> say([
        "Take the leftovers.",
        "You look stuffed...",
        "Share the rest with your friends and family."
      ])
      |> next()

    ctx
    |> set_char_var(:ama_sushi, get_char_var(ctx, :ama_sushi, 0) + 1)
    |> set_char_var(:fish_r, 0)
    |> erasequest(10_041)
    |> say([
      "Thanks a lot for today! Haha!",
      "Come back again when you feel like helping. Take care...!!!"
    ])
    |> close()
  end

  defp shop(ctx) do
    {ctx, choice} =
      ctx
      |> say([
        "Holy cow~",
        "This is a problem.....",
        "There are so many customers, but I can't get all the ingredients that I need..."
      ])
      |> next()
      |> say([
        "This is horrible...",
        "Some of my customers will not get",
        "the chance to eat fine Amatsu cuisine...",
        " "
      ])
      |> next()
      |> say([
        "Well, well. Are you a customer?",
        "Welcome. As always, my shop",
        "highly values the freshness of",
        "fish slices. What brings you down here...?"
      ])
      |> next()
      |> select([
        "I would like to buy Sushi",
        "I would like to buy fish slice",
        "Do you need assistance?",
        "Keep up the good work"
      ])

    shop_choice(ctx, choice)
  end

  defp shop_choice(ctx, 1) do
    {ctx, choice} =
      ctx
      |> say([
        "Alright...! How many?",
        "A set of Sushi is 700z. If you",
        "want just 1 Sushi. It is 74z.",
        "If you want more, tell me."
      ])
      |> next()
      |> select(["700z A set!", "74z A piece!", "I will try it later"])

    case choice do
      1 ->
        buy(ctx, 700, @sushi, 10, [
          "Oh man, you don't have enough money.",
          "If you want to eat delicious fish slices, you better bring more money."
        ])

      2 ->
        buy(ctx, 74, @sushi, 1, [
          "Oh man, you don't have enough money.",
          "If you want to eat delicious Sushi,",
          "you better bring more money."
        ])

      3 ->
        ctx
        |> say([
          "Up to you. My Sushi is",
          "the best of the best! The taste",
          "and freshness are the best in the",
          "world. If you have time, try my Sushi."
        ])
        |> close()

      _ ->
        ctx
    end
  end

  defp shop_choice(ctx, 2) do
    {ctx, choice} =
      ctx
      |> say([
        "Alright...! How many?",
        "A set of fish slices is 350z.",
        "1 fish slice is 37z.",
        "If you want more, tell me."
      ])
      |> next()
      |> select(["350z A set!", "37z A piece!", "I will try it later"])

    case choice do
      1 ->
        buy(ctx, 350, @fish_slice, 10, [
          "Oh man, you don't have enough money.",
          "If you want to eat delicious fish slices, you better bring more money."
        ])

      2 ->
        buy(ctx, 37, @fish_slice, 1, [
          "Oh man, you don't have enough money.",
          "If you want to eat delicious fish slice, you better bring more money."
        ])

      3 ->
        ctx
        |> say([
          "Up to you. My fish slice is",
          "the best of the best! The taste",
          "and freshness are the best in the",
          "world. If you have time, try my fish slices."
        ])
        |> close()

      _ ->
        ctx
    end
  end

  defp shop_choice(ctx, 3) do
    if Rathena.job_id(base_job(ctx)) == Rathena.job_id(:novice) do
      ctx
      |> say([
        "Haha~ YOU are the one who needs",
        "assistance! Help others",
        "when you can take care of yourself.",
        " "
      ])
      |> close()
    else
      ctx
      |> say([
        "Some help would be great~!!",
        "I was worried because we always",
        "run out of ingredients...",
        "Will you do me a favor?",
        "I will reward you."
      ])
      |> next()
      |> assign_errand(Enum.random(1..10))
      |> next()
      |> say([
        "Well, good luck to you...",
        "I will be waiting for you.",
        "Don't forget what I asked..."
      ])
      |> close()
    end
  end

  defp shop_choice(ctx, 4) do
    ctx
    |> say([
      "Haha, you won't forget the flavor of my fish slice once you've",
      "tasted it. If you have time, try my fish slices.",
      " "
    ])
    |> close()
  end

  defp shop_choice(ctx, _choice), do: ctx

  defp assign_errand(ctx, roll) when roll in [1, 2] do
    ctx
    |> set_char_var(:fish_r, 1)
    |> setquest(10_036)
    |> say([
      "I need some candies to make",
      "a dessert for the customers.",
      "Bring me ^0000FF10 Candy^000000.",
      "It's not hard, right?",
      " "
    ])
  end

  defp assign_errand(ctx, roll) when roll in [3, 4] do
    ctx
    |> set_char_var(:fish_r, 2)
    |> setquest(10_037)
    |> say([
      "I need some crab shells to make",
      "a sauce for my cuisine...",
      "If you bring me ^0000FF10 Crab Shells^000000,",
      "I will reward you.",
      "Okay?"
    ])
  end

  defp assign_errand(ctx, roll) when roll in [5, 6] do
    ctx
    |> set_char_var(:fish_r, 3)
    |> setquest(10_038)
    |> say([
      "I have used all of my conches.",
      "I need it to make an appetizer...",
      "Please bring me ^0000FF10 Conches^000000.",
      "It is hard to find conches around here...",
      "Please do me this favor."
    ])
  end

  defp assign_errand(ctx, roll) when roll in [7, 8] do
    ctx
    |> set_char_var(:fish_r, 4)
    |> setquest(10_039)
    |> say([
      "Decorative fish tails are out of",
      "stock. This is urgent...",
      "Please bring me ^0000FF10 fish tails^000000.",
      "They are always missing when I need them badly...",
      "Please do me this favor."
    ])
  end

  defp assign_errand(ctx, 9) do
    ctx
    |> set_char_var(:fish_r, 5)
    |> setquest(10_040)
    |> say([
      "We are missing a platter to serve",
      "fish slices to customers.",
      "This is horrible...",
      "Will you buy me some fine porcelain ^0000FFChina^000000?",
      "I can't just put food anywhere..."
    ])
  end

  defp assign_errand(ctx, _roll) do
    if Enum.random(1..10) == 1 do
      ctx
      |> set_char_var(:fish_r, 6)
      |> setquest(10_041)
      |> say([
        "Don't ask me why...",
        "But, I need something special...",
        "^0000FF100 Hearts of Mermaid^000000.....",
        "I know that it sounds impossible, but it is really important to me..."
      ])
      |> next()
      |> say([
        "Don't ask any questions",
        "about my request...",
        "Just keep what I want in mind."
      ])
    else
      ctx
      |> set_char_var(:fish_r, 5)
      |> setquest(10_040)
      |> say([
        "We are missing a platter to serve",
        "fish slices to customers.",
        "This is horrible...",
        "Will you buy me some fine porcelain ^0000FFChina^000000? I can't just put food anywhere..."
      ])
    end
  end

  defp buy(ctx, price, item_id, amount, short_of_money) do
    if zeny(ctx) < price do
      ctx
      |> say(short_of_money)
      |> close()
    else
      ctx
      |> pay_zeny(price)
      |> give_item(item_id, amount)
      |> say(["There you go. If you like the taste, please order some more."])
      |> close()
    end
  end

  defp thank(ctx, reason, gratitude, offer) do
    ctx
    |> say(["Oh! I really appreciate it.", "Right on time!", reason])
    |> next()
    |> say([gratitude, offer])
    |> next()
  end

  defp remind(ctx, request, closing) do
    ctx
    |> say(["Oh man, you didn't prepare", "what I asked for...", "Do not forget what I asked."])
    |> next()
    |> say(request ++ ["You didn't forget it, right?", closing])
    |> close()
  end

  defp say(ctx, lines), do: Enum.reduce(["[Magumagu]" | lines], ctx, &mes(&2, &1))
end
