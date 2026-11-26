defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNiflheim.Erious do
  @moduledoc """
  A grieving Prontera widower who starts and rewards the Message Delivery quest to his late wife.

  ## Behavior

  - Comforting him and offering to carry his message starts the quest.
  - While the message is undelivered, he hints that the town of the dead lies near a rest area.
  - Returning after Feylin's ritual ends the quest: with Elly's Mementos he rewards
    Yggdrasil Berries, Seeds and Leaves; after a failed ritual he rewards Yggdrasil Leaves.
    Either reward waits until the player can carry it.
  - Claiming to have met Elly without her Mementos, or denying it while carrying them, earns
    a rebuke.
  - After the quest he only wishes the player safe travels.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - Evera
    - Lupus
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_in",
        x: 161,
        y: 20,
        dir: 3,
        sprite: 92,
        name: "Erious",
        scope: :shared,
        unique_name: "Erious#nif"
      }
    ]

  @delivered 16_384
  @mementos 934
  @yggdrasil_berry 607
  @yggdrasil_seed 608
  @yggdrasil_leaf 610

  @impl true
  def on_talk(ctx) do
    if :erlang.band(get_char_var(ctx, :MISC_QUEST, 0), @delivered) != 0 do
      ctx
      |> mes("[Erious]")
      |> mes("I wish you safety from harm")
      |> mes("in your journeys, adventurer.")
      |> close()
    else
      case get_char_var(ctx, :nif_revive, 0) do
        0 -> grieve(ctx)
        1 -> hint_town(ctx)
        nif_revive when nif_revive in [5, 6] -> ask_about_elly(ctx, nif_revive)
        _ -> ctx
      end
    end
  end

  defp grieve(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Erious]")
      |> mes("*Sob*Sob*")
      |> mes("*Cries* Wahhh...!")
      |> mes("Elly, how could you")
      |> mes("leave me this way...")
      |> emotion(:cry)
      |> next()
      |> select(["Comfort him.", "Neglect him."])

    if choice == 1 do
      comfort(ctx)
    else
      ctx
      |> mes("[Erious]")
      |> mes("*Cries* Eeeeelllllyyyy~~~~!")
      |> mes("I never thought that would be")
      |> mes("the last time we would see")
      |> mes("each other...")
      |> mes("*Sob*...")
      |> close()
    end
  end

  defp comfort(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Erious]")
      |> mes("Ah, thank you for your kindness.")
      |> mes("*Sob* My wife died while I was on")
      |> mes("a trip. I'm so sorry that I")
      |> mes("couldn't be with her when")
      |> mes("the end came...")
      |> next()
      |> mes("[Erious]")
      |> mes("I wish I could talk to my Elly,")
      |> mes("although I know it's too late now.")
      |> mes("*Cries* But... there is one last")
      |> mes("hope that I have. My absolute")
      |> mes("final chance...")
      |> next()
      |> mes("[Erious]")
      |> mes("I was told that somewhere")
      |> mes("in this world, there exists a town")
      |> mes("where the dead reside. I might be")
      |> mes("able to meet my wife there, but")
      |> mes("I cannot leave my children here")
      |> mes("without me. *Cries*")
      |> next()
      |> select(["I can deliver your message to her.", "I am so sorry to hear that."])

    if choice == 1 do
      accept_message(ctx)
    else
      ctx
      |> mes("[Erious]")
      |> mes("*Cries* Is there no way that I")
      |> mes("can see her again? If I could")
      |> mes("talk to her at least once more,")
      |> mes("even if it's the last time,")
      |> mes("I would do anything...")
      |> close()
    end
  end

  defp accept_message(ctx) do
    ctx
    |> mes("[Erious]")
    |> mes("Oh, can you?")
    |> mes("Thank you so much for your")
    |> mes("generosity. If you can do")
    |> mes("this for me, I would be")
    |> mes("greatly indebted to you.")
    |> next()
    |> mes("[Erious]")
    |> mes("You're an adventurer, aren't you?")
    |> mes("If your journeys take you to that")
    |> mes("town of the dead, and if you")
    |> mes("happen to meet her by chance...")
    |> next()
    |> mes("[Erious]")
    |> mes("Please send Elly a message for me,")
    |> mes("let her know that what happened")
    |> mes("a month ago was all my fault.")
    |> mes("Thank you for your help,")
    |> mes("and please take care.")
    |> set_char_var(:nif_revive, 1)
    |> setquest(11_038)
    |> close()
  end

  defp hint_town(ctx) do
    ctx
    |> mes("[Erious]")
    |> mes("This place I was told about...")
    |> mes("The town of the dead...")
    |> mes("From what I remember, it was")
    |> mes("located near some rest area.")
    |> next()
    |> mes("[Erious]")
    |> mes("All day and night, it's filled")
    |> mes("with never ending screams of")
    |> mes("agony and despair. I hope that")
    |> mes("this will be helpful in your search.")
    |> close()
  end

  defp ask_about_elly(ctx, nif_revive) do
    {ctx, choice} =
      ctx
      |> mes("[Erious]")
      |> mes("Oh my! You really found the town,")
      |> mes("have you? I really appreciate that")
      |> mes("you've endured all this hardship")
      |> mes("for me... Um...So in the end...")
      |> mes("Were you able to meet my Elly?")
      |> next()
      |> select(["Yes.", "Sorry, I couldn't."])

    case {choice, nif_revive} do
      {1, 6} -> claim_met(ctx)
      {1, 5} -> scam_rebuke(ctx)
      {_, 5} -> console(ctx)
      {_, 6} -> denial_rebuke(ctx)
    end
  end

  defp claim_met(ctx) do
    if count_item(ctx, @mementos) > 0 do
      receive_mementos(ctx)
    else
      ctx
      |> mes("[Erious]")
      |> mes(
        "Hmm...this is odd. I'm sure she would give you something as a token of meeting her. By any chance, is there anything that you've forgetten to bring me?"
      )
      |> close()
    end
  end

  defp receive_mementos(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Erious]")
      |> mes("Are you serious? What did she say?")
      |> mes("Did she say she will forgive me?")
      |> next()
      |> select(["Yes. And she gave me...this."])

    ctx =
      ctx
      |> delitem(@mementos, 1)
      |> mes("[Erious]")
      |> mes("Ah...In this box were the gifts")
      |> mes("I gave her when we started")
      |> mes("seeing each other. She had a")
      |> mes("serious illness even before we")
      |> mes("met, so I promised her that I")
      |> mes("would cure her illness...")
      |> next()
      |> mes("[Erious]")
      |> mes("That's why I went on that trip...")
      |> mes("to find a cure or medicine")
      |> mes("for her... But my efforts turned")
      |> mes("out to be a good for nothing.")
      |> mes("...................")
      |> mes(".........")
      |> next()
      |> mes("[Erious]")
      |> mes("Anyway, I appreciate your")
      |> mes("generousity. I want to pay")
      |> mes("you back for all the trouble")
      |> mes("I caused you, but I only have")
      |> mes("the medicine I found for her")
      |> mes("illness during this trip.")
      |> next()
      |> mes("[Erious]")
      |> mes("I hope you will take this medicine")
      |> mes("as a token of my gratitute.")
      |> next()

    if checkweight(ctx, [{@yggdrasil_leaf, 26}]) == 1 do
      ctx
      |> finish_quest(11_043)
      |> give_item(@yggdrasil_berry, 2)
      |> give_item(@yggdrasil_seed, 2)
      |> give_item(@yggdrasil_leaf, 10)
      |> mes("[Erious]")
      |> mes("Thank you for everything.")
      |> mes("I wish you luck and safety")
      |> mes("in your adventures.")
      |> close()
    else
      overweight(ctx)
    end
  end

  defp console(ctx) do
    ctx =
      ctx
      |> mes("[Erious]")
      |> mes("I see...you have failed to find")
      |> mes("her... However, I also understand")
      |> mes("that fulfilling my request may")
      |> mes("be impossible...")
      |> next()
      |> mes("[Erious]")
      |> mes("You've really gone out of your way")
      |> mes("to help me, so I want to give you")
      |> mes("something as a token of my")
      |> mes("gratitute.")
      |> next()

    if checkweight(ctx, [{@yggdrasil_leaf, 10}]) == 1 do
      ctx
      |> finish_quest(11_042)
      |> give_item(@yggdrasil_leaf, 10)
      |> mes("[Erious]")
      |> mes("Thank you for everything.")
      |> mes("I wish you luck and safety")
      |> mes("from harm in your journeys.")
      |> close()
    else
      overweight(ctx)
    end
  end

  defp finish_quest(ctx, quest_id) do
    ctx
    |> set_char_var(:MISC_QUEST, :erlang.bor(get_char_var(ctx, :MISC_QUEST, 0), @delivered))
    |> set_char_var(:nif_revive, 0)
    |> completequest(quest_id)
  end

  defp overweight(ctx) do
    ctx
    |> mes("[Erious]")
    |> mes("I have something to give you,")
    |> mes("but you're carrying too much")
    |> mes("stuff for me to give it to")
    |> mes("right now. Why don't you")
    |> mes("store your items somewhere?")
    |> close()
  end

  defp scam_rebuke(ctx) do
    ctx
    |> mes("[Erious]")
    |> mes("I guess you misunderstood")
    |> mes("something or you're trying")
    |> mes("to scam a man in grief.")
    |> close()
  end

  defp denial_rebuke(ctx) do
    ctx
    |> mes("[Erious]")
    |> mes("I see...")
    |> mes("...Wait! Doesn't that belong")
    |> mes("to my wife, Elly? Why are you")
    |> mes("trying to cheat a grieving man...?")
    |> close()
  end
end
