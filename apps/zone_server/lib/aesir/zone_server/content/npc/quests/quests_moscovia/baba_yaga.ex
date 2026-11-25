defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.BabaYaga do
  @moduledoc """
  Baba Yaga forges the Golden Key, brews the waters that revive Maria and later sells potions.

  ## Behavior

  - Scares away adventurers before the Koshei quest reaches her, and tests the spell they
    learned: any answer but "Spellshield Protection" sends them away.
  - Takes 2 Cursed Ruby, 3 Gold, 1 Red Ring, 2 Lusalka's Hair and 10 Golden Thread to start
    the Golden Key, then sets a favor that depends on the base class.
  - The Mage favor takes the magic book and summons gardeners, then alarms, hiding her for up
    to three minutes each time (a summoned mob's death brings her back).
  - Hands over the Golden Key once a favor is done; silver spoons are taken if still carried.
  - After Koshei is beaten, takes 1 Holy Water, 1 Cursed Water, 2 Yggdrasil Leaves and 10
    Hinalle Leaflets for the Living and Dead Water, then tells the story of the seal.
  - Afterwards brews up to 100 Condensed Red or Yellow Potions at a time from materials and a
    zeny fee.

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
        map: "mosk_dun02",
        x: 48,
        y: 214,
        dir: 5,
        sprite: 970,
        name: "Baba Yaga",
        scope: :shared,
        unique_name: "Baba Yaga#rus32"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @npc_name "Baba Yaga#rus32"
  @mob_dead_event "Baba Yaga#rus32::OnMyMobDead"

  @cow_favor "My cow has run away. Find her and cast a Return Spell on her. The spell is '^ff0000Good feed is orange-flavored^000000'. You sould remember it."
  @coffin_favor "Behind my house, there is noisy coffin. It has been so nosiy recently that I can't sleep. Silence it."
  @spoons_favor "Please find my silver spoons. Those bad pirates stole them. I can feel them around the wrecked ship. Bring them to me."
  @book_favor "Buy me a magic book. It is published by Momotaro in Amatsu. Go there and buy it for me."
  @ghost_favor "Can you see a jar next to the cabin? There is a House ghost living in there. Drive him out of there. He irritates me a lot."
  @broom_favor "Go to the Broom Grandmother in Payon and buy me a broom. It is best for cleaning but I don't have time to go there."
  @hurry_up "Ok! Move, move! You better be quick or I will find a way to punish you. Ehehehehehe."
  @key_farewell "Here, help Maria with this key and watch out for Koshei. He is very dangerous. Kehehehehehe."
  @on_time "You are on time. I just finished making the 'Golden Key'!"
  @coffin_thanks "Oh, yes. I can sleep at night now. Kehehehehe."
  @ghost_thanks "Oh, yes. That irritating ghost is gone. Kehehehehe."
  @broom_thanks "Ooh, yes. Well done. My flying broom was getting old. Kehehehehe."

  @potions %{
    1 => %{
      item: 545,
      fee: 20,
      materials: [{501, 1}, {1092, 1}, {7134, 1}, {512, 5}],
      prompt: "I can only make 100 at a time. If you don't want any, then just say '0'"
    },
    2 => %{
      item: 546,
      fee: 50,
      materials: [{503, 1}, {1092, 1}, {7134, 1}, {513, 10}],
      prompt: "Tell me the number less than 100. If you don't want, tell me zero"
    }
  }

  @impl true
  def on_event("OnDisable", ctx), do: ctx |> initnpctimer() |> disablenpc(@npc_name)

  def on_event("OnTimer180000", ctx) do
    ctx
    |> stopnpctimer()
    |> killmonster("mosk_dun02", @mob_dead_event)
    |> enablenpc(@npc_name)
  end

  def on_event("OnMyMobDead", ctx), do: enablenpc(ctx, @npc_name)

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :rhea_rus_main, 0) do
      stage when stage < 9 -> shoo(ctx)
      9 -> confront(ctx)
      10 -> assign_favor(ctx)
      stage when stage in 11..15 -> remind_favor(ctx, @cow_favor)
      stage when stage in 16..20 -> remind_favor(ctx, @ghost_favor)
      stage when stage in 21..25 -> remind_favor(ctx, @spoons_favor)
      26 -> remind_favor(ctx, @book_favor)
      27 -> try_magic_book(ctx)
      28 -> summon_alarms(ctx)
      29 -> finish_alarms(ctx)
      stage when stage in 31..35 -> remind_favor(ctx, @ghost_favor)
      stage when stage in 36..40 -> remind_favor(ctx, @broom_favor)
      41 -> cow_returned(ctx)
      42 -> favor_done(ctx, "The coffin is now silenced!", @coffin_thanks)
      43 -> spoons_returned(ctx)
      44 -> temper_rewarded(ctx)
      45 -> favor_done(ctx, "The House ghost is now quiet!", @ghost_thanks)
      46 -> favor_done(ctx, "Here, the best broom from Payon!", @broom_thanks)
      stage when stage in 47..48 -> key_reminder(ctx)
      49 -> hear_of_koshei(ctx)
      50 -> brew_waters(ctx)
      51 -> waters_reminder(ctx)
      52 -> tell_of_seal(ctx)
      stage when stage > 52 -> potion_shop(ctx)
      _ -> ctx |> mes("[Baba Yaga]") |> mes("What are you, human child.") |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp shoo(ctx) do
    ctx
    |> mes("[Baba Yaga]")
    |> mes("...........................")
    |> mes(
      "If you lotter around here any longer, I will make myself some tasty human soup! Hehehehehe."
    )
    |> emotion(:kik)
    |> emotion(:huk, playerattached(ctx))
    |> close()
  end

  defp confront(ctx) do
    player_name = char_name(ctx, 0)

    {ctx, spell} =
      ctx
      |> mes("[Baba Yaga]")
      |> mes(
        "Why are you here, you yummy looking human? If you lotter around here any longer, I will make myself some tasty human soup! Hehehehehe"
      )
      |> next()
      |> mes("[#{player_name}]")
      |> mes("I, ah, I.. Gold.. golden...")
      |> next()
      |> mes("[Baba Yaga]")
      |> mes("What are you babbling about?")
      |> mes("Do you want me to transform you into a savage beast?!")
      |> next()
      |> mes("[Baba Yaga]")
      |> mes("'Presto Change-o!!'")
      |> mes("'Turn into a pig!!'")
      |> specialeffect2(:barrier)
      |> emotion(:huk)
      |> next()
      |> mes("[Baba Yaga]")
      |> mes("Hmm? You are protected by a Protection Spell?")
      |> mes("But, it was weake. My spell destroyed it.")
      |> next()
      |> mes("[Baba Yaga]")
      |> mes("Leave now, or I will curse you again! 'Presto...'")
      |> next()
      |> mes("[#{player_name}]")
      |> mes("Eh, eh.. I mean.. I say.. spell...")
      |> next()
      |> input(:string)

    ctx =
      ctx
      |> mes("[#{player_name}]")
      |> mes("Eh, eh.. I mean.. I say.. spell...")
      |> mes("#{spell} !!!")

    if spell == "Spellshield Protection" do
      ctx
      |> specialeffect2(:absorbspirits)
      |> next()
      |> ask_for_golden_key(player_name)
    else
      ctx
      |> next()
      |> mes("[Baba Yaga]")
      |> mes("What are you planning to do with that weak spell!?")
      |> mes("Get away, child!")
      |> close2()
      |> warp("mosk_dun02", 135, 163)
    end
  end

  defp ask_for_golden_key(ctx, player_name) do
    ctx =
      ctx
      |> mes("[Baba Yaga]")
      |> mes("Ho, you are protected by a Protection Spell. You are no ordinary kid.")
      |> next()
      |> mes("[#{player_name}]")
      |> mes("I heard that you are able to make the 'Golden Key' and that's why I am here!")
      |> next()
      |> mes("[Baba Yaga]")
      |> mes("'Golden Key'? Why do you need it?")
      |> next()
      |> mes("[#{player_name}]")
      |> mes("I need it to release Maria Mobrena from her dark wall prison.")
      |> next()
      |> mes("[Baba Yaga]")
      |> mes("...Maria Morebna...")
      |> mes("Are you fighting against Koshei?")
      |> next()
      |> mes("[#{player_name}]")
      |> mes("If he gets in my way of keeping my promise to her, I guess that I will fight him.")
      |> next()
      |> mes("[Baba Yaga]")
      |> mes("Ho, kiheeheheheheheh. Ehehehehehehe.")
      |> mes("You are interesting. You don't seem to be scared of Koshei.")
      |> next()
      |> mes("[Baba Yaga]")
      |> mes("Ok, the materials for the key are...")
      |> next()

    if count_item(ctx, 724) > 1 and count_item(ctx, 969) > 2 and
         Rathena.truthy?(count_item(ctx, 7877)) and count_item(ctx, 7878) > 1 and
         count_item(ctx, 7879) > 9 do
      ctx
      |> mes("[Baba Yaga]")
      |> mes("You have already gatered all the materials?")
      |> next()
      |> mes("[Baba Yaga]")
      |> mes("Ok, let's begin. Ah, before that... Wait here!")
      |> delitem(724, 2)
      |> delitem(969, 3)
      |> delitem(7877, 1)
      |> delitem(7878, 2)
      |> delitem(7879, 10)
      |> set_char_var(:rhea_rus_main, 10)
      |> close()
    else
      ctx
      |> mes("[Baba Yaga]")
      |> mes("What? I cannot make you the 'Golden Key' without the materials.")
      |> next()
      |> mes("[Baba Yaga]")
      |> mes(
        "Go and find ^0000ff2 Cursed Ruby, 3 Gold, 1 Red Ring, 2 Lusalka's Hair, 10 Golden Thread^000000!"
      )
      |> close()
    end
  end

  defp assign_favor(ctx) do
    ctx =
      ctx
      |> mes("[Baba Yaga]")
      |> mes("You come here!")
      |> next()
      |> mes("- Baba Yaga looks -")
      |> mes("- at you carefully -")
      |> next()
      |> mes("[Baba Yaga]")
      |> mes(
        "Hmmm, you look energetic and strong. Ok, while I make the 'Golden Key', you must first do a favor for me!"
      )
      |> next()

    base_job = Rathena.job_id(base_class(ctx))

    {favor, stage} =
      cond do
        base_job == Rathena.job_id(:archer) -> {@cow_favor, 11}
        base_job == Rathena.job_id(:acolyte) -> {@coffin_favor, 16}
        base_job == Rathena.job_id(:thief) -> {@spoons_favor, 21}
        base_job == Rathena.job_id(:mage) -> {@book_favor, 26}
        base_job == Rathena.job_id(:swordman) -> {@ghost_favor, 31}
        true -> {@broom_favor, 36}
      end

    ctx
    |> mes("[Baba Yaga]")
    |> mes(favor)
    |> next()
    |> mes("[Baba Yaga]")
    |> mes(@hurry_up)
    |> set_char_var(:rhea_rus_main, stage)
    |> close()
  end

  defp remind_favor(ctx, favor) do
    ctx
    |> mes("[Baba Yaga]")
    |> mes(favor)
    |> next()
    |> mes("[Baba Yaga]")
    |> mes(@hurry_up)
    |> close()
  end

  defp try_magic_book(ctx) do
    if count_item(ctx, 7881) > 0 do
      ctx
      |> mes("[Baba Yaga]")
      |> mes("Ho, did you buy the magic book? Give it to me. I will try it out.")
      |> next()
      |> mes("- Baba Yaga takes the book, -")
      |> mes("reads one of the pages, -")
      |> mes("and casts something -")
      |> next()
      |> mes("[Baba Yaga]")
      |> mes("Ok.. Let's do this.")
      |> mes("'Keep off the grass!!!'")
      |> specialeffect(:beginspell4)
      |> delitem(7881, 1)
      |> set_char_var(:rhea_rus_main, 28)
      |> summon_trio([
        {1493, "Violent Gardener"},
        {1500, "Dangerous Gardener"},
        {1497, "Brutal Gardener"}
      ])
      |> donpcevent("Baba Yaga#rus32::OnDisable")
      |> close()
    else
      remind_favor(ctx, @book_favor)
    end
  end

  defp summon_alarms(ctx) do
    ctx
    |> player_says("W, what is this, suddenly?!")
    |> next()
    |> mes("[Baba Yaga]")
    |> mes(
      "Ho.. this is for a beautiful garden. This is better than I expected. Ok then, let's do this."
    )
    |> next()
    |> player_says("Hey, are you listening to me?")
    |> next()
    |> mes("[Baba Yaga]")
    |> mes("'There is an order for you to open your eyes!!!'")
    |> specialeffect2(:beginspell3)
    |> set_char_var(:rhea_rus_main, 29)
    |> summon_trio([
      {1193, "Alarm to 5 minutes"},
      {1193, "Alarm on time"},
      {1193, "Alarm past 5 minutes"}
    ])
    |> donpcevent("Baba Yaga#rus32::OnDisable")
    |> close()
  end

  defp summon_trio(ctx, mobs) do
    mobs
    |> Enum.zip(52..54)
    |> Enum.reduce(ctx, fn {{mob_id, name}, x}, ctx ->
      summon_mob(ctx,
        mob_id: mob_id,
        map: "mosk_dun02",
        at: {x, 210},
        name: name,
        event: @mob_dead_event
      )
    end)
  end

  defp finish_alarms(ctx) do
    ctx
    |> player_says("What are you doing!!")
    |> next()
    |> mes("[Baba Yaga]")
    |> mes(
      "Hmm, this one makes people deligent and doesn't look effective. Ok then, next is a House Ghost..."
    )
    |> next()
    |> player_says("Hey, I am talking...")
    |> emotion(:cry, playerattached(ctx))
    |> next()
    |> mes("[Baba Yaga]")
    |> mes("'In the corner...'")
    |> next()
    |> player_says("!!!!!!!!!!!!!!!!!!!!!!!!!")
    |> emotion(:huk)
    |> next()
    |> mes("[Baba Yaga]")
    |> mes("What, child? Do you feel bad?")
    |> next()
    |> player_says("When will you give me the key?!")
    |> next()
    |> mes("[Baba Yaga]")
    |> mes("Huh, I can make it for you right now. You have a violent temper.")
    |> set_char_var(:rhea_rus_main, 44)
    |> close()
  end

  defp cow_returned(ctx) do
    ctx
    |> player_says("I have done your favor! I got the cow!")
    |> next()
    |> mes("[Baba Yaga]")
    |> mes("Oh, great. I just finished making the 'Golden Key'!")
    |> next()
    |> mes("[Baba Yaga]")
    |> mes(@key_farewell)
    |> hand_over_key()
  end

  defp favor_done(ctx, report, reaction) do
    ctx
    |> player_says("I have done your favor! #{report}")
    |> next()
    |> mes("[Baba Yaga]")
    |> mes(reaction)
    |> next()
    |> mes("[Baba Yaga]")
    |> mes(@on_time)
    |> next()
    |> mes("[Baba Yaga]")
    |> mes(@key_farewell)
    |> hand_over_key()
  end

  defp spoons_returned(ctx) do
    has_spoons = Rathena.truthy?(count_item(ctx, 7880))

    ctx =
      ctx
      |> player_says("I have done your favor! I found and got the silver spoons!")
      |> next()

    if has_spoons do
      ctx
      |> mes("[Baba Yaga]")
      |> mes("Oh, yes. They are expensive ones. Those bad pirates.. Kehehehehe.")
      |> next()
      |> mes("[Baba Yaga]")
      |> mes(@on_time)
      |> next()
      |> mes("[Baba Yaga]")
      |> mes(@key_farewell)
      |> delitem(7880, 1)
      |> hand_over_key()
    else
      ctx
      |> mes("[Baba Yaga]")
      |> mes("Oh, yes, yes. Give them to me.")
      |> next()
      |> player_says("Here they.. They..?!")
      |> next()
      |> mes("[Baba Yaga]")
      |> mes("You fool! Where did you sell my spoons!? Get them for me right now!")
      |> close()
    end
  end

  defp temper_rewarded(ctx) do
    ctx
    |> player_says("I have done your favor. Give me the key!")
    |> next()
    |> mes("[Baba Yaga]")
    |> mes("Oh, yes, you violent tempered child. I just finished making the 'Golden Key'.")
    |> next()
    |> mes("[Baba Yaga]")
    |> mes(@key_farewell)
    |> hand_over_key()
  end

  defp hand_over_key(ctx) do
    ctx
    |> set_char_var(:rhea_rus_main, 47)
    |> give_item(7876, 1)
    |> close()
  end

  defp key_reminder(ctx) do
    ctx
    |> mes("[Baba Yaga]")
    |> mes("You got the key and went to Maria immedately, right?")
    |> next()
    |> mes("[Baba Yaga]")
    |> mes(
      "Take care of yourself. When you release her, Koshei will come out and bring destruction."
    )
    |> close()
  end

  defp hear_of_koshei(ctx) do
    ctx
    |> mes("[Baba Yaga]")
    |> mes("What are you doing here? Kehehehe.")
    |> next()
    |> player_says("Koshei... suddenly appeared.. and Maria.. Wolf... killed...")
    |> next()
    |> mes("[Baba Yaga]")
    |> mes("Calm down and speak slowly. I cannot hear you at all. Drink some water.")
    |> next()
    |> mes("- You drink some water and -")
    |> mes("- tell her the story slowly -")
    |> next()
    |> mes("[Baba Yaga]")
    |> mes("You beat Koshei? Did you?")
    |> mes("Kehehe, you are no ordinary kid.")
    |> next()
    |> mes("[Baba Yaga]")
    |> mes("Water to enliven Maria...")
    |> next()
    |> water_ingredients()
    |> set_char_var(:rhea_rus_main, 50)
    |> close()
  end

  defp water_ingredients(ctx) do
    ctx
    |> mes("[Baba Yaga]")
    |> mes(
      "'Living Water'... I just need the ingredients.  I need ^0000ff1 Holy Water^000000 and ^0000ff2 Yggdrasil Leaves^000000."
    )
    |> next()
    |> mes("[Baba Yaga]")
    |> mes(
      "And 'Dead Water'.. I need ^0000ff1 Cursed Water^000000 and ^0000ff10 Hinalle Leaflets^000000."
    )
    |> next()
    |> mes("[Baba Yaga]")
    |> mes("Bring them to me quickly! Time is running out!")
  end

  defp brew_waters(ctx) do
    if Rathena.truthy?(count_item(ctx, 523)) and Rathena.truthy?(count_item(ctx, 12_020)) and
         count_item(ctx, 610) > 1 and count_item(ctx, 520) > 9 do
      ctx
      |> mes("[Baba Yaga]")
      |> mes("Kehe, you are very quick.")
      |> next()
      |> mes("[Baba Yaga]")
      |> mes("Ok, let's make the 'Living Water' first...")
      |> next()
      |> mes("- Baba Yaga brings a big pot, -")
      |> mes("- pours the Holy Water in it, -")
      |> mes("- puts the Yggdrasil Leaves -")
      |> mes("- in it and stirs them up -")
      |> mes("- as it casts strange spells -")
      |> next()
      |> mes("[Baba Yaga]")
      |> mes("Yg~ Yg~ Yggdrasil~ Yggdrasil has lots of iron~")
      |> specialeffect(:pharmacy_ok)
      |> next()
      |> mes("[Baba Yaga]")
      |> mes("Here, I made the 'Living Water' so now let's make the 'Dead Water'...")
      |> next()
      |> mes("- Baba Yaga pours the cursed -")
      |> mes("- water in another pot, then -")
      |> mes("- pounds the Hinalle leaflets, -")
      |> mes("- puts their juice in the pot -")
      |> mes("- and stirs them together -")
      |> mes("- as it casts strange spells -")
      |> next()
      |> mes("[Baba Yaga]")
      |> mes(
        "Hi~ hi~ hi~ hi~ na~ lle~ Stir with right hand~ Stir with left hand~ Both hands will be ok~"
      )
      |> specialeffect(:pharmacy_ok)
      |> next()
      |> mes("[Baba Yaga]")
      |> mes("Here, it's done.")
      |> next()
      |> mes("[Baba Yaga]")
      |> mes("Take this and help Maria. Kehehehehehe.")
      |> next()
      |> pouring_instructions()
      |> next()
      |> mes("- ^0000ffYou get the 'Living Water'^000000 -")
      |> mes("- ^0000ffand the 'Dead Water' !!^000000 -")
      |> delitem(523, 1)
      |> delitem(12_020, 1)
      |> delitem(610, 2)
      |> delitem(520, 10)
      |> set_char_var(:rhea_rus_main, 51)
      |> close()
    else
      ctx |> water_ingredients() |> close()
    end
  end

  defp waters_reminder(ctx) do
    ctx
    |> mes("[Baba Yaga]")
    |> mes("Go to Maria to help her.")
    |> next()
    |> pouring_instructions()
    |> close()
  end

  defp pouring_instructions(ctx) do
    ctx
    |> mes("[Baba Yaga]")
    |> mes(
      "First, pour the 'Dead Water' to remove the wound and curse on her and then pour the 'Living Water' to enliven her."
    )
    |> next()
    |> mes("[Baba Yaga]")
    |> mes("Go there right now! Kehehehehe")
  end

  defp tell_of_seal(ctx) do
    ctx
    |> mes("[Baba Yaga]")
    |> mes("You are more useful than I thought, kid.")
    |> next()
    |> mes("[Baba Yaga]")
    |> mes(
      "I thank you for helping Maria. To tell the truth, it was me that connected her with Koshei. In order to seal Koshei, I needed a sacrfice..."
    )
    |> next()
    |> mes("[Baba Yaga]")
    |> mes(
      "I succeeded in sealing Koshei away by using a girl who was magically strong. Sadly the girl also had to remain in the same condition as Koshei in order to maintain the seal."
    )
    |> next()
    |> mes("[Baba Yaga]")
    |> mes(
      "However, after so many years it was impossible to keep him sealed with Maria's power alone."
    )
    |> next()
    |> mes("[Baba Yaga]")
    |> mes(
      "So that's when I decided that if you could subdue Koshei, it would be the only way to release Maria instead of using her to maintain the seal."
    )
    |> next()
    |> mes("[Baba Yaga]")
    |> mes("So, that is why I helped you out by making the 'Golden Key'.")
    |> next()
    |> mes("[Baba Yaga]")
    |> mes(
      "Koshei is still alive, but he is weaker than before. So I don't need to use Maria anymore to seal Koshei."
    )
    |> next()
    |> mes("[Baba Yaga]")
    |> mes("Thank you so much for helping Maria...")
    |> next()
    |> mes("[Baba Yaga]")
    |> mes("I want to give anything helpful for you.")
    |> next()
    |> mes("[Baba Yaga]")
    |> mes(
      "Whenever you come to me, I will make you potions with just a few materials and a small fee. I hope that this will be of help to you. Kehehehehehe."
    )
    |> set_char_var(:rhea_rus_main, 53)
    |> close()
  end

  defp potion_shop(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Baba Yaga]")
      |> mes("Oh, you are back. What can I do for you?")
      |> next()
      |> select(["Condensed Red Potion", "Condensed Yellow Potion", "Cancel"])

    case choice do
      3 ->
        ctx
        |> mes("[Baba Yaga]")
        |> mes("You don't want anything?")
        |> next()
        |> mes("[Baba Yaga]")
        |> mes("I don't understand you. What do you want? kehehehehe.")
        |> close()

      choice when is_map_key(@potions, choice) ->
        offer_potion(ctx, Map.fetch!(@potions, choice))

      _ ->
        ctx
    end
  end

  defp offer_potion(ctx, %{item: item, fee: fee, materials: materials} = potion) do
    material_list =
      Enum.flat_map(materials, fn {id, amount} -> [amount, Rathena.getitemname(id)] end)

    ctx =
      ctx
      |> mes("[Baba Yaga]")
      |> mes(
        Rathena.format(
          "To make %s, I need ^0000ff%d %s, %d %s, %d %s, %d %s and %d Zeny^000000.",
          [Rathena.getitemname(item)] ++ material_list ++ [fee]
        )
      )

    if affordable?(ctx, potion, 1) do
      brew_potions(ctx, potion)
    else
      close(ctx)
    end
  end

  defp brew_potions(ctx, potion) do
    %{item: item, fee: fee, materials: materials, prompt: prompt} = potion

    most =
      materials
      |> Enum.map(fn {id, amount} -> div(count_item(ctx, id), amount) end)
      |> Enum.concat([div(zeny(ctx), fee)])
      |> Enum.min()

    ctx =
      ctx
      |> next()
      |> mes("[Baba Yaga]")
      |> mes(
        "With your materials, I can make ^0000ff#{most}^000000 #{Rathena.getitemname(item)}."
      )
      |> next()
      |> mes("[Baba Yaga]")
      |> mes("How many do you want me to make? #{prompt}. Kehehehehe.")
      |> next()

    case ask_quantity(ctx) do
      {:ok, ctx, quantity} -> craft(ctx, potion, quantity)
      {:declined, ctx} -> ctx
    end
  end

  defp ask_quantity(ctx) do
    {ctx, quantity} = input(ctx, :int)
    ctx = mes(ctx, "[Baba Yaga]")

    cond do
      not Rathena.truthy?(quantity) ->
        ctx =
          ctx
          |> mes("You don't want it?")
          |> next()
          |> mes("[Baba Yaga]")
          |> mes("I don't understand you. What do you want? Kehehehehe.")
          |> close()

        {:declined, ctx}

      quantity > 100 ->
        ctx |> mes("I said no more than 100 at a time. Kehehehehe.") |> next() |> ask_quantity()

      true ->
        {:ok, ctx, quantity}
    end
  end

  defp craft(ctx, %{item: item, fee: fee, materials: materials} = potion, quantity) do
    if affordable?(ctx, potion, quantity) do
      [{base_id, _}, _, _, {ground_id, _}] = materials

      ctx =
        ctx
        |> mes("[Baba Yaga]")
        |> mes("Ho, you want #{quantity}. Ok, wait here for a while.")
        |> next()
        |> mes("- Baba Yaga grinds the #{Rathena.getitemname(ground_id)} -")
        |> mes("- and pours the #{Rathena.getitemname(base_id)} -")
        |> mes("- into the Medicine Bowl, -")
        |> mes("- boils and cools it down -")
        |> mes("- and puts it in the Test Tube -")
        |> next()
        |> mes("[Baba Yaga]")
        |> mes("Here, done!")
        |> specialeffect(:pharmacy_ok)
        |> next()
        |> mes("[Baba Yaga]")
        |> mes("Whenever you want more, come to me.")

      materials
      |> Enum.reduce(ctx, fn {id, amount}, ctx -> delitem(ctx, id, amount * quantity) end)
      |> pay_zeny(quantity * fee)
      |> give_item(item, quantity)
      |> close()
    else
      ctx
      |> mes("[Baba Yaga]")
      |> mes("Where are the materials?")
      |> mes("They are not enough! Check them and come back again! Kehehehehe.")
      |> close()
    end
  end

  defp affordable?(ctx, %{fee: fee, materials: materials}, quantity) do
    zeny(ctx) >= fee * quantity and
      Enum.all?(materials, fn {id, amount} -> count_item(ctx, id) >= amount * quantity end)
  end

  defp player_says(ctx, line) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes(line)
  end
end
