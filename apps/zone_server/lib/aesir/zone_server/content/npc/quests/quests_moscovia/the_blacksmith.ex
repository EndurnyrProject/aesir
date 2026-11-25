defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.TheBlacksmith do
  @moduledoc """
  The blacksmith guides adventurers seeking the materials for a Golden Key.

  ## Behavior

  - Forges steel boots and explains how to collect the key materials.
  - Directs prepared adventurers to the keymaker.

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
        map: "moscovia",
        x: 178,
        y: 127,
        dir: 0,
        sprite: 63,
        name: "The Blacksmith",
        scope: :shared,
        unique_name: "The Blacksmith#rus06"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if max_weight(ctx) - weight(ctx) < 3500 do
      ctx
      |> mes("[The Blacksmith]")
      |> mes("Why are you carrying that much?")
      |> mes("Are you training for something?")
      |> close()
    else
      cond do
        get_char_var(ctx, :rhea_rus_main, 0) < 6 ->
          greeting(ctx)

        get_char_var(ctx, :rhea_rus_main, 0) == 6 ->
          begin_search(ctx)

        get_char_var(ctx, :rhea_rus_main, 0) == 7 ->
          forge_boots(ctx)

        get_char_var(ctx, :rhea_rus_main, 0) == 8 ->
          gather_materials(ctx)

        get_char_var(ctx, :rhea_rus_main, 0) == 9 ->
          keymaker_reminder(ctx)

        get_char_var(ctx, :rhea_rus_main, 0) > 9 and get_char_var(ctx, :rhea_rus_main, 0) < 52 ->
          keymaker_location(ctx)

        get_char_var(ctx, :rhea_rus_main, 0) > 51 ->
          quest_complete(ctx)

        true ->
          ctx
      end
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp greeting(ctx) do
    ctx
    |> mes("[The Blacksmith]")
    |> mes("Bahaha~")
    |> mes("Good weather! Eh?")
    |> mes("Perfect for a picnic.")
    |> next()
    |> mes("[The Blacksmith]")
    |> mes(
      "But, I've heard that some people have become lost in the forest on the island near this village. What's going on?"
    )
    |> close()
  end

  defp begin_search(ctx) do
    {ctx, _} =
      ctx
      |> mes("[The Blacksmith]")
      |> mes("Bahaha~")
      |> mes("Good weather! Eh?")
      |> mes("Perfect for a picnic.")
      |> next()
      |> mes("[The Blacksmith]")
      |> mes(
        "But, I've heard that some people have become lost in the forest on the island near this village. What's going on?"
      )
      |> next()
      |> select(["Excuse me..."])

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes(
        "Excuse me, have you heard of a keymaker who knows how to make a '^0000ffGolden Key^000000'?"
      )
      |> next()
      |> mes("[The Blacksmith]")
      |> mes("Hmm, are you an adventurer? Who told you about the '^0000ffGolden Key^000000'?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Ah, in fact...")
      |> next()
      |> mes("- You tell him about -")
      |> mes("- Maria Morebna -")
      |> mes("- and Gray Wolf -")
      |> next()
      |> mes("[The Blacksmith]")
      |> mes("Well, then... The keymaker for the '^0000ffGolden Key^000000'.")
      |> mes("You are very lucky to have asked me about this.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("W, what do you mean...?")
      |> next()
      |> mes("[The Blacksmith]")
      |> mes(
        "I'm the only one in this town that knows what materials are needed to make the '^0000ffGolden Key^000000'! Bahaha!"
      )
      |> next()
      |> mes("[The Blacksmith]")
      |> mes("I guess you think that getting the materials will be easy huh?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Hey I didn't say...")
      |> next()
      |> mes("[The Blacksmith]")
      |> mes("Bahahaha~")
      |> mes("It will take a lot of work.")
      |> mes("A long journey awaits you")
      |> mes("If you choose to take it.")
      |> next()
      |> mes("[The Blacksmith]")
      |> mes("Your boots will be worn")
      |> mes("out after this journey.")
      |> mes("What do you think?")
      |> mes("Would you like to try?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Of course! I have to help Maria!")
      |> next()
      |> mes("[The Blacksmith]")
      |> mes("Bahaha! I like you!")
      |> mes(
        "Ok, first, bring me ^0000ff25 Steel^000000. I'm not going anywhere so come back here when you have them."
      )
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Ok so that's the first thing you need for the 'Golden Key' right?")
    |> next()
    |> mes("[The Blacksmith]")
    |> mes("Bahahaha~")
    |> mes(
      "I promise you, I'll explain when you bring the ^0000ff25 Steel^000000 to me. Please just get the Steel and come back."
    )
    |> set_char_var(:rhea_rus_main, 7)
    |> close()
  end

  defp forge_boots(ctx) do
    if count_item(ctx, 999) > 24 do
      ctx =
        ctx
        |> mes("[The Blacksmith]")
        |> mes("Ohhh, that was faster than I expected!")
        |> next()
        |> mes("[The Blacksmith]")
        |> mes("Ok then, wait here.")
        |> next()
        |> mes("- He melts the steel -")
        |> mes("- and begins to forge -")
        |> mes("- it into something !! -")
        |> next()
        |> mes("[The Blacksmith]")
        |> mes("Bahaha~, it's not my")
        |> mes("best work, but it'll do.")
        |> mes("Here ya go!")
        |> next()

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Ah?! This is?!!")
        |> next()
        |> mes("[The Blacksmith]")
        |> mes("Strong Steel Boots!")
        |> next()

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("The Golden!!.........................")
        |> mes("....................Eh, what?")
        |> next()
        |> mes("[The Blacksmith]")
        |> mes(
          "Bahaha~ Didn't I tell you? A long journey awaits you. These boots will help you on your long journey."
        )
        |> next()
        |> mes("[The Blacksmith]")
        |> mes("When they have worn out, you will know that your journey is near it's end.")
        |> next()
        |> mes("[The Blacksmith]")
        |> mes(
          "^ff0000You must always wear these boots while gathering the materials for the 'Golden Key'.^000000"
        )
        |> next()
        |> mes("[The Blacksmith]")
        |> mes(
          "Ok, I'll tell you what materials you need to get. I can make the key anytime if you get them to me."
        )
        |> next()
        |> mes("[The Blacksmith]")
        |> mes(
          "You need ^0000ff2 Cursed Ruby, 3 Gold, 1 Red Ring, 2 Lusalka's Hair, 10 Golden Thread^000000 to make the key."
        )
        |> next()
        |> mes("[The Blacksmith]")
        |> mes("Well, you know what to do now. I will be waiting here.")
        |> mes("Bahahaha~")
        |> mes("And don't forget to wear these!")
        |> delitem(999, 25)
        |> set_char_var(:rhea_rus_main, 8)

      ctx =
        if Rathena.job_id(base_class(ctx)) == Rathena.job_id(:merchant) or
             Rathena.job_id(base_class(ctx)) == Rathena.job_id(:swordman) or
             Rathena.job_id(base_class(ctx)) == Rathena.job_id(:thief) or
             Rathena.job_id(base_class(ctx)) == Rathena.job_id(:archer) do
          give_item(ctx, 2429, 1)
        else
          give_item(ctx, 2430, 1)
        end

      close(ctx)
    else
      ctx
      |> mes("[The Blacksmith]")
      |> mes("What are you doing? First, you must get me ^0000ff25 Steel^000000.")
      |> next()
      |> mes("[The Blacksmith]")
      |> mes("The faster you get me the materials, The faster you can help Maria Morebna.")
      |> close()
    end
  end

  defp gather_materials(ctx) do
    if count_item(ctx, 724) > 1 and count_item(ctx, 969) > 2 and
         Rathena.truthy?(count_item(ctx, 7877)) and count_item(ctx, 7878) > 1 and
         count_item(ctx, 7879) > 9 and get_char_var(ctx, :rhea_rus_ring, 0) > 8 and
         get_char_var(ctx, :rhea_rus_hair, 0) > 8 and get_char_var(ctx, :rhea_rus_quiz, 0) > 29 do
      if getequipid(ctx, 2) != 2429 and getequipid(ctx, 2) != 2430 do
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("...Hmm, did I forget to wear something...?")
        |> close()
      else
        explain_protection(ctx)
      end
    else
      explain_materials(ctx)
    end
  end

  defp explain_protection(ctx) do
    ctx =
      ctx
      |> mes("[The Blacksmith]")
      |> mes("So, you got all the materials. I can't believe it.")
      |> mes("You did your best until your boots were worn out, didn't you?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Yes, you know, it's not very comfortable walking around in Steel boots all day!")
      |> next()
      |> mes("[The Blacksmith]")
      |> mes("Bahaha~ Ok, well done.")
      |> mes(
        "Well.. While you were looking for the materials, I was searching for the keymaker who can make the key!"
      )
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("I thought you said that you knew how to make the key?")
      |> next()
      |> mes("[The Blacksmith]")
      |> mes(
        "Hmm... Well I know the materials. And I know who makes the key. So I will tell you where to find the keymaker. Is that ok?"
      )
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Of course! I have to know where this person is.")
      |> next()
      |> mes("[The Blacksmith]")
      |> mes("Ok, listen carefully. The Keymaker is at a cabin deep inside of the forest.")
      |> next()
      |> mes("[The Blacksmith]")
      |> mes(
        "Ah, wait. Take off your armor. I need to cast a protection spell on you, ok? Hey, don't get the wrong idea. This is just a simple protection spell!"
      )
      |> nude()
      |> next()
      |> mes("[The Blacksmith]")
      |> mes("Bah ram y--- wait that's uh something else...")
      |> next()
      |> mes("[The Blacksmith]")
      |> mes("'^ff0000Spellshield Protection^000000.")
      |> specialeffect2(:absorbspirits)
      |> next()
      |> mes("[The Blacksmith]")
      |> mes(
        "This spell protects you from any curse the keymaker might try to use. Remember the words of the spell. It won't last very long because I am just a blacksmith."
      )
      |> next()
      |> mes("[The Blacksmith]")

    cond do
      Rathena.truthy?(count_item(ctx, 2429)) ->
        ctx |> delitem(2429, 1) |> finish_protection()

      Rathena.truthy?(count_item(ctx, 2430)) ->
        ctx |> delitem(2430, 1) |> finish_protection()

      true ->
        ctx
        |> mes("The forest is dangerous. Be very careful in there!")
        |> mes("Ah, and your steel boots..?")
        |> next()
        |> mes("[The Blacksmith]")
        |> mes("Where are they?")
        |> close()
    end
  end

  defp finish_protection(ctx) do
    ctx
    |> mes("The forest is dangerous. Be very careful in there!")
    |> mes("Ah and you shouldn't be needing those Steel Boots anymore. Good luck!")
    |> set_char_var(:rhea_rus_main, 9)
    |> close()
  end

  defp explain_materials(ctx) do
    {ctx, material_choice} =
      ctx
      |> mes("[The Blacksmith]")
      |> mes(
        "You need ^0000ff2 Cursed Ruby, 3 Gold, 1 Red Ring, 2 Lusalka's Hair, 10 Golden Thread^000000 to make the key."
      )
      |> next()
      |> select(["Red Ring?", "Lusalka's Hair?", "Golden Thread?"])

    case material_choice do
      1 ->
        ctx
        |> mes("[The Blacksmith]")
        |> mes(
          "The Red Ring has powerful enchanting powers. I had one before, but I gave it to my friend, Vassili, as a gift."
        )
        |> next()
        |> mes("[The Blacksmith]")
        |> mes(
          "I think it would be odd to ask him to give it back to me. So uh you've got to ask him if he would give it to you."
        )
        |> material_reminder()

      2 ->
        ctx
        |> mes("[The Blacksmith]")
        |> mes(
          "It's said that a bride who drowns to death just before her wedding becomes Lusalka, the aqua fairy."
        )
        |> mes("You must find Lusalka's hair.")
        |> next()
        |> mes("[The Blacksmith]")
        |> mes("I heard that a young maid has been lost recently.")
        |> mes("It's very unfortunate but...")
        |> mes("she might be Lusalka...")
        |> next()
        |> mes("[The Blacksmith]")
        |> mes(
          "Her mother is somewhere in this village asking for people to help her find her missing daughter."
        )
        |> material_reminder()

      3 ->
        ctx
        |> mes("[The Blacksmith]")
        |> mes(
          "Golden Thread is made from gold by using a special spinning wheel technique. I don't know exactly how it's done. But I know who does."
        )
        |> next()
        |> mes("[The Blacksmith]")
        |> mes(
          "Find a man named Marozka. He is the only one who knows how to use the spinning wheel to make the Golden Thread."
        )
        |> next()
        |> mes("[The Blacksmith]")
        |> mes("Maria should know where he is.")
        |> material_reminder()

      _ ->
        ctx
    end
  end

  defp material_reminder(ctx) do
    ctx
    |> next()
    |> mes("[The Blacksmith]")
    |> mes(
      "Ah, and... You still have the boots that I made right? ^ff0000Without them, you cannot get anything for the key, I swear. You must put on them.^000000"
    )
    |> next()
    |> mes("[The Blacksmith]")
    |> mes("Well, you know what to do now. I will be waiting here.")
    |> close()
  end

  defp keymaker_reminder(ctx) do
    ctx
    |> mes("[The Blacksmith]")
    |> mes("The keymaker is at a cabin deep inside of the forest.")
    |> next()
    |> mes("[The Blacksmith]")
    |> mes(
      "This person is no ordinary person. It is said that you can be cursed by the keymaker's words."
    )
    |> next()
    |> mes("[The Blacksmith]")
    |> mes("Don't forget the spell, '^ff0000Spellshield Protection.^000000'")
    |> close()
  end

  defp keymaker_location(ctx) do
    ctx
    |> mes("[The Blacksmith]")
    |> mes(
      "He is in his cabin deep inside of the forest. There, the keymaker of the Golden Key is living."
    )
    |> next()
    |> mes("[The Blacksmith]")
    |> mes("The Golden Key is able to release Maria. Good luck!")
    |> close()
  end

  defp quest_complete(ctx) do
    ctx
    |> mes("[The Blacksmith]")
    |> mes("I heard the news. You have done well.")
    |> next()
    |> mes("[The Blacksmith]")
    |> mes(
      "Ah, the person living around that cabin wants you to see her. She seems to have something to tell you."
    )
    |> close()
  end
end
