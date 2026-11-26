defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.MegingardSeal.Lady do
  @moduledoc """
  Emma Searth, a former Crusader hoping to join the Kafra Corporation, slowly recovers her lost
  memories of her old squad during the Megingard Seal quest.

  ## Behavior

  - A player carrying too many items is turned away first.
  - Outside the Megingard seal phase she only talks about her Kafra dream.
  - While the player searches for the squad, she tells her story: with a Memory Bookmark she
    recalls her past, and after Jack O's lead, a Green Herb makes her recall the squad and the
    name Egnigem.
  - Once the quest reaches its end, she thanks the player with an Old Blue Box and base
    experience scaled by base level and game mode.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Lupus
    - L0ne_W0lf
    - Samuray22
    - brianluau
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
        map: "aldebaran",
        x: 66,
        y: 213,
        dir: 0,
        sprite: 69,
        name: "Lady",
        scope: :shared,
        unique_name: "Lady#megin"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @renewal_reward_exp {2700, 3000, 5605, 8223, 21_227, 39_073, 45_102, 54_615, 122_035}
  @pre_renewal_reward_exp {27_000, 30_000, 56_052, 82_233, 212_271, 390_738, 451_020, 546_156,
                           1_220_358}

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{1301, 3}]) == 0 ->
        ctx
        |> mes("- You are carrying too many items!")
        |> close()

      seal_phase_open?(ctx) ->
        seal_talk(ctx, get_char_var(ctx, :god_eremes, 0))

      true ->
        ctx
        |> mes("[Emma Searth]")
        |> mes(
          "I hear the Kafra Ladies always travel around the world, something I've always dreamed of doing! Hopefully, one of these days, I'll be able to work for the Kafra Corporation too."
        )
        |> next()
        |> mes("[Emma Searth]")
        |> mes("^333333*Sigh...*^000000")
        |> mes("Still, it's discouraging. I haven't heard anything from them...")
        |> close()
    end
  end

  defp seal_phase_open?(ctx) do
    get_server_var(ctx, "God1", 0) >= get_server_temp_var(ctx, "god_check1", 0) and
      get_server_var(ctx, "God2", 0) < get_server_temp_var(ctx, "god_check2", 0)
  end

  defp seal_talk(ctx, stage) do
    cond do
      stage == 18 ->
        ctx |> sigh() |> close()

      stage > 18 and stage < 26 ->
        squad_search(ctx, get_char_var(ctx, :god_megin_4, 0))

      stage == 25 ->
        ctx |> egnigem_sadness() |> close()

      stage == 26 or stage == 27 ->
        reward(ctx)

      stage == 28 ->
        ctx
        |> egnigem_sadness()
        |> next()
        |> turns_away()
        |> close()

      true ->
        ctx |> sigh() |> close()
    end
  end

  defp squad_search(ctx, memories) when memories < 2 do
    {ctx, choice} =
      ctx
      |> sigh()
      |> next()
      |> mes("[Emma Searth]")
      |> mes(
        "Oh, an adventurer! I actually used to work in the same field that you do. More specifically, I used to be a Crusader."
      )
      |> next()
      |> mes("[Emma Searth]")
      |> mes(
        "My name is Emma Searth. Right now, I'm following my dream and applying to be a Kafra Lady. So my days of wielding a sword are over."
      )
      |> next()
      |> mes("[Emma Searth]")
      |> mes("Sadly, I haven't succeeded yet because I was diagnosed with")
      |> mes("some weird ^0000FFamnesia^000000.")
      |> next()
      |> mes("[Emma Searth]")
      |> mes("Of course, I understand that")
      |> mes("Kafra Corporation is a large, professional company, but")
      |> mes("if I can work for them even if it's just part-time...")
      |> next()
      |> mes("[Emma Searth]")
      |> mes("Is it that big of a problem?")
      |> mes("I suppose they're worried")
      |> mes("that I'd forget important customer information once I'm hired.")
      |> next()
      |> mes("[Emma Searth]")
      |> mes("It's strange. When I was")
      |> mes("a Crusader, I remembered")
      |> mes("everything lucidly, and I never had any problems recalling the past.")
      |> next()
      |> mes("[Emma Searth]")
      |> mes(
        "But now I get these migraines whenever I try to focus on my memories from those times"
      )
      |> mes("when I used to fight in the Prontera Military.")
      |> next()
      |> mes("[Emma Searth]")
      |> mes("^333333*Sigh...*^000000")
      |> next()
      |> select([
        "About her past.",
        "Why be a Kafra Lady?",
        "About memories she can remember."
      ])

    case choice do
      1 -> her_past(ctx)
      2 -> kafra_dream(ctx)
      3 -> squad_memories(ctx)
      _ -> ctx
    end
  end

  defp squad_search(ctx, _memories) do
    ctx
    |> mes("[Emma Searth]")
    |> mes(
      "^0000FFJack O, The Nineball, Zan.Huadoku, Cuaque Donon, Egnigem.^000000 Oh, I really miss those guys..."
    )
    |> close()
  end

  defp her_past(ctx) do
    if count_item(ctx, 7015) > 0 do
      ctx
      |> mes("^3355FFThe scent of your")
      |> mes("Memory Bookmark")
      |> mes("seems to bring clarity")
      |> mes("to her thoughts.^000000")
      |> next()
      |> mes("[Emma Searth]")
      |> mes(
        "I was born in a wealthy family where I was raised to learn etiquette, fencing, Peco riding, and music lessons since I was"
      )
      |> mes("born. I suppose you can say I'm pretty well educated.")
      |> next()
      |> mes("[Emma Searth]")
      |> mes("However, my parents weren't")
      |> mes("pleased when they learned that I wanted to become a Kafra Lady.")
      |> next()
      |> mes("[Emma Searth]")
      |> mes("My parents insisted that")
      |> mes("I become a Sage or a Scholar.")
      |> mes("In the end, I ended up running")
      |> mes("away from them by joining the Crusaders.")
      |> next()
      |> mes("[Emma Searth]")
      |> mes(
        "Luckily, the Crusaders were advertising their recruitment at the time, so I took that chance. Plus, having military experience might even help me join Kafra!"
      )
      |> next()
      |> mes("[Emma Searth]")
      |> mes("Since I did so well in Boot Camp,")
      |> mes(
        "I got the chance to join an elite squad. My squad was often assigned difficult missions, and we never failed to complete those."
      )
      |> next()
      |> mes("[Emma Searth]")
      |> mes(
        "Eventually, my reputation as a female Crusader, and being in a respectable military position, was enough to satisfy my family."
      )
      |> next()
      |> mes("[Emma Searth]")
      |> mes("But after that day,")
      |> mes("everything went wrong.")
      |> mes("I only remember that it")
      |> mes("was very sad and depressing.")
      |> mes("Somehow, I feel like we were")
      |> mes("even betrayed...")
      |> next()
      |> mes("[Emma Searth]")
      |> mes("I think I can")
      |> mes("try to remember")
      |> mes("my comrades...")
      |> set_char_var(:god_megin_4, 1)
      |> close()
    else
      ctx
      |> mes("[Emma Searth]")
      |> mes(
        "Ah, let's not talk about it. It's too depressing. Maybe if you had some sort of ^0000FFmemory^000000 aid, I might be able to recall my forgotten past. Anything, like a reminder, a scheduler, a bookmark, a string..."
      )
      |> close()
    end
  end

  defp kafra_dream(ctx) do
    ctx
    |> mes("[Emma Searth]")
    |> mes(
      "One day, I happened to see Ms. Leilah at work here in Al De Baran. She was shining with confidence and commanded respect, even from her customers!"
    )
    |> next()
    |> mes("[Emma Searth]")
    |> mes(
      "She carried herself like a professional, no matter what the situation. Even though I knew she was tired from working in the summer heat, she made everything look effortless!"
    )
    |> next()
    |> mes("[Emma Searth]")
    |> mes(
      "When the male customers try to flirt with her, she never loses her poise. She just adjusts her glasses and does what she needs to do."
    )
    |> next()
    |> mes("[Emma Searth]")
    |> mes(
      "To me, she's like a lone, guardian angel. At that moment, it seemed the world existed just to be mocked by Ms. Leila."
    )
    |> next()
    |> mes("[Emma Searth]")
    |> mes(
      "I've also heard that Kafra Ladies are always traveling around the world, which is something I've always dreamed of doing."
    )
    |> next()
    |> mes("[Emma Searth]")
    |> mes("Ms. Leilah is my idol,")
    |> mes("and she's the reason why")
    |> mes("I want to become a Kafra Lady.")
    |> close()
  end

  defp squad_memories(ctx) do
    if count_item(ctx, 511) > 0 and get_char_var(ctx, :god_megin_3, 0) > 1 do
      ctx
      |> migraine()
      |> next()
      |> mes(
        "^3355FFRemembering that a Green Herb was able to relieve Jack O, you gave a Green Herb to Emma. She takes it, and looks a little more relaxed.^000000"
      )
      |> next()
      |> not_sure_what_i_remember()
      |> next()
      |> mes("[Emma Searth]")
      |> mes("Let me...")
      |> mes(
        "Try to remember every one in our squad. Let's see, there was Jack O, The Nineball. Z-Zan. Zan.H-Huadoku. C-Cuaque Donon. Myself. Um, E... Eni... Egni... Um..."
      )
      |> next()
      |> mes("[Emma Searth]")
      |> mes("Egni...")
      |> mes("Egnigem?^000000")
      |> mes("Who was that?")
      |> mes("Oh no. I'm sure he might")
      |> mes("have, no, was there someone")
      |> mes("named that with us?")
      |> close2()
      |> set_char_var(:god_megin_4, 2)
    else
      ctx
      |> migraine()
      |> next()
      |> not_sure_what_i_remember()
      |> close()
    end
  end

  defp reward(ctx) do
    ctx
    |> egnigem_sadness()
    |> next()
    |> turns_away()
    |> next()
    |> mes("[Emma Searth]")
    |> mes(
      "I wish I knew what that name really means. I'm sure it's linked to an important memory from my past."
    )
    |> next()
    |> mes("[Emma Searth]")
    |> mes(
      "I really appreciate you coming here to talk to me about the old days. I, I want you to have this."
    )
    |> set_char_var(:god_eremes, 28)
    |> give_item(603, 1)
    |> give_reward_exp()
    |> close()
  end

  defp give_reward_exp(ctx) do
    table =
      if Rathena.truthy?(checkre(ctx, 3)),
        do: @renewal_reward_exp,
        else: @pre_renewal_reward_exp

    getexp(ctx, elem(table, level_bracket(base_level(ctx))), 0)
  end

  defp level_bracket(level) do
    cond do
      level < 56 -> 0
      level < 61 -> 1
      level < 66 -> 2
      level < 71 -> 3
      level < 76 -> 4
      level < 81 -> 5
      level < 86 -> 6
      level < 91 -> 7
      true -> 8
    end
  end

  defp sigh(ctx) do
    ctx
    |> mes("[Emma Searth]")
    |> mes("^333333*Sigh...*^000000 I haven't gotten any response from them. I don't know")
    |> mes("if I can wait much longer to join the Kafra Corporation.")
  end

  defp egnigem_sadness(ctx) do
    ctx
    |> mes("[Emma Searth]")
    |> mes("Egnigem...")
    |> mes("That name makes")
    |> mes("me so sad. I'm not")
    |> mes("quite sure why, but...")
  end

  defp turns_away(ctx) do
    mes(
      ctx,
      "^3355FFEmma turns away before you can see her cry. Still, her shoulders heave with each sob as you imagine the hardship she's had to endure.^000000"
    )
  end

  defp migraine(ctx) do
    mes(
      ctx,
      "^3355FFEmma Searth clutches her head and winces as she suffers from another migraine.^000000"
    )
  end

  defp not_sure_what_i_remember(ctx) do
    ctx
    |> mes("[Emma Searth]")
    |> mes("I'm not even sure")
    |> mes("how much I can remember")
    |> mes("and how much I've actually")
    |> mes("forgotten.")
  end
end
