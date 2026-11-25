defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.ChiefBalrog do
  @moduledoc """
  Chief Balrog recruits adventurers into the Continental Guard and rewards them for driving off
  Satan Morocc.

  ## Behavior

  - Until the Continental Guard Official registers the player, he only points them to the other
    guards and messengers.
  - A registered player above base level 79 who insists three times is tested with 30 Live Coals,
    then 50 Glacial Hearts, and receives the Continental Guard certificate (quests 3050 to 3053).
  - Guard members can hear a briefing on the situation around Morocc.
  - Satan Morocc's skin is exchanged for base EXP (200,000 with renewal EXP, 2,000,000 otherwise)
    and a choice of the Seal of Continental Guard, Morocc Charm Stone or Morocc Ring; declining
    the choice keeps it open for a later visit.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Gepard
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "morocc", x: 159, y: 113, dir: 3, sprite: 752, name: "Chief Balrog", scope: :shared}
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :rebirth_moc_edq, 0) do
      1 -> recruitment(ctx)
      2 -> live_coals(ctx)
      3 -> glacial_hearts(ctx)
      4 -> offer_briefing(ctx)
      5 -> unproven_victory(ctx)
      6 -> morocc_skin(ctx)
      7 -> choose_reward(ctx)
      8 -> after_victory(ctx)
      _ -> greeting(ctx)
    end
  end

  defp greeting(ctx) do
    ctx
    |> introduce()
    |> balrog(
      "I'm sorry, but I'm too busy checking through all these applications for future Continental Guards to greet you adventurers one by one."
    )
    |> next()
    |> balrog(
      "Listen, it might be more helpful if you talk to some other people first. I'm sure one of the other Continental Guards or our messengers will be better equipped to help you out."
    )
    |> close()
  end

  defp recruitment(ctx) do
    {ctx, choice} =
      ctx
      |> introduce()
      |> balrog(
        "It looks like you have business with me. Please make it brief since I don't have a lot of time on my hands. There's lots of things I need to take care of..."
      )
      |> next()
      |> select([
        "Ask about Continental Guards",
        "I want to join the Continental Guard.",
        "End Conversation"
      ])

    case choice do
      1 -> about_guard(ctx)
      2 -> volunteer(ctx)
      3 -> close(ctx)
      _ -> ctx
    end
  end

  defp about_guard(ctx) do
    ctx
    |> balrog(
      "The damage that Satan Morocc's resurrection has caused is obvious just by taking a look around this area."
    )
    |> mes(
      "What's scary is that all this was caused just by breaking out from it's prison. Just think of the damage it could do if it was left to roam around freely..."
    )
    |> next()
    |> balrog(
      "Morocc Village is completely devastated, and Satan Morocc has now claimed possession of the Sograt Desert."
    )
    |> next()
    |> balrog(
      "I've no doubt that if left unchecked, Satan Morocc will take over the entire Midgard Continent. We've got to stop him right now before the entire world suffers."
    )
    |> next()
    |> balrog(
      "That's why the kingdom has ordered us elite soldiers to form the Continental Guard, and recruit reputable adventurers around the world so that we can make a united stand against Satan Morocc."
    )
    |> next()
    |> balrog(
      "Of course, it'll be incredibly difficult... We'll need to make sacrifices... I'm not even sure if we can win. Still, the fate of the world is at stake, and we've got to do something. Dark times have truly fallen upon us..."
    )
    |> close()
  end

  defp volunteer(ctx) do
    ctx =
      ctx
      |> balrog("Huh? Do you want to join us and volunteer for the Continental Guard?")
      |> next()

    if base_level(ctx) > 79, do: hear_of_you(ctx), else: too_weak(ctx)
  end

  defp hear_of_you(ctx) do
    ctx
    |> balrog("What was your name? #{char_name(ctx, 0)}? Oh yes, I've heard of you.")
    |> next()
    |> balrog(
      "Hmm, it occurs to me that you don't understand the danger involved in all this. Do you have any idea how powerful Satan Morocc is?"
    )
    |> next()
    |> warn_inexperienced()
    |> next()
    |> select(["End Conversation", "Ask Again"])
    |> continue_or_close(&ask_again/1)
  end

  defp ask_again(ctx) do
    ctx
    |> balrog(
      "Look, I understand your enthusiasm, but you're mistaken if you think you can help us. I don't have time to fully explain the danger that we're all facing."
    )
    |> next()
    |> balrog(
      "Satan Morocc is nothing like the monsters you may have encountered. At best you'll throw your life away, but there's the chance that you might get one of my men killed by your mistakes and incompetence. I can't have that!"
    )
    |> next()
    |> balrog(
      "Please understand that this is for your own good. Fight some Porings or whatever else might be a good match for your level."
    )
    |> next()
    |> select(["End Conversation", "You've just got to let me join!"])
    |> continue_or_close(&insist/1)
  end

  defp insist(ctx) do
    ctx
    |> balrog(
      "Sigh... Why are you so persistent? Can't you understand that no means no? Let me say this one more time."
    )
    |> next()
    |> balrog(
      "We're too busy fighting Satan Morocc to watch after rookies like you. You'd just be throwing your life away."
    )
    |> next()
    |> balrog("Stop bothering me. You'd be nothing but a burden.")
    |> next()
    |> select(["Give Up", "Give me a chance to prove myself!"])
    |> continue_or_close(&live_coal_task/1)
  end

  defp live_coal_task(ctx) do
    {ctx, choice} =
      ctx
      |> balrog("Huh? You want a chance to prove yourself?")
      |> next()
      |> player("Yes, I'll do whatever it takes to join the Continental Guard!")
      |> next()
      |> balrog("Hmm...")
      |> next()
      |> balrog(
        "Interesting. You have my attention. Alright, I guess it's only fair that I acknowledge your strength if you can handle something for me."
      )
      |> next()
      |> balrog(
        "The Continental Guard has been on full alert around this village and the desert. We need to be prepared in case Satan Morocc storms our defenses."
      )
      |> next()
      |> balrog(
        "Soldiers need firewood to keep the bonfires burning all night, but we've been suffering a firewood shortage."
      )
      |> next()
      |> balrog(
        "I happened to hear that the monsters in the Lava Dungeon have everlasting flame which would solve our bonfire problems. I want you to gather those flames for us."
      )
      |> next()
      |> select(["That's too hard! Let me think about it!", "No problem."])

    case choice do
      1 ->
        ctx
        |> balrog(
          "Hmpf, I was right. I knew you wouldn't be able to handle such a simple task. I shouldn't have wasted my time with you."
        )
        |> close()

      2 ->
        ctx
        |> balrog(
          "Excellent! Bring back ^0000FF30 Live Coals^000000. I'll be waiting for your return."
        )
        |> set_char_var(:rebirth_moc_edq, 2)
        |> changequest(3050, 3051)
        |> close()

      _ ->
        ctx
    end
  end

  defp too_weak(ctx) do
    ctx
    |> balrog(
      "What? How can you even think of joining us when you don't have any real skills to offer?"
    )
    |> next()
    |> balrog(
      "I guarantee that you'd just drag my soldiers down with you. You'd only be a threat to Satan Morocc in your dreams. Just give it up."
    )
    |> next()
    |> warn_inexperienced()
    |> close()
  end

  defp warn_inexperienced(ctx) do
    ctx
    |> balrog(
      "You won't be able to help us if you don't fully understand the risks. I've seen thousands of foolhardy adventurers throw their lives away by thinking they could defeat Satan Morocc with their own strength."
    )
    |> next()
    |> balrog(
      "We are facing a threat that will determine the world's future, and fools that can't work in a team will be liabilities, not assets."
    )
    |> next()
    |> balrog(
      "I'm sorry, but inexperienced adventurers would just get in our way. I hope you understand. If you really want to help us, then please focus on your training for now."
    )
  end

  defp live_coals(ctx) do
    ctx =
      ctx
      |> balrog(
        "So, did you find ^0000FF30 Live Coals^000000? You didn't come empty-handed, did you?"
      )
      |> next()

    if count_item(ctx, 7098) > 29,
      do: glacial_heart_task(ctx),
      else: remind(ctx, "30 Live Coals, 30")
  end

  defp glacial_heart_task(ctx) do
    {ctx, choice} =
      ctx
      |> balrog(
        "Let's see... One, two, three... Thirty, you've brought them all. Well, this was a pretty simple task. All it takes is time and a little effort. Anyone could do it."
      )
      |> next()
      |> balrog(
        "Anyways, thank you for bringing the Live Coals. I guess you're stronger than I thought."
      )
      |> next()
      |> player("Now will you let me join the Continental Guard?")
      |> next()
      |> balrog(
        "No, gathering these flames is a piece of cake compared to what we're going to do."
      )
      |> next()
      |> balrog(
        "I'm still not convinced that you're good enough to join us. Let me think... Hmm..."
      )
      |> next()
      |> player(
        "I didn't think you would accept me so easily. I'm ready. Ask me whatever you want."
      )
      |> next()
      |> balrog(
        "Ah, I've got an idea. Now, because this is an allied operation, we've accepted some mercenary soldiers from the Schwarzwald Republic to join the Continental Guard."
      )
      |> next()
      |> balrog(
        "These mercenaries have never seen the desert, and they're having trouble carrying out operations in the heat, dry air, and sandstorms. It's not their fault, but they could use a little help since they're out of their element."
      )
      |> next()
      |> player("(This guy seems threatening, but he seems to have a good heart.)")
      |> next()
      |> balrog(
        "Now, I remember hearing that the monsters in the Ice Cave to the north have frozen hearts. Those hearts might be able to relieve those soldiers from the heat."
      )
      |> next()
      |> select(["That's too hard!", "No problem. How many do you want?"])

    case choice do
      1 ->
        ctx
        |> balrog(
          "I knew that'd be too tough for you. I'm glad you finally realized your limits before it was too late. It takes wisdom to recognize your weakness."
        )
        |> next()
        |> balrog(
          "You'd better pack up and return where you came from. You want to be far away from here when Satan Morocc attacks."
        )
        |> close()

      2 ->
        ctx
        |> balrog("Huh?! Are you sure you can bring those? Hmm...")
        |> next()
        |> balrog(
          "Well... If you insist on giving it a try, then... I'll need at least 50 of those frozen hearts."
        )
        |> next()
        |> balrog(
          "Please bring me ^0000FF50 Glacial Hearts^000000. The faster you get them here, the better."
        )
        |> delitem(7098, 30)
        |> set_char_var(:rebirth_moc_edq, 3)
        |> changequest(3051, 3052)
        |> close()

      _ ->
        ctx
    end
  end

  defp glacial_hearts(ctx) do
    ctx = ctx |> balrog("So, did you find 50 Glacial Hearts?") |> next()

    if count_item(ctx, 7561) > 49,
      do: welcome_to_guard(ctx),
      else: remind(ctx, "50 Glacial Hearts, 50")
  end

  defp welcome_to_guard(ctx) do
    ctx
    |> balrog(
      "Thank you. I'm sure that my soldiers will appreciate these... Those guys aren't used to the desert, and could use the relief."
    )
    |> next()
    |> balrog("Well... It looks like you earned this.")
    |> delitem(7561, 50)
    |> give_item(7826, 1)
    |> set_char_var(:rebirth_moc_edq, 4)
    |> changequest(3052, 3053)
    |> next()
    |> player("What's this?")
    |> next()
    |> balrog(
      "You'd know if you read it. It's a certificate that proves that you're a member of the Continental Guard. I admit that I'm impressed by your skills and gumption."
    )
    |> next()
    |> balrog(
      "Welcome to the Continental Guard, my friend. Are you ready to risk your life for the sake of peace in the world?"
    )
    |> next()
    |> balrog(
      "Your mission from here on will be simple, but extremely difficult: you will join the rest of the Continental Guard to keep Satan Morocc from fully reviving its true power."
    )
    |> next()
    |> balrog(
      "My soldiers are risking their lives to fight Morocc's doppelgangers and underlings in order to make it safer for their comrades to travel to Morocc's lair."
    )
    |> next()
    |> balrog(
      "It looks like your help could be useful after all. It's time for you to pitch in. Good luck."
    )
    |> close()
  end

  defp remind(ctx, amount) do
    ctx
    |> balrog("Umm... Didn't you hear what I said? I said #{amount}.")
    |> next()
    |> balrog("Now hurry up. If you feel like giving up, it's no problem. Let me know, though!")
    |> close()
  end

  defp offer_briefing(ctx) do
    {ctx, choice} =
      ctx
      |> balrog("I guess you'd benefit from a full situational briefing. Shall I brief you now?")
      |> next()
      |> select(["Yes", "No"])

    case choice do
      1 ->
        briefing(ctx)

      2 ->
        ctx
        |> balrog(
          "I see. Keep up your good work in fighting Satan Morocc. Don't forget that the future of the continent is in our hands."
        )
        |> close()

      _ ->
        ctx
    end
  end

  defp briefing(ctx) do
    ctx
    |> balrog(
      "I'm going to tell you some basic information about fighting Satan Morocc as a member of the Continental Guard."
    )
    |> next()
    |> balrog(
      "Do you remember what Morocc was like before this happened? You would if you've been here before."
    )
    |> next()
    |> balrog(
      "Right now, all of Morocc's entrances and the outer fields leading to other villages are currently under our control."
    )
    |> next()
    |> balrog(
      "The main reason for this is because Satan Morocc has been sighted in Sograt Desert, but there's another important reason."
    )
    |> next()
    |> balrog(
      "Satan Morocc's power has been causing unnatural gaps in our time-space continuum. The gaps are isolated to this area for now, but we can't be sure if they'll spread."
    )
    |> next()
    |> balrog(
      "Due to the time-space gaps, Sograt Desert's terrain has changed, and some parts of the desert have disappeared."
    )
    |> next()
    |> balrog(
      "Furthermore, the situation's gotten worse since Satan Morocc's doppelgangers started appearing, and other monsters have become influenced by its power."
    )
    |> next()
    |> balrog(
      "That's all we know so far. If you go out, you'll see what I mean... You may even see horrors that we haven't discovered yet. If you need more information, please speak to the Continental Official."
    )
    |> next()
    |> balrog(
      "Please do your best to hold back Satan Morocc. Don't forget that the future of the continent is in our hands. Dismissed."
    )
    |> close()
  end

  defp unproven_victory(ctx) do
    ctx
    |> balrog("Wah... What? Did you really defeat Satan Morocc?")
    |> next()
    |> balrog("How? Do you have any proof of your victory?")
    |> next()
    |> demand_proof()
  end

  defp morocc_skin(ctx) do
    ctx =
      ctx
      |> balrog("What? Did you really defeat Satan Morocc?")
      |> next()
      |> balrog("How? Do you have any proof of your victory?")
      |> next()

    if count_item(ctx, 7820) > 0, do: accept_skin(ctx), else: demand_proof(ctx)
  end

  defp demand_proof(ctx) do
    ctx
    |> balrog(
      "...No, I can't just accept and trust your verbal account. I mean, if you've completed such an important mission, you must bring me some evidence."
    )
    |> next()
    |> balrog("Go back, bring proof of your victory, and then come back.")
    |> close()
  end

  defp accept_skin(ctx) do
    ctx
    |> balrog("Is... Isn't this?")
    |> next()
    |> balrog(
      "Wow... I think this is really the skin of Satan Morocc. Congratulations, soldier. You just saved this world and people from being consumed by destruction and evil."
    )
    |> next()
    |> balrog(
      "I guess you seriously wounded Satan Morocc, and it retreated to a time-space gap. No doubt it's trying to recoup its strength."
    )
    |> next()
    |> balrog(
      "My only regret is that we can't pursue Morocc beyond this dimension. I'm glad, however, that you defeated Satan Morocc and kept it from regaining its full strength. For now, anyway..."
    )
    |> next()
    |> balrog(
      "Our researchers might be able to learn some important new facts from this piece of skin... We need to learn all we can about that monster if peace is to be possible in our world's future."
    )
    |> next()
    |> balrog(
      "Once again, I thank you for your distinguished service on behalf of the Continental Guard and the Rune-Midgarts Kingdom. I'll report your great achievement to His Majesty right away."
    )
    |> next()
    |> delitem(7820, 1)
    |> getexp(if(checkre(ctx, 3) == 1, do: 200_000, else: 2_000_000), 0)
    |> set_char_var(:rebirth_moc_edq, 7)
    |> changequest(3055, 3056)
    |> choose_reward()
  end

  defp choose_reward(ctx) do
    {ctx, choice} =
      ctx
      |> balrog(
        "I've prepared a few things to give as a reward for you. Let's see... I have three items. Which one do you like to receive?"
      )
      |> next()
      |> select(["1. Seal of Continental Guard", "2. Morocc Charm Stone", "3. Morocc Ring"])

    case choice do
      1 ->
        ctx
        |> balrog(
          "The Seal of Continental Guard is an extremely valuable reward given directly from the kingdom court. It is a symbol of strength."
        )
        |> next()
        |> balrog("The accessory's options are: ^0000FF MHP+50, +3% Attack Speed^000000.")
        |> next()
        |> confirm_reward(
          "the Seal of Continental Guard",
          2730,
          "No problem. Take your time to think, and then speak to me again."
        )

      2 ->
        ctx
        |> balrog(
          "The Morocc Charm Stone is an extremely valuable reward given directly from the kingdom court, and it is a symbol of prosperity and mana."
        )
        |> next()
        |> balrog("The accessory's options are: ^0000FF MSP+50, -1% Casting Speed^000000.")
        |> next()
        |> confirm_reward(
          "a Morocc Charm Stone",
          2731,
          "No problem. Take your time to think, and then speak to me again."
        )

      3 ->
        ctx
        |> balrog(
          "The Morocc Ring is an extremely valuable reward given directly from the kingdom court that symbolizes critical power."
        )
        |> next()
        |> balrog("The accessory's option is: ^0000FF CRI + 5^000000.")
        |> next()
        |> confirm_reward(
          "a Morocc Ring",
          2732,
          "No problem. Take your time to think about it, and then speak to me again."
        )

      _ ->
        ctx
    end
  end

  defp confirm_reward(ctx, reward, item_id, decline) do
    {ctx, choice} =
      ctx
      |> balrog("Do you really want #{reward}?")
      |> next()
      |> select(["1. Yes.", "2. No."])

    case choice do
      1 ->
        ctx
        |> balrog("Great, then I'll reward you with #{reward}. Congratulations.")
        |> next()
        |> give_item(item_id, 1)
        |> set_char_var(:rebirth_moc_edq, 8)
        |> completequest(3056)
        |> balrog(
          "I hope you keep in mind that our battle is far from over. Our enemy is the king of demons... I fear that Satan Morocc will return someday soon."
        )
        |> next()
        |> balrog(
          "Enjoy your victory, but be ever watchful and vigilant. I will always be here to help and reward you for your service."
        )
        |> next()
        |> balrog("You should go rest now. Don't worry, we'll take care of everything else here.")
        |> close()

      2 ->
        ctx |> balrog(decline) |> close()

      _ ->
        ctx
    end
  end

  defp after_victory(ctx) do
    ctx
    |> balrog(
      "I've heard that the kingdom is planning to send out a large group of researchers to investigate the other world to which Satan Morocc has escaped."
    )
    |> next()
    |> balrog(
      "That means it's time for both of us -- you and I -- to get to work. Who knows when Morocc will return to plague us?"
    )
    |> next()
    |> balrog(
      "Please keep up the good work, and don't forget that the future of the continent and the kingdom relies on us."
    )
    |> close()
  end

  defp introduce(ctx) do
    ctx
    |> balrog(
      "You've come here at a bad time, but it's nice to meet you. I'm Continental Guard Chief Balrog. We've been dispatched to Morocc in order to suppress Satan Morocc... We'll need all the strength and luck we can gather."
    )
    |> next()
  end

  defp continue_or_close({ctx, 1}, _continue), do: close(ctx)
  defp continue_or_close({ctx, 2}, continue), do: continue.(ctx)
  defp continue_or_close({ctx, _choice}, _continue), do: ctx

  defp balrog(ctx, text), do: ctx |> mes("[Chief Balrog]") |> mes(text)

  defp player(ctx, text), do: ctx |> mes("[#{char_name(ctx, 0)}]") |> mes(text)
end
