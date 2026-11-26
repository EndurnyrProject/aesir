defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.BrisingamenSeal.StudyingScholar do
  @moduledoc """
  Enrico Kaili, the scholar who leads the Brisingamen Seal quest research.

  ## Behavior

  - Turns away overweight adventurers and talks about Red Potions while the seal is not open
    or already released.
  - Recruits the adventurer to find Hermite Charles, then follows the hunt for Freya's traces,
    the four Dwarves and Brisingamen with stage-specific advice.
  - At the final stage grants an Old Card Album and base EXP, advances the server's third seal
    counter and announces when the seal appears or is released.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Toms
    - L0ne_W0lf
    - Samuray22
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_in04",
        x: 47,
        y: 113,
        dir: 1,
        sprite: 749,
        name: "Studying Scholar",
        scope: :shared,
        unique_name: "Studying Scholar#1"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{908, 200}]) == 0 ->
        ctx
        |> mes(
          "^3355FFWait a second! Right now, you're carrying too many items with you. Please come back after putting some of your things into Kafra Storage.^000000"
        )
        |> close()

      get_server_var(ctx, "God3", 0) == get_server_temp_var(ctx, "god_check2", 0) ->
        ponder_best_red_potion(ctx)

      get_server_var(ctx, "God2", 0) >= get_server_temp_var(ctx, "god_check1", 0) ->
        research(ctx, get_char_var(ctx, :god_brising, 0))

      true ->
        ponder_faster_red_potions(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp ponder_best_red_potion(ctx) do
    ctx
    |> mes("[Studying Scholar]")
    |> mes("Hmmm...")
    |> mes("The highest quality Red Potion ever...")
    |> next()
    |> mes("[Studying Scholar]")
    |> mes(
      "If only I could figure a way to balance the consistency of the ground Red Herbs mixed with the water. That part is most crucial..."
    )
    |> close()
  end

  defp ponder_faster_red_potions(ctx) do
    ctx
    |> mes("[Studying Scholar]")
    |> mes("Do you know how")
    |> mes("to make Red Potions?")
    |> mes(
      "You grind a lot of Red Herbs and carefully shake the liquid until you achieve the desire consistency."
    )
    |> next()
    |> mes("[Studying Scholar]")
    |> mes("If I could find a way")
    |> mes("to produce them much faster,")
    |> mes("I'd become rich in no time...")
    |> close()
  end

  defp research(ctx, 50) do
    ctx
    |> mes("[Enrico Kaili]")
    |> mes("Ah, #{char_name(ctx, 0)},")
    |> mes("you've returned.")
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes(
      "Learning about Brisingamen was truly fascinating. But since we've hit a plateau for now, I've started a new research project."
    )
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes("Hahahaha~")
    |> mes(
      "I'm sorry, but I cannot tell you about it for now, since it's confidential. But once I get a chance, I'll ask you for help."
    )
    |> close()
  end

  defp research(ctx, 49), do: reward_research(ctx)

  defp research(ctx, 48) do
    ctx
    |> mes("[Enrico Kaili]")
    |> mes("Why are you still here?")
    |> mes("I asked you to go find Alfrik.")
    |> mes("Ah~ I cannot wait...")
    |> emotion(:spark)
    |> close()
  end

  defp research(ctx, 47), do: review_brisingamen_materials(ctx)

  defp research(ctx, 46) do
    ctx
    |> mes("[Enrico Kaili]")
    |> mes("I guess he finally sang for you?")
    |> mes(
      "By the way, why didn't you speak to Grer the Dwarf? Oh right, the mine is heavily populated with monsters."
    )
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes("I know it won't be easy,")
    |> mes("but please seek him out")
    |> mes("and get more information.")
    |> mes("Thank you in advance.")
    |> close()
  end

  defp research(ctx, 45) do
    ctx
    |> mes("[Enrico Kaili]")
    |> mes("Hm...?")
    |> mes(
      "Did you forget the words to the song? Well, I didn't write them down either. Hahahaha! I guess there's only one thing you can do~"
    )
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes(
      "You've got to go back to Berling and ask him for the lyrics again. Good luck, and don't forget to memorize them this time."
    )
    |> close()
  end

  defp research(ctx, 44) do
    ctx
    |> mes("[Enrico Kaili]")
    |> mes("It looks like you were able to answer that riddle. Good work!")
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes(
      "That strange, unearthly feeling of dampness... Ah, you've brought Freya's Tear Drops! That means Grer must have awakened on his own now."
    )
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes(
      "I suppose your next course of action should be to enter the mine. I'm sorry for the trouble, but I grow more excited with each new thing we learn."
    )
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes(
      "It's only with your help that I've been able to make such progress with my research. Anyway, I shall share my conclusions with you later."
    )
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes("So are you heading for the mine now? Be careful around those monsters.")
    |> close()
  end

  defp research(ctx, 43) do
    ctx
    |> mes("[Enrico Kaili]")
    |> mes("Dvalin's riddle?")
    |> mes("He must have been")
    |> mes("talking about the")
    |> mes("endless war that")
    |> mes("Freya had to cause.")
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes("There were two kings that")
    |> mes(
      "each had twenty knights. The kings and these knights fought and killed each other, and would be brought back to life the next morning by Freya until thousands of Valkyries filled Valhalla."
    )
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes("All forty-two")
    |> mes("of them did this...")
    |> mes("Everyday. It's an old")
    |> mes("story that everyone knows.")
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes("In any case, it's about time that you investigated Berling. There's")
    |> mes(
      "a stream that begins northwest of Prontera and passes through a mine in Mount Mjolnir."
    )
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes("It may be wise to")
    |> mes("start your search there and investigate any streams and")
    |> mes("puddles that you can find.")
    |> close()
  end

  defp research(ctx, 42) do
    ctx
    |> mes("[Enrico Kaili]")
    |> mes("Are you sure?!")
    |> mes("Those items were")
    |> mes("intended to create")
    |> mes("Freya's necklace,")
    |> mes("Brisingamen?")
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes("If the four Dwarves")
    |> mes("awaken, Brisingamen may")
    |> mes("appear before human eyes?")
    |> mes("Fascinating. Just fascinating.")
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes("Let's see....")
    |> mes("The place where")
    |> mes("Dvalin is sleeping?")
    |> mes("I assume it may be near")
    |> mes("the place where the Monks")
    |> mes("train, but I am unsure.")
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes("In any case, it would")
    |> mes("to no harm to investigate")
    |> mes("any leads yes? The monastery,")
    |> mes("I believe, is to the east")
    |> mes("of Prontera.")
    |> close()
  end

  defp research(ctx, 41) do
    ctx
    |> mes("[Enrico Kaili]")
    |> mes("What...?")
    |> mes("You actually")
    |> mes("met Alfrik...?")
    |> mes("I can't believe")
    |> mes("the legendary Alfrick")
    |> mes("is still alive...")
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes(
      "Alfrik is one of the four Dwarves who created Brisingamen, the world's most beautiful necklace, for the goddess Freya."
    )
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes("Now I realize...")
    |> mes(
      "We've been gathering information related to an item containing the power of the gods!"
    )
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes("Let's see...")
    |> mes("There's another Dwarf, Dvalin.")
    |> mes("Did Alfrik tell you anything about where Dvalin may be sleeping? Hmm...")
    |> close()
  end

  defp research(ctx, 40) do
    ctx
    |> mes("[Enrico Kaili]")
    |> mes("For now, I suppose")
    |> mes("it would be best to")
    |> mes("investigate Lutie.")
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes("Somewhere there, I'm")
    |> mes(
      "sure you can find a remaining trace of the goddess Freya. If you were able to meet Valkyrie, I'm sure you'll be able to do this."
    )
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes("I've been thinking...")
    |> mes("About those words")
    |> mes("Valkyrie told you")
    |> mes("to remember...")
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes("^4d4dffThe beauty of the stars")
    |> mes("Wanes in comparison.")
    |> mes("We lost our hearts")
    |> mes("To that golden hair")
    |> mes("And those dazzling eyes.^000000")
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes("What could that mean?")
    |> mes("I'm beginning to doubt")
    |> mes("what I think I know...")
    |> close()
  end

  defp research(ctx, 35), do: interpret_valkyrie_poem(ctx)

  defp research(ctx, stage) when stage > 9 and stage < 35 do
    ctx
    |> mes("[Enrico Kaili]")
    |> mes("Hmm...?")
    |> mes("I see...")
    |> mes("I know the work")
    |> mes("I'm having you do might")
    |> mes("be quite troublesome...")
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes("But rest assured,")
    |> mes("I will reward you")
    |> mes("once our work is completed.")
    |> mes("Good help such as the kind")
    |> mes("you provide is hard to find.")
    |> close()
  end

  defp research(ctx, stage) when stage > 3 and stage < 10 do
    ctx
    |> mes("[Enrico Kaili]")
    |> mes("So have you")
    |> mes("met Hermite? Hm?")
    |> mes("He actually asked")
    |> mes("you to do that?")
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes(
      "For now, it looks like you might have no alternative. It would probably be wise to do what he wants. Knowing Charles, it's probably won't be too bad."
    )
    |> close()
  end

  defp research(ctx, 3) do
    ctx
    |> mes("[Enrico Kaili]")
    |> mes("Hermite...?")
    |> mes("Do you need more")
    |> mes("information about him?")
    |> mes("Let's see...")
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes("Oh, that's right!")
    |> mes(
      "He's a registered member of that Monster Research Organization. Why don't you ask the lady over there for more information on him?"
    )
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes(
      "If she'll let you look at her records, you can probably find out where he lives. Now why don't you talk to that lady towards the left part of this room?"
    )
    |> close()
  end

  defp research(ctx, 2) do
    {ctx, choice} =
      ctx
      |> mes("[Enrico Kaili]")
      |> mes("So, have you")
      |> mes("considered my proposal?")
      |> mes("Work for me, and I shall")
      |> mes("surely repay you.")
      |> next()
      |> select(["No thanks.", "Sure, why not."])

    case choice do
      1 ->
        ctx
        |> mes("[Enrico Kaili]")
        |> mes("What...?!")
        |> mes("Then why bother")
        |> mes("to speak to me?")
        |> mes("If you just intend to")
        |> mes("bother me, then please")
        |> mes("leave right away.")
        |> close()

      2 ->
        send_to_hermite(ctx)

      _ ->
        ctx
    end
  end

  defp research(ctx, 1) do
    {ctx, choice} =
      ctx
      |> mes("[Enrico Kaili]")
      |> mes("Ah, you've arrived!")
      |> mes("#{char_name(ctx, 0)}, right?")
      |> mes("Yes, I was told by Nelliorde that you'd come. He always manages")
      |> mes("to find me good, reliable help.")
      |> next()
      |> mes("[Enrico Kaili]")
      |> mes("As Nelliorde probably mentioned,")
      |> mes(
        "I need some help in completing my research. Since you adventurers are always traveling, I was hoping you'd help me find someone."
      )
      |> next()
      |> select(["I'm no good at finding people.", "I can do that!"])

    case choice do
      1 ->
        ctx
        |> mes("[Enrico Kaili]")
        |> mes("Oh... Really?")
        |> mes(
          "I was really hoping that you'd be able to help me. But I understand if it's not within your capacity."
        )
        |> next()
        |> mes("[Enrico Kaili]")
        |> mes(
          "I suppose I can try to find another adventurer to help me. But if you change your mind later, please do not hesitate to lend me your assistance."
        )
        |> set_char_var(:god_brising, 2)
        |> close()

      2 ->
        send_to_hermite(ctx)

      _ ->
        ctx
    end
  end

  defp research(ctx, _stage) do
    ctx
    |> mes("[Enrico Kaili]")
    |> mes(
      "I'm not exactly sure why you've come to me, but I apologize for the fact that I'm unable to help you."
    )
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes("Right now, I'm far")
    |> mes("too busy trying to")
    |> mes("complete my research.")
    |> mes("Please leave me alone")
    |> mes("to do my work.")
    |> close()
  end

  defp send_to_hermite(ctx) do
    ctx
    |> mes("[Enrico Kaili]")
    |> mes("Really?")
    |> mes(
      "If you could help me, that would be great! Before we start, would you take a look at this?"
    )
    |> next()
    |> mes(
      "^3355FFEnrico Kaili showed you a small white crystallization inside a box. It looked very fragile, but emanated an intensely"
    )
    |> mes("cold aura.^000000")
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes("I call this the Snow Crystal.")
    |> mes("It looks just like a snowflake, doesn't it? Strangely enough,")
    |> mes("it's never melted.")
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes("A few years ago,")
    |> mes("a young adventurer")
    |> mes(
      "gave this to me. I need to find this person so that I can find out exactly what this is, as well as where it came from."
    )
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes("Now, the person")
    |> mes("who brought this to")
    |> mes("me is, let's see, ah...")
    |> mes("Hermite Charles.")
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes("When you find him,")
    |> mes("please give him this letter.")
    |> next()
    |> mes("^3355FFEnrico gave you a small")
    |> mes("letter addressed to Hermite")
    |> mes("Charles that is sealed with")
    |> mes("red wax.^000000")
    |> set_char_var(:god_brising, 3)
    |> close()
  end

  defp interpret_valkyrie_poem(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Enrico Kaili]")
      |> mes("I can tell you've")
      |> mes("gone through a lot...")
      |> mes("So what did you hear")
      |> mes("from Hermite?")
      |> next()
      |> mes("^3355FFYou tell Enrico Kaili")
      |> mes("what you were told by Hermite,")
      |> mes("as well as your experiences")
      |> mes("with Valkyrie.^000000")
      |> next()
      |> mes("[Enrico Kaili]")
      |> mes("I can scarcely believe this!")
      |> mes("But if what you say is true, it may be possible for humans to possess godly power.")
      |> next()
      |> mes("[Enrico Kaili]")
      |> mes("Hm? There's a reaction coming")
      |> mes(
        "from this thing that was sent from the royal court. Hm, come closer and take a look."
      )
      |> next()
      |> mes(
        "^3355FFEnrico opened a locked chest, revealing an incredibly clear, shimmering jewel.^000000"
      )
      |> next()
      |> mes("[Enrico Kaili]")
      |> mes("Isn't it amazing?")
      |> mes("If what Valkyrie said is true, this jewel must be a crystal from Freya's teardrop.")
      |> next()
      |> mes("[Enrico Kaili]")
      |> mes(
        "I don't understand why all of this is happening so suddenly. For now, I'll have to think about the poem you heard from Valkyrie."
      )
      |> next()
      |> mes("[Enrico Kaili]")
      |> mes("A cold snowy path on")
      |> mes("which the goddess tread.")
      |> mes("A blue river the goddess crossed.")
      |> mes("A narrow path the goddess passed.")
      |> mes("Four Dwarves that the goddess met...")
      |> next()
      |> mes("[Enrico Kaili]")
      |> mes(
        "I'm sure the four Dwarves are the famous craftsmen I've studied, but I can't determine what the rest of the poem means."
      )
      |> next()
      |> mes("[Enrico Kaili]")
      |> mes("Now...")
      |> mes("I'll need your")
      |> mes("help once again!")
      |> next()
      |> select(["Wah? It's not over?!", "What is it this time?"])

    case choice do
      1 ->
        ctx
        |> mes("[Enrico Kaili]")
        |> mes("Hah...!")
        |> mes("Our work has just begun!")
        |> mes("Now, head over to Lutie")
        |> mes("and find some clues.")
        |> next()
        |> mes("[Enrico Kaili]")
        |> mes(
          "The poem mentions a snowy path, and this jewel was found there, so Lutie is a pretty well educated guess as the location of our next clue."
        )
        |> send_to_lutie()

      2 ->
        ctx
        |> mes("[Enrico Kaili]")
        |> mes("Hahahaha...!")
        |> mes("I like your attitute!")
        |> mes("Once again, Nelliorde has")
        |> mes("proven to be an excellent")
        |> mes("judge of character.")
        |> next()
        |> mes("[Enrico Kaili]")
        |> mes("The poem mentions")
        |> mes(
          "a snowy path, and this jewel was found in Lutie. So Lutie would be a pretty good place to search for the next clue."
        )
        |> send_to_lutie()

      _ ->
        ctx
    end
  end

  defp send_to_lutie(ctx) do
    ctx
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes("I hope we'll be")
    |> mes("able to learn what")
    |> mes("the goddess Freya has")
    |> mes("left behind in Midgard...")
    |> set_char_var(:god_brising, 40)
    |> close()
  end

  defp review_brisingamen_materials(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Enrico Kaili]")
      |> mes("I guess it's true that")
      |> mes("the four Dwarves have been")
      |> mes("awakened. Does this mean that Brisingamen can now be created?")
      |> next()
      |> mes("[Enrico Kaili]")
      |> mes(
        "If such a thing is possible, what do we need in order to create it? Let's review the information you've gathered..."
      )
      |> next()
      |> mes("[Enrico Kaili]")
      |> mes(
        "There's Freya's Tear Drop Crystal, Freya's Jewel, the Never-Melting Snow Crystal found where Alfrik"
      )
      |> mes("used to stay, the Drifting Air from the path where Dvalin slept. Hmm.")
      |> next()
      |> mes("[Enrico Kaili]")
      |> mes(
        "Perhaps we could find something from the pond of Freya's Gold Tears where Berling is sleeping,"
      )
      |> mes("though I am unsure.")
      |> next()
      |> mes("[Enrico Kaili]")
      |> mes("I also assume that the splendid Silver Ornament constructed by")
      |> mes("Gher is also needed to create Brisingamen.")
      |> next()
      |> mes("[Enrico Kaili]")
      |> mes("So what")
      |> mes("do you think?")
      |> next()
      |> select(["I'm not sure...", "I suppose you're right."])

    case choice do
      1 ->
        ctx =
          ctx
          |> mes("[#{char_name(ctx, 0)}]")
          |> mes("I'm not sure...")
          |> mes("I mean, maybe")
          |> mes("Alfrik would")
          |> mes("probably know, bu--")
          |> next()
          |> mes("[Enrico Kaili]")
          |> mes("Of course!")
          |> mes(
            "That's a great idea! I'll wait here while you go and ask Alfrik. You're my only hope in completing this research!"
          )
          |> next()

        ctx
        |> emotion(:scratch, playerattached(ctx))
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("(^333333I shouldn't have said anything...^000000)")
        |> next()
        |> mes("[Enrico Kaili]")
        |> mes("Well, what are")
        |> mes("waiting for? Please")
        |> mes("come back as soon")
        |> mes("as possible.")
        |> set_char_var(:god_brising, 48)
        |> close()

      2 ->
        ctx
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("I suppose")
        |> mes("you're right.")
        |> next()
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("Still, who knows what exactly is in the Pond of Freya's Golden Tears.")
        |> next()
        |> mes("[Enrico Kaili]")
        |> mes("Yes.")
        |> mes("Ah! Right.")
        |> mes("Hm, perhaps it would be")
        |> mes("best to ask Alfrik first?")
        |> next()
        |> mes("[Enrico Kaili]")
        |> mes("Hurry and seek him")
        |> mes("out! And I thank you")
        |> mes("in advance.")
        |> set_char_var(:god_brising, 48)
        |> close()

      _ ->
        ctx
    end
  end

  defp reward_research(ctx) do
    {ctx, _choice} =
      ctx
      |> mes("[Enrico Kaili]")
      |> mes(
        "Ah, I see. So it's true that Berling sealed himself in the ripple where the goddess' tear"
      )
      |> mes("fell into the waters.")
      |> next()
      |> mes("[Enrico Kaili]")
      |> mes(
        "Oh! I'm so excited! I don't know what to do first! Should I report to His Majesty or publish my findings or..."
      )
      |> next()
      |> select(["^333333*Ahem!*^000000 My reward!"])

    exp = if Rathena.truthy?(checkre(ctx, 3)), do: 60_000, else: 600_000

    ctx
    |> mes("[Enrico Kaili]")
    |> mes("Oh, right.")
    |> mes(
      "Thank you for all the trouble you have endured for my sake. You are truly one of the best researchers I've ever met."
    )
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes("Then as promised...")
    |> mes(
      "I will give you something from my precious collection! Now, let me see what we have here..."
    )
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes("Please...")
    |> mes("Take this.")
    |> set_char_var(:god_brising, 50)
    |> give_item(616, 1)
    |> getexp(exp, 0)
    |> next()
    |> mes("[Enrico Kaili]")
    |> mes("Please accept this as my way of thanking you for assisting in my")
    |> mes(
      "research. If the opportunity arises, I would like to ask you for your help once again. Now please, take care."
    )
    |> advance_third_seal()
    |> announce_third_seal()
    |> close()
  end

  defp advance_third_seal(ctx) do
    third_seal = get_server_var(ctx, "God3", 0)

    if third_seal < get_server_temp_var(ctx, "god_check2", 0) do
      set_server_var(ctx, "God3", third_seal + 1)
    else
      ctx
    end
  end

  defp announce_third_seal(ctx) do
    third_seal = get_server_var(ctx, "God3", 0)
    released = get_server_temp_var(ctx, "god_check2", 0)

    cond do
      third_seal == get_server_temp_var(ctx, "god_check1", 0) ->
        announce(ctx, "The 3rd Seal of [Brisingamen] has appeared.", 0)

      third_seal != released ->
        ctx

      all_seals_released?(ctx, released) ->
        announce(
          ctx,
          "Four seals have been released at the same time with the seal of [Brisingamen].",
          0
        )

      true ->
        announce(ctx, "The 3rd seal of [Brisingamen] has been released.", 0)
    end
  end

  defp all_seals_released?(ctx, released) do
    Enum.all?(["God1", "God2", "God3", "God4"], &(get_server_var(ctx, &1, 0) == released))
  end
end
