defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.Employee25345 do
  @moduledoc """
  Song Zhi Du tends the medicine storage and seeks revenge for his master.

  ## Behavior

  - Discusses his master and recruits the player for his poison plot.
  - Requests ingredients and a delivery, then prepares poison and rewards assistance.
  - Responds to the player's progress and the outcome of the revenge plot.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Paradox924X
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lou_in02",
        x: 253,
        y: 45,
        dir: 0,
        sprite: 822,
        name: "Employee",
        scope: :shared,
        unique_name: "Employee#poison"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{1201, 1}]) == 0 ->
        overweight(ctx)

      get_char_var(ctx, :ch_par, 0) < 10 and get_char_var(ctx, :ch_poison, 0) < 6 ->
        initial_conversation(ctx)

      get_char_var(ctx, :ch_par, 0) > 9 and get_char_var(ctx, :ch_poison, 0) < 5 ->
        ask_about_poison(ctx)

      get_char_var(ctx, :ch_par, 0) > 9 and get_char_var(ctx, :ch_poison, 0) == 5 ->
        discuss_revenge(ctx)

      get_char_var(ctx, :ch_par, 0) > 9 and get_char_var(ctx, :ch_poison, 0) == 6 ->
        respond_to_disappointment(ctx)

      get_char_var(ctx, :ch_par, 0) > 9 and get_char_var(ctx, :ch_poison, 0) == 7 ->
        collect_ingredients(ctx)

      get_char_var(ctx, :ch_par, 0) > 9 and get_char_var(ctx, :ch_poison, 0) == 8 ->
        request_delivery(ctx)

      get_char_var(ctx, :ch_par, 0) > 9 and get_char_var(ctx, :ch_poison, 0) == 9 ->
        receive_delivery(ctx)

      get_char_var(ctx, :ch_par, 0) > 9 and get_char_var(ctx, :ch_poison, 0) == 10 ->
        prepare_poison(ctx)

      get_char_var(ctx, :ch_par, 0) > 9 and get_char_var(ctx, :ch_poison, 0) == 11 ->
        assign_poisoning(ctx)

      get_char_var(ctx, :ch_par, 0) > 9 and get_char_var(ctx, :ch_poison, 0) == 12 ->
        remind_about_poisoning(ctx)

      get_char_var(ctx, :ch_par, 0) > 9 and get_char_var(ctx, :ch_poison, 0) == 13 ->
        reward_assistance(ctx)

      get_char_var(ctx, :ch_par, 0) > 9 and get_char_var(ctx, :ch_poison, 0) == 14 ->
        after_revenge(ctx)

      get_char_var(ctx, :ch_par, 0) > 9 and get_char_var(ctx, :ch_poison, 0) == 15 and
          get_char_var(ctx, :ch_poison, 0) < 20 ->
        question_failed_plot(ctx)

      get_char_var(ctx, :ch_par, 0) > 9 and get_char_var(ctx, :ch_poison, 0) == 20 ->
        resolve_revenge(ctx)

      get_char_var(ctx, :ch_poison, 0) > 20 ->
        after_resolution(ctx)

      true ->
        default_conversation(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp sort_medicine(ctx) do
    if get_local(ctx, :r_o_o_f, 0) > 5 do
      ctx
    else
      ctx =
        if Enum.random(1..4) > 2 do
          ctx
          |> set_local(:r_o_o_f, get_local(ctx, :r_o_o_f, 0) + 1)
          |> mes("[Song Zhi Du]")
          |> mes("Let's see, there's that medicine, and then the medicine over here...")
          |> next()
        else
          ctx |> mes("[Song Zhi Du]") |> mes("...") |> mes("......") |> next()
        end

      sort_medicine(ctx)
    end
  end

  defp overweight(ctx) do
    ctx
    |> mes("^3355FF * Wait a minute! *")
    |> mes(
      "You're carrying too many items with you right now. Please put some of your things into Kafra Storage and try again.^000000"
    )
    |> close()
  end

  defp initial_conversation(ctx) do
    {ctx, choice} =
      ctx
      |> sort_medicine()
      |> mes("[Song Zhi Du]")
      |> mes("I feel like you're looking at me. Is there something that you want?")
      |> next()
      |> select([
        "......",
        "Ask him about his master.",
        "Ask about Poison Organization.",
        "Ask why he's working here."
      ])

    case choice do
      1 ->
        ctx
        |> mes("[Song Zhi Du]")
        |> mes(
          "I guess there's nothing you really need from me. Well then, if you'll excuse me..."
        )
        |> close()

      2 ->
        ctx
        |> mes("[Song Zhi Du]")
        |> mes(
          "Oh, I'm sorry, but I'm kind of busy right now. You see, we're running out of medicine..."
        )
        |> next()
        |> mes("[Song Zhi Du]")
        |> mes("My master, Hua Tuo,")
        |> mes(
          "is also having difficulty treating all of his patients. I must get him the medicine that he needs..."
        )
        |> close()

      3 ->
        {ctx, answer} =
          ctx
          |> mes("[Song Zhi Du]")
          |> mes("What...?")
          |> mes("What did")
          |> mes("you just say...?")
          |> next()
          |> input(:string)

        ctx = ctx |> set_local(:"input$", answer) |> mes("[Song Zhi Du]")

        ctx
        |> mes(Rathena.concat(Rathena.concat("", get_local(ctx, :"input$", "")), "...?"))
        |> next()
        |> mes("[Song Zhi Du]")
        |> mes(
          "I've never heard of that organization in my life. I'm sorry I can't help you. Now, if you'll excuse me..."
        )
        |> close()

      4 ->
        {ctx, _} =
          ctx
          |> mes("[Song Zhi Du]")
          |> mes(
            "Of course I'm working here to learn about medicine. I'm grateful for the chance to work under the most famous doctor in this area."
          )
          |> next()
          |> mes("[Song Zhi Du]")
          |> mes(
            "Doctor Hua Tuo is such a great person. I'm more than happy to assist him in saving the lives of others with his medical knowledge."
          )
          |> next()
          |> mes("[Song Zhi Du]")
          |> mes(
            "Even though I'm just in charge of the medicine storage, I'm working hard to become his disciple someday."
          )
          |> next()
          |> mes("[Song Zhi Du]")
          |> mes(
            "And working with Doctor Hua Tuo is really worthwhile. Well, sometimes it's really hard to supply medicine when we have too many patients though."
          )
          |> next()
          |> select(["Why don't you gather medicinal herbs then?"])

        ctx
        |> mes("[Song Zhi Du]")
        |> mes("My job is keeping this storage.")
        |> mes(
          "I'm not supposed to leave my position. I need to organize the herbs, and make sure they're in good condition."
        )
        |> close()

      _ ->
        ctx
    end
  end

  defp ask_about_poison(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Song Zhi Du]")
      |> mes(
        "Well, well. Thank you for your trouble. I didn't expect you to gather all these herbs for us..."
      )
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes("I suppose I underestimated you. By the way, do you know anything about poison?")
      |> next()
      |> select(["Yes, I am kind of interested in it.", "No, not at all."])

    if choice == 1 do
      ctx
      |> mes("[Song Zhi Du]")
      |> mes(
        "Oh, I see. Well, if you have some time, why don't you go visit my old master in the slums?"
      )
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes("If you two get along, I will tell you something important.")
      |> close()
    else
      ctx
      |> mes("[Song Zhi Du]")
      |> mes(
        "Huh. I see. Well, thank you for your trouble once again. I hope you have a good time in Luoyang."
      )
      |> close()
    end
  end

  defp discuss_revenge(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Song Zhi Du]")
      |> mes("...")
      |> mes("So, did you talk")
      |> mes("to my old master?")
      |> mes("It seems he really")
      |> mes("likes you.")
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes(
        "As you know, my master has been accused of something he didn't do! And they crippled his use of the martial arts!"
      )
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes("I can't forgive what")
      |> mes("they've have done to my master!")
      |> mes("I want to grind their bones")
      |> mes("to powder! And that's before")
      |> mes("I kill them!")
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes("He's innocent and all he did")
      |> mes("was research poison with all")
      |> mes("of his effort! And for that,")
      |> mes("they destroyed him!")
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes("I was young")
      |> mes("when it happened...")
      |> mes("Too young to know")
      |> mes("any martial arts.")
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes("I couldn't protect him.")
      |> mes("All I could do was hide and")
      |> mes("watch other people get killed.")
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes("I hate myself")
      |> mes("for not being strong!")
      |> mes("But, my body isn't suited")
      |> mes("for martial arts.")
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes(
        "All I can do is maintain my weak body and make sure it's reasonably healthy. Even so, if it weren't for my master, I'd be dead"
      )
      |> mes("in the streets...")
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes(
        "It was my master who picked me up from the streets and cured me. So, I've decided to become a doctor and save as many lives as I can."
      )
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes("But before")
      |> mes("I do that,")
      |> mes("I want ^FF0000revenge^000000!")
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes("As I told you, I am weak.")
      |> mes("Too weak... I know that from")
      |> mes("the bottom of my heart.")
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes("But...")
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes(
        "I am knowledgable about medicine, especially the use of poison. I can tell you that I'm one of the best."
      )
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes(
        "Poison can kill people but it can also be used to save lifes. The people who destroyed my master"
      )
      |> mes("will pay the price.")
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes("Do you understand")
      |> mes("why I'm furious!?")
      |> next()
      |> select(["But revenge isn't good.", "Yes, I fully understand."])

    if choice == 1 do
      ctx
      |> mes("[Song Zhi Du]")
      |> mes("Hmm...")
      |> mes("I see.")
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes("I suppose you couldn't")
      |> mes("understand the way I feel.")
      |> mes("After all, you didn't have")
      |> mes("to go through the same")
      |> mes("things I did.")
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes(
        "I suppose I expected too much, since my master likes you. How could you know the rage and"
      )
      |> mes("sadness that I feel!?")
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes("Fine.")
      |> mes("Go do whatever")
      |> mes("you were going to do.")
      |> mes("I'm just disappointed...")
      |> set_char_var(:ch_poison, 6)
      |> changequest(11070, 11071)
      |> close()
    else
      ctx
      |> mes("[Song Zhi Du]")
      |> mes("Yes! Yes!")
      |> mes("You do understand!")
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes(
        "I volunteered for this medicine storage position so that I can secretly study poison! Now, the time for action has come!"
      )
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes("Still, I'll need some materials to complete my research. Then, when")
      |> mes(
        "I succeed and create a poison pill, I'll need someone to carry my revenge out for me."
      )
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes(
        "Since my body is so frail, I can't bear the tension and rage of seeing my lifelong enemy face to face."
      )
      |> set_char_var(:ch_poison, 8)
      |> changequest(11070, 11073)
      |> close()
    end
  end

  defp respond_to_disappointment(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Song Zhi Du]")
      |> mes("I'm so disappointed.")
      |> mes("You've even seen the")
      |> mes("pitiable state of my")
      |> mes("master for yourself!")
      |> mes("How could you not")
      |> mes("understand me?!")
      |> next()
      |> select(["I'm sorry for last time.", "No matter what, revenge isn't good."])

    if choice == 1 do
      ctx
      |> mes("[Song Zhi Du]")
      |> mes("If you really")
      |> mes("feel sorry for me,")
      |> mes("then you must help me")
      |> mes("carry out my revenge!")
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes("I still need to complete the")
      |> mes(
        "poison potion I'm creating. I hope you can bring what I need to finish it. Go and get me..."
      )
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes("^0000FF4 Bee Sting,")
      |> mes("10 Venom Canine,")
      |> mes("10 Empty Potion,")
      |> mes("30 Green Potion^000000.")
      |> set_char_var(:ch_poison, 7)
      |> changequest(11071, 11072)
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes(
        "An apology is fine, but you must also show me that you are sorry and help me carry out my plan. Do you have any problem with this?"
      )
      |> close()
    else
      ctx
      |> mes("[Song Zhi Du]")
      |> mes("Oh, forget about it.")
      |> mes("I don't think I can ever")
      |> mes("make you understand how I feel.")
      |> specialeffect(:endure)
      |> close2()
      |> set_char_var(:ch_poison, 6)
      |> changequest(11070, 11071)
    end
  end

  defp collect_ingredients(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Song Zhi Du]")
      |> mes("So, did you")
      |> mes("gather everything")
      |> mes("I asked of you?")
      |> next()
      |> select(["Yes.", "What do you need again?"])

    if choice == 1 do
      if count_item(ctx, 939) > 3 and count_item(ctx, 937) > 9 and count_item(ctx, 1093) > 9 and
           count_item(ctx, 506) > 29 do
        ctx
        |> delitem(939, 4)
        |> delitem(937, 10)
        |> delitem(1093, 10)
        |> delitem(506, 30)
        |> set_char_var(:ch_poison, 8)
        |> changequest(11072, 11073)
        |> mes("[Song Zhi Du]")
        |> mes("Ah...")
        |> mes(
          "With these, I accept your apology. Thank you for all the trouble you went through to get this stuff."
        )
        |> next()
        |> mes("[Song Zhi Du]")
        |> mes(
          "Now that you're this involved, you're in this with me all the way! I've been waiting for this"
        )
        |> mes("day for years...")
        |> next()
        |> mes("[Song Zhi Du]")
        |> mes("All that's left is to create this poison, and then to get the")
        |> mes("lord of Luoyang to drink it...")
        |> close()
      else
        ctx
        |> mes("[Song Zhi Du]")
        |> mes("Where are things")
        |> mes("I asked you to bring?")
        |> mes("Are you testing my")
        |> mes("patience or what?")
        |> next()
        |> mes("[Song Zhi Du]")
        |> mes(
          "You're still missing some of the items I need. I must have them all in order to finish making this poison!"
        )
        |> specialeffect(:endure)
        |> close()
      end
    else
      ctx
      |> mes("[Song Zhi Du]")
      |> mes("*Sigh...*")
      |> mes("Go and get me...")
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes("^0000FF4 Bee Sting,")
      |> mes("10 Venom Canine,")
      |> mes("10 Empty Potion,")
      |> mes("30 Green Potion^000000.")
      |> specialeffect(:endure)
      |> close()
    end
  end

  defp request_delivery(ctx) do
    ctx
    |> emotion(:surprise)
    |> mes("[Song Zhi Du]")
    |> mes("Ah, hello.")
    |> mes("Please give me a minute,")
    |> mes("I've just received a message.")
    |> next()
    |> mes("[Song Zhi Du]")
    |> mes("Ah!")
    |> mes("It says here")
    |> mes("that my delivery")
    |> mes("has finally arrived!")
    |> next()
    |> mes("[Song Zhi Du]")
    |> mes("Would you bring me the")
    |> mes("box from the firecracker")
    |> mes("lady at the entrance")
    |> mes("to Luoyang? Thanks")
    |> mes("in advance.")
    |> close()
  end

  defp receive_delivery(ctx) do
    if count_item(ctx, 7126) > 0 do
      ctx
      |> delitem(7126, count_item(ctx, 7126))
      |> mes("[Song Zhi Du]")
      |> mes("Ah. Thank you,")
      |> mes("I needed this. Now,")
      |> mes("shall we begin?")
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes("First, I shall mix a poison extracted from Venom Canine")
      |> mes("with a foreign liquid named Karvodailnirol.")
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes(
        "Then, I add Green Herb extract, poison extracted from Bee Sting and a Large Jellopy into the liquid! Finally, I must heat them all!"
      )
      |> specialeffect(:beginspell)
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes(
        "Finally, I have to carefully heat the mixture and collect it all into a Potion Bottle."
      )
      |> specialeffect(:enchantpoison)
      |> specialeffect(:venomdust)
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes("Now, I've got to do this just right. This is a very delicate procedure...")
      |> next()
      |> specialeffect(:magnumbreak)
      |> emotion(:huk)
      |> mes("[Song Zhi Du]")
      |> mes(
        "No!! I failed again! ^666666*Sigh...*^000000 And I spent a long time preparing all of those materials..."
      )
      |> set_char_var(:ch_poison, 10)
      |> changequest(11074, 11075)
      |> close()
    else
      request_delivery(ctx)
    end
  end

  defp prepare_poison(ctx) do
    if count_item(ctx, 939) > 3 and count_item(ctx, 937) > 9 and count_item(ctx, 1093) > 9 and
         count_item(ctx, 506) > 29 and count_item(ctx, 7126) > 0 do
      ctx =
        ctx
        |> mes("[Song Zhi Du]")
        |> mes("Oh! You brought")
        |> mes("me everything I need!")
        |> mes("I'm very impressed!")
        |> next()
        |> mes("[Song Zhi Du]")
        |> mes("You're the only one")
        |> mes("who actually understands how")
        |> mes("I feel. Thank you for gathering all of these ^FF0000materials^000000.")
        |> next()

      ctx = delitem(ctx, 939, count_item(ctx, 939))
      ctx = delitem(ctx, 937, count_item(ctx, 937))
      ctx = delitem(ctx, 1093, count_item(ctx, 1093))
      ctx = delitem(ctx, 506, count_item(ctx, 506))

      ctx =
        ctx
        |> delitem(7126, count_item(ctx, 7126))
        |> mes("[Song Zhi Du]")
        |> mes("Alright, now")
        |> mes("to create the poison.")
        |> mes("This is going to be tough.")
        |> mes("Here we go...")
        |> next()

      if Enum.random(1..1000) > 700 do
        ctx
        |> mes("[Song Zhi Du]")
        |> mes("First, I shall mix a poison extracted from Venom Canine")
        |> mes("with a foreign liquid named Karvodailnirol.")
        |> next()
        |> mes("[Song Zhi Du]")
        |> mes("Then, I add Green Herb extract,")
        |> mes("a poison extracted from Bee Sting and a Large Jellopy!")
        |> specialeffect(:beginspell)
        |> next()
        |> mes("[Song Zhi Du]")
        |> mes(
          "Finally, I have to carefully heat the mixture and collect it all into a Potion Bottle."
        )
        |> specialeffect(:enchantpoison)
        |> specialeffect(:venomdust)
        |> next()
        |> mes("[Song Zhi Du]")
        |> mes("*Phew...*")
        |> mes("Did...")
        |> mes("Did I make it?")
        |> next()
        |> specialeffect(:pattack)
        |> specialeffect(:poisonhit)
        |> emotion(:huk)
        |> mes("[Song Zhi Du]")
        |> mes("Hahaha~!")
        |> mes("Success! ")
        |> mes("It works!")
        |> mes("I finally created it!")
        |> mes("Mwahahahahahah!")
        |> next()
        |> mes("[Song Zhi Du]")
        |> mes("Muhahahahaha!")
        |> next()
        |> mes("[Song Zhi Du]")
        |> mes("Muhahahahaha!")
        |> mes("Hahahahahahahahahahah!")
        |> next()
        |> mes("[Song Zhi Du]")
        |> mes("I made it!")
        |> mes("I made it!")
        |> mes("Now, revenge will be mine!")
        |> next()
        |> set_char_var(:ch_poison, 11)
        |> give_item(678, 2)
        |> mes("[Song Zhi Du]")
        |> mes("Hahaha! Now, please")
        |> mes(
          "take this bottle. But be careful. Even if you smell it just a little, it can cause your body to decompose, leading to death."
        )
        |> close()
      else
        ctx
        |> mes("[Song Zhi Du]")
        |> mes("First, I shall mix a poison extracted from Venom Canine")
        |> mes("with a foreign liquid named Karvodailnirol.")
        |> next()
        |> mes("[Song Zhi Du]")
        |> mes(
          "Then I add Green Herb extract, a poison extracted from Bee Sting and a Large Jellopy!"
        )
        |> specialeffect(:beginspell)
        |> next()
        |> mes("[Song Zhi Du]")
        |> mes("Then I must carefully heat the mixture, and gather it all into a potion bottle.")
        |> specialeffect(:enchantpoison)
        |> specialeffect(:venomdust)
        |> next()
        |> mes("[Song Zhi Du]")
        |> mes("*Phew...*")
        |> mes("Did...")
        |> mes("Did I make it?")
        |> next()
        |> specialeffect(:magnumbreak)
        |> emotion(:huk)
        |> mes("[Song Zhi Du]")
        |> mes("NO! I... I've failed again! And I spent a long time getting everything ready...")
        |> close()
      end
    else
      ctx
      |> mes("[Song Zhi Du]")
      |> mes("I'm not sure what went wrong.")
      |> mes("Hmm, would you please help me again? I've used all the materials from last time.")
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes("^0000FF4 Bee Sting^000000,")
      |> mes("^0000FF10 Venom Canine^000000,")
      |> mes("^0000FF10 Empty Potion Bottle^000000,")
      |> mes("^0000FF30 Green Potion^000000 and")
      |> mes("^0000FF1 Large Jellopy^000000.")
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes("That's everything I'll need.")
      |> mes(
        "I would apologize, but since you've shown that you'll help carry out my revenge, I know you'll understand."
      )
      |> close()
    end
  end

  defp assign_poisoning(ctx) do
    ctx
    |> mes("[Song Zhi Du]")
    |> mes("Hahahaha...!")
    |> mes("Now, time has come.")
    |> mes("With this poison, Luoyang's")
    |> mes("lord will be cast into hell!")
    |> next()
    |> mes("[Song Zhi Du]")
    |> mes("If they lied about my master,")
    |> mes("then I'll simply make their lies into truth. Then, my master")
    |> mes("won't feel victimized!")
    |> next()
    |> mes("[Song Zhi Du]")
    |> mes("Lord Bai Long!")
    |> mes("You will die!")
    |> mes("Ha HA HA HA HA!")
    |> next()
    |> mes("[Song Zhi Du]")
    |> mes("Muhahahaha!")
    |> mes("Hahaha...Haha..hahaha..haha...hahahahaha...mmmmuhahahahahahahaha!!")
    |> next()
    |> mes("[Song Zhi Du]")
    |> mes("Muhahahahahaha!")
    |> mes("...........")
    |> next()
    |> mes("[Song Zhi Du]")
    |> mes("Ah, forgive me.")
    |> mes("I was overly excited.")
    |> mes("Yes, I must calm down...")
    |> next()
    |> mes("[Song Zhi Du]")
    |> mes(
      "Now, I have one last favor to ask of you. Please sneak into the Castle of the Dragon."
    )
    |> next()
    |> mes("[Song Zhi Du]")
    |> mes(
      "I want you to put this poison some place where Lord Bai Long might stay. But be careful, the castle has a lot of security."
    )
    |> next()
    |> mes("[Song Zhi Du]")
    |> mes(
      "Still, you're an adventurer from Midgard. You've probably had challenges like this before, so I'm sure you'll find a way."
    )
    |> next()
    |> mes("[Song Zhi Du]")
    |> mes("Anyway, I'm sure my master")
    |> mes("will be happy to know that")
    |> mes("I finally created the ^0000FFpoison")
    |> mes("he wished to create^000000!")
    |> next()
    |> mes("[Song Zhi Du]")
    |> mes("Hahaha...!")
    |> mes("Master, I did it!")
    |> mes("Your disciple Song Zhi Du made the world's deadliest poison for you!")
    |> set_char_var(:ch_poison, 12)
    |> changequest(11075, 11076)
    |> close()
  end

  defp remind_about_poisoning(ctx) do
    ctx
    |> mes("[Song Zhi Du]")
    |> mes("Remember...")
    |> mes("The Castle of the Dragon")
    |> mes("is under heavy surveillance.")
    |> mes("I guess Lord Bai Long is")
    |> mes("insecure. Heh heh.")
    |> next()
    |> mes("[Song Zhi Du]")
    |> mes("Anyways, I hope you'll be")
    |> mes(
      "really careful. When you go in, don't forget to use this poison somewhere the Lord Bai Long"
    )
    |> mes("can ingest it.")
    |> next()
    |> mes("[Song Zhi Du]")
    |> mes("Anyway, I'm sure my master")
    |> mes("will be happy to know that")
    |> mes("I finally created the ^0000FFpoison")
    |> mes("he wished to create^000000!")
    |> next()
    |> mes("[Song Zhi Du]")
    |> mes("Hahaha...!")
    |> mes("Master, I did it!")
    |> mes("Your disciple Song Zhi Du made the world's deadliest poison for you!")
    |> next()
    |> mes("[Song Zhi Du]")
    |> mes("Leave now,")
    |> mes("my friend!")
    |> mes("For my revenge!")
    |> mes("Go and kill Lord Bai Long!")
    |> close()
  end

  defp reward_assistance(ctx) do
    ctx =
      ctx
      |> mes("[Song Zhi Du]")
      |> mes("Ah!")
      |> mes("You came back!")
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes("Ah yes.")
      |> mes("All I have to do now")
      |> mes("is wait and hear news")
      |> mes("of Lord Bai Long's death.")
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes("Thank you so much, my friend. You've satisfied my old grudge.")
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes("Now, I am getting tired.")
      |> mes("Let me rest... Take care, my friend, and travel in safety.")
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes("But before you go, let me give you some poison and a medicinal pill.")
      |> mes("I made these with the leftover materials and medicine in the storage.")
      |> set_char_var(:ch_poison, 14)
      |> give_item(678, 3)
      |> next()
      |> mes("[Song Zhi Du]")
      |> mes("Please take the")
      |> mes("medicine pill")
      |> mes("right away.")
      |> next()
      |> mes("^3355FFYou swallowed a strange pill")
      |> mes("that shines with a gold color.")
      |> mes("It tastes bitter...^000000")
      |> next()
      |> mes(
        "^3355FFThe nasty taste lingers in your mouth, but then you feel a great warmth flowing throughout your body. Eventually, you pass out.^000000"
      )
      |> next()

    ctx =
      cond do
        Rathena.truthy?(checkre(ctx, 3)) ->
          cond do
            base_level(ctx) < 56 -> getexp(ctx, 500, 0)
            base_level(ctx) > 55 and base_level(ctx) < 61 -> getexp(ctx, 700, 0)
            base_level(ctx) > 60 and base_level(ctx) < 66 -> getexp(ctx, 850, 0)
            base_level(ctx) > 65 and base_level(ctx) < 71 -> getexp(ctx, 1270, 0)
            base_level(ctx) > 70 and base_level(ctx) < 76 -> getexp(ctx, 1600, 0)
            base_level(ctx) > 75 and base_level(ctx) < 81 -> getexp(ctx, 2100, 0)
            base_level(ctx) > 80 and base_level(ctx) < 86 -> getexp(ctx, 4000, 0)
            base_level(ctx) > 85 and base_level(ctx) < 91 -> getexp(ctx, 7000, 0)
            true -> getexp(ctx, 11000, 0)
          end

        base_level(ctx) < 56 ->
          getexp(ctx, 8909, 0)

        base_level(ctx) > 55 and base_level(ctx) < 61 ->
          getexp(ctx, 10213, 0)

        base_level(ctx) > 60 and base_level(ctx) < 66 ->
          getexp(ctx, 17684, 0)

        base_level(ctx) > 65 and base_level(ctx) < 71 ->
          getexp(ctx, 25411, 0)

        base_level(ctx) > 70 and base_level(ctx) < 76 ->
          getexp(ctx, 68757, 0)

        base_level(ctx) > 75 and base_level(ctx) < 81 ->
          getexp(ctx, 128_246, 0)

        base_level(ctx) > 80 and base_level(ctx) < 86 ->
          getexp(ctx, 142_340, 0)

        base_level(ctx) > 85 and base_level(ctx) < 91 ->
          getexp(ctx, 152_052, 0)

        true ->
          getexp(ctx, 366_786, 0)
      end

    warp(ctx, "louyang", 270, 136)
  end

  defp after_revenge(ctx) do
    ctx
    |> mes("[Song Zhi Du]")
    |> mes("......................")
    |> next()
    |> mes(
      "^3355FFSong Zhi Du looks blankly at the ceiling. With his revenge, it seems he's lost his motivation in life. Was it a good idea to help him, after all?^000000"
    )
    |> next()
    |> mes(
      "^3355FFBy hearsay, the poisoned drink didn't work so well, as a Thief from a foreign land actually stole the bottle.^000000"
    )
    |> close()
  end

  defp question_failed_plot(ctx) do
    ctx
    |> mes("[Song Zhi Du]")
    |> mes("What happened?")
    |> mes("Why isn't")
    |> mes("Lord Bai Long dead yet?!")
    |> next()
    |> mes("[Song Zhi Du]")
    |> mes("Hmmm...")
    |> mes("You don't have")
    |> mes("a different plot")
    |> mes("in mind, do you?")
    |> close()
  end

  defp resolve_revenge(ctx) do
    ctx
    |> mes("[Song Zhi Du]")
    |> mes("Ah...")
    |> mes("Welcome.")
    |> mes("My master told")
    |> mes("me everything.")
    |> next()
    |> mes("[Song Zhi Du]")
    |> mes(
      "Somehow, I feel relieved, but sorry at the same time. Still, now I can forget everything that's happened in the past."
    )
    |> next()
    |> mes("[Song Zhi Du]")
    |> mes(
      "Now, I've decided to focus more on my medical studies so that I can really save as many lives as I can. I'm sorry I've been so rude to you before."
    )
    |> next()
    |> mes("[Song Zhi Du]")
    |> mes("Also, I hope you will")
    |> mes("take these, since I don't")
    |> mes("need them any longer.")
    |> set_char_var(:ch_poison, 21)
    |> completequest(11083)
    |> give_item(678, 5)
    |> next()
    |> mes("[Song Zhi Du]")
    |> mes("Thank you")
    |> mes("once again, friend.")
    |> mes("Now, if you'll excuse me,")
    |> mes("I have many things to do...")
    |> close()
  end

  defp after_resolution(ctx) do
    ctx
    |> mes(
      "^3355FFSong Zhi Du is busily engaged with organizing medicinal herbs. The faint look of sadness that used to be on his face now seems drained.^000000"
    )
    |> next()
    |> mes(
      "^3355FFStill, from his movements and the pace at which he is working, you can tell that he loves what he is doing. It seems that Song Zhi Du has finally found his life's path.^000000"
    )
    |> close()
  end

  defp default_conversation(ctx) do
    ctx
    |> mes("[Song Zhi Du]")
    |> mes(
      "Nagash Arses is also the name of poison king in a legend of Arcturus. There's good reason for my master to be proud of his name!"
    )
    |> close()
  end
end
