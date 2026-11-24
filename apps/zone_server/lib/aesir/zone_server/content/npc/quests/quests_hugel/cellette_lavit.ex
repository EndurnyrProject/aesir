defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.CelletteLavit do
  @moduledoc """
  Cellette sells Fish Cake Soup and hires players to deliver it.

  ## Behavior

  - Assigns a random customer or sells a bowl of soup.
  - Replaces lost deliveries for a fee and rewards completed deliveries.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "hu_in01", x: 15, y: 372, dir: 3, sprite: 74, name: "Cellette Lavit", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    delivery = get_char_var(ctx, :hg_odeng, 0)

    cond do
      not Rathena.truthy?(delivery) -> offer_soup(ctx)
      delivery in 1..4 -> pending_delivery(ctx, delivery)
      delivery == 5 -> refuse_service(ctx)
      delivery == 10 -> reward_delivery(ctx)
      true -> greet(ctx)
    end
  end

  defp offer_soup(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Cellette]")
      |> mes("Hi there, thanks for")
      |> mes("visiting our lovely town!")
      |> mes("Why don't you come in and")
      |> mes("have a taste of authentic")
      |> mes("Hugel cuisine? I guarantee")
      |> mes("that you won't regret it~")
      |> next()
      |> mes("[Cellette]")
      |> mes("My name is Cellette Lavit,")
      |> mes("and I proudly serve Fish Cake")
      |> mes("Soup, Hugel's specialty dish.")
      |> mes("All the tourists that've tried")
      |> mes("it have loved it, and I have")
      |> mes("many regular customers~")
      |> next()
      |> mes("[Cellette]")
      |> mes("This dish has something")
      |> mes("of a cult following, and it's")
      |> mes("not widely popularized, but I'm")
      |> mes("sure that it'll be considered")
      |> mes("representative of Schwarzwald")
      |> mes("Republic cuisine someday.")
      |> next()
      |> mes("[Cellette]")
      |> mes("Listen, you look like an")
      |> mes("able adventurer, so would")
      |> mes("you consider working part time")
      |> mes("for me? I have many orders for")
      |> mes("Fish Cake Soup, so there's")
      |> mes("no way I can make deliveries...")
      |> next()
      |> mes("[Cellette]")
      |> mes("If you work for me, I'll")
      |> mes("waive the price: I'll give you")
      |> mes("1 Fish Cake Soup for each")
      |> mes("delivery that you complete.")
      |> mes("But if you're not interested,")
      |> mes("you can just buy some now~")
      |> next()
      |> select(["Sure, I'll work for you!", "I want to buy Fish Cake Soup.", "See ya."])

    case choice do
      1 -> assign_delivery(ctx)
      2 -> buy_soup(ctx)
      3 -> decline(ctx)
      _ -> ctx
    end
  end

  defp assign_delivery(ctx) do
    ctx =
      ctx
      |> mes("[Cellette]")
      |> mes("Oh, thank you so much!")
      |> mes("You can't imagine how busy")
      |> mes("I've been, and how much I need the help! Now, let's get started~")
      |> next()

    case Enum.random(1..4) do
      1 -> assign_neha(ctx)
      2 -> assign_maewan(ctx)
      3 -> assign_layoma(ctx)
      4 -> assign_erjan(ctx)
      _ -> buy_soup(ctx)
    end
  end

  defp buy_soup(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Cellette]")
      |> mes("Oh, you'd like to try my")
      |> mes("Fish Cake Soup, eh? Good")
      |> mes("choice, I know you'll enjoy")
      |> mes("its delicious, hearty flavor~")
      |> mes("Each order costs 100 zeny.")
      |> next()
      |> select(["Order a Fish Cake Soup", "Cancel"])

    case choice do
      1 -> if zeny(ctx) > 99, do: sell_soup(ctx), else: insufficient_zeny(ctx)
      2 -> cancel_purchase(ctx)
      _ -> ctx
    end
  end

  defp pending_delivery(ctx, delivery) do
    if Rathena.truthy?(count_item(ctx, 584)) do
      delivery_reminder(ctx, delivery)
    else
      ctx = lost_soup(ctx, delivery)
      if zeny(ctx) > 99, do: replace_soup(ctx), else: deny_replacement(ctx)
    end
  end

  defp assign_neha(ctx) do
    ctx
    |> mes("[Cellette]")
    |> mes("Alright, please take this")
    |> mes("order of Fish Cake Soup to")
    |> mes("my friend Neha. I'm grateful")
    |> mes("that she's a regular customer--")
    |> mes("she's a good friend, but I'm sure that she loves the soup as well.")
    |> set_char_var(:hg_odeng, 1)
    |> setquest(8064)
    |> give_item(584, 1)
    |> close()
  end

  defp assign_maewan(ctx) do
    ctx
    |> mes("[Cellette]")
    |> mes("Right, take this next order")
    |> mes("of Fish Cake Soup to Maewan,")
    |> mes("another one of my regulars.")
    |> mes("He's been buying my soup ever")
    |> mes("since I helped him start his business. Nice of him, isn't it?")
    |> set_char_var(:hg_odeng, 2)
    |> setquest(8065)
    |> give_item(584, 1)
    |> close()
  end

  defp assign_layoma(ctx) do
    ctx
    |> mes("[Cellette]")
    |> mes("Okay, this order of Fish")
    |> mes("Cake Soup is ready! Please")
    |> mes("take it to my roommate Layoma.")
    |> mes("But... Be careful. She's got")
    |> mes("a thing about punctuality.")
    |> mes("Just try not to be late...")
    |> set_char_var(:hg_odeng, 3)
    |> setquest(8066)
    |> give_item(584, 1)
    |> close()
  end

  defp assign_erjan(ctx) do
    ctx
    |> mes("[Cellette]")
    |> mes("Quick, take this Fish")
    |> mes("Paste Soup to Erjan. Um,")
    |> mes("but be careful, he's really")
    |> mes("nitpicky... And he likes to")
    |> mes("have everything in such")
    |> mes("and such and order...")
    |> set_char_var(:hg_odeng, 4)
    |> setquest(8067)
    |> give_item(584, 1)
    |> close()
  end

  defp sell_soup(ctx) do
    ctx
    |> mes("[Cellette]")
    |> mes("Thanks! Enjoy your")
    |> mes("bowl of Fish Cake Soup.")
    |> mes("I hope you come and ")
    |> mes("visit me again, okay?")
    |> pay_zeny(100)
    |> give_item(584, 1)
    |> close()
  end

  defp insufficient_zeny(ctx) do
    ctx
    |> mes("[Cellette]")
    |> mes("Oh, what's this?")
    |> mes("You don't have enough")
    |> mes("money? Well, come back")
    |> mes("after you save 100 zeny.")
    |> mes("That's a really good price")
    |> mes("for my gourmet soup, you know.")
    |> close()
  end

  defp cancel_purchase(ctx) do
    ctx
    |> mes("[Cellette]")
    |> mes("If you're ever hungry,")
    |> mes("or just want to enjoy")
    |> mes("a delicious meal, come")
    |> mes("and have some of my soup~")
    |> close()
  end

  defp decline(ctx) do
    ctx
    |> mes("[Cellette]")
    |> mes("Oh? You're not interested")
    |> mes("in trying my Fish Cake Soup")
    |> mes("at all? Well, if you change")
    |> mes("your mind, please come")
    |> mes("back. I just know you'll love")
    |> mes("the taste if you give it a try.")
    |> close()
  end

  defp replace_soup(ctx) do
    ctx
    |> mes("[Cellette]")
    |> mes("But you need to be")
    |> mes("responsible and pay")
    |> mes("me for the food you lost.")
    |> mes("There, I took 100 zeny")
    |> mes("from you. That's fair, so")
    |> mes("please don't lose it this time.")
    |> pay_zeny(100)
    |> give_item(584, 1)
    |> close()
  end

  defp deny_replacement(ctx) do
    ctx
    |> mes("[Cellette]")
    |> mes("W-wait... You don't")
    |> mes("have any money to pay")
    |> mes("me for the soup you lost?")
    |> mes("Well, I don't think I can")
    |> mes("trust somebody like you")
    |> mes("with any deliveries...")
    |> set_char_var(:hg_odeng, 5)
    |> close()
  end

  defp refuse_service(ctx) do
    ctx
    |> mes("[Cellette]")
    |> mes("Ah, I'm sorry, but")
    |> mes("I can't do any business")
    |> mes("with somebody that's proven")
    |> mes("to be irresponsible. Nothing")
    |> mes("personal, it's just my policy.")
    |> close()
  end

  defp greet(ctx) do
    ctx
    |> mes("[Cellette]")
    |> mes("Come and taste some")
    |> mes("authentic Hugel cuisine!")
    |> mes("Enjoy a big steaming bowl")
    |> mes("of delicious Fish Cake Soup~")
    |> close()
  end

  defp delivery_reminder(ctx, 1) do
    ctx
    |> mes("[Cellette]")
    |> mes("Haven't you left already?")
    |> mes("My friend Neha is waiting")
    |> mes("for you to deliver her order")
    |> mes("of Fish Cake Soup. Please")
    |> mes("try to get it to her before the")
    |> mes("soup gets cold, okay?")
    |> close()
  end

  defp delivery_reminder(ctx, 2) do
    ctx
    |> mes("[Cellette]")
    |> mes("Whoa, whoa, whoa!")
    |> mes("You should have left")
    |> mes("already to deliver that")
    |> mes("soup to Maewan! Hurry,")
    |> mes("before it gets too cold!")
    |> close()
  end

  defp delivery_reminder(ctx, 3) do
    ctx
    |> mes("[Cellette]")
    |> mes("I thought you left to")
    |> mes("deliver that soup to")
    |> mes("Layoma. You should hurry")
    |> mes("and bring it to her, before")
    |> mes("it doesn't taste good after")
    |> mes("it gets cold, you know.")
    |> close()
  end

  defp delivery_reminder(ctx, 4) do
    ctx
    |> mes("[Cellette]")
    |> mes("Oh, dear, you better")
    |> mes("leave now and deliver")
    |> mes("that Fish Cake Soup to")
    |> mes("Erjan before he can think")
    |> mes("of something to complain about. Although it's probably too late...")
    |> close()
  end

  defp lost_soup(ctx, 1) do
    ctx
    |> mes("[Cellette]")
    |> mes("What's that? You lost")
    |> mes("the Fish Cake Soup you're")
    |> mes("supposed to deliver to Neha?")
    |> mes("Oh well, I suppose I'll have")
    |> mes("to give you this fresh bowl")
    |> mes("of soup that I just made...")
    |> next()
  end

  defp lost_soup(ctx, 2) do
    ctx
    |> mes("[Cellette]")
    |> mes("What's that? You lost")
    |> mes("the Fish Cake Soup you're")
    |> mes("supposed to give to Maewan?")
    |> mes("Oh well, I suppose I'll have")
    |> mes("to give you this fresh bowl")
    |> mes("of soup that I just made...")
    |> next()
  end

  defp lost_soup(ctx, 3) do
    ctx
    |> mes("[Cellette]")
    |> mes("What's that? You lost")
    |> mes("the Fish Cake Soup you're")
    |> mes("supposed to give to Layoma?")
    |> mes("Oh well, I suppose I'll have")
    |> mes("to give you this fresh bowl")
    |> mes("of soup that I just made...")
    |> next()
  end

  defp lost_soup(ctx, 4) do
    ctx
    |> mes("[Cellette]")
    |> mes("What's that? You lost")
    |> mes("the Fish Cake Soup you're")
    |> mes("supposed to deliver to Erjan?")
    |> mes("Oh well, I suppose I'll have")
    |> mes("to give you this fresh bowl")
    |> mes("of soup that I just made...")
    |> next()
  end

  defp reward_delivery(ctx) do
    ctx =
      ctx
      |> mes("[Cellette]")
      |> mes("Good work! I hear that")
      |> mes("you successfully delivered")
      |> mes("the soup. I knew I could trust")
      |> mes("you! Ah, before I forget, here")
      |> mes("is your Fish Cake Soup. Thank")
      |> mes("you so much for your help~")
      |> set_char_var(:hg_odeng, 0)
      |> set_local(:i, 8072)
      |> erase_delivery_quests()
      |> give_item(584, 3)

    ctx
    |> getexp(if(Rathena.truthy?(checkre(ctx, 3)), do: 100, else: 1000), 0)
    |> next()
    |> mes("[Cellette]")
    |> mes("It was really nice working")
    |> mes("with you, and I hope you come")
    |> mes("by and help me again sometime.")
    |> mes("Oh, and please tell all your")
    |> mes("friends about my delicious")
    |> mes("Fish Cake Soup. See you later~")
    |> close()
  end

  defp erase_delivery_quests(ctx) do
    if get_local(ctx, :i, 0) <= 8075 do
      ctx =
        if checkquest(ctx, get_local(ctx, :i, 0)) > -1 do
          erasequest(ctx, get_local(ctx, :i, 0))
        else
          ctx
        end

      ctx |> set_local(:i, get_local(ctx, :i, 0) + 1) |> erase_delivery_quests()
    else
      ctx
    end
  end
end
