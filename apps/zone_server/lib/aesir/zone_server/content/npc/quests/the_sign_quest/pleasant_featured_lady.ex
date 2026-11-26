defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.PleasantFeaturedLady do
  @moduledoc """
  Serin, the lost soul in Niflheim who guides the Sign quest through the realm of the dead.

  ## Behavior

  - Asks the player to help the other souls of Niflheim, then rewards the help with Serin's
    Gold Ring and points them to the Bard.
  - Tells what she knows about the Queen of the Dead, the Symbol of Nine Realms and Angrboda,
    and later warns the player about the witch's plans for the symbol.
  - Reveals the rumour of the witch's ritual to summon Dark Lord and warps the player to the
    magic circle while nobody else is being sent there.
  - As a lingering trace of herself, accepts her ring back for a large EXP reward (lower in
    renewal) and later takes the gold ring back.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "niflheim",
        x: 313,
        y: 70,
        dir: 4,
        sprite: 90,
        name: "Pleasant-Featured Lady",
        scope: :shared,
        unique_name: "Pleasant-Featured Lady#s"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars
  alias Aesir.ZoneServer.Script.Rathena

  @gold_ring 2642
  @serins_ring 2643

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])
    sign_q = get_char_var(ctx, :sign_q, 0)

    cond do
      sign_q < 82 -> not_the_one(ctx)
      sign_q == 82 -> ask_for_help(ctx)
      sign_q == 83 -> helping_the_souls(ctx)
      sign_q == 84 -> remind_of_the_souls(ctx)
      sign_q == 85 -> point_to_the_bard(ctx)
      sign_q < 92 -> surprised_you_survived(ctx)
      sign_q == 92 -> queen_of_the_dead(ctx)
      sign_q == 93 -> angrboda_sealed(ctx)
      sign_q == 94 -> symbol_warning(ctx)
      sign_q < 118 -> bring_the_symbol(ctx)
      sign_q == 118 -> doubt_the_witch(ctx)
      sign_q < 129 -> lingering_memory(ctx)
      sign_q == 129 -> return_her_ring(ctx)
      sign_q == 130 -> silent_tears(ctx)
      sign_q == 131 -> witch_rumours(ctx)
      sign_q == 132 -> send_to_circle(ctx)
      sign_q < 135 or sign_q == 199 -> follow_the_trace(ctx)
      sign_q < 137 -> forgotten(ctx)
      sign_q > 199 -> faded_trace(ctx)
      true -> take_back_gold_ring(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp not_the_one(ctx) do
    ctx
    |> mes("[Serin]")
    |> mes("I'm sorry,")
    |> mes("but you're not")
    |> mes("the person I'm")
    |> mes("looking for. No...")
    |> close()
  end

  defp ask_for_help(ctx) do
    courage = if sex(ctx) == 1, do: "his courage.", else: "her courage."

    {ctx, choice} =
      ctx
      |> mes("[Serin]")
      |> mes("Kind adventurer...")
      |> mes("You're the one I'm looking")
      |> mes("for, the one who's been on")
      |> mes("a long journey to prove")
      |> mes(courage)
      |> next()
      |> mes("[Serin]")
      |> mes("Even in the darkness of")
      |> mes("Niflheim, I can recognize")
      |> mes("you. You shine out to me like")
      |> mes("a star! I beg of you, please")
      |> mes("listen to my story...")
      |> next()
      |> select(["I'm busy, sorry.", "Sure, go ahead."])

    case choice do
      1 -> declined(ctx)
      2 -> tell_her_story(ctx)
      _ -> ctx
    end
  end

  defp tell_her_story(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Serin]")
      |> mes("Thank you...")
      |> mes("Now, if you've heard")
      |> mes("from the others and as")
      |> mes("you can tell by my appearance,")
      |> mes("I clearly don't belong here.")
      |> next()
      |> mes("[Serin]")
      |> mes("I might not have")
      |> mes("the luck to be selected")
      |> mes("by Valkyrie, but I need")
      |> mes("your help to get out of")
      |> mes("here as soon as I can~")
      |> next()
      |> select(["Er, I'm busy, now that I think about it.", "Sure, let's do it."])

    case choice do
      1 -> declined(ctx)
      2 -> help_the_others(ctx)
      _ -> ctx
    end
  end

  defp declined(ctx) do
    ctx
    |> mes("[Serin]")
    |> mes("I know I can't stop")
    |> mes("you from pursing your")
    |> mes("path to glory. But if you")
    |> mes("should change your mind...!")
    |> close()
  end

  defp help_the_others(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Serin]")
      |> mes("I know I'm asking too much")
      |> mes("of you, but if you'd also help")
      |> mes("the other unfortunate souls in")
      |> mes(
        "this place, I'd be truly grateful. Somehow, I think solving their problems will help me get back."
      )
      |> next()
      |> select(["Sure, why not?", "Why should I help them?"])

    case choice do
      1 ->
        ctx
        |> mes("[Serin]")
        |> mes("I knew you'd understand!")
        |> mes("You really are a kind person.")
        |> mes("Now, in order to help the other")
        |> mes(
          "misfortunate in Niflheim, you've got to remember to gain their trust first and get close to them, okay?"
        )
        |> set_char_var(:sign_q, 83)
        |> close()

      2 ->
        ctx
        |> mes("[Serin]")
        |> mes("I... I understand.")
        |> mes(
          "Although I asked too much in asking you to help the other people here, I was hoping you'd realize that"
        )
        |> mes("would be the best way to learn clues for a way to escape for now.")
        |> set_char_var(:sign_q, 84)
        |> close()

      _ ->
        ctx
    end
  end

  defp helping_the_souls(ctx) do
    sign_sq = get_char_var(ctx, :sign_sq, 0)

    cond do
      sign_sq < 8 ->
        ctx
        |> mes("[Serin]")
        |> mes("Hmm...?")
        |> mes("You don't know which")
        |> mes("people you need to help")
        |> mes("here in Niflheim? Mmm,")
        |> mes("let me think about it...")
        |> next()
        |> mes("[Serin]")
        |> mes("In this doomed place,")
        |> mes("there isn't too much trust")
        |> mes("amongst some of the people")
        |> mes("here, but some will share their")
        |> mes("problems if you ^3355FFapproach them")
        |> mes("closely^000000, ^3355FFface to face^000000. Okay?")
        |> next()
        |> mes("[Serin]")
        |> mes("In this way, if they talk")
        |> mes("to you first, they might")
        |> mes("be more willing to accept")
        |> mes("help or tell you what you")
        |> mes("really need to know.")
        |> mes("I hope this helps...")
        |> close()

      sign_sq == 8 ->
        ctx
        |> mes("[Serin]")
        |> mes("Thank you so much for")
        |> mes("your help. This is all I have,")
        |> mes("and it means a lot to me, but")
        |> mes(
          "I want you to have this ring. It's the only way I can properly express my gratitude for your aid so far."
        )
        |> set_char_var(:sign_q, 85)
        |> set_char_var(:sign_sq, 0)
        |> give_item(@gold_ring, 1)
        |> close()

      true ->
        ctx
        |> mes("[Serin]")
        |> mes("To the dead,")
        |> mes("living people")
        |> mes("are either good")
        |> mes("prey or good marks.")
        |> close()
    end
  end

  defp remind_of_the_souls(ctx) do
    ctx
    |> mes("[Serin]")
    |> mes("Hello, adventurer.")
    |> mes("How have you been doing?")
    |> mes("I'm surprised to still see you")
    |> mes("around this dangerous town.")
    |> next()
    |> mes("[Serin]")
    |> mes("If you wander around")
    |> mes("Niflheim, you'll find that")
    |> mes("some of the deceased here are")
    |> mes(
      "different than most of the others in this town. Please talk to them and see if you can be of any help."
    )
    |> set_char_var(:sign_q, 87)
    |> close()
  end

  defp point_to_the_bard(ctx) do
    ctx
    |> mes("[Serin]")
    |> mes("There's a Bard in")
    |> mes("Niflheim with a very")
    |> mes("sweet, yet melancholy voice.")
    |> mes("He sings for strangers just")
    |> mes("like you, adventurer.")
    |> next()
    |> mes("[Serin]")
    |> mes("I think he might know")
    |> mes("some useful information,")
    |> mes("so it might be a good")
    |> mes("idea to speak with him.")
    |> set_char_var(:sign_q, 86)
    |> close()
  end

  defp surprised_you_survived(ctx) do
    ctx
    |> mes("[Serin]")
    |> mes("Hello, #{char_name(ctx, 0)},")
    |> mes("I'm surprised that")
    |> mes("you've managed to survive")
    |> mes(
      "here all this time. It's no small feat for a mortal to be able to remain alive in Niflheim..."
    )
    |> close()
  end

  defp queen_of_the_dead(ctx) do
    has_gold_ring = count_item(ctx, @gold_ring) > 0

    greeting =
      ctx
      |> mes("[Serin]")
      |> mes("Ah, #{char_name(ctx, 0)}~")
      |> mes("How is everything?")

    greeting =
      if has_gold_ring do
        greeting
        |> mes("Once again, I want to")
        |> mes("thank you for helping the")
        |> mes("poor souls in this place.")
      else
        greeting
      end

    {ctx, choice} =
      greeting
      |> next()
      |> mes("[Serin]")
      |> mes("Hmm...?")
      |> mes("What's with that")
      |> mes("look on your face?")
      |> mes("Do you have something")
      |> mes("you want to ask me?")
      |> next()
      |> select(["Nothing.", "About the Queen of the Dead..."])

    case choice do
      1 ->
        ctx
        |> mes("[Serin]")
        |> mes("Well, if you ever")
        |> mes("need my help, please")
        |> mes("don't hesitate to ask.")
        |> close()

      2 ->
        tell_of_the_queen(ctx)

      _ ->
        ctx
    end
  end

  defp tell_of_the_queen(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Serin]")
      |> mes("The Queen of the Dead?")
      |> mes("Why, she's the ruler of Niflheim.")
      |> mes(
        "As Loki and Angrboda's last child, she was given complete control of this realm by Odin."
      )
      |> next()
      |> mes("[Serin]")
      |> mes("She usually rules from her")
      |> mes(
        "castle, Hell, but sometimes she goes out to tour Niflheim. That's all I really know about her."
      )
      |> next()
      |> select(["About the Symbol of Nine Realms"])

    {ctx, _} =
      ctx
      |> mes("[Serin]")
      |> mes("Oh that...?")
      |> mes("Sometimes it's called")
      |> mes("the Voucher of the Dead.")
      |> mes("Odin gave it to the Queen")
      |> mes("of the Dead to signify her")
      |> mes("authority over Niflheim.")
      |> next()
      |> mes("[Serin]")
      |> mes("There are many rumors")
      |> mes("floating around about that")
      |> mes("symbol and its abilities, but")
      |> mes("all we know for sure is that it can be used to command the dead...")
      |> next()
      |> select(["About Angrboda"])

    {ctx, _} =
      ctx
      |> mes("[Serin]")
      |> mes("Angrboda...?")
      |> mes("She's the mother of the")
      |> mes("Queen of Hell, as well as")
      |> mes("some of the most powerful")
      |> mes("monsters in this universe.")
      |> next()
      |> mes("[Serin]")
      |> mes("The gods feared her monstrous")
      |> mes("children so much that they bound")
      |> mes("them and sealed Angrboda away.")
      |> mes("Nothing has been heard")
      |> mes("of her since...")
      |> next()
      |> select(["I was told by the Witch that you're..."])

    ctx
    |> mes("[Serin]")
    |> mes("Oh, the Witch was")
    |> mes("talking about me? I'm")
    |> mes("aware that she doesn't")
    |> mes("think very highly of me.")
    |> mes("Then again, it's not like")
    |> mes("I can trust her either.")
    |> next()
    |> mes("[Serin]")
    |> mes("Well, it can't be helped.")
    |> mes("At least we both agree that")
    |> mes("somehow I don't really belong")
    |> mes("here in Niflheim.")
    |> emotion(:think)
    |> set_char_var(:sign_q, 93)
    |> close()
  end

  defp angrboda_sealed(ctx) do
    ctx
    |> mes("[Serin]")
    |> mes("I'm sorry that I sort of")
    |> mes("rambled on and on that last")
    |> mes("time we spoke. Now that I think")
    |> mes(
      "about it, I didn't really give you any information that might have been very useful to you."
    )
    |> next()
    |> mes("[Serin]")
    |> mes("But lately I've heard that the")
    |> mes("Queen of the Dead is seeking her")
    |> mes("mother, Angrboda. It's strange that even the queen, with all of her")
    |> mes("power, is unable to find her.")
    |> next()
    |> mes("[Serin]")
    |> mes("I have no idea how,")
    |> mes("but it seems like Angrboda")
    |> mes("has been sealed away in the")
    |> mes("world of Midgard...")
    |> emotion(:think)
    |> set_char_var(:sign_q, 94)
    |> close()
  end

  defp symbol_warning(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Serin]")
      |> mes("I've told you")
      |> mes("everything I know.")
      |> mes("But if you want to learn more")
      |> mes(
        "about Angrboda, you probably need to talk to someone who actually communicates with the gods."
      )
      |> next()
      |> mes("[Serin]")
      |> mes("Perhaps Valkyrie")
      |> mes("or someone who actually")
      |> mes("lived in Asgard may know")
      |> mes("more about where Angrboda")
      |> mes("is sealed away.")
      |> next()
      |> mes("[Serin]")
      |> mes("Also, why would you want")
      |> mes("the Symbol of the Nine Realms?")
      |> mes(
        "It's a very dangerous object that could cause a lot of trouble if it fell into the wrong hands..."
      )
      |> next()
      |> select(["What do you mean??", "Don't worry, it won't."])

    case choice do
      1 ->
        symbol_dangers(ctx)

      2 ->
        ctx
        |> mes("[Serin]")
        |> mes("Ah...")
        |> mes("Alright, I suppose")
        |> mes("that if you're worthy")
        |> mes("of obtaining the symbol,")
        |> mes("you should also be able")
        |> mes("to protect it from abuse.")
        |> set_char_var(:sign_q, 95)
        |> close()

      _ ->
        ctx
    end
  end

  defp symbol_dangers(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Serin]")
      |> mes("There are plenty of dead")
      |> mes("people in Niflheim that are")
      |> mes("driven by regret and despair.")
      |> mes(
        "The rage of being dead may result in some of them performing horrific deeds if they had the symbol."
      )
      |> next()
      |> select(["Then what should I do?", "Thanks for the concern, but I'm not worried."])

    case choice do
      1 ->
        {ctx, _} =
          ctx
          |> mes("[Serin]")
          |> mes("I really think that you")
          |> mes("should bring that symbol")
          |> mes(
            "to me before you show it to anybody else. Then, I want you to know why I really need its power."
          )
          |> next()
          |> mes("[Serin]")
          |> mes("I can't explain myself")
          |> mes("now, but I want to use the")
          |> mes("power of the symbol to do")
          |> mes("something really helpful")
          |> mes("for you. You'll just need")
          |> mes("to trust me on this.")
          |> next()
          |> select(["I'll think about it."])

        ctx
        |> mes("[Serin]")
        |> mes("Then I will")
        |> mes("wait for you here.")
        |> set_char_var(:sign_q, 95)
        |> close()

      2 ->
        ctx
        |> mes("[Serin]")
        |> mes("Alright...")
        |> mes("It's your decision.")
        |> set_char_var(:sign_q, 95)
        |> close()

      _ ->
        ctx
    end
  end

  defp bring_the_symbol(ctx) do
    ctx
    |> mes("[Serin]")
    |> mes("If you obtain the")
    |> mes("Symbol of Nine Realms,")
    |> mes("please bring it to me")
    |> mes("right away, #{char_name(ctx, 0)}.")
    |> close()
  end

  defp doubt_the_witch(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Serin]")
      |> mes("Yes...")
      |> mes("This is the Symbol of the")
      |> mes("Nine Realms. It only has enough")
      |> mes(
        "power for one use, but it's still not easy to get this. Now, what were you planning to use this for?"
      )
      |> next()
      |> select(["Tell her your story."])

    {ctx, choice} =
      ctx
      |> mes("[Serin]")
      |> mes("Ah, so you're here")
      |> mes("in Niflheim to overcome")
      |> mes("the ordeals of the gods and")
      |> mes("prove your courage to Valkyrie.")
      |> next()
      |> mes("[Serin]")
      |> mes("So wait...")
      |> mes("You've obtained that symbol")
      |> mes("just for that witch? This may")
      |> mes("seem rude, but I want to tell")
      |> mes("you exactly how I feel about her.")
      |> next()
      |> mes("[Serin]")
      |> mes("Isn't it suspicious that she")
      |> mes("hasn't explained her intentions to you? The Symbol of Nine Realms")
      |> mes(
        "is one of the most powerful objects in Niflheim. Whatever she's planning has to be large scale."
      )
      |> next()
      |> mes("[Serin]")
      |> mes("Then, there's that Metz Brayde.")
      |> mes(
        "Do you really believe that after he completes his research, he'll just give it back to you? You can't just trust someone to hold an object of enormous power and give it back!"
      )
      |> next()
      |> select(["W-what should I do?", "I can't believe this!"])

    case choice do
      1 ->
        ctx
        |> mes("[Serin]")
        |> mes("Well, I can't really tell")
        |> mes(
          "you what to do, but I don't think it's a good idea to let that witch have the Symbol of Nine Realms. There's no telling what she'll"
        )
        |> mes("use its power for.")
        |> next()
        |> mes("[Serin]")
        |> mes("Actually...")
        |> mes("There is this rumor")
        |> mes("going around, but I don't")
        |> mes("know if you want to hear it...")
        |> set_char_var(:sign_q, 131)
        |> close()

      2 ->
        ctx
        |> mes("[Serin]")
        |> mes("I'm sorry if you were offended.")
        |> mes(
          "I know I can't really convince you to believe anything, but please understand that I just don't want anyone to take advantage of you. Forgive my rudeness."
        )
        |> close()

      _ ->
        ctx
    end
  end

  defp lingering_memory(ctx) do
    ctx
    |> mes("^3355FFThis is only")
    |> mes("a lingering trace")
    |> mes("of Serin, a manifestation")
    |> mes("of her definitive memory.^000000")
    |> close()
  end

  defp return_her_ring(ctx) do
    ctx =
      ctx
      |> mes("[Serin]")
      |> mes("...")
      |> mes("......")
      |> next()
      |> mes("[Serin]")
      |> mes("...")
      |> mes("......")
      |> mes("..........")

    if count_item(ctx, @serins_ring) == 1 do
      {ctx, choice} =
        ctx
        |> next()
        |> select(["Give Serin her ring.", "Keep the ring."])

      case choice do
        1 -> give_back_ring(ctx)
        2 -> ctx |> emotion(:cry) |> close()
        _ -> ctx
      end
    else
      ctx |> emotion(:cry) |> close()
    end
  end

  defp give_back_ring(ctx) do
    ctx
    |> mes("[Serin]")
    |> mes("...")
    |> mes("......")
    |> mes(".............")
    |> next()
    |> mes("[Serin]")
    |> mes("....#{char_name(ctx, 0)}.....")
    |> mes("I don't want to forget you.")
    |> mes("I can forget my obsession with")
    |> mes("life and all my other memories,")
    |> mes("But if I can keep just one memory, I want it to be of your kindness.")
    |> next()
    |> mes("[Serin]")
    |> mes("Even now, you're still")
    |> mes("so very kind to me. Thank")
    |> mes("you for giving back my ring,")
    |> mes("my most precious possession.")
    |> mes("Thank you, thank you...")
    |> emotion(:cry)
    |> next()
    |> mes("^3355FFThe sound of Serin's voice")
    |> mes("softened and when it grew silent, her eyes blankly stared ahead as")
    |> mes("if she were in a trance. It looks like she has already forgotten")
    |> mes("everything...^000000")
    |> next()
    |> mes("^3355FFBut Serin has also been able")
    |> mes("to forget her sadness. The tears streaked across her cheeks and")
    |> mes("the faint smile on her lips tell you that her memories of you")
    |> mes("will always remain in her heart.^000000")
    |> delitem(@serins_ring, 1)
    |> then(&getexp(&1, ring_exp(&1), 0))
    |> close()
  end

  defp ring_exp(ctx), do: if(Rathena.truthy?(checkre(ctx, 3)), do: 50_000, else: 500_000)

  defp silent_tears(ctx) do
    ctx
    |> mes("[Serin]")
    |> mes("...........")
    |> emotion(:cry)
    |> next()
    |> mes("[Serin]")
    |> mes("...........")
    |> emotion(:think)
    |> next()
    |> mes("[Serin]")
    |> mes("...........")
    |> emotion(:think)
    |> next()
    |> mes("[Serin]")
    |> mes("...........")
    |> emotion(:cry)
    |> close()
  end

  defp witch_rumours(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Serin]")
      |> mes("........")
      |> next()
      |> select(["Tell me the rumors about the witch."])

    {ctx, _} =
      ctx
      |> next()
      |> mes("[Serin]")
      |> mes(
        "Well, I've heard that the witch has been hiding deep in Niflheim and will only speak to those who pass her test. Apparently, she's been preparing some sort of ritual"
      )
      |> mes("to gain more power...")
      |> next()
      |> mes("[Serin]")
      |> mes("It's almost too horrible")
      |> mes("to believe, but I think that")
      |> mes("she's preparing the ritual to")
      |> mes("summon Dark Lord, ruler of")
      |> mes("the Realm of Fiends.")
      |> next()
      |> select(["Dark Lord...?"])

    {ctx, _} =
      ctx
      |> mes("[Serin]")
      |> mes("Well, most people don't")
      |> mes("know this, but Dark Lord")
      |> mes("comes from the Realm of Fiends.")
      |> mes("In his own domain, he's so powerful that even the gods fear his might.")
      |> next()
      |> mes("[Serin]")
      |> mes("Now, sometimes Dark Lord can")
      |> mes(
        "enter the world of Midgard, but only in a manifestation that represents just a small portion"
      )
      |> mes("of his full power.")
      |> next()
      |> mes("[Serin]")
      |> mes(
        "You see, it takes too much energy to travel from the Realm of Fiends to Midgard. And since the life force in Midgard conflicts with his powers, Dark Lord can't reach your world directly."
      )
      |> next()
      |> select(["Wouldn't Lady Hell stop him?"])

    {ctx, _} =
      ctx
      |> mes("[Serin]")
      |> mes("Well, Dark Lord only wants")
      |> mes(
        "Midgard, so the Queen of the Dead doesn't feel threatened about her control of Niflheim."
      )
      |> next()
      |> mes("[Serin]")
      |> mes("In fact, I'm sure she's aware")
      |> mes(
        "that Dark Lord will cause thousands of deaths in Midgard, meaning that there would be thousands more souls for her to rule over. So it's not to her advantage to stop him."
      )
      |> next()
      |> select(["Then what should we do...?"])

    {ctx, _} =
      ctx
      |> mes("[Serin]")
      |> mes("No matter what the cost,")
      |> mes("we've got to stop her from")
      |> mes("summoning Dark Lord in order")
      |> mes("to protect Midgard from")
      |> mes("total annihiliation.")
      |> next()
      |> mes("[Serin]")
      |> mes("I used to be a pretty")
      |> mes("skilled Wizard, so I know")
      |> mes(
        "that she needs to draw a really huge magic circle in Niflheim if she wants to summon Dark Lord."
      )
      |> next()
      |> select(["Can you tell me where?"])

    ctx
    |> mes("[Serin]")
    |> mes("Well, there are certain rules")
    |> mes(
      "and conditions to perform the summoning. There aren't any spaces wide enough in the Valley of Gyoll, and Niflheim's entrance is watched by too many people..."
    )
    |> next()
    |> mes("[Serin]")
    |> mes("Now, if I were to summon")
    |> mes("Dark Lord, I would probably")
    |> mes("do it somewhere inside town")
    |> mes("to avoid attention. Hmmm...")
    |> mes("I'll send you there once I figure out where the circle might be.")
    |> set_char_var(:sign_q, 132)
    |> close()
  end

  defp send_to_circle(ctx) do
    if circle_in_use?(ctx) do
      ctx
      |> mes("[Serin]")
      |> mes("I need to finish")
      |> mes("my preparations to send")
      |> mes("you to the magic circle,")
      |> mes("so I need a little more time...")
      |> close()
    else
      {ctx, choice} =
        ctx
        |> mes("[Serin]")
        |> mes("Alright...")
        |> mes("So are you")
        |> mes("ready to leave?")
        |> next()
        |> select(["Yes", "Not yet"])

      case choice do
        1 ->
          ctx
          |> mes("[Serin]")
          |> mes("Okay~")
          |> mes("Let's go...")
          |> close2()
          |> set_server_temp_var("sign_w2", 1)
          |> warp("que_sign01", 199, 36)

        2 ->
          close(ctx)

        _ ->
          ctx
      end
    end
  end

  defp follow_the_trace(ctx) do
    if circle_in_use?(ctx) do
      ctx
      |> mes("[Serin]")
      |> mes("My preparations")
      |> mes("are taking longer")
      |> mes("than I thought. Would")
      |> mes("you wait a little while?")
      |> close()
    else
      {ctx, choice} =
        ctx
        |> mes("^3355FFThis is just a lingering")
        |> mes("trace of Serin, an impression")
        |> mes("of her soul and memories that")
        |> mes("you can still sense somehow.^000000")
        |> next()
        |> select(["Follow the trace.", "Ignore it."])

      case choice do
        1 ->
          ctx
          |> close2()
          |> set_char_var(:sign_q, 199)
          |> set_server_temp_var("sign_w2", 1)
          |> warp("que_sign01", 199, 36)

        2 ->
          close(ctx)

        _ ->
          ctx
      end
    end
  end

  defp circle_in_use?(ctx), do: get_server_temp_var(ctx, "sign_w2", 0) == 1

  defp forgotten(ctx) do
    ctx
    |> mes("[Serin]")
    |> mes("...")
    |> mes("......")
    |> mes("W-who...")
    |> mes("Who are you?")
    |> emotion(:think)
    |> close()
  end

  defp faded_trace(ctx) do
    ctx =
      ctx
      |> mes("^3355FFThis is just a lingering")
      |> mes("trace of Serin, an impression")
      |> mes("of her soul and memories that")
      |> mes("you can still sense somehow.")
      |> mes("What could have happened to her?^000000")

    if count_item(ctx, @gold_ring) > 0 do
      ctx
      |> next()
      |> mes("^33555FFSuddenly, Serin's")
      |> mes("gold ring sparkled")
      |> mes("with a soft glow and")
      |> mes("faded away.^000000")
      |> delitem(@gold_ring, 1)
      |> close()
    else
      close(ctx)
    end
  end

  defp take_back_gold_ring(ctx) do
    if count_item(ctx, @gold_ring) > 0 do
      ctx
      |> mes("[Serin]")
      |> mes("Thank you...")
      |> emotion(:cry)
      |> delitem(@gold_ring, 1)
      |> next()
      |> mes("^3355FFYou returned")
      |> mes("Serin's gold ring.^000000")
      |> close()
    else
      ctx
      |> mes("[Serin]")
      |> mes("...")
      |> mes("......")
      |> emotion(:think)
      |> close()
    end
  end
end
