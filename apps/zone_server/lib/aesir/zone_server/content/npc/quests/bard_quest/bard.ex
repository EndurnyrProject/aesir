defmodule Aesir.ZoneServer.Content.Npc.Quests.BardQuest.Bard do
  @moduledoc """
  Errende shares stories and songs while seeking the forgotten lyrics of the eighth love.

  ## Behavior

  - Sends adventurers to Gunther, Kino Kitty, and the Juno bookstore to recover the lyrics.
  - Marks the player with the Seal of Friendship and rewards recovered lyrics with a song
    and experience based on level and game mode.
  - Offers news, rumors, and songs, charging 500 zeny for a requested paid performance.

  ## Credits

  - Original from rAthena, by Riotblade and L0ne_W0lf.
  - Changelog contributors: Lupus, SinSloth, and Euphy.

  ## Adaptation

  - Transpiled by `mix aesir.import.npcs` from `quests/bard_quest.txt`.
  - LLM-assisted, behavior-preserving Elixir refactor.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "geffen",
        x: 132,
        y: 38,
        dir: 3,
        sprite: 51,
        name: "Bard",
        scope: :shared,
        unique_name: "Bard#2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      if get_char_var(ctx, :bard_q, 0) > 5 do
        set_char_var(ctx, :gef_bard_q, get_char_var(ctx, :bard_q, 0))
      else
        ctx
      end

    ctx = set_temp_var(ctx, :"name$", char_name(ctx, 0))
    ctx = quest_dialogue(ctx)
    {ctx, _} = ctx |> close() |> cutin("", 255) |> story_or_song([])
    ctx
  end

  defp quest_dialogue(ctx) do
    cond do
      get_char_var(ctx, :gef_bard_q, 0) > 29 ->
        {ctx, _} =
          ctx
          |> cutin("bard_eland02", 2)
          |> mes("[Errende]")
          |> mes("Why, hello there~")
          |> mes("Isn't the weather")
          |> mes("especially pleasant today?")
          |> next()
          |> mes("[Errende]")
          |> mes(
            "Ah~ There are only two things that can make this picturesque moment even more beautiful: story and song. Now then, which would you like to hear?"
          )
          |> story_or_song([1])

        ctx

      get_char_var(ctx, :gef_bard_q, 0) == 14 or get_char_var(ctx, :gef_bard_q, 0) == 15 ->
        reward_song(ctx)

      get_char_var(ctx, :gef_bard_q, 0) > 11 and get_char_var(ctx, :gef_bard_q, 0) < 14 ->
        ctx
        |> cutin("bard_eland02", 2)
        |> mes("[Errende]")
        |> mes(
          "It seems you haven't found it yet. Well, take your time, I can wait as long as you want. It doesn't really bore me, since waiting seems to be a part of my profession."
        )
        |> close()
        |> cutin("", 255)

      get_char_var(ctx, :gef_bard_q, 0) == 11 ->
        ctx
        |> cutin("bard_eland01", 2)
        |> mes("[Errende]")
        |> mes(
          "Mr. Skezti has a small book store on the book street at the right side of Mineta in Juno. If you show him the seal, he'll help you out."
        )
        |> close()
        |> cutin("", 255)

      get_char_var(ctx, :gef_bard_q, 0) == 10 ->
        mark_friendship(ctx)

      get_char_var(ctx, :gef_bard_q, 0) == 20 ->
        introduce_bard_alternate(ctx)

      get_char_var(ctx, :gef_bard_q, 0) == 27 ->
        forgotten_song_alternate(ctx)

      get_char_var(ctx, :gef_bard_q, 0) == 26 ->
        question_lyrics_alternate(ctx)

      get_char_var(ctx, :gef_bard_q, 0) == 25 ->
        refused_lyrics_alternate(ctx)

      get_char_var(ctx, :gef_bard_q, 0) == 24 ->
        museum_directions_alternate(ctx)

      get_char_var(ctx, :gef_bard_q, 0) == 22 ->
        ctx
        |> mes("[Errende]")
        |> mes("*Sigh...*")
        |> mes("Where can")
        |> mes("I find the 8th love...?")
        |> mes("Have you met Gunther?")
        |> mes("Ah, perhaps not yet.")
        |> next()
        |> cutin("bard_eland04", 2)
        |> mes("[Errende]")
        |> mes(
          "*Sigh* I've lost the heart to sing ever since I've forgotten that line to the song. I just... can't. My spirit is unmoved. There's no inspiration."
        )
        |> next()
        |> mes("[Errende]")
        |> mes(
          "Please ask ^483D8BGunther^000000 about the ^483D8B8th love^000000 in ^483D8BAt One, I Fall in Love^000000. Thank you in advance."
        )
        |> close()
        |> cutin("", 255)

      get_char_var(ctx, :gef_bard_q, 0) == 23 ->
        recovered_lyrics_alternate(ctx)

      get_char_var(ctx, :gef_bard_q, 0) == 21 ->
        ctx = ctx |> cutin("bard_eland01", 2) |> mes("[Errende]") |> mes("Welcome back,")

        {ctx, _} =
          ctx
          |> mes("#{get_temp_var(ctx, :"name$", "")}~")
          |> mes("What would you like")
          |> mes("me to do for you?")
          |> mes("Would you like to hear")
          |> mes("a tale or listen to a song?")
          |> story_or_song([3])

        ctx

      get_char_var(ctx, :gef_bard_q, 0) == 7 ->
        forgotten_song(ctx)

      get_char_var(ctx, :gef_bard_q, 0) == 6 ->
        question_lyrics(ctx)

      get_char_var(ctx, :gef_bard_q, 0) == 5 ->
        refused_lyrics(ctx)

      get_char_var(ctx, :gef_bard_q, 0) == 4 ->
        museum_directions(ctx)

      get_char_var(ctx, :gef_bard_q, 0) == 2 ->
        ctx
        |> cutin("bard_eland04", 2)
        |> mes("[Errende]")
        |> mes("*Sigh...* Where can I find the 8th love...? Have you met Gunther?")
        |> mes("Ah, perhaps not yet.")
        |> next()
        |> mes("[Errende]")
        |> mes(
          "*Sigh* I've lost the heart to sing ever since I forgotten that line to the song. I just... can't. My spirit is unmoved. There's no inspiration."
        )
        |> next()
        |> mes("[Errende]")
        |> mes(
          "Please ask ^483D8BGunther^000000 about the ^483D8B8th love^000000 in ^483D8BAt One, I Fall in Love^000000. Thank you in advance."
        )
        |> close()
        |> cutin("", 255)

      get_char_var(ctx, :gef_bard_q, 0) == 3 ->
        recovered_lyrics(ctx)

      get_char_var(ctx, :gef_bard_q, 0) == 1 ->
        ctx = ctx |> cutin("bard_eland01", 2) |> mes("[Errende]") |> mes("Welcome back,")

        {ctx, _} =
          ctx
          |> mes("#{get_temp_var(ctx, :"name$", "")}~")
          |> mes("What would you like")
          |> mes("me to do for you?")
          |> mes("Would you like to hear")
          |> mes("a tale or listen to a song?")
          |> story_or_song([4])

        ctx

      true ->
        introduce_bard(ctx)
    end
  end

  defp reward_song(ctx) do
    ctx =
      if get_char_var(ctx, :gef_bard_q, 0) == 14 do
        ctx
        |> cutin("bard_eland04", 2)
        |> mes("[Errende]")
        |> mes("Hmmm?")
        |> mes(
          "Is that the seal of black...? Huh. Kino Kitty removed the one he gave me without a trace, so I surmise that he likes you a lot. Otherwise..."
        )
        |> next()
        |> mes("^3355FFYou give Errende the letter")
        |> mes("you have received from Kino Kitty.^000000")
        |> next()
        |> cutin("bard_eland01", 2)
        |> mes("[Errende]")
        |> mes(
          "Er, he knows everything already? From this spot of blood, I think he still has health problems. He should stop torturing himself..."
        )
        |> next()
        |> mes("[Errende]")
        |> mes(
          "Thank you, I really appreciate what you've done for me. But, what would be an appropriate way to express my gratitude for an adventurer like yourself?"
        )
      else
        ctx
        |> cutin("bard_eland01", 2)
        |> mes("[Errende]")
        |> mes("Ah, so how did it go?")
        |> mes("Wait, you already found it?")
        |> mes("Yes, this is it! Great!")
        |> mes("This is so amazing!!")
        |> mes("Ah, yes, right.")
        |> mes("Right.")
        |> next()
        |> mes("[Errende]")
        |> mes(
          "I would like to express my gratitute. But, what would be appropriate for an adventurer"
        )
        |> mes("like yourself?")
      end

    ctx =
      ctx
      |> next()
      |> mes("[Errende]")
      |> mes(
        "Oh~! I have just the thing. Alright, please make yourself comfortable, and listen to my song."
      )
      |> next()
      |> cutin("bard_eland03", 2)
      |> mes("^483D8BEvery god never grows old")
      |> mes("Because of beautiful")
      |> mes("Goddess, Idun.")
      |> mes("Keeper of the apples of youth")
      |> mes("Goddess of immortality.^000000")
      |> specialeffect2(:steal)
      |> next()
      |> mes("^483D8BEvery god never grows old.")
      |> mes("Idun, the wife of Bragi,")
      |> mes("Idun, Odin's daughter in law~")
      |> mes("The apples she keeps")
      |> mes("In her basket.^000000")
      |> next()
      |> mes("^483D8BWithout Idun,")
      |> mes("Every god would")
      |> mes("have succumbed to age.")
      |> mes("Even Thor, the strongest of gods,")
      |> mes("would grow frail, Megingjard would")
      |> mes("slip from his waist, and Mjolnir")
      |> mes("would never fly again.^000000")
      |> next()
      |> mes("^483D8BWithout Idun,")
      |> mes("Every god would")
      |> mes("have succumbed to age.")
      |> mes("Loki was careless once,")
      |> mes("and made her lost to the gods.")
      |> mes("He was forced to get her back.^000000")
      |> specialeffect2(:steal)
      |> next()
      |> mes("^483D8BMy goddess stands")
      |> mes("In the field of Asgard")
      |> mes("She hands me fruit from heaven.")
      |> mes("You will be loved by every god...")
      |> mes("You will be blessed")
      |> mes("By every god...^000000")
      |> next()
      |> specialeffect(:beginspell6)
      |> mes("^483D8BIf you share the")
      |> mes("Apple of youth with me")
      |> mes("Even a bite of it with")
      |> mes("This poor poet.")
      |> mes("You will be loved by every god...")
      |> mes("You will be blessed")
      |> mes("By every god...^000000")
      |> next()
      |> specialeffect2(:resurrection)
      |> mes(
        "^3355FFWhile listening to his song, you feel at ease, and your thoughts become clearer. You believe that you see the vision of an angel, and you gain some experience points.^000000"
      )

    ctx = set_char_var(ctx, :gef_bard_q, get_char_var(ctx, :gef_bard_q, 0) + 16)

    ctx =
      cond do
        Rathena.truthy?(checkre(ctx, 3)) ->
          cond do
            base_level(ctx) < 56 -> getexp(ctx, 450, 0)
            base_level(ctx) > 55 and base_level(ctx) < 61 -> getexp(ctx, 550, 0)
            base_level(ctx) > 60 and base_level(ctx) < 66 -> getexp(ctx, 968, 0)
            base_level(ctx) > 65 and base_level(ctx) < 71 -> getexp(ctx, 1341, 0)
            base_level(ctx) > 70 and base_level(ctx) < 76 -> getexp(ctx, 3575, 0)
            base_level(ctx) > 75 and base_level(ctx) < 81 -> getexp(ctx, 6024, 0)
            base_level(ctx) > 80 and base_level(ctx) < 86 -> getexp(ctx, 7034, 0)
            base_level(ctx) > 85 and base_level(ctx) < 91 -> getexp(ctx, 9205, 0)
            true -> getexp(ctx, 15_678, 0)
          end

        base_level(ctx) < 56 ->
          getexp(ctx, 4500, 0)

        base_level(ctx) > 55 and base_level(ctx) < 61 ->
          getexp(ctx, 5500, 0)

        base_level(ctx) > 60 and base_level(ctx) < 66 ->
          getexp(ctx, 9684, 0)

        base_level(ctx) > 65 and base_level(ctx) < 71 ->
          getexp(ctx, 13_411, 0)

        base_level(ctx) > 70 and base_level(ctx) < 76 ->
          getexp(ctx, 35_757, 0)

        base_level(ctx) > 75 and base_level(ctx) < 81 ->
          getexp(ctx, 60_246, 0)

        base_level(ctx) > 80 and base_level(ctx) < 86 ->
          getexp(ctx, 70_340, 0)

        base_level(ctx) > 85 and base_level(ctx) < 91 ->
          getexp(ctx, 92_052, 0)

        true ->
          getexp(ctx, 156_786, 0)
      end

    ctx
    |> next()
    |> cutin("bard_eland02", 2)
    |> mes("[Errende]")
    |> mes(
      "So, how do you feel now? I hope my song has refreshed you. I'm afraid it may not be enough to repay you, but please understand that this is the best way for me to express my gratitude."
    )
    |> next()
    |> mes("[Errende]")
    |> mes(
      "Besides, I've been thinking of you now as my friend, with whom I may candidly speak without any worry. And I think you have a beautiful smile. Am I wrong~? Hahaha~"
    )
    |> next()
    |> mes("[Errende]")
    |> mes(
      "I hope that you'll always remain honest and respectful towards other people, and that you continue to ignore greed for fortune or power."
    )
    |> close()
    |> cutin("", 255)
  end

  defp mark_friendship(ctx) do
    ctx
    |> cutin("bard_eland01", 2)
    |> mes("[Errende]")
    |> mes("So, have you met Mr. Kitty?")
    |> mes("Ah, in Morocc? He has a chronic disease, but obviously doesn't")
    |> mes("seem to care about it.")
    |> mes("So what did he say?")
    |> next()
    |> mes("[Errende]")
    |> mes("Hm? In Juno?")
    |> mes("Then that must be it.")
    |> mes(
      "It won't be easy if you want to go visit Mr. Sketzi's book store. Here, let me mark you with"
    )
    |> mes("^483D8BThe Seal of Friendship^000000.")
    |> next()
    |> cutin("bard_eland03", 2)
    |> mes("[Errende]")
    |> mes("Give me your left hand.")
    |> mes("Now, let me cast a spell...")
    |> mes("*Mumble mumble...*")
    |> next()
    |> specialeffect2(:cone)
    |> mes(
      "^3355FFOn your left wrist, a crescent shaped mark glowing with a silver light appeared. It's only noticeable when you concentrate on finding it, but it might clearly appear under the moonlight.^000000"
    )
    |> next()
    |> mes("[Errende]")
    |> mes("There you go. Now, you may go to Mr. Sketzi. Remember, you must")
    |> mes("show him the Seal of Friendship.")
    |> mes("Good luck, now~")
    |> set_char_var(:gef_bard_q, 11)
    |> close()
    |> cutin("", 255)
  end

  defp introduce_bard_alternate(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("bard_eland03", 2)
      |> mes("[Bard]")
      |> mes("^483D8BWhat day is")
      |> mes("best for drinking?")
      |> mes("La la la~")
      |> mes("It's the day of")
      |> mes("the earth, the sun")
      |> mes("And the moon~")
      |> mes("La la la~^000000")
      |> next()
      |> mes("^483D8BLa la la~")
      |> mes("I'll only")
      |> mes("drink on one day~")
      |> mes("So if you'll tell me")
      |> mes("when you'll drink")
      |> mes("I'll tell you when")
      |> mes("I'll drink with you~^000000")
      |> next()
      |> mes("^483D8BLet's get together")
      |> mes("Yea yea ye-^000000 Hmmmmm...?")
      |> next()
      |> mes("[Bard]")
      |> mes("Why, hello there. Oh, have you come to listen to my song and forget your worries?")
      |> next()
      |> select(["Who are you?", "Ignore him."])

    if choice == 1 do
      ctx = cutin(ctx, "bard_eland04", 2)

      {ctx, _} =
        ctx
        |> mes("[#{get_temp_var(ctx, :"name$", "")}]")
        |> mes("You seem to be")
        |> mes("new around here...")
        |> mes("Who are you?")
        |> next()
        |> cutin("bard_eland02", 2)
        |> mes("[Errende]")
        |> mes(
          "Mm? Ah yes. I am merely another wandering poet who goes where the wind takes him. Please call me ^483D8BErrende^000000, the Bard who wishes to please you."
        )
        |> next()
        |> mes("[Errende]")
        |> mes("If you will let me, I will tell you of my travels. By your leave,")
        |> mes("I will play a song that will help you forget your troubles.")
        |> set_char_var(:gef_bard_q, 21)
        |> story_or_song([2])

      ctx
    else
      ctx
      |> cutin("bard_eland01", 2)
      |> mes("[Errende]")
      |> mes("Waaah, wah~")
      |> mes(
        "You can't just ignore me like that! Where's your sense of merriment, your sense of romance?"
      )
      |> close()
      |> cutin("", 255)
    end
  end

  defp forgotten_song_alternate(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("bard_eland01", 2)
      |> mes("[Errende]")
      |> mes("How could I forget the song?")
      |> mes("I'm worthless as a Bard~!")
      |> mes("Please... Just...")
      |> mes("Please just leave")
      |> mes("me alone.")
      |> next()
      |> select(["No problem~", "Is there any way I can help you?"])

    ctx =
      if choice == 1 do
        ctx
        |> cutin("bard_eland04", 2)
        |> mes("[Errende]")
        |> mes("Waaaah~! You're so mean!")
        |> mes("You're supposed to say, 'Errende, what's wrong? Maybe I can help?'")
        |> next()
        |> mes("[Errende]")
        |> mes("I mean, we're supposed")
        |> mes("to know each other better")
        |> mes("than that. But...")
        |> mes("Maybe I was wrong!")
        |> next()
        |> mes("[Errende]")
        |> mes("*Sob...*")
        |> mes("Who made this poor Bard cry by neglecting him? *Sniff* I do believe it was you!")
      else
        ctx
        |> mes("[Errende]")
        |> mes("Help me?")
        |> mes("Hmmm...")
        |> mes("That's it!")
        |> mes("Gunther!")
        |> next()
        |> mes("[Errende]")
        |> mes("Let me ask you a favor.")
        |> mes(
          "If perchance you happen to meet ^483D8BGunther Doubleharmony^000000, please inform him of my dilemna."
        )
        |> next()
        |> mes("[Errende]")
        |> mes(
          "Tell him that ^483D8BMinty Errende^000000 happened to forget a line of the song, ^483D8BAt One, I Fall in Love^000000. The line is called ^483D8B8th love^000000."
        )
        |> next()
        |> mes("[Errende]")
        |> mes(
          "I beseech you, if you meet him, please ask him of the 8th love and inform me of that lyric immediately~"
        )
        |> set_char_var(:gef_bard_q, 22)
      end

    ctx |> close() |> cutin("", 255)
  end

  defp question_lyrics_alternate(ctx) do
    ctx =
      ctx
      |> cutin("bard_eland01", 2)
      |> mes("[Errende]")
      |> mes("Argh...!")
      |> mes(
        "Who changed the words of this song anyway? It's really difficult to understand. I wish I could ask the person who changed the words."
      )
      |> next()
      |> mes("[Errende]")
      |> mes("This is so frustrating!")
      |> mes("Now, I've lost the passion")
      |> mes("to sing or play...")
      |> next()

    {ctx, choice} =
      ctx
      |> mes("[#{get_temp_var(ctx, :"name$", "")}]")
      |> mes("Don't you think...")
      |> mes("The person would be...")
      |> input(:string)

    ctx = set_local(ctx, :"inputstr$", choice)
    ctx = ctx |> mes("#{get_local(ctx, :"inputstr$", "")}?") |> next()

    cond do
      get_local(ctx, :"inputstr$", "") == "Kino Kitty" ->
        {ctx, choice} =
          ctx
          |> cutin("bard_eland04", 2)
          |> mes("[Errende]")
          |> mes("Ah! Of course!")
          |> mes("I think you're right!")
          |> mes("How could I not think of that?")
          |> next()
          |> mes("[Errende]")
          |> mes(
            "It all makes sense now. After all, he used to be a member of the Invincible Single Army. His changes might have been a little mean, since this song used to be about a happy couple..."
          )
          |> next()
          |> cutin("bard_eland01", 2)
          |> mes("[Errende]")
          |> mes("Ummm...")
          |> mes(
            "I'm sorry to ask a favor of you again, but in your travels, do you think you could find the original lyrics for this song? I can wait for it..."
          )
          |> next()
          |> select(["No, thanks.", "I can, so stop crying."])

        ctx =
          if choice == 1 do
            ctx
            |> mes("[Errende]")
            |> mes(
              "Ah, I guess it was too much to ask of you. My apologies. Don't worry about it, I'll find out some other way."
            )
            |> set_char_var(:gef_bard_q, 25)
          else
            ctx
            |> mes("[Errende]")
            |> mes("Are you serious?")
            |> mes("Oh, thank you so much!")
            |> mes("You must be an angel!")
            |> mes("An angel that truly understands the heart of a poet!")
            |> next()
            |> mes("[Errende]")
            |> mes("I'll pay you back somehow!")
            |> mes("Thank you for your trouble")
            |> mes("in advance~")
            |> set_char_var(:gef_bard_q, 24)
          end

        ctx |> close() |> cutin("", 255)

      get_local(ctx, :"inputstr$", "") == "Gunther" ->
        ctx
        |> mes("[Errende]")
        |> mes(
          "Gunther? I don't think he would do this. He always puts lines in his songs like 'doubleharmony for you.' Plus, he's too silly for that."
        )
        |> close()
        |> cutin("", 255)

      get_local(ctx, :"inputstr$", "") == "Gunther Doubleharmony" ->
        ctx
        |> mes("[Errende]")
        |> mes(
          "Gunther? I don't think he would do this. He always puts lines in his songs like 'doubleharmony for you.' Plus, he's too silly for that."
        )
        |> close()
        |> cutin("", 255)

      get_local(ctx, :"inputstr$", "") == "Errende" ->
        ctx
        |> cutin("bard_eland04", 2)
        |> mes("[Errende]")
        |> mes("Surely you jest!")
        |> mes("If I did, why would")
        |> mes("I not know what")
        |> mes("this song is about?")
        |> close()
        |> cutin("", 255)

      true ->
        ctx = mes(ctx, "[Errende]")

        ctx
        |> mes("#{get_local(ctx, :"inputstr$", "")}...?")
        |> mes("I don't think I know that person. Maybe you misunderstood")
        |> mes("something? *Sigh...*")
        |> next()
        |> mes("[Errende]")
        |> mes("What was the line...?")
        |> mes("How could I forget")
        |> mes("the 8th love?")
        |> set_char_var(:gef_bard_q, 26)
        |> close()
        |> cutin("", 255)
    end
  end

  defp refused_lyrics_alternate(ctx) do
    ctx =
      ctx
      |> cutin("bard_eland04", 2)
      |> mes("[Errende]")
      |> mes("Oh...!")
      |> mes("These tears just won't stop!")
      |> mes("Wh-why must people always treat Bards like this?")
      |> next()
      |> mes("^483D8BWho made")
      |> mes("this poor Bard cry?")
      |> mes("Who broke his")
      |> mes("tender heart of glass?")
      |> mes("Shattering his dreams...^000000")
      |> next()
      |> mes("^483D8BNo dreams,")
      |> mes("No heart,")
      |> mes("No love,")
      |> mes("No hope")
      |> mes("No....^000000")
      |> set_local(:random, Enum.random(1..50))
      |> next()

    if get_local(ctx, :random, 0) > 27 and get_local(ctx, :random, 0) < 37 do
      {ctx, choice} =
        ctx
        |> mes(
          "^3355FFErrende continues to sing about his personal despair. He seems to be disappointed in your refusal to help him. Of course, you begin to feel sorry for him.^000000"
        )
        |> next()
        |> select(["Well, I should help him then...", "Ignore him anyway."])

      ctx =
        if choice == 1 do
          ctx
          |> mes("[#{get_temp_var(ctx, :"name$", "")}]")
          |> mes(
            "Hey. Hey, Errende. Stop singing this song. It's embarassing, okay? Alright, I'll go find the original song for you."
          )
          |> next()
          |> mes("[Errende]")
          |> mes("*Gasp!* Really! Are you sure? Thank you! Thank you so much!")
          |> mes("You really do care about")
          |> mes("the sadness of a Bard!")
          |> next()
          |> mes("[Errende]")
          |> mes(
            "I promise to pay you back as best as I can! I'll wait for you here until you return!"
          )
          |> set_char_var(:gef_bard_q, 24)
        else
          ctx
          |> cutin("bard_eland04", 2)
          |> mes("^3355FFYou ignore his")
          |> mes("heart wrenching song.")
          |> mes("But at what cost to your soul?^000000")
        end

      ctx |> close() |> cutin("", 255)
    else
      ctx
      |> cutin("bard_eland01", 2)
      |> mes("[Errende]")
      |> mes(
        "You don't have anything you want to ask me, do you? If not, would you like to listen to my song...?"
      )
      |> next()
      |> mes("^483D8BMiiiiserable...")
      |> mes("Noboooody looooves meee")
      |> mes("Friends foooooor never...")
      |> mes("Ooooooooh wah!^000000")
      |> close()
      |> cutin("", 255)
    end
  end

  defp museum_directions_alternate(ctx) do
    ctx
    |> cutin("bard_eland02", 2)
    |> mes("[Errende]")
    |> mes("Umm...")
    |> mes(
      "I am not sure exactly where Mr. Kitty is. Maybe you might be able to find out at the Monster Museum in Juno? I think he's a member of the Monster Research Organization."
    )
    |> next()
    |> mes("[Errende]")
    |> mes(
      "If you're experienced in exploration, you'd know the Monster Research Organization. Recently, many scholars have been wounded as a result of researching monsters."
    )
    |> next()
    |> cutin("bard_eland01", 2)
    |> mes("[Errende]")
    |> mes(
      "Because of the dangers of monster research, adventurers are needed to gather the information for the researchers."
    )
    |> next()
    |> mes("[Errende]")
    |> mes(
      "For wanderers like myself, it's a great way to earn money. We give them the information they need, and they give us financial support to live the way we please."
    )
    |> next()
    |> mes("[Errende]")
    |> mes(
      "Anyway, you should visit the Monster Museum in Juno to find out about Mr. Kitty. It's pretty far from here, but when you get to Juno, the Museum is West of the central plaza."
    )
    |> next()
    |> mes("[Errende]")
    |> mes("Once again,")
    |> mes("thank you so much")
    |> mes("for your help.")
    |> close()
    |> cutin("", 255)
  end

  defp recovered_lyrics_alternate(ctx) do
    ctx =
      ctx
      |> cutin("bard_eland02", 2)
      |> mes("[Errende]")
      |> mes("So...")
      |> mes("Have you")
      |> mes("seen Gunther?")
      |> next()
      |> mes("^3355FFYou turn around")
      |> mes("to show him your back.^000000")
      |> next()
      |> mes("[Errende]")
      |> mes("Huh...?!")
      |> mes("Isn't that?!")
      |> mes(
        "Is that the line of the song written on your back? Wait, don't move! The 8th love is..."
      )
      |> mes("Now I see!")
      |> next()
      |> mes("[Errende]")
      |> mes("At One, I fall in love.")
      |> mes("At Two, you give me your smile.")
      |> mes("At Three, I adore your touch.")
      |> mes("At Four, a tender kiss.")
      |> next()
      |> mes("[Errende]")
      |> mes("At Five, we change our minds.")
      |> mes("A petal scatters through the air.")
      |> mes("At Six, I fall in love~")
      |> mes("At Seven, you fall in love~")
      |> next()
      |> mes("[Errende]")
      |> mes("At Eight we turn away...")
      |> mes("At Nine, love is reborn.")
      |> mes("At Ten, my Love is gone.")
      |> mes("At Eleven I find out why.")

    ctx =
      if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
        mes(
          ctx,
          "At Twelve I see his new girlfriend?"
        )
      else
        mes(
          ctx,
          "At Twelve I see her new boyfriend?"
        )
      end

    {ctx, choice} =
      ctx
      |> next()
      |> mes("[Errende]")
      |> mes("...")
      |> next()
      |> mes("[Errende]")
      |> mes("...")
      |> mes("......")
      |> next()
      |> cutin("bard_eland04", 2)
      |> mes("[Errende]")
      |> mes("This...")
      |> mes("This cannot be.")
      |> mes("This song is supposed to be about love, not a romantic travesty!")
      |> next()
      |> mes("[Errende]")
      |> mes(
        "The lyrics. They must have been changed. Did Gunther say anything about this?! Hmmm, but who would change the lyrics...?"
      )
      |> next()
      |> cutin("bard_eland01", 2)
      |> input(:string)

    ctx = set_local(ctx, :"inputstr$", choice)

    cond do
      get_local(ctx, :"inputstr$", "") == "Kino Kitty" ->
        {ctx, choice} =
          ctx
          |> mes("[Errende]")
          |> mes("Ah! Of course!")
          |> mes("I think you're right!")
          |> mes("How could I not think of that?")
          |> next()
          |> mes("[Errende]")
          |> mes(
            "It all makes sense now. After all, he used to be a member of the Invincible Single Army. His changes might have been a little mean, since this song used to be about a happy couple..."
          )
          |> next()
          |> mes("[Errende]")
          |> mes("Ummm...")
          |> mes(
            "I'm sorry to ask a favor of you again, but in your travels, do you think you could find the original lyrics for this song? I can wait for it..."
          )
          |> next()
          |> select(["No, thanks.", "I can, so stop crying."])

        ctx =
          if choice == 1 do
            ctx
            |> mes("[Errende]")
            |> mes(
              "Ah, I guess it was too much to ask of you. My apologies. Don't worry about it, I'll find out some other way."
            )
            |> set_char_var(:gef_bard_q, 25)
          else
            ctx
            |> mes("[Errende]")
            |> mes("Are you serious?")
            |> mes("Oh, thank you so much!")
            |> mes("You must be an angel!")
            |> mes("An angel that truly understands the heart of a poet!")
            |> next()
            |> mes("[Errende]")
            |> mes("I'll pay you back somehow!")
            |> mes("Thank you for your trouble")
            |> mes("in advance~")
            |> set_char_var(:gef_bard_q, 24)
          end

        ctx |> close() |> cutin("", 255)

      get_local(ctx, :"inputstr$", "") == "Gunther" ->
        ctx
        |> mes("[Errende]")
        |> mes(
          "Gunther? I don't think he would do this. He always puts lines in his songs like 'doubleharmony for you.' Plus, he's too silly for that."
        )
        |> set_char_var(:gef_bard_q, 26)
        |> close()
        |> cutin("", 255)

      get_local(ctx, :"inputstr$", "") == "Gunther Doubleharmony" ->
        ctx
        |> mes("[Errende]")
        |> mes(
          "Gunther? I don't think he would do this. He always puts lines in his songs like 'doubleharmony for you.' Plus, he's too silly for that."
        )
        |> set_char_var(:gef_bard_q, 26)
        |> close()
        |> cutin("", 255)

      get_local(ctx, :"inputstr$", "") == "Errende" ->
        ctx
        |> cutin("bard_eland04", 2)
        |> mes("[Errende]")
        |> mes("Surely you jest!")
        |> mes("If I did, why would")
        |> mes("I not know what this")
        |> mes("song is about?")
        |> set_char_var(:gef_bard_q, 26)
        |> close()
        |> cutin("", 255)

      true ->
        ctx = mes(ctx, "[Errende]")

        ctx
        |> mes("#{get_local(ctx, :"inputstr$", "")}...?")
        |> mes("I don't think I know that person. Maybe you misunderstood")
        |> mes("something? *Sigh...*")
        |> next()
        |> mes("[Errende]")
        |> mes("What was the line...?")
        |> mes("How could I forget")
        |> mes("the 8th love?")
        |> set_char_var(:gef_bard_q, 26)
        |> close()
        |> cutin("", 255)
    end
  end

  defp forgotten_song(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("bard_eland04", 2)
      |> mes("[Errende]")
      |> mes("How could I forget the song?")
      |> mes("I'm worthless as a Bard~! Please... Just... Please just leave me alone.")
      |> next()
      |> select(["No problem.", "Is there any way I can help you?"])

    ctx =
      if choice == 1 do
        ctx
        |> mes("[Errende]")
        |> mes("Waaaah~! You're so mean!")
        |> mes("You're supposed to say, 'Errende, what's wrong? Maybe I can help?'")
        |> next()
        |> mes("[Errende]")
        |> mes(
          "I mean, we're supposed to know each other better than that. But, but maybe I was wrong!"
        )
        |> next()
        |> mes("[Errende]")
        |> mes("*Sob...*")
        |> mes("Who made this poor Bard cry by neglecting him? *Sniff* I do believe it was you!")
      else
        ctx
        |> cutin("bard_eland01", 2)
        |> mes("[Errende]")
        |> mes("Help me?")
        |> mes("Hmmmmmmm...")
        |> mes("That's it!")
        |> mes("Gunther!")
        |> next()
        |> mes("[Errende]")
        |> mes(
          "Let me ask you a favor. If perchance you happen to meet ^3355FFGunther Doubleharmony^000000, please inform him of my dilemna."
        )
        |> next()
        |> mes("[Errende]")
        |> mes(
          "Tell him that ^483D8BMinty Errende^000000 happened to forget a line of the song, ^483D8BAt One, I Fall in Love^000000. The line is called ^483D8B8th love^000000."
        )
        |> next()
        |> mes("[Errende]")
        |> mes(
          "I beseech you, if you meet him, please ask him of the 8th love and inform me of that lyric immediately~"
        )
        |> set_char_var(:gef_bard_q, 2)
      end

    ctx |> close() |> cutin("", 255)
  end

  defp question_lyrics(ctx) do
    ctx =
      ctx
      |> cutin("bard_eland04", 2)
      |> mes("[Errende]")
      |> mes(
        "Who could have changed the lyrics to the song? I can't understand why such a thing would happen. I really wish I could ask the person who changed the words..."
      )
      |> next()
      |> mes("[Errende]")
      |> mes(
        "*Sigh* I'm so frustrated I can't even sing. I just... can't. My spirit is unmoved. There's no inspiration."
      )
      |> next()

    {ctx, choice} =
      ctx
      |> mes("[#{get_temp_var(ctx, :"name$", "")}]")
      |> mes("Could it be that")
      |> mes("the person who")
      |> mes("changed the song is...")
      |> input(:string)

    ctx = set_local(ctx, :"inputstr$", choice)
    ctx = ctx |> mes("#{get_local(ctx, :"inputstr$", "")}?") |> next()

    cond do
      get_local(ctx, :"inputstr$", "") == "Kino Kitty" ->
        {ctx, choice} =
          ctx
          |> cutin("bard_eland01", 2)
          |> mes("[Errende]")
          |> mes("Ah! Of course!")
          |> mes("I think you're right!")
          |> mes("How could I not think of that?")
          |> next()
          |> mes("[Errende]")
          |> mes(
            "It all makes sense now. After all, he used to be a member of the Invincible Single Army. His changes might have been a little mean, since this song used to be about a happy couple..."
          )
          |> next()
          |> mes("[Errende]")
          |> mes("Ummm...")
          |> mes(
            "I'm sorry to ask a favor of you again, but in your travels, do you think you could find the original lyrics for this song? I can wait for it..."
          )
          |> next()
          |> select(["No, thanks.", "I can, so stop crying."])

        ctx =
          if choice == 1 do
            ctx
            |> mes("[Errende]")
            |> mes(
              "Ah, I guess it was too much to ask of you. My apologies. Don't worry about it, I'll find out some other way."
            )
            |> set_char_var(:gef_bard_q, 5)
          else
            ctx
            |> mes("[Errende]")
            |> mes(
              "Are you serious? Oh, thank you so much! You must be an angel! An angel that truly understands the heart of a poet!"
            )
            |> next()
            |> mes("[Errende]")
            |> mes("I'll pay you back somehow! Thank you for your trouble in advance~")
            |> set_char_var(:gef_bard_q, 4)
          end

        ctx |> close() |> cutin("", 255)

      get_local(ctx, :"inputstr$", "") == "Gunther" ->
        ctx
        |> mes("[Errende]")
        |> mes(
          "Gunther? I don't think he would do this. He always puts lines in his songs like 'doubleharmony for you.' Plus, he's too silly for that."
        )
        |> close()
        |> cutin("", 255)

      get_local(ctx, :"inputstr$", "") == "Gunther Doubleharmony" ->
        ctx
        |> mes("[Errende]")
        |> mes(
          "Gunther? I don't think he would do this. He always puts lines in his songs like 'doubleharmony for you.' Plus, he's too silly for that."
        )
        |> close()
        |> cutin("", 255)

      get_local(ctx, :"inputstr$", "") == "Errende" ->
        ctx
        |> cutin("bard_eland04", 2)
        |> mes("[Errende]")
        |> mes("Surely you jest! If I did, why would I not know what this song is about?")
        |> close()
        |> cutin("", 255)

      true ->
        ctx =
          mes(
            ctx,
            "[Errende]"
          )

        ctx
        |> mes("#{get_local(ctx, :"inputstr$", "")}...?")
        |> mes("I don't think I know that person. Maybe you misunderstood something? *Sigh...*")
        |> next()
        |> mes("[Errende]")
        |> mes("What was the line...?")
        |> mes("How could I forget")
        |> mes("the 8th love?")
        |> set_char_var(:gef_bard_q, 6)
        |> close()
        |> cutin("", 255)
    end
  end

  defp refused_lyrics(ctx) do
    ctx =
      ctx
      |> cutin("bard_eland04", 2)
      |> mes("[Errende]")
      |> mes("Oh...!")
      |> mes("These tears just won't stop!")
      |> mes("Wh-why must people always treat Bards like this?")
      |> next()
      |> mes("^483D8BWho made this poor Bard cry?")
      |> mes("Who broke his tender heart of glass?")
      |> mes("Shattering his dreams...")
      |> mes("No dreams, no heart, no love, no hope, no...^000000")
      |> next()
      |> set_local(
        :random,
        Enum.random(1..50)
      )

    if get_local(ctx, :random, 0) > 27 and get_local(ctx, :random, 0) < 37 do
      {ctx, choice} =
        ctx
        |> mes(
          "^3355FFErrende continues to sing about his personal despair. He seems to be disappointed in your refusal to help him. Of course, you begin to feel sorry for him.^000000"
        )
        |> next()
        |> select(["Well, I should help him then...", "Ignore him anyway."])

      ctx =
        if choice == 1 do
          ctx
          |> mes("[#{get_temp_var(ctx, :"name$", "")}]")
          |> mes(
            "Hey. Hey, Errende. Stop singing this song. It's embarassing, okay? Alright, I'll go find the original song for you."
          )
          |> next()
          |> cutin("bard_eland01", 2)
          |> mes("[Errende]")
          |> mes(
            "*Gasp!* Really! Are you sure? Thank you! Thank you so much! You really do care about the sadness of a Bard!"
          )
          |> next()
          |> mes("[Errende]")
          |> mes(
            "I promise to pay you back as best as I can! I'll wait for you here until you return!"
          )
          |> set_char_var(:gef_bard_q, 4)
        else
          ctx
          |> mes("^3355FFYou ignore his")
          |> mes("heart wrenching song.")
          |> mes("But at what cost to your soul?^000000")
        end

      ctx |> close() |> cutin("", 255)
    else
      ctx
      |> cutin("bard_eland01", 2)
      |> mes("[Errende]")
      |> mes(
        "You don't have anything you want to ask me, do you? If not, would you like to listen to my song...?"
      )
      |> next()
      |> mes("^483D8BMiiiiserable...")
      |> mes("Noboooody looooves meee")
      |> mes("Friends foooooor never...")
      |> mes("Ooooooooooh wah!^000000")
      |> close()
      |> cutin("", 255)
    end
  end

  defp museum_directions(ctx) do
    ctx
    |> cutin("bard_eland01", 2)
    |> mes("[Errende]")
    |> mes("Umm...")
    |> mes(
      "I am not sure exactly where Mr. Kitty is. Maybe you might be able to find out at the Monster Museum in Juno? I think he's a member of the Monster Research Organization."
    )
    |> next()
    |> mes("[Errende]")
    |> mes(
      "If you're experienced in exploration, you'd know the Monster Research Organization. Recently, many scholars have been wounded as a result of researching monsters."
    )
    |> next()
    |> mes("[Errende]")
    |> mes(
      "Because of the dangers of monster research, adventurers are needed to gather the information for the researchers."
    )
    |> next()
    |> mes("[Errende]")
    |> mes(
      "For wanderers like myself, it's a great way to earn money. We give them the information they need, and they give us financial support to live the way we please."
    )
    |> next()
    |> mes("[Errende]")
    |> mes(
      "Anyway, you should visit the Monster Museum in Juno to find out about Mr. Kitty. It's pretty far from here, but when you get to Juno, the Museum is West of the central plaza."
    )
    |> next()
    |> mes("[Errende]")
    |> mes("Once again,")
    |> mes("thank you so much")
    |> mes("for your help.")
    |> close()
    |> cutin("", 255)
  end

  defp recovered_lyrics(ctx) do
    ctx =
      ctx
      |> cutin("bard_eland02", 2)
      |> mes("[Errende]")
      |> mes("So...")
      |> mes("Have you")
      |> mes("seen Gunther?")
      |> next()
      |> mes("^3355FFYou turn around")
      |> mes("to show him your back.^000000")
      |> next()
      |> cutin("bard_eland03", 2)
      |> mes("[Errende]")
      |> mes("Huh...?!")
      |> mes("Isn't that?!")
      |> mes(
        "Is that the line of the song written on your back? Wait, don't move! The 8th love is..."
      )
      |> mes("Now I see!")
      |> next()
      |> mes("[Errende]")
      |> mes("At One, I fall in love.")
      |> mes("At Two, you give me your smile.")
      |> mes("At Three, I adore your touch.")
      |> mes("At Four, a tender kiss.")
      |> next()
      |> mes("[Errende]")
      |> mes("At Five, we change our minds.")
      |> mes("A petal scatters through the air.")
      |> mes("At Six, I fall in love~")
      |> mes("At Seven, you fall in love~")
      |> next()
      |> mes("[Errende]")
      |> mes("At Eight we turn away...")
      |> mes("At Nine, love is reborn.")
      |> mes("At Ten, my Love is gone.")
      |> mes("At Eleven I find out why.")

    ctx =
      if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
        mes(
          ctx,
          "At Twelve I see her new boyfriend?"
        )
      else
        mes(
          ctx,
          "At Twelve I see his new girlfriend?"
        )
      end

    {ctx, choice} =
      ctx
      |> next()
      |> mes("[Errende]")
      |> mes("...")
      |> next()
      |> mes("[Errende]")
      |> mes("...")
      |> mes("......")
      |> next()
      |> cutin("bard_eland04", 2)
      |> mes("[Errende]")
      |> mes("This...")
      |> mes("This cannot be.")
      |> mes("This song is supposed to be about love, not a romantic travesty!")
      |> next()
      |> mes("[Errende]")
      |> mes(
        "The lyrics. They must have been changed. Did Gunther say anything about this?! Hmmm, but who would change the lyrics...?"
      )
      |> next()
      |> input(:string)

    ctx =
      set_local(
        ctx,
        :"inputstr$",
        choice
      )

    cond do
      get_local(ctx, :"inputstr$", "") == "Kino Kitty" ->
        {ctx, choice} =
          ctx
          |> cutin("bard_eland01", 2)
          |> mes("[Errende]")
          |> mes("Ah! Of course!")
          |> mes("I think you're right!")
          |> mes("How could I not think of that?")
          |> next()
          |> mes("[Errende]")
          |> mes(
            "It all makes sense now. After all, he used to be a member of the Invincible Single Army. His changes might have been a little mean, since this song used to be about a happy couple..."
          )
          |> next()
          |> mes("[Errende]")
          |> mes("Ummm...")
          |> mes(
            "I'm sorry to ask a favor of you again, but in your travels, do you think you could find the original lyrics for this song? I can wait for it..."
          )
          |> next()
          |> select(["No, thanks.", "I can, so stop crying."])

        ctx =
          if choice == 1 do
            ctx
            |> mes("[Errende]")
            |> mes(
              "Ah, I guess it was too much to ask of you. My apologies. Don't worry about it, I'll find out some other way."
            )
            |> set_char_var(:gef_bard_q, 5)
          else
            ctx
            |> mes("[Errende]")
            |> mes(
              "Are you serious? Oh, thank you so much! You must be an angel! An angel that truly understands the heart of a poet!"
            )
            |> next()
            |> mes("[Errende]")
            |> mes("I'll pay you back somehow! Thank you for your trouble in advance~")
            |> set_char_var(:gef_bard_q, 4)
          end

        ctx |> close() |> cutin("", 255)

      get_local(ctx, :"inputstr$", "") == "Gunther" ->
        ctx
        |> mes("[Errende]")
        |> mes(
          "Gunther? I don't think he would do this. He always puts lines in his songs like 'doubleharmony for you.' Plus, he's too silly for that."
        )
        |> set_char_var(:gef_bard_q, 6)
        |> close()
        |> cutin("", 255)

      get_local(ctx, :"inputstr$", "") == "Gunther Doubleharmony" ->
        ctx
        |> mes("[Errende]")
        |> mes(
          "Gunther? I don't think he would do this. He always puts lines in his songs like 'doubleharmony for you.' Plus, he's too silly for that."
        )
        |> set_char_var(:gef_bard_q, 6)
        |> close()
        |> cutin("", 255)

      get_local(ctx, :"inputstr$", "") == "Errende" ->
        ctx
        |> cutin("bard_eland04", 2)
        |> mes("[Errende]")
        |> mes("Surely you jest! If I did, why would I not know what this song is about?")
        |> set_char_var(:gef_bard_q, 6)
        |> close()
        |> cutin("", 255)

      true ->
        ctx =
          mes(
            ctx,
            "[Errende]"
          )

        ctx
        |> mes("#{get_local(ctx, :"inputstr$", "")}...?")
        |> mes("I don't think I know that person. Maybe you misunderstood something? *Sigh...*")
        |> next()
        |> mes("[Errende]")
        |> mes("What was the line...?")
        |> mes("How could I forget")
        |> mes("the 8th love?")
        |> set_char_var(:gef_bard_q, 6)
        |> close()
        |> cutin("", 255)
    end
  end

  defp introduce_bard(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("bard_eland03", 2)
      |> mes("^483D8BWhat day is")
      |> mes("best for drinking?")
      |> mes("La la la~")
      |> mes("It's the day of")
      |> mes("the earth, the sun")
      |> mes("And the moon~")
      |> mes("La la la~^000000")
      |> next()
      |> mes("^483D8BLa la la~")
      |> mes("I'll only")
      |> mes("drink on one day~")
      |> mes("So if you'll tell me")
      |> mes("when you'll drink")
      |> mes("I'll tell you when")
      |> mes("I'll drink with you~^000000")
      |> next()
      |> mes("^483D8BLet's get together")
      |> mes("Yea yea ye-^000000 Hmmmmm...?")
      |> next()
      |> mes("[Bard]")
      |> mes("Why, hello there. Oh, have you come to listen to my song and forget your worries?")
      |> next()
      |> select(["Who are you?", "Ignore him."])

    if choice == 1 do
      ctx = cutin(ctx, "bard_eland04", 2)

      {ctx, _} =
        ctx
        |> mes("[#{get_temp_var(ctx, :"name$", "")}]")
        |> mes("You seem to be")
        |> mes("new around here...")
        |> mes("Who are you?")
        |> next()
        |> cutin("bard_eland02", 2)
        |> mes("[Errende]")
        |> mes(
          "Mm? Ah yes. I am merely another wandering poet who goes where the wind takes him. Please call me ^483D8BErrende^000000, the Bard who wishes to please you."
        )
        |> next()
        |> mes("[Errende]")
        |> mes("If you will let me, I will tell you of my travels. By your leave,")
        |> mes("I will play a song that will help you forget your troubles.")
        |> set_char_var(:gef_bard_q, 1)
        |> story_or_song([5])

      ctx
    else
      ctx
      |> mes("[Errende]")
      |> mes("Waaah, wah~")
      |> mes(
        "You can't just ignore me like that! Where's your sense of merriment, your sense of romance?"
      )
    end
  end

  defp story_or_song(ctx, args) do
    {ctx, choice} =
      ctx |> next() |> select(["Tell me a story.", "Would you play a song?", "Eh, maybe later."])

    ctx =
      case choice do
        1 -> ctx |> tell_story() |> close() |> cutin("", 255) |> song_menu(args) |> farewell()
        2 -> ctx |> song_menu(args) |> farewell()
        3 -> farewell(ctx)
        _ -> ctx
      end

    {ctx, nil}
  end

  defp tell_story(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Errende]")
      |> mes(
        "You like stories, huh? What kind of story would you like me to tell? I'll you whatever I know... Just for you, of course. *Grins*"
      )
      |> next()
      |> select(["News and rumors~", "Cancel."])

    if choice == 1 do
      ctx =
        ctx
        |> cutin("bard_eland01", 2)
        |> mes("[Errende]")
        |> set_local(:random, Enum.random(1..3))

      cond do
        get_local(ctx, :random, 0) == 1 ->
          ctx
          |> mes(
            "Hmmm. Then shall we talk about this town, Geffen? Have you ever been to the Pub or the Inn here?"
          )
          |> next()
          |> mes("[Errende]")
          |> mes(
            "I'd be lying if I didn't say that the sisters that work the Pub and Inn are... ^FF6699sensuously captivating^000000."
          )
          |> next()
          |> mes("[Errende]")
          |> mes(
            "The elder one is gorgeous, graceful and carries with her an air of refinement. And the younger one is so cheerful, energetic and so... ^FF6699nubile^000000."
          )
          |> next()
          |> mes("[Errende]")
          |> mes("But I digress.")
          |> mes("Sometimes though,")
          |> mes("just sometimes mind you,")
          |> mes("they're not as sexy as usual.")
          |> next()
          |> mes("[Errende]")
          |> mes(
            "It seems the spirit of their late father, God bless his soul for siring such hot women, possesses them from time to time."
          )
          |> next()
          |> cutin("bard_eland02", 2)
          |> mes("[Errende]")
          |> mes("I guess when someone acts even")
          |> mes(
            "a little flirtacious towards those girls, their father's spirit takes over. I should know."
          )
          |> next()
          |> mes("[Errende]")
          |> mes(
            "I guess a father's love endures forever, even into the afterlife. Of course, I wouldn't know."
          )
          |> next()
          |> mes("[Errende]")
          |> cutin("bard_eland01", 2)
          |> mes("Let's see...")
          |> mes("Look out for this really shady Merchant that hangs out behind")
          |> mes("the Pub in Geffen.")
          |> next()
          |> mes("[Errende]")
          |> mes(
            "Judging from his clothes, he must be from Morocc, which is a lot warmer. That's why he's got a Hood, even though it has no drawstrings, for the cooler weather over here."
          )
          |> next()
          |> mes("[Errende]")
          |> mes(
            "I must warn you, don't let him talk you into buying that Hood of his since he's selling it for an outrageous price. He's definitely not trustworthy."
          )
          |> next()
          |> mes("[Errende]")
          |> mes(
            "Lastly, I want to mention the lost city of Geffenia, hidden under the Geffen Tower. I hear some kind of condition is required to enter Geffenia, but I'm not sure."
          )
          |> next()
          |> mes("[Errende]")
          |> mes(
            "Geffenia is related to the two attractive ladies I mentioned earlier. It seems their father, William, entered Geffen Tower with a party to exterminate monsters, but he never returned."
          )
          |> next()
          |> mes("[Errende]")
          |> mes(
            "It's tragic that he left his family behind in that way. But perhaps, it is more tragic that his spirit scares away anyone interested in those girls."
          )

        get_local(ctx, :random, 0) == 2 ->
          ctx
          |> mes(
            "Okay, let me tell you a story about Morocc, city of the desert. Adventurers worth their salt are expected to have explored the city and its surrounding desert."
          )
          |> next()
          |> mes("[Errende]")
          |> mes(
            "The Sphinx and the Pyramids are especially popular areas of exploration for adventurers. Have you been there before? I haven't yet, but perhaps someday I'll go."
          )
          |> next()
          |> mes("[Errende]")
          |> mes(
            "While I was in Morocc, I found a Merchant that sells Sword Maces to Priests and Priestess. Aside from those, Priests are prohibited from using any kind of weapon with blades."
          )
          |> next()
          |> mes("[Errende]")
          |> mes(
            "I also saw an energetic little boy who kept begging his father to tame a Munak for him. I heard the father speak a bit, and it seems that one of his friends from Morocc is lost in Alberta."
          )
          |> next()
          |> cutin("bard_eland02", 2)
          |> mes("[Errende]")
          |> mes(
            "In any case, I helped the father with an errand, and he gave me a mysterious box in return. When I opened that box, I found a strange feather. I'm unaware of how it works, though..."
          )
          |> next()
          |> mes("[Errende]")
          |> mes("I wonder if that man's friend, Pandger Mayer, ever found")
          |> mes("his way back home...")

        get_local(ctx, :random, 0) == 3 ->
          ctx
          |> mes(
            "Why don't we talk about Alberta? There is a sunken ship developed by an event agency as a place where adventurers may go on expeditions. It seems they're making a lot of money."
          )
          |> next()
          |> mes("[Errende]")
          |> mes(
            "When the sunken ship first drifted near Alberta, it was immediately found by one of the Alberta Security Knights."
          )
          |> next()
          |> mes("[Errende]")
          |> mes(
            "That Security Knight ventured inside and found an infant deep inside one of the rooms. Next to the baby was a music box."
          )
          |> next()
          |> mes("[Errende]")
          |> mes(
            "This baby was the one and only survivor from the sunken ship. He was brought up in Alberta, although he was treated with contempt when he was a child. He's fine now, but I digress."
          )
          |> next()
          |> mes("[Errende]")
          |> mes(
            "As for the sunken ship, I'm unsure of whether or not it was a pirate ship. It is said that skeleton monsters wearing pirate costumes roam its remains."
          )
          |> next()
          |> mes("[Errende]")
          |> mes(
            "One of Alberta's other mysteries is the elusive Turtle Island. It seems that one seafarer has found a dependable route to that place and is giving passage to adventurers."
          )
          |> next()
          |> mes("[Errende]")
          |> mes(
            "Still, it seems Turtle Island is not quite safe. Two squads of Alberta Security Knights have already traveled there, but have not yet returned. Verily, this is cause for concern."
          )
          |> next()
          |> mes("[Errende]")
          |> mes(
            "Still, that didn't stop me from visiting that place. By sheer accident, I found the journal of an adventurer who had already been there. It seems he's a famous scholar now."
          )
          |> next()
          |> cutin("bard_eland02", 2)
          |> mes("[Errende]")
          |> mes(
            "In that journal are details about an ultimate swordsman, and the exploration of Turtle Island. I'm sure that anyone seeking treasure in that place will find exciting adventure."
          )

        true ->
          ctx
      end
    else
      ctx
      |> cutin("bard_eland01", 2)
      |> mes("[Errende]")
      |> mes(
        "Oh, how disappointing. But promise me that you will drop by later, so that we can share stories and merriment."
      )
    end
  end

  defp song_menu(ctx, args) do
    ctx = ctx |> set_local(:num, Enum.at(args, 0, 0)) |> mes("[Errende]")

    ctx =
      if get_local(ctx, :num, 0) < 3 do
        mes(
          ctx,
          "You recognize my talent, so you deserve to listen to my songs! Now, what would you like to hear? I can play anything you want, you know."
        )
      else
        mes(
          ctx,
          "At last, I've met someone who recognizes my talent! You deserve to listen to my songs! Now, what would you like to hear? I can play anything you want, you know."
        )
      end

    {ctx, choice} =
      ctx
      |> next()
      |> select(["Hmm, any song will do.", "Play an upbeat song~!", "Never mind..."])

    case choice do
      1 ->
        ctx
        |> paid_song()
        |> close()
        |> cutin("", 255)
        |> upbeat_song()
        |> close()
        |> cutin("", 255)
        |> decline_song()

      2 ->
        ctx |> upbeat_song() |> close() |> cutin("", 255) |> decline_song()

      3 ->
        decline_song(ctx)

      _ ->
        ctx
    end
  end

  defp paid_song(ctx) do
    ctx = mes(ctx, "[Errende]")

    if zeny(ctx) > 499 do
      ctx =
        ctx
        |> pay_zeny(500)
        |> cutin("bard_eland03", 2)
        |> mes("Alright.")
        |> mes("Here we go~")
        |> set_local(:random, Enum.random(1..3))

      cond do
        get_local(ctx, :random, 0) == 1 -> soundeffect(ctx, "ring_of_nibelungen.wav", 0)
        get_local(ctx, :random, 0) == 2 -> soundeffect(ctx, "dont_forget_me_not.wav", 0)
        true -> soundeffect(ctx, "in_to_the_abyss.wav", 0)
      end
    else
      ctx
      |> cutin("bard_eland04", 2)
      |> mes("Ahahaha~")
      |> mes("My apologies,")
      |> mes(
        "But I cannot offer my services for free. Even a Bard needs zeny to live, wouldn't you agree?"
      )
    end
  end

  defp upbeat_song(ctx) do
    ctx =
      ctx
      |> cutin("bard_eland03", 2)
      |> mes("[Errende]")
      |> mes("An upbeat song...?")
      |> mes("Hmmm... Let's see.")
      |> mes("An upbeat song,")
      |> mes("An upbeat song...")
      |> mes("Okay, here we go~")
      |> next()

    ctx =
      if get_local(ctx, :num, 0) == 3 or get_local(ctx, :num, 0) == 4 do
        set_local(ctx, :random, Enum.random(1..5))
      else
        set_local(ctx, :random, Enum.random(1..3))
      end

    cond do
      get_local(ctx, :random, 0) == 1 ->
        ctx =
          ctx
          |> mes("^483D8BValhalla dazzles in gold")
          |> mes("The fifth as we know")
          |> mes("Is old Glast Heim!")
          |> mes("Glorious warriors answer")
          |> mes("The summons of Odin.^000000")
          |> next()
          |> mes("^483D8BPalace of the dead")
          |> mes("With a silver roof~")
          |> mes("The third as we know...")
          |> mes("Valaskjalf!")
          |> mes("Glorious warriors answer")
          |> mes("The summons of Odin.^000000")
          |> next()
          |> mes("^483D8BFive hundred forty doors")
          |> mes("In the grand halls of Valhalla")
          |> mes("Fling open to the heart of a hero.")
          |> mes("Eight hundred warriors gather")
          |> mes("Under the will of God, and")
          |> mes("Charge as one out through")
          |> mes("Those doors.^000000")
          |> next()
          |> mes("^483D8BGodly warriors")
          |> mes("Step into Yggdrassil")
          |> mes("Towards their fate.")
          |> mes("With pride and honor,")
          |> mes("They accept Valyrie's")
          |> mes("Welcome.^000000")
          |> next()
          |> mes("^483D8BWarriors fallen in battle")
          |> mes("In glorious clashes of red")
          |> mes("Death may have come,")
          |> mes("But your fame lives on")
          |> mes("and your spirit will be")
          |> mes("led to Valhalla.^000000")

        ctx =
          if get_local(ctx, :num, 0) == 2 do
            ctx
            |> next()
            |> mes("[Errende]")
            |> mes("...")
            |> next()
            |> mes("[Errende]")
            |> mes("...")
            |> mes("......")
            |> next()
            |> mes("[Errende]")
            |> mes(
              "You know this song is about a legend regarding Valhalla don't you? Supposedly, more than one place was used as the sacred Hall of Honor."
            )
            |> next()
            |> mes("[Errende]")
            |> mes(
              "But only the gods will know if this was true or not. Was a place like Glast Heim really the fifth Valhalla? We humans"
            )
            |> mes("may never know")
            |> mes("with certainty.")
          else
            ctx
          end

        ctx |> close() |> cutin("", 255)

      get_local(ctx, :random, 0) == 2 ->
        ctx
        |> mes("^483D8BThe sounds of galloping")
        |> mes("Echo in the distance.")
        |> mes("A cloud of hazy dust")
        |> mes("Fills the setting sun.")
        |> mes("Thousands of eyes open")
        |> mes("Torches on the castle")
        |> mes("Flare like thousands of Ifrits.")
        |> next()
        |> mes("^483D8BHear the throbbing of my heart,")
        |> mes("The blood flowing in my veins.")
        |> mes("Feeling the heaviness of my armor.")
        |> mes("The enemy has appeared before us.^000000")
        |> next()
        |> mes("^483D8BBeat the drums hard, harder!")
        |> mes("Courage, soldiers, march forward!")
        |> mes("Shout loud, soldiers, louder!")
        |> mes("Today will never come back!^000000")
        |> next()
        |> mes("^483D8BStun the sky")
        |> mes("Provoke the earth.")
        |> mes("I feel my heartbeat again.")
        |> mes("Blow the bugle to")
        |> mes("Sway the fortress.")
        |> mes("Today will never come back!^000000")
        |> next()
        |> mes("[Errende]")
        |> mes(
          "Ah, this is called 'Drumming in the Battlefield,' which was written by Mr. Iolo. Yes, I rather like this song."
        )

      true ->
        ctx =
          if get_local(ctx, :num, 0) == 3 or get_local(ctx, :num, 0) == 4 do
            ctx = mes(ctx, "[Errende]")

            ctx =
              if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
                mes(ctx, "Heroic warrior,")
              else
                mes(ctx, "My fair lady,")
              end

            {ctx, choice} =
              ctx
              |> mes(
                "Please listen to my song. If you have a flower in hand and are in love, let's count the flower petals as we go along."
              )
              |> next()
              |> mes("^483D8BAt One, I fall in love.")
              |> mes("At Two, you give me your smile.")
              |> mes("At Three, I adore your touch.")
              |> mes("At Four, a tender kiss.")
              |> mes("At Five, we change our minds.")
              |> mes("A petal scatters through the air.^000000")
              |> next()
              |> cutin("bard_eland04", 2)
              |> mes("^483D8BAt Six, I fall in love~")
              |> mes("At Seven, you fall in love~")
              |> mes("At Eight~^000000")
              |> next()
              |> mes("[Errende]")
              |> mes("At eight~")
              |> mes("At... Eight...")
              |> mes("What was next...?")
              |> next()
              |> mes("[Errende]")
              |> mes("Oh my...!")
              |> mes("What was the next part?!")
              |> mes("What was the 8th love?!")
              |> mes("How shameful for a Bard")
              |> mes("to forget the words")
              |> mes("to a song!")
              |> next()
              |> mes("[Errende]")
              |> mes("I...")
              |> mes("I can't bear the humiliation!")
              |> mes("Or the suspense of what")
              |> mes("happens next...!")
              |> next()
              |> mes("[Errende]")
              |> mes(
                "You're an adventurer, aren't you? So you must travel quite a bit? It's embarassing for me to ask,"
              )
              |> mes("but I have a favor to ask...!")
              |> next()
              |> select(["Sure, no problem.", "I ain't gonna help you."])

            ctx =
              if choice == 1 do
                ctx =
                  ctx
                  |> cutin("bard_eland01", 2)
                  |> mes("[Errende]")
                  |> mes("Thank you, so much!")
                  |> mes("Let's see, who would know?")
                  |> mes("I've got it! Gunther!")
                  |> next()
                  |> mes("[Errende]")
                  |> mes(
                    "If perchance you happen to meet ^483D8BGunther Doubleharmony^000000, please inform him of my dilemna."
                  )
                  |> next()
                  |> mes("[Errende]")
                  |> mes(
                    "Tell him that ^483D8BMinty Errende^000000 happened to forget a line of the song, ^483D8BAt One, I Fall in Love^000000. The line is called ^483D8B8th love^000000."
                  )
                  |> next()
                  |> mes("[Errende]")
                  |> mes(
                    "I beseech you, if you meet him, please ask him of the 8th love and inform me of that lyric immediately~"
                  )

                ctx =
                  if get_char_var(ctx, :gef_bard_q, 0) == 1 do
                    set_char_var(ctx, :gef_bard_q, 2)
                  else
                    ctx
                  end

                if get_char_var(ctx, :gef_bard_q, 0) == 21 do
                  set_char_var(ctx, :gef_bard_q, 22)
                else
                  ctx
                end
              else
                ctx =
                  ctx
                  |> mes("[Errende]")
                  |> mes("*Sigh...*")
                  |> mes(
                    "I can't remember the 8th part of this song if my life depended on it. And it does~! *Wahhhh~*"
                  )

                ctx =
                  if get_char_var(ctx, :gef_bard_q, 0) == 1 do
                    set_char_var(ctx, :gef_bard_q, 7)
                  else
                    ctx
                  end

                if get_char_var(ctx, :gef_bard_q, 0) == 21 do
                  set_char_var(ctx, :gef_bard_q, 27)
                else
                  ctx
                end
              end

            ctx |> close() |> cutin("", 255)
          else
            ctx
          end

        ctx =
          ctx
          |> mes("^483D8BA good Bard sings")
          |> mes("To please his listener.")
          |> mes("So do not expect a sad song")
          |> mes("That deepens your anguish.^000000")
          |> next()
          |> mes("^483D8BA good Dancer dances")
          |> mes("To please her audience.")
          |> mes("Shall we dance together?")
          |> mes("Just hold my hands.")
          |> mes("La la la~ La la la~^000000")
          |> next()

        ctx =
          ctx
          |> mes("[#{get_temp_var(ctx, :"name$", "")}]")
          |> mes("By the way...")
          |> mes("Why do you guys play")
          |> mes("discords sometimes?")
          |> mes("It sounds weird")
          |> mes("when you do that.")
          |> next()
          |> mes("[Errende]")

        mes(
          ctx,
          "H-how can you say such a thing, #{get_temp_var(ctx, :"name$", "")}? Have you ever been a Bard before? It's difficult to come up with fresh, original melodies!"
        )
    end
  end

  defp decline_song(ctx) do
    ctx
    |> cutin("bard_eland01", 2)
    |> mes("[Errende]")
    |> mes("But of course.")
    |> mes("Merriment is best")
    |> mes("enjoyed when you")
    |> mes("are in the mood for it.")
    |> mes("Please come again.")
    |> close()
    |> cutin("", 255)
  end

  defp farewell(ctx) do
    ctx
    |> cutin("bard_eland01", 2)
    |> mes("[Errende]")
    |> mes("Hmm~?")
    |> mes(
      "Well, alright. Though, listening to a good story or cheerful song can really do you some good. Alright then, see you later."
    )
    |> close()
    |> cutin("", 255)
  end
end
