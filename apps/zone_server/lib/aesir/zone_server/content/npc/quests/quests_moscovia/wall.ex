defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.Wall do
  @moduledoc """
  The dungeon wall where Maria Morebna is sealed, the climax of the Koshei the Immortal quest.

  ## Behavior

  - On a one-in-three chance, the first visit with Gray Wolf reveals Maria, who asks the player to
    find the keymaker and his Golden Key.
  - While the key is being made, she can open a portal to Marozka's cave for a player wearing the
    required shoes.
  - With the Golden Key and the correct phrase, Maria is freed, struck down by Koshei, and the
    player must fight Koshei, the Immortal; the key is spent and only one fight runs at a time.
  - After Koshei falls, Gray Wolf sends the player for the Life and Death Water; pouring Death
    Water first revives Maria, who rewards a random stat dish and level-based EXP (an Old Violet
    Box at the level cap).

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
        map: "mosk_dun01",
        x: 45,
        y: 259,
        dir: 0,
        sprite: 111,
        name: "Wall",
        scope: :shared,
        unique_name: "Wall#rus04"
      }
    ]

  @gold_key 7876
  @key_phrase "The Free wind blows and gets you wherever you want"
  @stat_dishes [12_093, 12_088, 12_073, 12_078, 12_083, 12_098]
  @renewal_exp_rows [
    {56, 1300, 350},
    {61, 2460, 615},
    {66, 4242, 1060},
    {71, 6489, 1622},
    {76, 16_491, 4123},
    {81, 27_629, 6907},
    {86, 34_041, 8510},
    {91, 41_846, 10_462},
    {275, 88_814, 22_204}
  ]
  @classic_exp_rows [
    {56, 13_000, 3500},
    {61, 24_600, 6150},
    {66, 42_420, 10_605},
    {71, 64_892, 16_223},
    {76, 164_908, 41_227},
    {81, 276_292, 69_073},
    {86, 340_408, 85_102},
    {91, 418_460, 104_615},
    {99, 888_140, 222_035}
  ]

  @impl true
  def on_event("OnInit", ctx) do
    set_server_temp_var(ctx, "rus_req02", 0)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnEnable", ctx) do
    enablenpc(ctx, "Wall#rus04")
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnDisable", ctx) do
    disablenpc(ctx, "Wall#rus04")
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnMyMobDead", ctx) do
    ctx
    |> donpcevent("Koshei#rus47::OnDisable")
    |> set_server_temp_var("rus_req02", 0)
    |> announce(
      "Koshei, the Immortal : Keeeek, you, cursed human.. I'll never give up!!! We'll see who's smiling in the end!!!",
      1,
      13_513_009
    )
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :rhea_rus_main, 0)

    cond do
      stage < 5 -> ctx |> puzzled() |> close()
      stage == 5 -> meet_maria(ctx)
      stage < 8 -> golden_key_hint(ctx)
      stage == 8 -> gather_key_materials(ctx)
      stage < 47 -> waiting_for_key(ctx)
      stage == 47 -> use_golden_key(ctx)
      stage == 48 -> after_ambush(ctx)
      stage < 51 -> waters_hint(ctx)
      stage == 51 -> revive_maria(ctx)
      true -> farewell(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp player_header(ctx), do: mes(ctx, "[#{char_name(ctx, 0)}]")

  defp puzzled(ctx) do
    ctx
    |> player_header()
    |> mes("...?!")
    |> emotion(:question, playerattached(ctx))
  end

  defp meet_maria(ctx) do
    case Enum.random(1..3) do
      3 ->
        ctx
        |> puzzled()
        |> donpcevent("Gray Wolf#rus05::OnEnable")
        |> next()
        |> ask_for_help()

      _ ->
        ctx |> puzzled() |> close()
    end
  end

  defp ask_for_help(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Girl's Voice]")
      |> mes("Who is there? Gray Wolf?!")
      |> mes("Wolf, who are you with?")
      |> next()
      |> mes("[Gray Wolf]")
      |> mes(
        "This is an adventurer from another land. He is not afraid of Koshei. He may be able to help you."
      )
      |> next()
      |> mes("[Girl's Voice]")
      |> mes("Help me? Do you think he can stop Koshei?")
      |> next()
      |> player_header()
      |> mes("Ah, hold on. Who is Koshei and who is talking?")
      |> next()
      |> mes("[Girl's Voice]")
      |> mes(
        "Koshei.. He is an immortal and endless evil. I fought against him a long tim ago. After a fierce fight, I had to seal him in the darkness because he is immortal."
      )
      |> next()
      |> mes("[Girl's Voice]")
      |> mes("And as a result I became imprisoned in this wall.")
      |> mes("He has found a way to break away from his seal and I fear for the worst.")
      |> next()
      |> mes("[Girl's Voice]")
      |> mes(
        "My name is Maria Morebna. Help me exterminate Koshei. I want to keep peace in Moscovia. Can you help me?"
      )
      |> next()
      |> select(["Ok, I can"])

    ctx
    |> player_header()
    |> mes("So, how can I help you?")
    |> next()
    |> mes("[Gray Wolf]")
    |> mes("First, you need to find a way to get her out of there.")
    |> mes(
      "I've heard about a '^0000ffGolden Key^000000' that can open anything. There is a keymaker in town."
    )
    |> next()
    |> mes("[Gray Wolf]")
    |> mes(
      "As you see, I look like a monster so I am not able to go there. I want you to find this keymaker and ask about the '^0000ffGolden Key^000000'."
    )
    |> next()
    |> mes("[Girl's Voice]")
    |> mes("Please don't forget about me.")
    |> donpcevent("Gray Wolf#rus05::OnDisable")
    |> set_char_var(:rhea_rus_main, 6)
    |> close()
  end

  defp golden_key_hint(ctx) do
    ctx
    |> mes("[Girl's Voice]")
    |> mes("Help me get out of here.")
    |> mes("I hope you can help me find that '^0000ffGolden Key^000000' that can open anything.")
    |> next()
    |> mes("[Girl's Voice]")
    |> mes(
      "I've heard about a keymaker in Moscovia who knows how to make a '^0000ffGolden Key^000000'."
    )
    |> close()
  end

  defp gather_key_materials(ctx) do
    if get_char_var(ctx, :rhea_rus_quiz, 0) < 3 do
      offer_marozka_portal(ctx)
    else
      ctx
      |> mes("[Girl's Voice]")
      |> mes("Have you.. got the key?")
      |> next()
      |> player_header()
      |> mes("Not yet... Give me a second.")
      |> next()
      |> mes("[Girl's Voice]")
      |> mes(
        "If you gather all the necessary things, go to Moscovia and find the keymaker. Do me this favor, please."
      )
      |> close()
    end
  end

  defp offer_marozka_portal(ctx) do
    if getequipid(ctx, 2) != 2429 and getequipid(ctx, 2) != 2430 do
      ctx
      |> player_header()
      |> mes("...Hmm, did I forget to wear something...?")
      |> close()
    else
      ctx
      |> mes("[Girl's Voice]")
      |> mes("Did you get the key?")
      |> next()
      |> player_header()
      |> mes("...I need golden thread. I heard that I was able to get it from Marozka. He....")
      |> next()
      |> mes("[Girl's Voice]")
      |> mes(
        "Marozka... He is the owner of winter and dwells in the deep underground. He won't let just anyone see him."
      )
      |> next()
      |> mes("[Girl's Voice]")
      |> mes(
        "He has monsters that guard his underground lair. It's very dangerous. But, I know where he is."
      )
      |> next()
      |> mes("[Girl's Voice]")
      |> mes("What do you think? I can open a portal to the cave Do you want to go there now?")
      |> next()
      |> select(["Not yet...", "Open the portal!"])
      |> case do
        {ctx, 1} ->
          ctx
          |> mes("[Girl's Voice]")
          |> mes("... When you're ready, just tell me.")
          |> close()

        {ctx, _} ->
          ctx
          |> mes("[Girl's Voice]")
          |> mes("...Ok, be careful There are a lot of monsters there.")
          |> donpcevent("1#rus27::OnEnable")
          |> close()
      end
    end
  end

  defp waiting_for_key(ctx) do
    ctx =
      ctx
      |> mes("[Girl's Voice]")
      |> mes("Have you.. got the key?")
      |> next()

    if get_char_var(ctx, :rhea_rus_ring, 0) > 8 and get_char_var(ctx, :rhea_rus_hair, 0) > 8 and
         get_char_var(ctx, :rhea_rus_quiz, 0) > 29 do
      ctx
      |> player_header()
      |> mes("I collected every meterial for the key, But have not yet got the key...")
      |> next()
      |> mes("[Girl's Voice]")
      |> mes("Go to Moscovia and find the keymaker.")
      |> close()
    else
      ctx
      |> player_header()
      |> mes("Not yet... Give me a second.")
      |> next()
      |> mes("[Girl's Voice]")
      |> mes(
        "If you gather all the things necessary, go to Moscovia and find the keymaker. Do me this favor, please."
      )
      |> close()
    end
  end

  defp use_golden_key(ctx) do
    cond do
      count_item(ctx, @gold_key) == 0 ->
        ctx
        |> mes("[Girl's Voice]")
        |> mes("Have you.. got the key?")
        |> next()
        |> player_header()
        |> mes("Sure! Here it...")
        |> mes("...............Errr?")
        |> close()

      get_server_temp_var(ctx, "rus_req02", 0) == 1 ->
        ctx
        |> mes("[Girl's Voice]")
        |> mes("I can feel Koshei's energy.. It is not a time to use the key...")
        |> close()

      true ->
        shout_key_phrase(ctx)
    end
  end

  defp shout_key_phrase(ctx) do
    {ctx, phrase} =
      ctx
      |> set_server_temp_var("rus_req02", 1)
      |> mes("[Girl's Voice]")
      |> mes("Did you get the key?")
      |> next()
      |> player_header()
      |> mes("I did. So, how do I use it?")
      |> next()
      |> mes("[Girl's Voice]")
      |> mes("Listen very carefully!")
      |> mes(
        "Left the key up, and shout '^0000ffThe Free wind blows and gets you wherever you want^000000'."
      )
      |> next()
      |> input(:string)

    if phrase == @key_phrase do
      ctx
      |> player_header()
      |> mes("^0000ff #{phrase} !! ^000000")
      |> next()
      |> mes("- The key begins to glow -")
      |> mes("- wind begins to blow -")
      |> mes("- from somewhere -")
      |> specialeffect2(:beginspell)
      |> specialeffect(:freezed)
      |> next()
      |> koshei_ambush()
    else
      ctx
      |> player_header()
      |> mes(" #{phrase} !! ")
      |> next()
      |> mes("[Girl's Voice]")
      |> mes(
        "........................................................................................."
      )
      |> next()
      |> mes("[Girl's Voice]")
      |> mes("You must've said it wrong...")
      |> set_server_temp_var("rus_req02", 0)
      |> close()
    end
  end

  defp koshei_ambush(ctx) do
    ctx
    |> mes("- The wind disappears and -")
    |> mes("- a very young girl appears -")
    |> donpcevent("Maria Morebna#rus46::OnEnable")
    |> specialeffect(:freezed, :area, "Maria Morebna#rus46")
    |> next()
    |> mes("[Maria Morebna]")
    |> mes("Thank you!")
    |> mes("I'm finally out of there! Now I can.....................aaaaak!!!....")
    |> next()
    |> specialeffect(:hit2, :area, "Maria Morebna#rus46")
    |> specialeffect(:darkbreath, :area, "Maria Morebna#rus46")
    |> specialeffect(:devil, :area, "Maria Morebna#rus46")
    |> mes("- Maria is attacked -")
    |> mes("- and falls down!! -")
    |> next()
    |> player_header()
    |> mes("Maria?! What happened?!")
    |> sc_start(:sc_curse, 60_000, 0)
    |> emotion(:huk, playerattached(ctx))
    |> next()
    |> mes("[Koshei, the Immortal]")
    |> mes(
      "I really want to thank you, human. Maria was imprisoned in the wall so I couldn't do anything!"
    )
    |> next()
    |> mes("[Koshei, the Immortal]")
    |> mes("She'll thank me for giving her a quick death!!")
    |> next()
    |> mes("[Koshei, the Immortal]")
    |> mes("But you, human... You are here to disturb me?")
    |> next()
    |> mes("[Koshei, the Immortal]")
    |> mes("No one can stop me! Now, die!!!")
    |> next()
    |> mes("[Gray Wolf]")
    |> mes("Watch out!!")
    |> next()
    |> donpcevent("Gray Wolf#rus05::OnEnable")
    |> mes("[Koshei, the Immortal]")
    |> mes("Gray Wolf...")
    |> mes("You think you can fight me?!")
    |> next()
    |> specialeffect(:firehit, :area, "Gray Wolf#rus05")
    |> mes("- Staggering from -")
    |> mes("- Koshei's flames, -")
    |> mes("- Gray Wolf quickly tell me -")
    |> next()
    |> mes("[Gray Wolf]")
    |> mes("Listen, I can still help Maria if I treat her now.")
    |> mes("I will flee with her and leave you to deal with Koshei!!")
    |> next()
    |> donpcevent("Gray Wolf#rus05::OnDisable")
    |> donpcevent("Maria Morebna#rus46::OnDisable")
    |> mes("[Koshei, the Immortal]")
    |> mes("Stop! Where do you think you're going?!!!")
    |> delitem(@gold_key, 1)
    |> set_char_var(:rhea_rus_main, 48)
    |> summon_mob(
      mob_id: 1890,
      map: "mosk_dun01",
      at: {45, 256},
      name: "Koshei, the Immortal",
      event: "Wall#rus04::OnMyMobDead"
    )
    |> donpcevent("Koshei#rus47::OnEnable")
    |> close()
  end

  defp koshei_nearby(ctx) do
    ctx
    |> mes("[Gray Wolf's voice]")
    |> mes("I can sense Koshei's presence.")
    |> next()
    |> mes("[Gray Wolf's voice]")
    |> mes("I can still help Maria if I treat her now.")
    |> mes("I will flee with her and leave you to deal with Koshei!!")
    |> close()
  end

  defp after_ambush(ctx) do
    if get_server_temp_var(ctx, "rus_req02", 0) == 1 do
      koshei_nearby(ctx)
    else
      ctx
      |> player_header()
      |> mes("...Maria...")
      |> mes("I... could do nothing...")
      |> next()
      |> mes("[Gray Wolf]")
      |> mes("No, it's not too late!")
      |> emotion(:surprise, playerattached(ctx))
      |> donpcevent("Gray Wolf#rus05::OnEnable")
      |> next()
      |> mes("[Gray Wolf]")
      |> mes("She's alive.")
      |> mes("But, she's still unstable.")
      |> next()
      |> mes("[Gray Wolf]")
      |> mes(
        "To save her, I need 'Life Water' and 'Death Water'. Find Baba Yaga, she'll know what to do."
      )
      |> next()
      |> mes("[Gray Wolf]")
      |> mes("I can't keep her alive for much longer. You must find Baba Yaga.")
      |> set_char_var(:rhea_rus_main, 49)
      |> close2()
      |> donpcevent("Gray Wolf#rus05::OnDisable")
    end
  end

  defp waters_hint(ctx) do
    ctx
    |> mes("[Gray Wolf's voice]")
    |> mes("But, she's still unstable.")
    |> next()
    |> mes("[Gray Wolf's voice]")
    |> mes(
      "To save her, I need 'Life Water' and 'Death Water'. Find Baba Yaga, she'll know what to do."
    )
    |> next()
    |> mes("[Gray Wolf's voice]")
    |> mes("I can't keep her alive for much longer. You must find Baba Yaga.")
    |> close()
  end

  defp revive_maria(ctx) do
    if get_server_temp_var(ctx, "rus_req02", 0) == 1 do
      koshei_nearby(ctx)
    else
      ctx
      |> mes("[Gray Wolf's voice]")
      |> mes("Did you get the 'Life Water' and 'Death Water'?")
      |> next()
      |> player_header()
      |> mes("I've got them! How's Maria?!")
      |> donpcevent("Gray Wolf#rus05::OnEnable")
      |> donpcevent("Maria Morebna#rus46::OnEnable")
      |> next()
      |> mes("[Gray Wolf]")
      |> mes(
        "I fear that her spirit has gone. Severe wounds and curses are hindering her spirit from coming back. But we can save her with that water."
      )
      |> next()
      |> player_header()
      |> mes("Ok... First...")
      |> next()
      |> select(["Death Water", "Life Water"])
      |> case do
        {ctx, 1} -> ctx |> pour_death_water() |> pour_life_water()
        {ctx, _} -> pour_life_water_first(ctx)
      end
    end
  end

  defp pour_death_water(ctx) do
    ctx
    |> player_header()
    |> mes("I hope this works...")
    |> next()
    |> mes("- I pour the Death Water -")
    |> mes("- on Maria's stiff body -")
    |> next()
    |> mes("- The wounds and -")
    |> mes("- curses on her body -")
    |> mes("- are removed !! -")
    |> specialeffect(:absorbspirits, :area, "Maria Morebna#rus46")
    |> next()
  end

  defp pour_life_water_first(ctx) do
    ctx
    |> player_header()
    |> mes("I hope this works...")
    |> next()
    |> mes("- I pour the Life Water -")
    |> mes("- on Maria's stiff body -")
    |> next()
    |> mes("[Maria Morebna]")
    |> mes("..........................")
    |> next()
    |> mes("- Nothing changed -")
    |> next()
    |> player_header()
    |> mes("Huk, was this wrong...?!")
    |> next()
    |> mes("[Gray Wolf]")
    |> mes(
      "What are you doing?! I told you we did not have much time! What are you going to do now?!"
    )
    |> next()
    |> donpcevent("Gray Wolf#rus05::OnDisable")
    |> donpcevent("Maria Morebna#rus46::OnDisable")
    |> player_header()
    |> mes("I am so sorry. But some water is left...")
    |> close()
  end

  defp pour_life_water(ctx) do
    ctx
    |> player_header()
    |> mes("Ok! Next...")
    |> next()
    |> select(["Death Water", "Life Water"])
    |> case do
      {ctx, 1} ->
        ctx
        |> player_header()
        |> mes("Pour the 'Death Water' again...")
        |> next()
        |> player_header()
        |> mes("...!? No, not 'Death Water'.. I should pour 'Life Water'.......")
        |> next()
        |> mes("[Gray Wolf]")
        |> mes("............................")
        |> mes("Can I trust you...?")
        |> next()
        |> player_header()
        |> mes("Hehehe, you can trust me. Next is the 'Life Water'.")
        |> next()
        |> mes("- I pour 'Life Water' on Maria -")
        |> next()
        |> maria_thanks()

      {ctx, _} ->
        ctx
        |> player_header()
        |> mes("Ok, next the 'Life Water'.")
        |> next()
        |> mes("- I pour the Life Water -")
        |> mes("- on Maria's stiff body  -")
        |> next()
        |> maria_thanks()
    end
  end

  defp maria_thanks(ctx) do
    ctx
    |> mes("- !! -")
    |> specialeffect(:resurrection, :area, "Maria Morebna#rus46")
    |> next()
    |> mes("[Gray Wolf]")
    |> mes("Success!!")
    |> next()
    |> mes("[Maria Morebna]")
    |> mes("Ah, did I...?!")
    |> mes("You saved me. I really appreicate it. Thank you for helping us fight against Koshei.")
    |> next()
    |> mes("[Maria Morebna]")
    |> mes("And you, Gray Wolf.. Thank you for protecting me while I was helpless.")
    |> next()
    |> mes("[Maria Morebna]")
    |> mes(
      "Koshei wasn't completely destroyed. But, his power has weakened, it shouldn't be hard to seal his power without me also being sealed."
    )
    |> next()
    |> mes("[Maria Morebna]")
    |> mes(
      "Koshei and I are bound by magic. If one's power should be sealed, the other must be sealed as well."
    )
    |> next()
    |> mes("[Maria Morebna]")
    |> mes(
      "But the original seal weakened over time and Koshei was able to get out of his confinement. That is why I asked you to get me out of here."
    )
    |> next()
    |> mes("[Maria Morebna]")
    |> mes(
      "He realized that I was trying to break free and waited here for anyone who would help me. I never ever expected it..."
    )
    |> next()
    |> mes("[Maria Morebna]")
    |> mes("Anyway, I'm so grateful for everything you did.")
    |> next()
    |> mes("[Maria Morebna]")
    |> mes(
      "Please accept my poor reward, I hope that it will be of some help for such a brave adventurer. I hope that the gods will bless you on your journey."
    )
    |> next()
    |> mes("[Maria Morebna]")
    |> mes(
      "It's been a long time since I've felt the sunlight, fresh wind and the scent of grass. I'm so grateful."
    )
    |> set_char_var(:rhea_rus_main, 52)
    |> set_local(:rus_food, Enum.random(1..6))
    |> give_item(Enum.at(@stat_dishes, Enum.random(1..6) - 1), 1)
    |> grant_level_reward()
    |> donpcevent("Gray Wolf#rus05::OnDisable")
    |> donpcevent("Maria Morebna#rus46::OnDisable")
    |> close()
  end

  defp grant_level_reward(ctx) do
    rows = if checkre(ctx, 3) == 1, do: @renewal_exp_rows, else: @classic_exp_rows
    grant_exp(ctx, rows)
  end

  defp grant_exp(ctx, rows) do
    level = base_level(ctx)

    case Enum.find(rows, fn {below, _, _} -> level < below end) do
      {_, base_exp, job_exp} -> getexp(ctx, base_exp, job_exp)
      nil -> give_item(ctx, 617, 1)
    end
  end

  defp farewell(ctx) do
    ctx
    |> mes("[Girl's Voice]")
    |> mes("... Koshei is immortal and will surely appear again someday...")
    |> next()
    |> mes("[Girl's Voice]")
    |> mes(
      "When that time comes, I will deal with him. I will use my time of waiting to train to make myself strong whenever he returns..."
    )
    |> next()
    |> mes("[Girl's Voice]")
    |> mes(
      "I'm grateful that you did your best for me and my village. I will never forget your kindness."
    )
    |> next()
    |> mes("[Girl's Voice]")
    |> mes("Ah, Go to Baba Yaga in your free time. She seems to have something to tell you.")
    |> next()
    |> mes("[Girl's Voice]")
    |> mes(
      "Take care of yourself. It is better for you to stay away from here because, Koshei may try to use your power as his own, huhu."
    )
    |> close()
  end
end
