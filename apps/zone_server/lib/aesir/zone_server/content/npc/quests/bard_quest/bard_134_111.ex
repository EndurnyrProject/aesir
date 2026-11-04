defmodule Aesir.ZoneServer.Content.Npc.Quests.BardQuest.Bard134111 do
  @moduledoc """
  Kino Kitty shares songs and stories while helping recover Errende's lost lyrics.

  ## Behavior

  - Introduces himself and directs the player to the original song in Juno.
  - Offers a letter and a friendship seal, then advances the quest accordingly.
  - Shares different stories and songs after either quest ending.

  ## Credits

  - Original from rAthena, by Riotblade and L0ne_W0lf.
  - Changelog contributors: Lupus, SinSloth, and Euphy.

  ## Adaptation

  - Transpiled by `mix aesir.import.npcs` from `quests/bard_quest.txt`.
  - LLM-assisted Elixir refactor.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "morocc",
        x: 134,
        y: 111,
        dir: 3,
        sprite: 741,
        name: "Bard",
        scope: :shared,
        unique_name: "Bard#3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = set_temp_var(ctx, :"name$", char_name(ctx, 0))

    cond do
      get_char_var(ctx, :gef_bard_q, 0) == 31 ->
        perform_after_seal(ctx)

      get_char_var(ctx, :gef_bard_q, 0) == 30 ->
        perform_after_letter(ctx)

      get_char_var(ctx, :gef_bard_q, 0) > 12 and get_char_var(ctx, :gef_bard_q, 0) < 16 ->
        await_errende_visit(ctx)

      get_char_var(ctx, :gef_bard_q, 0) == 12 ->
        offer_original_lyrics(ctx)

      get_char_var(ctx, :gef_bard_q, 0) == 10 ->
        recommend_bookstore(ctx)

      get_char_var(ctx, :gef_bard_q, 0) == 11 ->
        explain_silver_seal(ctx)

      get_char_var(ctx, :gef_bard_q, 0) > 19 and get_char_var(ctx, :gef_bard_q, 0) < 28 ->
        greet_friend(ctx)

      true ->
        private_performance(ctx)
    end
  end

  defp perform_after_seal(ctx) do
    {ctx, choice} =
      offer_performance(ctx, [
        "Tell me a story...",
        "Your voice is...",
        "No thanks, I appreciate it though."
      ])

    case choice do
      1 ->
        ctx = set_local(ctx, :random, Enum.random(1..3))

        cond do
          get_local(ctx, :random, 0) == 1 -> sing_rheingold(ctx)
          get_local(ctx, :random, 0) == 2 -> sing_siegfried(ctx, "Vanquished a mighty dragon\t")
          true -> tell_umbala_story(ctx)
        end

      2 ->
        explain_voice(ctx)

      3 ->
        thank_listener(ctx)

      _ ->
        ctx
    end
  end

  defp perform_after_letter(ctx) do
    {ctx, choice} =
      offer_performance(ctx, [
        "Tell me a story, or sing something~",
        "Your voice is...",
        "No thanks. I appreciate it, though."
      ])

    case choice do
      1 ->
        ctx = set_local(ctx, :random, Enum.random(1..3))

        cond do
          get_local(ctx, :random, 0) == 1 -> sing_siegfried(ctx, "Vanquished a mighty dragon")
          get_local(ctx, :random, 0) == 2 -> sing_remembrance(ctx)
          true -> tell_umbala_story(ctx)
        end

      2 ->
        explain_voice(ctx)

      3 ->
        thank_listener(ctx)

      _ ->
        ctx
    end
  end

  defp await_errende_visit(ctx) do
    ctx
    |> mes("[Kino Kitty]")
    |> mes(
      "Errende must be waiting for you. Although others would be in anguish if they were made to wait, and people like Errende and me wouldn't mind, it's still more polite to hurry when you can."
    )
    |> close()
  end

  defp offer_original_lyrics(ctx) do
    {ctx, hand_choice} =
      ctx
      |> mes("[Kino Kitty]")
      |> mes("I guess you've met Mr. Sketzi.")
      |> mes(
        "By the way, why do you have that look on your face? Didn't find what you were looking for? Haha, would you show me your left hand?"
      )
      |> next()
      |> select(["Here you go.", "Um... No!"])

    if hand_choice == 1 do
      {ctx, seal_choice} =
        ctx
        |> mes("[Kino Kitty]")
        |> mes("Well, while you were gone,")
        |> mes("I remembered the original lyrics to the song. I guess they really are important.")
        |> next()
        |> mes("[Kino Kitty]")
        |> mes(
          "Here, let me give you a letter with the lyrics to Errende. I should also give you my seal so that Errende will know it's me. You don't mind, do you?"
        )
        |> next()
        |> select(["Yes, I mind!", "No, I don't mind."])

      case seal_choice do
        1 ->
          ctx
          |> mes("[Kino Kitty]")
          |> mes("Ah, right.")
          |> mes(
            "You already have a seal marked by Errende. Oh well, if you don't want it, what can I do?"
          )
          |> set_char_var(:gef_bard_q, 13)
          |> close()

        2 ->
          sing_original_lyrics(ctx)

        _ ->
          ctx
      end
    else
      ctx
      |> mes("[Kino Kitty]")
      |> mes("Hmmm...?")
      |> mes("There's no reason to be scared.")
      |> mes("I mean, I won't bite or anything.")
      |> close()
    end
  end

  defp recommend_bookstore(ctx) do
    ctx
    |> mes("[Kino Kitty]")
    |> mes("Didn't you leave already?")
    |> mes("I'm sure you can find the lyrics in a bookstore in Juno.")
    |> next()
    |> mes("[Kino Kitty]")
    |> mes(
      "Well, I'm sure Errende knows more about bookstores, so he can probably tell you where to look in Juno. Why don't you ask Errende?"
    )
    |> next()
    |> mes("[Kino Kitty]")
    |> mes(
      "If you don't mind, please come again and listen to this poor Bard's songs. I'll prepare a song just for you."
    )
    |> next()
    |> mes("[Kino Kitty]")
    |> mes(
      "Don't worry about my health. I'm a Bard at heart, and I can't help but sing for my audience."
    )
    |> next()
    |> mes("[Kino Kitty]")
    |> mes(
      "Also, I'd like to thank you for helping Errende. He may be a little whiny, but he's a good person."
    )
    |> close()
  end

  defp explain_silver_seal(ctx) do
    ctx
    |> mes("[Kino Kitty]")
    |> mes("A silver seal...?")
    |> mes("Well, welcome to the wanderer's club. I must say, the silver crescent suits you.")
    |> next()
    |> mes("[Kino Kitty]")
    |> mes(
      "If you have that seal, Mr. Sketzi will permit you to read his books full of Norse songs."
    )
    |> close()
  end

  defp greet_friend(ctx) do
    ctx =
      ctx
      |> mes("[Kino Kitty]")
      |> mes("What business")
      |> mes("do you have with me,")
      |> mes("my friend?")
      |> next()

    if get_char_var(ctx, :gef_bard_q, 0) == 24 do
      discuss_changed_lyrics(ctx)
    else
      {ctx, entertainment_choice} = select(ctx, ["Tell me a story.", "Sing a song.", "Nothing."])

      case entertainment_choice do
        1 ->
          tell_baldur_story(ctx)

        2 ->
          ctx
          |> mes("[Kino Kitty]")
          |> mes(
            "Sorry, but I don't feel like singing at the moment. I hope you understand. I want to sing the last song of my life for Jorti..."
          )
          |> close()

        3 ->
          ctx
          |> mes("[Kino Kitty]")
          |> mes("You have no")
          |> mes("business with me?")
          |> mes("What a shame.")
          |> close()

        _ ->
          ctx
      end
    end
  end

  defp discuss_changed_lyrics(ctx) do
    ctx =
      ctx
      |> mes(
        "^3355FFYou gave candy to the crying little girl, and relate the problem with the lyrics to Kino Kitty.^000000"
      )
      |> next()
      |> mes("[Kino Kitty]")
      |> mes("Hmm...")
      |> mes(
        "I'm insulted that Errende does not like the words I wrote for 'At One, I Fall in Love.' But, I suppose he is a romantic at heart."
      )
      |> next()

    ctx
    |> mes(
      Rathena.concat(
        Rathena.concat("[", get_temp_var(ctx, :"name$", "")),
        "]"
      )
    )
    |> mes("So...")
    |> mes("Do you know the")
    |> mes("original words")
    |> mes("for the song?")
    |> next()
    |> mes("[Kino Kitty]")
    |> mes(
      "The original lyrics were horrible. There's not enough room in my mind to remember so romantic nonsense. ^333333*Cries*...^000000"
    )
    |> next()
    |> mes("[Kino Kitty]")
    |> mes("Romance is for foolish dreamers!")
    |> mes("I refuse to sing or even remember such vapid lyrics!")
    |> next()
    |> mes("[Jorti]")
    |> mes("U-uncle Kino")
    |> mes("You're scaring me.")
    |> mes("Please don't yell!")
    |> mes("It makes me want")
    |> mes("to cry...")
    |> next()
    |> mes("[Kino Kitty]")
    |> mes("Oh...")
    |> mes("I'm sorry, princess.")
    |> mes("It won't happen again.")
    |> mes("Your Unclde Kino will")
    |> mes("try to be good")
    |> mes("from now on.")
    |> next()
    |> mes("[Kino Kitty]")
    |> mes("*Sigh...*")
    |> mes("Alright, listen.")
    |> next()
    |> mes("[Kino Kitty]")
    |> mes(
      "You'll need an old book of edda lyrics for the original words to the song. All the new books no longer contain the original version."
    )
    |> next()
    |> mes("[Kino Kitty]")
    |> mes("I wonder...")
    |> mes(
      "How did Errende happen to know the original lyrics? In any case, I'm sorry about all this. I suppose I'm a little jaded."
    )
    |> next()
    |> mes("[Kino Kitty]")
    |> mes(
      "You know, maybe you should go to Juno. There's a small book store on the book street, and you can probably find the song in that store."
    )
    |> next()
    |> mes("[Kino Kitty]")
    |> mes("^333333^333333*Cough Cough*^000000^000000")
    |> mes(
      "Wh-why do I have to suffer? Are my final days as a Bard on this earth soon approaching? I feel so pathetic..."
    )
    |> set_char_var(:gef_bard_q, 10)
    |> close()
  end

  defp private_performance(ctx) do
    {ctx, response} =
      ctx
      |> mes("^D43D1AEven in the sandy wind,")
      |> mes("Even in the pouring rain,")
      |> mes("Even in the falling snow,")
      |> mes("I know it's you~^000000")
      |> next()
      |> mes("[Mysterious Bard]")
      |> mes("...")
      |> next()
      |> mes("[Mysterious Bard]")
      |> mes("...")
      |> mes("......")
      |> next()
      |> mes("[Mysterious Bard]")
      |> mes("My apologies,")
      |> mes("^333333*Cough*^000000 but this is")
      |> mes("a private performance")
      |> mes("for my little")
      |> mes("princess.")
      |> next()
      |> select(["Um, was that a love song?", "I'm sorry for interrupting you."])

    if response == 1 do
      react_to_love_song(ctx)
    else
      introduce_self(ctx)
    end
  end

  defp react_to_love_song(ctx) do
    ctx =
      ctx
      |> mes("[Mysterious Bard]")
      |> mes("A...")
      |> mes("Love song?!")
      |> next()
      |> mes("[Mysterious Bard]")
      |> mes(
        "Love songs are for fools who have never known true love, or never had their hearts broken. Happy songs are fine, but I refuse to sing nonsense!"
      )
      |> next()
      |> mes("[Jorti]")
      |> mes("Waaaah~!")
      |> mes("Uncle Kino,")
      |> mes("I'm scared!")
      |> mes("I wanna see")
      |> mes("my mommy...!")
      |> mes("*Cries*")
      |> next()
      |> mes("[Mysterious Bard]")
      |> mes("There, there,")
      |> mes("princess. Don't cry.")
      |> mes("Everything's okay.")
      |> next()
      |> mes("[Mysterious Bard]")

    ctx = reassure_jorti(ctx)
    ctx = next(ctx)

    ctx
    |> mes(
      Rathena.concat(
        Rathena.concat("[", get_temp_var(ctx, :"name$", "")),
        "]"
      )
    )
    |> mes("Um...")
    |> mes("^333333(Wasn't the little girl")
    |> mes("scared by your outburst...?)^000000")
    |> close()
  end

  defp reassure_jorti(ctx) do
    cond do
      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:swordman) ->
        mes(
          ctx,
          "There's no reason to be scared. The scary people with swords only use them on monsters, okay?"
        )

      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:acolyte) ->
        mes(
          ctx,
          "You don't need to be scared, that person is a servant of God, okay?"
        )

      Rathena.job_id(class(ctx)) == Rathena.job_id(:thief) or
          Rathena.job_id(class(ctx)) == Rathena.job_id(:rogue) ->
        mes(
          ctx,
          "There's no reason to be afraid of this riffraff, your Uncle Kino is here, okay?"
        )

      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:assassin) ->
        mes(
          ctx,
          "There's no reason to be afraid. I know that person looks scary, but you're a good girl, so you'll be okay."
        )

      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:blacksmith) ->
        mes(
          ctx,
          "There's no reason to be scared, honey. It's just a Blacksmith."
        )

      true ->
        mes(
          ctx,
          "There's no reason to be scared. See...? That person won't hurt you."
        )
    end
  end

  defp introduce_self(ctx) do
    cond do
      get_char_var(ctx, :gef_bard_q, 0) == 2 ->
        introduce_to_errendes_friend(ctx, 22)

      get_char_var(ctx, :gef_bard_q, 0) == 3 ->
        introduce_to_errendes_friend(ctx, 23)

      get_char_var(ctx, :gef_bard_q, 0) == 4 ->
        seek_original_lyrics(ctx)

      sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) ->
        ctx
        |> mes("[Kino Kitty]")
        |> mes(
          "You're such a nice young man. I will remember your name. I would much appreciate it if you would also remember mine."
        )
        |> next()
        |> mes("[Mysterious Bard]")
        |> mes(
          "I am known as Kino Kitty. I am a wandering poet who wishes to rediscover wishes and dreams."
        )
        |> next()
        |> mes("[Kino Kitty]")
        |> mes(
          "When next we meet, I will tell you what I have heard and experienced. That is, I am willing to spend my time with you."
        )
        |> set_char_var(:gef_bard_q, 20)
        |> close()

      true ->
        ctx
        |> mes("[Mysterious Bard]")
        |> mes(
          "Ah, it is a privilege to meet a noble woman such as yourself. By your leave, I shall give you my name."
        )
        |> next()
        |> mes("[Mysterious Bard]")
        |> mes(
          "My lady, fair as wisteria, whose beauty rivals that of the goddess Freya, let me introduce myself as the poor poet who wanders the earth, Kino Kitty. I hope you remember me."
        )
        |> set_char_var(:gef_bard_q, 20)
        |> close()
    end
  end

  defp introduce_to_errendes_friend(ctx, progress) do
    ctx
    |> mes("[Mysterious Bard]")
    |> mes(
      "You're such a kind, young person. I will remember your name. I would much appreciate it if you would also remember mine."
    )
    |> next()
    |> mes("[Mysterious Bard]")
    |> mes(
      "I am known as Kino Kitty. I am a wandering poet who wishes to rediscover wishes and dreams."
    )
    |> next()
    |> mes("[Kino Kitty]")
    |> mes(
      "When next we meet, I will tell you what I have heard and experienced. That is, I am willing to spend my time with you."
    )
    |> set_char_var(:gef_bard_q, progress)
    |> close()
  end

  defp seek_original_lyrics(ctx) do
    {ctx, search_choice} =
      ctx
      |> mes("[Mysterious Bard]")
      |> mes("Oh, you're most admirable. You truly do respect Bards, don't you?")
      |> next()
      |> mes("[Mysterious Bard]")
      |> mes(
        "Now that I think about it, are you look for anything, or is there a reason you wish to speak to me?"
      )
      |> next()
      |> select(["I'm looking for Kino Kitty...", "Nothing, really."])

    if search_choice == 1 do
      ctx =
        ctx
        |> mes("[Kino Kitty]")
        |> mes("How do you")
        |> mes("know my name?")
        |> mes("Ah, I'm flattered")
        |> mes("that my reputation")
        |> mes("precedes me.")
        |> next()
        |> mes(
          "^3355FFYou give some candy to the crying girl and relate your tale regarding the lyrics for the song 'At One, I Fall in Love.'^000000"
        )
        |> next()
        |> mes("[Kino Kitty]")
        |> mes("Hmm...")
        |> mes(
          "I'm insulted that Errende does not like the words I wrote for 'At One, I Fall in Love.' But, I suppose he is a romantic at heart."
        )
        |> next()

      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat(
            "[",
            get_temp_var(ctx, :"name$", "")
          ),
          "]"
        )
      )
      |> mes("So...")
      |> mes("Do you know the")
      |> mes("original words")
      |> mes("for the song?")
      |> next()
      |> mes("[Kino Kitty]")
      |> mes(
        "The original lyrics were horrible. There's not enough room in my mind to remember so romantic nonsense. ^333333*Cries*...^000000"
      )
      |> next()
      |> mes("[Kino Kitty]")
      |> mes(
        "Romance is for foolish dreamers! I refuse to sing or even remember such vapid lyrics!"
      )
      |> next()
      |> mes("[Jorti]")
      |> mes("U-uncle Kino")
      |> mes("You're scaring me.")
      |> mes("Please don't yell!")
      |> mes("It makes me want")
      |> mes("to cry...")
      |> next()
      |> mes("[Kino Kitty]")
      |> mes("Oh...")
      |> mes(
        "I'm sorry, princess. It won't happen again. Your Unclde Kino will try to be good from now on."
      )
      |> next()
      |> mes("[Kino Kitty]")
      |> mes("*Sigh...*")
      |> mes("Alright, listen.")
      |> next()
      |> mes("[Kino Kitty]")
      |> mes(
        "You'll need an old book of edda lyrics for the original words to the song. All the new books no longer contain the original version."
      )
      |> next()
      |> mes("[Kino Kitty]")
      |> mes("I wonder...")
      |> mes(
        "How did Errende happen to know the original lyrics? In any case, I'm sorry about all this. I supposed I'm a little jaded."
      )
      |> next()
      |> mes("[Kino Kitty]")
      |> mes(
        "You know, maybe you should go to Juno. There's a small book store on the book street, and you can probably find the song in that store."
      )
      |> next()
      |> mes("[Kino Kitty]")
      |> mes("^333333^333333*Cough Cough*^000000^000000")
      |> mes(
        "Wh-why do I have to suffer? Are my final days as a Bard on this earth soon approaching? I feel so pathetic..."
      )
      |> set_char_var(:gef_bard_q, 10)
      |> close()
    else
      ctx
      |> mes("[Mysterious Bard]")
      |> mes("Really now?")
      |> mes("That's strange.")
      |> mes(
        "You adventurers are always one some kind of adventure, aren't you? I mean, that's the very definition of the word."
      )
      |> close()
    end
  end

  defp explain_voice(ctx) do
    ctx
    |> mes("[Kino Kitty]")
    |> mes(
      "Oh... Well, I have a chronic disease so I can't speak out loud. I, um, even cough up a little blood. But aside from that, I'm perfectly healthy."
    )
    |> next()
    |> mes(
      "^3355FFA look of bitterness momentarily flashed across Kino Kitty's face. He then adjusted his guitar strings and began to play, humming a low tune.^000000"
    )
    |> soundeffect("humming.wav", 0)
    |> close()
  end

  defp offer_performance(ctx, options) do
    ctx
    |> mes("[Kino Kitty]")
    |> mes("Everything will be")
    |> mes("fine in the end, right?")
    |> mes("I'll be okay, Jorti will be okay, and she'll be... Oh.")
    |> next()
    |> mes("[Kino Kitty]")
    |> mes("I'm sorry, I was just")
    |> mes("muttering to myself.")
    |> mes("Is there anything")
    |> mes("you want from me?")
    |> next()
    |> select(options)
  end

  defp sing_original_lyrics(ctx) do
    ctx
    |> mes("[Kino Kitty]")
    |> mes("Now, let's see...")
    |> mes("How is it supposed to go?")
    |> mes("...Lu lu lu...")
    |> mes("...La la la...")
    |> next()
    |> mes("^D43D1AAt One, I fall in love.")
    |> mes("At Two, you give me your smile.")
    |> mes("At Three, I adore your touch.")
    |> mes("At Four, a tender kiss.")
    |> mes("At Five, we change our minds.")
    |> mes("A petal scatters through the air.^000000")
    |> next()
    |> mes("^D43D1AAt Six, I fall in love~")
    |> mes("At Seven, you fall in love~")
    |> mes("At Eight, we're both in love.")
    |> mes("At Nine, you know my heart.")
    |> mes("At Ten, I know you've")
    |> mes("been waiting for me.^000000")
    |> next()
    |> mes("^D43D1AAt Eleven, a precious")
    |> mes("Whisper: 'Will you marry me?'")
    |> mes("At Twelve, our two hearts")
    |> mes("Are one. 12 petals, our")
    |> mes("Love finally blossoms.^000000")
    |> next()
    |> specialeffect2(:poisonreact2)
    |> mes(
      "^3355FFAfter the song, Kino smiles at you. You feel a sharp pain on your wrist. On the spot where the silver crescent was, you see a tiny black cross.^000000"
    )
    |> next()
    |> mes("[Kino Kitty]")
    |> mes(
      "So, how do you like it? Well, I'm certain that Errende will love it for sure. Hahahahaha~ ^333333*Cough Cough*^000000"
    )
    |> next()
    |> mes("[Kino Kitty]")
    |> mes("I want to apologize.")
    |> mes(
      "I didn't mean to make you wait, but I just remembered the old lyrics to the song. Now, hurry to Errende, I'm sure he's waiting."
    )
    |> next()
    |> mes("^3355FFKino Kitty hands you a letter that is labeled 'Dear Errende'")
    |> mes("on the front.^000000")
    |> set_char_var(:gef_bard_q, 14)
    |> close()
  end

  defp sing_remembrance(ctx) do
    ctx
    |> mes("[Kino Kitty]")
    |> mes("Ah...")
    |> mes(
      "I do feel like singing a song. You know, every song has its own story. ^333333*Cough Cough*^000000"
    )
    |> next()
    |> mes(
      "^3355FFKino Kitty coughed a few times, wiping his mouth with his sleeve. As he adjusts the guitar strings, you notice small stains of blood on his sleeve. Then, he began to sing.^000000"
    )
    |> next()
    |> mes("^D43D1AI still remember feeling")
    |> mes("Your shoulder's warmth")
    |> mes("As I leaned on it.")
    |> mes("You held my hands")
    |> mes("until the final moment.^000000")
    |> next()
    |> mes("^D43D1ACrying on the inside,")
    |> mes("I saw you off with a smile.")
    |> mes("Things would never be the same,")
    |> mes("But I'd remember every single")
    |> mes("Moment we shared.^000000")
    |> next()
    |> mes("^D43D1AI still remember the clear chimes")
    |> mes("Of the Prontera Church Bells")
    |> mes("The ice cream we shared in Morocc,")
    |> mes("Being chased by bats")
    |> mes("In Payon dungeon.^000000")
    |> next()
    |> mes("^D43D1AGazing together at")
    |> mes("Comodo's fireworks")
    |> mes("Snuggles under the")
    |> mes("Gently falling Lutie")
    |> mes("Snowflakes...^000000")
    |> next()
    |> mes("^D43D1AYour beautiful soul")
    |> mes("Will be with Odin.")
    |> mes("When the day")
    |> mes("Of the dusk comes,")
    |> mes("A brand new place")
    |> mes("Will be before your eyes.^000000")
    |> next()
    |> mes("^D43D1AI will remember you forever.")
    |> mes("Forget me not, call my name.")
    |> mes("I'll hear you, and look to the skies.^000000")
    |> next()
    |> mes("[Jorti]")
    |> mes(
      "Ah, Uncle Kino, isn't this the song my mom always sang? Sing more songs, please! Please~!"
    )
    |> next()
    |> mes("[Kino Kitty]")
    |> mes("You're right...")
    |> mes(
      "She always used to sing this song... ^333333*Cough*^000000 There are always people waiting for their beloved to return..."
    )
    |> next()
    |> mes("[Kino Kitty]")
    |> mes(
      "If you have someone who you've left behind, someone that is waiting for you, make sure you come back to that person. You'll regret it if you don't."
    )
    |> close()
  end

  defp sing_rheingold(ctx) do
    ctx
    |> mes("[Kino Kitty]")
    |> mes(
      "Many legends have been passed down as songs. Stories of Gods and tales of brave warriors have all been written as songs."
    )
    |> next()
    |> mes("[Kino Kitty]")
    |> mes(
      "Many people love to listen to those songs because they dream of the romantic past. To sing these kinds of songs is the reason people like me exist."
    )
    |> next()
    |> mes(
      "^3355FFKino Kitty adjusted the strings on his guitar, and began to sing in a low voice.^000000"
    )
    |> next()
    |> mes("^D43D1ARheingold...")
    |> mes("Hidden in the Rhein river.")
    |> mes("If made into a ring,")
    |> mes("Could rule the world~^000000")
    |> next()
    |> mes("^D43D1AProtected by a spell")
    |> mes("Cursing its thief")
    |> mes("To never find love.")
    |> mes("Alberich had known")
    |> mes("Nonetheless stole it.")
    |> mes("Love was forsaken for power.^000000")
    |> next()
    |> mes("^D43D1AGiants built beautiful Valhalla")
    |> mes("Matrimony with Freya")
    |> mes("Goddess of beauty")
    |> mes("Their supposed payment.")
    |> mes("In not receiving it")
    |> mes("They forcefully took her.^000000")
    |> next()
    |> mes("^D43D1AThe gods would")
    |> mes("give Alberich's treasure")
    |> mes("To the Giants for Freya's return.")
    |> mes("Loki tricked Alberich,")
    |> mes("Stealing his ring or power.^000000")
    |> next()
    |> mes("^D43D1ABut Alberich cursed his ring")
    |> mes("Before it was returned to him,")
    |> mes("Envy and death would")
    |> mes("befall its wearers.^000000")
    |> next()
    |> mes("^D43D1AThe ring was given to the giants")
    |> mes("Freya was returned to the gods")
    |> mes("The giants killed themselves")
    |> mes("Fighting over the rheingold,")
    |> mes("Victims of")
    |> mes("Alberich's curse~^000000")
    |> next()
    |> mes("[Kino Kitty]")
    |> mes("Hmm...")
    |> mes("^333333*Cough Cough*^000000")
    |> mes("This old song")
    |> mes("is about the ring")
    |> mes("of the Nibelungs.")
    |> next()
    |> mes("[Kino Kitty]")
    |> mes("^333333*Cough Cough*^000000")
    |> mes(
      "Hah... I can't sing more than one song nowadays. But did you like it? ^333333*Cough Cough*^000000"
    )
    |> close()
  end

  defp sing_siegfried(ctx, dragon_verse) do
    ctx
    |> mes("[Kino Kitty]")
    |> mes("Ah...")
    |> mes(
      "I do feel like singing a song. You know, every song has its own story. ^333333*Cough Cough*^000000"
    )
    |> next()
    |> mes(
      "^3355FFKino Kitty coughed a few times, wiping his mouth with his sleeve. As he adjusts the guitar strings, you notice small stains of blood on his sleeve. Then, he began to sing.^000000"
    )
    |> next()
    |> mes("^D43D1ABrave hero Siegfried ")
    |> mes(dragon_verse)
    |> mes("Its blood coated his skin")
    |> mes("Making it impenetrable")
    |> mes("Save for one tender spot")
    |> mes("Blocked by a single leaf")
    |> mes("From a linden tree.^000000")
    |> next()
    |> mes("^D43D1ASiegfried was powerful")
    |> mes("Clearly invincible, save for")
    |> mes("those who knew of his secret.")
    |> mes("In the end he was killed, by")
    |> mes("A spear flung into his back")
    |> mes("set into motion by the wrath")
    |> mes("And jealousy of a woman.^000000")
    |> next()
    |> mes("[Jorti]")
    |> mes("Bravo, Bravo~!")
    |> mes("Uncle Kino is the best Bard in the world~! Jorti likes Uncle Kino's singing!")
    |> next()
    |> mes("[Kino Kitty]")
    |> mes("Thank you, Jorti.")
    |> mes("Anytime for my")
    |> mes("little princess.")
    |> next()
    |> mes("[Kino Kitty]")
    |> mes(
      "This song is about Sigfried, who was invincible, except for a single spot on his back. Just singing this reminds me of the influence women have over the world."
    )
    |> close()
  end

  defp tell_baldur_story(ctx) do
    ctx
    |> mes("[Kino Kitty]")
    |> mes("A story? Mmmm...")
    |> mes("My throat hurts,")
    |> mes("but if you listen,")
    |> mes("I will do my best")
    |> mes("to relate a tale.")
    |> next()
    |> mes("[Kino Kitty]")
    |> mes(
      "Do you know how Baldur, son of Odin, died? There is a story involving his obsessive mother"
    )
    |> mes("and the wicked god, Loki.")
    |> next()
    |> mes("[Kino Kitty]")
    |> mes(
      "One night, Baldur had a nightmare where he was cast into the pit of Hell. Upon hearing of this, Baldur's mother Frigg was stricken with panic."
    )
    |> next()
    |> mes("[Kino Kitty]")
    |> mes(
      "To prevent tragedy from befalling her son, she made every single object on earth to agree to an oath where they would not harm Baldur."
    )
    |> next()
    |> mes("[Kino Kitty]")
    |> mes(
      "^333333*Cough Cough*^000000 And they all got together to ^333333*Wheeeeze*^000000 celebr--^333333^333333*Cough*^000000^000000..."
    )
    |> next()
    |> mes("[Jorti]")
    |> mes("Uncle Kino...?")
    |> mes("Are you okay?....?")
    |> next()
    |> mes("[Kino Kitty]")
    |> mes("...Hah...")
    |> mes("...Hah...")
    |> mes("I'm sorry, but I don't think I can speak for much longer.")
    |> close()
  end

  defp tell_umbala_story(ctx) do
    ctx
    |> mes("[Kino Kitty]")
    |> mes("You want to")
    |> mes("listen to a story?")
    |> mes("Mmm, let me think...")
    |> next()
    |> mes("[Kino Kitty]")
    |> mes(
      "When you go venture Southwest from Morocc, you will arrive at Fortress Sandarman. Did you know that the fortress is built on a sand hill, which serves as a natural defense?"
    )
    |> next()
    |> mes("[Kino Kitty]")
    |> mes(
      "When you go South of Sandarman, you will see Paros Lighthouse. East from the Lighthouse, you will see Kokomo Beach. North of the beach is Papuchica Forest."
    )
    |> next()
    |> mes("[Kino Kitty]")
    |> mes(
      "I'm not boring you, am I? I just wanted to tell you about the village of Umbala, which is above that last place I was telling you about. Have you ever been there?"
    )
    |> next()
    |> mes("[Kino Kitty]")
    |> mes(
      "Umbala itself is a pretty interesting place. But I'm really interested in this giant tree in Umbala. I've heard that it leads to Niffheim..."
    )
    |> next()
    |> mes("[Kino Kitty]")
    |> mes("I wonder...")
    |> mes(
      "Could that tree be Yggdrasil? Is it possible that I could meet her in the Niffheim, realm of the dead?"
    )
    |> close()
  end

  defp thank_listener(ctx) do
    ctx
    |> mes("[Kino Kitty]")
    |> mes("Hmm...?")
    |> mes(
      "I wish everyone in the world were as kind and honest as you. If that were the case, there'd be no selfish fights. Hahahahaha~"
    )
    |> close()
  end
end
