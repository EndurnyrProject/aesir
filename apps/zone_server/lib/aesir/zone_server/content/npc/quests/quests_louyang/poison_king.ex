defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.PoisonKing do
  @moduledoc """
  Nagash Arses, the exiled poison master at the heart of the Poison King quest.

  ## Behavior

  - Carries over progress from the old quest variables before talking.
  - Recites his poem; players carrying poison ingredients sometimes get to ask about
    the poem, Morocc, poison and his past. Passing the poem quiz, hearing his life story
    and his downfall advance the quest, and asking about poison sends the player to his
    disciple Song Zhi Du.
  - Learns of his disciple's poisoning plot from the Poison Bottle and begs the player
    to save Lord Bai Long.
  - Hands over his journal for the lord and, on receiving the lord's letter, grants
    level-based EXP and warps the player back to Louyang.

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
        x: 123,
        y: 39,
        dir: 4,
        sprite: 824,
        name: "Poison King",
        scope: :shared,
        unique_name: "Poison King#lou"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @frost_options ["frost", "dew", "pebbles", "snow"]
  @theme_options ["Tragedy", "Separation", "Love", "Revenge", "Buddy Cop Film"]

  @impl true
  def on_talk(ctx) do
    ctx = migrate_legacy_progress(ctx)

    if checkweight(ctx, [{1201, 1}]) == 0 do
      overweight(ctx)
    else
      talk(ctx, get_char_var(ctx, :ch_poison, 0))
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp migrate_legacy_progress(ctx) do
    if get_char_var(ctx, :ch_poison, 0) == 0 and get_char_var(ctx, :CL_POISONKING, 0) != 0 do
      ctx
      |> restore_legacy_progress(get_char_var(ctx, :QL_POISONKING, 0))
      |> set_char_var(:QL_POISONKING, 0)
    else
      ctx
    end
  end

  defp restore_legacy_progress(ctx, legacy) do
    cond do
      legacy <= 12 -> set_char_var(ctx, :ch_poison, legacy)
      legacy == 16 -> set_char_var(ctx, :ch_poison, 19)
      legacy >= 17 -> set_char_var(ctx, :ch_poison, 20)
      true -> ctx
    end
  end

  defp overweight(ctx) do
    ctx
    |> mes("^3355FF * Wait a minute! *")
    |> mes(
      "Right now, you are carrying too many items with you. Please place some of your items into Kafra Storage and try again.^000000"
    )
    |> close()
  end

  defp talk(ctx, progress) do
    cond do
      progress < 6 -> reminisce(ctx, progress)
      progress > 4 and progress < 12 -> point_to_disciple(ctx)
      progress == 12 -> ask_after_disciple(ctx)
      progress == 13 -> sense_trouble(ctx)
      progress == 14 -> lost_in_anguish(ctx)
      progress in [15, 16] -> plead_for_the_lord(ctx)
      progress == 17 -> hand_over_journal(ctx)
      progress == 18 -> remind_journal(ctx)
      progress == 19 -> decline_the_lords_offer(ctx)
      progress > 20 -> at_peace(ctx)
      true -> boast_of_name(ctx)
    end
  end

  defp reminisce(ctx, progress) do
    ctx =
      ctx
      |> mes("[Nagash Arses]")
      |> mes(
        "It's been 40 years since I came here. Hahaha, but it doesn't feel like it's been that long."
      )
      |> next()
      |> mes("[Nagash Arses]")
      |> mes("In the past, I was one of the")
      |> mes("most renowned experts in the use")
      |> mes(
        "of poison. I even created a martial art based on its use, and formed my own martial arts organization."
      )
      |> next()
      |> mes("[Nagash Arses]")
      |> mes("Now, those memories")
      |> mes("don't even seem real")
      |> mes("anymore. This poem is")
      |> mes("all I can remember...")
      |> next()
      |> recite_poem()
      |> next()

    if carries_poison_ingredient?(ctx) and progress > 0 and Enum.random(1..300) > 99 do
      ask_about_past(ctx, progress)
    else
      share_feelings(ctx)
    end
  end

  defp carries_poison_ingredient?(ctx) do
    count_item(ctx, 506) > 0 or count_item(ctx, 511) > 0 or count_item(ctx, 716) > 0
  end

  defp recite_poem(ctx) do
    ctx
    |> mes("[Nagash Arses]")
    |> mes("As I lay in bed looking")
    |> mes("up at the moonlight")
    |> mes(" ")
    |> mes("It looks like the")
    |> mes("frost on the ground.")
    |> next()
    |> mes("[Nagash Arses]")
    |> mes("I lift head up to look")
    |> mes("at the bright moon,")
    |> mes(" ")
    |> mes("I lower my head")
    |> mes("feeling homesick.")
  end

  defp ask_about_past(ctx, progress) do
    {ctx, choice} =
      select(ctx, [
        "Ask about the poem.",
        "Ask about his hometown.",
        "Ask about use of Poison.",
        "Ask about his situation."
      ])

    case choice do
      1 -> poem_quiz(ctx)
      2 -> hometown(ctx, progress)
      3 -> poison_teaching(ctx, progress)
      4 -> situation(ctx, progress)
      _ -> ctx
    end
  end

  defp poem_quiz(ctx) do
    ctx =
      ctx
      |> mes("[Nagash Arses]")
      |> mes("Ah, have you")
      |> mes("heard of this poem?")
      |> mes("As I grow older, my")
      |> mes("memory also grows worse,")
      |> mes("but I really like this poem")
      |> mes("and don't want to forget it.")
      |> next()
      |> mes("[Nagash Arses]")
      |> mes("I hope you don't")
      |> mes("mind helping me")
      |> mes("memorize this poem...")
      |> next()

    case Enum.random(1..4) do
      1 -> first_line_quiz(ctx)
      2 -> second_line_quiz(ctx)
      3 -> third_line_quiz(ctx)
      _ -> last_line_quiz(ctx)
    end
  end

  defp first_line_quiz(ctx) do
    {ctx, score} =
      ctx
      |> mes("[Nagash Arses]")
      |> mes(
        "'^3355FFAs I lay^000000 [ ] ^3355FFlooking up at the moonlight^000000.' In this first line, what word should be in [ ]?"
      )
      |> next()
      |> score_answer(0, ["on the ground", "with you", "in bed", "in the stars"], 3)

    {ctx, score} = ask_frost_word(ctx, score)

    {ctx, score} =
      ctx
      |> mes("[Nagash Arses]")
      |> mes(
        "Now to see if you see really understand the poem. It's no use to just know the words. They must be a part of you as well."
      )
      |> next()
      |> mes("[Nagash Arses]")
      |> mes("How would you describe the overall mood and tone of the speaker of this poem?")
      |> next()
      |> score_answer(score, ["Romantic", "Wistful", "Regretful", "Passionate"], 2)

    {ctx, score} =
      ctx
      |> mes("[Nagash Arses]")
      |> mes("What do you think is the")
      |> mes("major theme of this poem?")
      |> next()
      |> score_answer(score, @theme_options, 2)

    first_line_options =
      if score > 30 do
        [
          "When I lay in bed looking up at the moon light",
          "When I lay in bed thinking of the moon light",
          "As I lay in bed looking up at the moonlight",
          "As I lay in bed thinking of the moonlight"
        ]
      else
        [
          "When I lay in bed looking up at the moon light",
          "When I lay in bed thinking of the moon light",
          "As I lay in bed looking up at the moonlight",
          "As I lay in bed thinking of the moon light"
        ]
      end

    recite_line(ctx, score, "first", first_line_options, 3)
  end

  defp second_line_quiz(ctx) do
    {ctx, score} = ask_frost_word(ctx, 0)
    {ctx, score} = ask_homesick_word(ctx, score)

    {ctx, score} =
      ctx
      |> next()
      |> mes("[Nagash Arses]")
      |> mes(
        "Now to see if you see really understand the poem. It's no use to just know the words. To know this poem by heart is to truly take it to heart."
      )
      |> next()
      |> mes("[Nagash Arses]")
      |> mes("According to the poem,")
      |> mes("where is the location")
      |> mes("of the speaker as he is")
      |> mes("gazing at the moon?")
      |> next()
      |> score_answer(
        score,
        ["In his hometown.", "In jail.", "In the depths of the cosmos.", "In bed."],
        4
      )

    {ctx, score} =
      ctx
      |> mes("[Nagash Arses]")
      |> mes(
        "Although this poem is only four lines long, its structure can be easily classified. How would you describe this poem's structure?"
      )
      |> next()
      |> score_answer(
        score,
        [
          "Why, it's a sonnet.",
          "It's prose with erratic caesuras.",
          "It's a quatrain, of course.",
          "Iambic pentameter?"
        ],
        3
      )

    recite_line(
      ctx,
      score,
      "first",
      [
        "It looks like the frost on the ground",
        "It looks like an icicle on the ground",
        "It looks as though shining",
        "It looks like the frost in the sky"
      ],
      1
    )
  end

  defp third_line_quiz(ctx) do
    {ctx, score} = ask_frost_word(ctx, 0)
    {ctx, score} = ctx |> next() |> ask_homesick_word(score)

    {ctx, score} =
      ctx
      |> next()
      |> mes("[Nagash Arses]")
      |> mes(
        "Now to see if you see really understand the poem. It's not enough to just know the words. You must know what they truly mean."
      )
      |> next()
      |> mes("[Nagash Arses]")
      |> mes("In the first two lines, what two images are being linked by the poet?")
      |> next()
      |> score_answer(
        score,
        ["Bed and ground", "Frost and hometown", "Gloomy", "Smokey", "Moonlight and frost"],
        5
      )

    {ctx, score} =
      ctx
      |> mes("[Nagash Arses]")
      |> mes(
        "In this land, the image of the moon often appears in poems expressing separation, longing and homesickness. Why would gazing at the moon offer comfort?"
      )
      |> next()
      |> score_answer(
        score,
        [
          "The rabbit on the moon grants wishes.",
          "Its sheer beauty eases any anxiety.",
          "Because it wanes and waxes.",
          "All places and peoples share the same moon."
        ],
        4
      )

    recite_line(
      ctx,
      score,
      "third",
      [
        "I look up at the bright moon",
        "I lift my head to look at the bright moon",
        "I turn my head to look at the bright moon",
        "I face the bright moon"
      ],
      2
    )
  end

  defp last_line_quiz(ctx) do
    {ctx, score} =
      ctx
      |> mes("[Nagash Arses]")
      |> mes(
        "'^3355FFIt looks like the^000000 [ ] ^3355FFon the ground^000000.' In the second line,"
      )
      |> mes("which word should be in [ ]?")
      |> next()
      |> score_answer(0, @frost_options, 1)

    {ctx, score} =
      ctx
      |> next()
      |> mes("[Nagash Arses]")
      |> mes(
        "'^3355FFI lift my^000000 [ ] ^3355FFto look at the bright moon^000000.' In the third line, which word should be in [ ]?"
      )
      |> next()
      |> score_answer(score, ["eyes", "head", "gaze", "sights"], 2)

    {ctx, score} =
      ctx
      |> next()
      |> mes("[Nagash Arses]")
      |> mes("Now to see if you see really understand the poem. It's no")
      |> mes("use to just know the words. They must be a part of you as well.")
      |> next()
      |> mes("[Nagash Arses]")
      |> mes("What do you think is the major theme of this poem?")
      |> next()
      |> score_answer(score, @theme_options, 2)

    {ctx, score} =
      ctx
      |> next()
      |> mes("[Nagash Arses]")
      |> mes(
        "Why might be one reason why the bright moonlight looks like frost on the ground to the poet?"
      )
      |> next()
      |> score_answer(
        score,
        [
          "He's looking through a frosty window.",
          "A bright moon glimmers like icicles.",
          "He's homesick, so the moonlight looks cold",
          "It's called 'poetic license.'"
        ],
        3
      )

    recite_line(
      ctx,
      score,
      "last",
      [
        "I cry for my home town.",
        "I lower my head feeling homesick.",
        "I miss my home town.",
        "I sob feeling homesick."
      ],
      2
    )
  end

  defp ask_frost_word(ctx, score) do
    ctx
    |> mes("[Nagash Arses]")
    |> mes(
      "'^3355FFIt looks like the^000000 [ ] ^3355FFon the ground^000000.' In the second line, which word should be in [ ]?"
    )
    |> next()
    |> score_answer(score, @frost_options, 1)
  end

  defp ask_homesick_word(ctx, score) do
    ctx
    |> mes("[Nagash Arses]")
    |> mes("'^3355FFI lower my head feeling^000000 [ ].' Which word should be in [ ]?")
    |> next()
    |> score_answer(score, ["homesick.", "drowsy", "loneliness.", "heartbroken."], 1)
  end

  defp score_answer(ctx, score, options, correct) do
    {ctx, choice} = select(ctx, options)
    {ctx, if(choice == correct, do: score + 10, else: score)}
  end

  defp recite_line(ctx, score, line, options, correct) do
    {ctx, choice} =
      ctx
      |> next()
      |> mes("[Nagash Arses]")
      |> mes(
        "Ha ha ha! You understand this poem well! Now, would you repeat the #{line} line for me again?"
      )
      |> next()
      |> select(options)

    ctx = if score > 30 and choice == correct, do: set_char_var(ctx, :ch_poison, 2), else: ctx

    ctx
    |> mes("[Nagash Arses]")
    |> mes("Thank you for your time,")
    |> mes("youngster. Oh, and this is")
    |> mes("an old, famous poem written")
    |> mes("by Li Tai Bai. You know that,")
    |> mes("don't you?")
    |> close()
  end

  defp hometown(ctx, progress) do
    ctx =
      ctx
      |> mes("[Nagash Arses]")
      |> mes("Are you asking me")
      |> mes("about my hometown...?")
      |> mes("As a Midgardian,")
      |> mes("I'm sure you've at least")
      |> mes("heard of Morocc...")
      |> next()
      |> mes("[Nagash Arses]")
      |> mes(
        "A city built in the middle of the desert, its founders had to combat the harsh and unforgiving forces of nature everyday."
      )
      |> next()
      |> mes("[Nagash Arses]")
      |> mes("Yeah, the blazing sun never")
      |> mes("seems to leave, and it's a dry,")
      |> mes("desert area, but people still")
      |> mes("manage to live there.")
      |> next()

    if progress == 2, do: miss_morocc(ctx), else: wish_to_see_morocc(ctx)
  end

  defp miss_morocc(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Nagash Arses]")
      |> mes("Ah~ I miss Morocc, my hometown.")
      |> mes(
        "I used to be a member of the Assassin organization known as the 'Canine of Desert.' Long ago, I was their poison expert."
      )
      |> next()
      |> select(["Tell him news of Morocc.", "Info about 'Canine of Desert'.", "Just listen."])

    case choice do
      1 -> hear_recent_news(ctx)
      2 -> quiz_on_canine_of_desert(ctx)
      3 -> listen_to_life_story(ctx)
      _ -> ctx
    end
  end

  defp hear_recent_news(ctx) do
    ctx =
      ctx
      |> mes("[Nagash Arses]")
      |> mes("Hm? Do you have recent news of Morocc?")
      |> next()

    {ctx, news} =
      ctx
      |> mes(player_label(ctx))
      |> mes("Yeah, I've got some news you might be interested in.")
      |> input(:string)

    ctx = ctx |> mes(player_label(ctx)) |> mes("#{news}") |> next()

    if Enum.random(1..50) > 25 do
      ctx
      |> mes("[Nagash Arses]")
      |> mes("Ah, I see. Thank you for the news. Now, let me continue my story.")
      |> next()
      |> tell_life_story()
    else
      ctx
      |> mes("[Nagash Arses]")
      |> mes("I see! You just said,")
      |> mes("#{news}.")
      |> next()
      |> mes("[Nagash Arses]")
      |> mes("Thank you for")
      |> mes("telling me the news.")
      |> close()
    end
  end

  defp quiz_on_canine_of_desert(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Nagash Arses]")
      |> mes(
        "I just told you what 'Canine of Desert' is. Now you tell me what it is. If you were listening, you would be able to."
      )
      |> next()
      |> input(:string)

    if canine_of_desert_answer?(answer) do
      ctx
      |> praise_canine_answer()
      |> next()
      |> mes("[Nagash Arses]")
      |> mes("'Canine of Desert' is the name of that Assassin organization. Don't forget that.")
      |> next()
      |> mes("[Nagash Arses]")
      |> mes("...")
      |> next()
      |> mes("[Nagash Arses]")
      |> mes("...")
      |> mes("......")
      |> next()
      |> mes("[Nagash Arses]")
      |> mes(
        "Bah! I forgot what I was just talking about! This bad memory of mine frustrates me so much!"
      )
      |> close()
    else
      scold_wrong_canine_answer(ctx)
    end
  end

  defp listen_to_life_story(ctx) do
    if Enum.random(1..33) < 12 do
      ctx
      |> mes("[Nagash Arses]")
      |> mes("Wait...")
      |> mes("Let me think...")
      |> mes("Now how did I becoming interested in the use of poison...?")
      |> close()
    else
      tell_life_story(ctx)
    end
  end

  defp tell_life_story(ctx) do
    ctx
    |> mes("[Nagash Arses]")
    |> mes("I tried many things to develop my poison skills when I was young.")
    |> mes(
      "I tried to extract poison from Muka's needles and from purple mushrooms. Eventually, I became"
    )
    |> mes("an expert of toxins from my efforts.")
    |> next()
    |> mes("[Nagash Arses]")
    |> mes("One time I even injected")
    |> mes("a poison into my own body")
    |> mes("to fully test it. Yeah...")
    |> mes("It almost killed me.")
    |> next()
    |> mes("[Nagash Arses]")
    |> mes("I was recognized as the man who")
    |> mes(
      "was most highly skilled in the use of poison in the 'Canine of Desert,' and I was sent on the most crucial and dangerous missions."
    )
    |> next()
    |> mes("[Nagash Arses]")
    |> mes(
      "One day, I was hired by the Alberta Merchant Guild to assassinate an enemy that had been threatening them. However, I never got to complete that mission."
    )
    |> next()
    |> mes("[Nagash Arses]")
    |> mes(
      "While I was on the ship to procceed with my mission, we encountered heavy wind and waves and the ship sank. I believe I was the only survivor of that accident."
    )
    |> next()
    |> mes("[Nagash Arses]")
    |> mes("I was floated helplessly on the ocean and somehow managed")
    |> mes("to arrive here, in Luoyang. That was forty years ago.")
    |> next()
    |> mes("[Nagash Arses]")
    |> mes(
      "It seemed that my arrival was rather timely. Luoyang was intruded by huge mobs of dangerous monsters that were even able to infiltrate the Castle of the Dragon."
    )
    |> next()
    |> mes("[Nagash Arses]")
    |> mes(
      "Since I was one of the best Assassins of the 'Canine of Desert,' I did far more than my share of monster killing."
    )
    |> next()
    |> mes("[Nagash Arses]")
    |> mes("It was on the battlefield that")
    |> mes(
      "I met Bai Long who is now lord of this town. But back then, he was known as the 'Street Knight.'"
    )
    |> next()
    |> mes("[Nagash Arses]")
    |> mes("I remember seeing him surrounded")
    |> mes(
      "by enemies, and I dove into thick of battle to keep him from getting killed. We fought back to back and managed to stay alive back then."
    )
    |> next()
    |> mes("[Nagash Arses]")
    |> mes("You have to understand that it's not easy to let someone back you")
    |> mes(
      "up in battle unless there's a solid trust. Those fights... were the greatest moments in my life."
    )
    |> next()
    |> mes("[Nagash Arses]")
    |> mes("Sadly, many of our comrades,")
    |> mes(
      "all of them respectable and highly skilled martial artists, fell in battle. The number of monsters we had to contend with was just overwhelming."
    )
    |> next()
    |> mes("[Nagash Arses]")
    |> mes(
      "Still, I managed to continue my poison research, even during those tough times. I studied medicine in this town and was able use that knowledge to enhance my understanding of poisons."
    )
    |> next()
    |> mes("[Nagash Arses]")
    |> mes("I created a new skill based on all of my knowledge, and learned how")
    |> mes("to put poison on weapons.")
    |> next()
    |> mes("[Nagash Arses]")
    |> mes("I even learned martial arts in Luoyang, and combined that")
    |> mes("knowledge with my poison expertise to create my own unique fighting style.")
    |> next()
    |> mes("[Nagash Arses]")
    |> mes("Well, that's my story.")
    |> mes("But now, I just miss my")
    |> mes("home town. I miss the heat")
    |> mes("of the desert and the glare")
    |> mes("of the blazing sun...")
    |> set_char_var(:ch_poison, 3)
    |> close()
  end

  defp wish_to_see_morocc(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Nagash Arses]")
      |> mes("Ah, Morocc.")
      |> mes("That name brings")
      |> mes("back memories of")
      |> mes("being an Assassin")
      |> mes("in the 'Canine of Desert.'")
      |> next()
      |> mes("[Nagash Arses]")
      |> mes("^666666*Sigh...*^000000")
      |> mes("I wish I could see")
      |> mes("Morocc just once before I die.")
      |> next()
      |> select(["Tell him news of Morocc.", "Ask about 'Canine of Desert.'"])

    if choice == 1, do: share_morocc_news(ctx), else: test_canine_of_desert(ctx)
  end

  defp share_morocc_news(ctx) do
    ctx =
      ctx
      |> mes("[Nagash Arses]")
      |> mes("Hm...?")
      |> mes("Is there anything")
      |> mes("you want to say?")
      |> next()

    {ctx, news} =
      ctx
      |> mes(player_label(ctx))
      |> mes("I have news")
      |> mes("of Morocc...")
      |> input(:string)

    ctx = ctx |> mes(player_label(ctx)) |> mes("#{news}") |> next()

    if Enum.random(1..50) > 30 do
      ctx
      |> mes("[Nagash Arses]")
      |> mes("I see...")
      |> mes("Thank you for")
      |> mes("telling me that.")
      |> close()
    else
      ctx
      |> mes("[Nagash Arses]")
      |> mes("I see!")
      |> mes("You just said, #{news}. Thank you.")
      |> close()
    end
  end

  defp test_canine_of_desert(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Nagash Arses]")
      |> mes(
        "I just told you what 'Canine of Desert.' If you can't remember what I just told you, it's no use for me to explain further. You go ahead and tell me what it is."
      )
      |> next()
      |> input(:string)

    if canine_of_desert_answer?(answer) do
      ctx
      |> praise_canine_answer()
      |> next()
      |> mes("[Nagash Arses]")
      |> mes("Canine of Desert")
      |> mes("is the name of an")
      |> mes("Assassin organization.")
      |> mes("Do not forget that.")
      |> close()
    else
      scold_wrong_canine_answer(ctx)
    end
  end

  defp canine_of_desert_answer?(answer),
    do: answer in ["Assassin Organization", "Assassin", "Assassins"]

  defp praise_canine_answer(ctx) do
    ctx
    |> mes("[Nagash Arses]")
    |> mes(
      "Correct. You listened to me very well. They are Assassins. Assassins that were abandoned by society."
    )
  end

  defp scold_wrong_canine_answer(ctx) do
    if Rathena.job_id(base_job(ctx)) == Rathena.job_id(:assassin) do
      ctx
      |> mes("[Nagash Arses]")
      |> mes(
        "How could you not know what the 'Canine of Desert' is?! Just how long have you been an Assassin?!"
      )
      |> next()
      |> mes("[Nagash Arses]")
      |> mes("You're supposed to be aware of your origins and your colleagues! Oh, the shame...")
      |> close()
    else
      ctx
      |> mes("[Nagash Arses]")
      |> mes(
        "Well, I suppose I can't blame you for not knowing or remembering. When you get the chance, find someone wearing a purple suit..."
      )
      |> next()
      |> mes("[Nagash Arses]")
      |> mes("Any Assassin worth his salt should know what the 'Canine of Desert' is.")
      |> close()
    end
  end

  defp poison_teaching(ctx, progress) do
    ctx =
      ctx
      |> mes("[Nagash Arses]")
      |> mes("Did you just say you")
      |> mes("want to learn about the")
      |> mes("use of poison?")
      |> next()
      |> mes("[Nagash Arses]")
      |> mes("Why do you want")
      |> mes("to learn about it?")
      |> mes("Even if I wanted to")
      |> mes("teach, I'm too old to")
      |> mes("remember everything")
      |> mes("clearly...")

    if progress in [4, 5] do
      ctx
      |> next()
      |> mes("[Nagash Arses]")
      |> mes("Go find my last disciple,")
      |> mes(
        "^0000FFSong Zhi Du^000000, as he may tell you something useful. He's working at the doctor's office. If it weren't for him, I'd be starving now."
      )
      |> set_char_var(:ch_poison, 5)
      |> setquest(11_070)
      |> close()
    else
      close(ctx)
    end
  end

  defp situation(ctx, 3) do
    {ctx, choice} =
      ctx
      |> mes("[Nagash Arses]")
      |> mes("You're asking me how")
      |> mes("things came to be like")
      |> mes("this? Life used to be good.")
      |> next()
      |> mes("[Nagash Arses]")
      |> mes(
        "As I told you, I distinguished myself in the battles with monsters. I was rewarded with Luoyang citizenship and given"
      )
      |> mes("gifts of money.")
      |> next()
      |> mes("[Nagash Arses]")
      |> mes(
        "I was invited to join a martial arts organization that specialized in the use of poison. I joined them, excited about further broadening my knowledge."
      )
      |> next()
      |> mes("[Nagash Arses]")
      |> mes(
        "I was stunned by the enormous body of knowledge about toxins that they provided. I tried to learn as much as I could so I could develop my own, unique poisoning skills."
      )
      |> next()
      |> mes("[Nagash Arses]")
      |> mes(
        "As I studied with them, together we started to clear the town of the remaining monsters. Can you guess the results of our efforts to clean up the city?"
      )
      |> next()
      |> select([
        "...??",
        "It must have been good.",
        "I guess it was okay?",
        "I don't know, but how did it go?"
      ])

    case choice do
      1 ->
        ctx
        |> mes("[Nagash Arses]")
        |> mes(
          "Did you even listen to me? It's no use talking to you if you don't even care about what I have to say."
        )
        |> next()
        |> mes("[Nagash Arses]")
        |> mes(
          "I'm sorry for keeping you from what you wanted to do. Take care of yourself, youngster."
        )
        |> close()

      2 ->
        ctx
        |> mes("[Nagash Arses]")
        |> mes("You're right!")
        |> mes("We got rid of every")
        |> mes("single monster in the city!")
        |> next()
        |> tell_downfall()

      3 ->
        ctx
        |> mes("[Nagash Arses]")
        |> mes("Just okay...?")
        |> mes("I don't think you realized how powerful we were back then! Eh...")
        |> next()
        |> mes("[Nagash Arses]")
        |> mes(
          "Sorry for keeping you from what you wanted to do. Take care of yourself, youngster."
        )
        |> close()

      4 ->
        ctx
        |> mes("[Nagash Arses]")
        |> mes("We got rid of every single monster in the city!")
        |> next()
        |> tell_downfall()

      _ ->
        ctx
    end
  end

  defp situation(ctx, _progress) do
    ctx
    |> mes("[Nagash Arses]")
    |> mes("I...")
    |> mes("I don't want")
    |> mes("to talk about that.")
    |> mes("Let's not talk about it.")
    |> close()
  end

  defp tell_downfall(ctx) do
    ctx
    |> mes("[Nagash Arses]")
    |> mes(
      "We managed to eliminate every monster that was wandering around Luoyang. At the time, we were the only people brave enough to take on this sort of task."
    )
    |> next()
    |> mes("[Nagash Arses]")
    |> mes(
      "Unfortunately, other martial arts organizations grew envious of our success, insisting that we were dishonorable for using poison to attack our enemies."
    )
    |> next()
    |> mes("[Nagash Arses]")
    |> mes(
      "Although we can accept criticism for our use of poison, we were finally blamed for something we never would have done."
    )
    |> next()
    |> mes("[Nagash Arses]")
    |> mes(
      "Someone put poison into a meal which was eaten by a son of the lord and then falsely accused us!"
    )
    |> next()
    |> mes("[Nagash Arses]")
    |> mes("In the end, our organization was disbanded and I was put in jail.")
    |> mes("I suffered through much to escape from prison...")
    |> next()
    |> mes("[Nagash Arses]")
    |> mes(
      "However, because of all the injuries I've had to endure in jail and in my escape attempts,"
    )
    |> mes("I can no longer use my")
    |> mes("martial arts.")
    |> next()
    |> mes("[Nagash Arses]")
    |> mes(
      "Even to this day, the police are hounding after me. I really want to tell the lord of Luoyang that I'm innocent, but it may be"
    )
    |> mes("too late now...")
    |> set_char_var(:ch_poison, 4)
    |> close()
  end

  defp share_feelings(ctx) do
    {ctx, choice} =
      select(ctx, [
        "Grin at him.",
        "Lament for his grief.",
        "Reprove him.",
        "Listen to the poem again.",
        "Show him a sad look."
      ])

    case choice do
      1 ->
        ctx
        |> mes("[Nagash Arses]")
        |> mes("Yeah, I don't blame you.")
        |> mes("I know I look stupid. Legally,")
        |> mes("I'm a criminal after all.")
        |> mes("I don't any friends and")
        |> mes("there's no one I can trust.")
        |> close()

      2 ->
        ctx
        |> mes("[Nagash Arses]")
        |> mes("How can you sympathize?")
        |> mes("I doubt anyone has had")
        |> mes("experiences that are")
        |> mes("much worse than mine...")
        |> close()

      3 ->
        ctx
        |> mes("[Nagash Arses]")
        |> mes(
          "Wha--? I haven't wronged you in any way! Why must you be so mean to an old man? You don't even know half of what I've had to go through."
        )
        |> close()

      4 ->
        ctx |> recite_poem() |> close()

      5 ->
        show_sad_look(ctx)

      _ ->
        ctx
    end
  end

  defp show_sad_look(ctx) do
    ctx =
      ctx
      |> mes("[Nagash Arses]")
      |> mes("Do you miss your hometown")
      |> mes("as much as I do? I'm envious")
      |> mes("of you, youngster. You have")
      |> mes("the freedom to go")
      |> mes("wherever you want.")
      |> next()
      |> mes("[Nagash Arses]")
      |> mes("I'm a wanted criminal.")
      |> mes("Even if I were free to")
      |> mes("travel, I may not have")
      |> mes("the strength to try.")
      |> next()
      |> mes("[Nagash Arses]")
      |> mes("Let's not talk about this any longer. It's reminding me of")
      |> mes("my worst memories.")
      |> next()
      |> set_char_var(:ch_poison, 1)

    if Rathena.job_id(base_class(ctx)) == Rathena.job_id(:thief) do
      ctx
      |> mes("[Nagash Arses]")
      |> mes("Ah, you look just like I did when")
      |> mes("I was young. It seems you know")
      |> mes("a little something about poison.")
      |> next()
      |> mes("[Nagash Arses]")
      |> mes("It seems you haven't")
      |> mes("perfected your knowledge yet,")
      |> mes("though. Oh well, I doubt I can")
      |> mes("pinpoint what you need to master.")
      |> next()
      |> too_old_to_remember()
    else
      too_old_to_remember(ctx)
    end
  end

  defp too_old_to_remember(ctx) do
    ctx
    |> mes("[Nagash Arses]")
    |> mes(
      "I'm too old to remember anything. Ha ha ha. Maybe if I saw something related to poison, I might remember something..."
    )
    |> next()
    |> mes("[Nagash Arses]")
    |> mes("...")
    |> next()
    |> mes("[Nagash Arses]")
    |> mes("No, no...")
    |> mes("I think I'm too old")
    |> mes("to remember anything.")
    |> mes("Anything at all.")
    |> close()
  end

  defp point_to_disciple(ctx) do
    ctx
    |> mes("[Nagash Arses]")
    |> mes(
      "If you wish to talk about poison, you'd better go to the doctor's office. My last disciple is"
    )
    |> mes("working there.")
    |> next()
    |> mes("[Nagash Arses]")
    |> mes("Now, let me rest.")
    |> mes("I am very tired.")
    |> mes("I... I hope he doesn't")
    |> mes("have any bad intentions...")
    |> close()
  end

  defp ask_after_disciple(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Nagash Arses]")
      |> mes("Aren't you the youngster")
      |> mes("I talked to a while ago?")
      |> mes("Did you get a chance")
      |> mes("to meet my disciple?")
      |> mes("How was he?")
      |> next()
      |> mes("[Nagash Arses]")
      |> mes(
        "He was sick all the time when he was young, so he worried me a lot. But now I'm proud of him and he's doing as well just any other fine young man."
      )
      |> next()
      |> mes("[Nagash Arses]")
      |> mes("I am living only for him,")
      |> mes(
        "and hope that he becomes a great healer someday. Recently, I've found that my sole comfort is in treating diseases for other people..."
      )
      |> next()
      |> mes("[Nagash Arses]")
      |> mes("By the way...")
      |> mes("You look pale...")
      |> mes("Did something happen?")
      |> next()
      |> select(["Nothing.", "I want to talk about your diciple.", "I don't feel good."])

    case choice do
      1 ->
        ctx
        |> mes("[Nagash Arses]")
        |> mes("Oh...")
        |> mes("I see...")
        |> mes("But take care")
        |> mes("of yourself.")
        |> next()
        |> mes("[Nagash Arses]")
        |> mes(
          "You better enjoy your physical strength when you're young. When you're my age, it's tough to regain your health once you lose it."
        )
        |> close()

      2 ->
        worry_about_disciple(ctx)

      3 ->
        ctx
        |> mes("[Nagash Arses]")
        |> mes("Oh, you don't?")
        |> mes("Well, that can happen")
        |> mes("sometimes when you're")
        |> mes("in a foreign land for")
        |> mes("too long. I hope you")
        |> mes("feel better soon.")
        |> close()

      _ ->
        ctx
    end
  end

  defp worry_about_disciple(ctx) do
    ctx =
      ctx
      |> mes("[Nagash Arses]")
      |> mes("Did something happen to him?")
      |> mes(
        "I've been worried since he hasn't come to visit me since you last came to speak with me."
      )
      |> next()

    if count_item(ctx, 678) > 1, do: offer_poison_bottle(ctx), else: mention_rumors(ctx)
  end

  defp offer_poison_bottle(ctx) do
    {ctx, choice} = select(ctx, ["Give him Poison Bottle.", "Cancel and go to 'Song Zhi Du."])

    if choice == 1 do
      show_poison_bottle(ctx)
    else
      ctx
      |> mes(player_label(ctx))
      |> mes("...Nothing much.")
      |> next()
      |> mention_rumors()
    end
  end

  defp show_poison_bottle(ctx) do
    {ctx, choice} =
      ctx
      |> delitem(678, 1)
      |> mes("[Nagash Arses]")
      |> mes("Huh!?")
      |> mes("Isn't this...!?")
      |> next()
      |> mes("[Nagash Arses]")
      |> mes("I've dreamed of creating")
      |> mes("a poison of such potency!")
      |> mes("W-where did you find this?")
      |> next()
      |> select(["It's common nowadays.", "Explain to him what happened."])

    if choice == 1 do
      ctx
      |> mes("[Nagash Arses]")
      |> mes("Really...?")
      |> mes("Then someone")
      |> mes("finally figured it out.")
      |> next()
      |> mes("[Nagash Arses]")
      |> mes(
        "I shared all of my knowledge with others, so I guess a doctor might have figured how to create this."
      )
      |> next()
      |> mes("[Nagash Arses]")
      |> mes("^666666*Sigh...*^000000")
      |> mes("Now I feel depressed")
      |> mes("for some reason...")
      |> close()
    else
      ctx
      |> mes("^3355FFYou tell Nagash Arses how")
      |> mes(
        "Song Zhi Du created this Deadly Poison Bottle and his plan to get his revenge on the lord of Luoyang.^000000"
      )
      |> next()
      |> mes("[Nagash Arses]")
      |> mes("^666666*Sigh...*^000000")
      |> next()
      |> mes("[Nagash Arses]")
      |> mes("Will you...")
      |> mes("Will you excuse")
      |> mes("me for a second...?")
      |> set_char_var(:ch_poison, 15)
      |> changequest(11_077, 11_078)
      |> close()
    end
  end

  defp mention_rumors(ctx) do
    ctx
    |> mes("[Nagash Arses]")
    |> mes("Hmm...?")
    |> mes(
      "I guess you don't know what is going on. I've heard some bad rumors about him, which is why I'm asking."
    )
    |> next()
    |> mes("[Nagash Arses]")
    |> mes("I hope he'll be fine.")
    |> mes("After all, he's truly")
    |> mes("kind at heart.")
    |> close()
  end

  defp sense_trouble(ctx) do
    ctx
    |> mes("[Nagash Arses]")
    |> mes("Recently...")
    |> mes("I've been getting")
    |> mes("a bad feeling...")
    |> next()
    |> mes("[Nagash Arses]")
    |> mes("I want to blame it")
    |> mes("on my solitude, but...")
    |> close()
  end

  defp lost_in_anguish(ctx) do
    ctx
    |> mes(
      "^3355FFNagash Arses. He is no longer a well-known Assassin or the martial arts organization of which he was once master has long since disbanded.^000000"
    )
    |> next()
    |> mes("^3355FFNow he is but a poor old man")
    |> mes(
      "who is in anguish over his disciple. No matter what you say, he continues to talk about something totally unrelated, as if in a dream.^000000"
    )
    |> close()
  end

  defp plead_for_the_lord(ctx) do
    ctx
    |> mes("[Nagash Arses]")
    |> mes("Youngster...")
    |> mes("I beg of you.")
    |> mes("Please do not let him")
    |> mes("bring any harm to the lord.")
    |> next()
    |> mes("[Nagash Arses]")
    |> mes("If you cannot stop him,")
    |> mes("then please interrupt him")
    |> mes("from carrying out his plan.")
    |> next()
    |> mes("[Nagash Arses]")
    |> mes("I tried...")
    |> mes("To convince myself")
    |> mes("that what I had heard")
    |> mes("were just ugly rumors.")
    |> mes("I was wrong...")
    |> next()
    |> mes("[Nagash Arses]")
    |> mes(
      "I am pretty sure he's been asking you, as well as others, for aid. Even if you do not agree to carry out his plan, I'm sure he will find someone to poison Lord Bai Long."
    )
    |> next()
    |> mes("[Nagash Arses]")
    |> mes("There is only one way he can poison")
    |> mes(
      "the lord. He likes drinking, and has a favorite drink bottle he keeps with him all the time. You must get rid of his drink."
    )
    |> next()
    |> mes("[Nagash Arses]")
    |> mes("Please, I beg you.")
    |> mes("For my sake, as well")
    |> mes("as that of my disciple,")
    |> mes("Luoyang's leader must live...")
    |> set_char_var(:ch_poison, 16)
    |> changequest(11_078, 11_079)
    |> close()
  end

  defp hand_over_journal(ctx) do
    ctx
    |> mes("[Nagash Arses]")
    |> mes("So...")
    |> mes("What...")
    |> mes("What happened?")
    |> next()
    |> mes(player_label(ctx))
    |> mes("I made it.")
    |> next()
    |> mes("[Nagash Arses]")
    |> mes("You did?!")
    |> mes("Oh~ thank you,")
    |> mes("thank you so much!")
    |> emotion(:fret)
    |> next()
    |> mes("[Nagash Arses]")
    |> mes("Thank God I've")
    |> mes("lived this long.")
    |> mes("And... I just realized")
    |> mes("something while you away.")
    |> next()
    |> mes("[Nagash Arses]")
    |> mes(
      "This is a journal that I have been writing for 15 years about my feelings of guilt, and what really happened in the past. I hope you can deliver this to the lord for me."
    )
    |> next()
    |> mes("^3355FFYou obtained")
    |> mes("^0000FFPoison King")
    |> mes("Nagash Arses' Journal^000000.")
    |> set_char_var(:ch_poison, 18)
    |> changequest(11_080, 11_081)
    |> close()
  end

  defp remind_journal(ctx) do
    ctx
    |> mes("[Nagash Arses]")
    |> mes("I hope you")
    |> mes("can deliver this")
    |> mes("to Lord Bai Long...")
    |> close()
  end

  defp decline_the_lords_offer(ctx) do
    ctx
    |> mes("^3355FFYou gave him the")
    |> mes("^0000FFLetter from Bai Long^000000.")
    |> next()
    |> mes("[Nagash Arses]")
    |> mes("What's this...?")
    |> next()
    |> mes("[Nagash Arses]")
    |> mes("Why, he's invited me")
    |> mes("to take the position of")
    |> mes("a government official!")
    |> mes("I'm truly grateful!")
    |> next()
    |> mes("[Nagash Arses]")
    |> mes("However, please let him")
    |> mes(
      "know that I must respectfully decline his offer. I'm afraid that I may be a burden to him once again."
    )
    |> next()
    |> mes("[Nagash Arses]")
    |> mes(
      "Please tell him that I wish to enjoy the rest of my life here. Also, there are people here"
    )
    |> mes("who still need me...")
    |> next()
    |> mes("[Nagash Arses]")
    |> mes("Thank you, youngster.")
    |> mes("You've stopped my disciple")
    |> mes("and helped me make up")
    |> mes("with an old friend...")
    |> next()
    |> mes(
      "^3355FFNagash Arses put his palm on your back, and you can feel his strength flowing into you.^000000"
    )
    |> next()
    |> mes(
      "^3355FFYou grow dizzy, but you also feel like you're becoming more powerful and gaining experience.^000000"
    )
    |> next()
    |> set_char_var(:ch_poison, 20)
    |> changequest(11_082, 11_083)
    |> grant_experience()
    |> mes("^3355FFThen...")
    |> mes("Everything blacks out...^000000")
    |> close2()
    |> warp("louyang", 270, 136)
  end

  defp grant_experience(ctx) do
    renewal = Rathena.truthy?(checkre(ctx, 3))
    level = base_level(ctx)

    {renewal_exp, classic_exp} =
      cond do
        level < 56 -> {1_050, 9_000}
        level < 61 -> {1_230, 10_500}
        level < 66 -> {1_570, 18_684}
        level < 71 -> {2_300, 27_411}
        level < 76 -> {3_400, 70_757}
        level < 81 -> {4_500, 130_246}
        level < 86 -> {9_000, 150_340}
        level < 91 -> {18_000, 182_052}
        true -> {20_000, 406_786}
      end

    getexp(ctx, if(renewal, do: renewal_exp, else: classic_exp), 0)
  end

  defp at_peace(ctx) do
    ctx
    |> mes("^3355FFHe looks tired")
    |> mes("for some reason,")
    |> mes("as if he's thinking")
    |> mes("of Morocc, his hometown.^000000")
    |> next()
    |> mes(
      "^3355FFYou reflect on when he gave you his remaining strength and remember that he told you that he used to be one of the greatest Assassins...^000000"
    )
    |> next()
    |> mes("^3355FFBut after all that's happened,")
    |> mes(
      "he just looks like an old man who likes treating other people. It seems that he's finally at peace with himself.^000000"
    )
    |> close()
  end

  defp boast_of_name(ctx) do
    ctx
    |> mes("[Nagash Arses]")
    |> mes("My name, Nagash Arses,")
    |> mes(
      "is also the name of the poison king in the legend of Arcturus. I have good reason to be proud of my name!"
    )
    |> close()
  end

  defp player_label(ctx), do: "[#{char_name(ctx, 0)}]"
end
