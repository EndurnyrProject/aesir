defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.ArunafeltzLinguist do
  @moduledoc """
  Linguist Dictionary, who drives the Otherworld Language quest in the Midgard Expedition Camp.

  ## Behavior

  - Before the quest starts, lectures on language and turns the player away.
  - On introduction, asks the player to memorize what the fairy and wooden giant races say
    (completes quest 8243, starts 8244).
  - Has the player type back three fairy and three wooden giant sentences; a single wrong
    sentence sends the player back out, all six correct advance the quest.
  - Once stumped by the samples, sends the player to the Rune-Midgarts Magician
    (completes 8244, starts 8245).
  - After the language gem is decoded, sends the player to the Schwarzwald Mechanic Engineer
    (completes 8247, starts 8248).
  - Otherwise repeats the current errand or congratulates the player on the finished translator.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Gepard
    - Masao
    - Euphy
    - Joseph
    - Jeybla
    - Mazvi

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mid_campin",
        x: 168,
        y: 82,
        dir: 3,
        sprite: 935,
        name: "Arunafeltz Linguist",
        scope: :shared,
        unique_name: "Arunafeltz Linguist#1"
      }
    ]

  @speaker "[Linguist Dictionary]"

  @fairy_sentences [
    {["RLGHLRXLA TKANTLFDMS"], "And?", "Mmm... Hmm...?"},
    {["WJACK TNAHRDNJSDMFH"], "And?", "I see...?"},
    {["WLSGHKWND !!", "WLSGHKWND"], "Is that all?", "Is that all?"}
  ]

  @giant_sentences [
    {["TJDTMFJDNS CJFDI"], "And?", "And?"},
    {["TKADLFDMF QKATOS"], "And?", "And?"},
    {["EKDTLSDML DLFMADMS..", "EKDTLSDML DLFMADMS"], "This is it?", "Is that all?"}
  ]

  @impl true
  def on_talk(ctx) do
    rhea = get_char_var(ctx, :ep13_2_rhea, 0)

    cond do
      rhea < 1 -> turn_away(ctx)
      rhea == 1 -> introduce(ctx)
      rhea == 2 -> review_samples(ctx)
      rhea == 3 -> admit_defeat(ctx)
      rhea < 6 -> remind_magician(ctx)
      rhea == 6 -> report_decoding(ctx)
      rhea < 13 -> remind_engineer(ctx)
      true -> praise_translator(ctx)
    end
  end

  defp turn_away(ctx) do
    ctx
    |> lecture(
      "Language distinguishes humans from animals. Every single intellectual life form has their own language."
    )
    |> say(
      "This is a restricted place under control of our Commander. No one could enter here without proper approval... Are you acquainted with our Commander?"
    )
    |> close()
  end

  defp introduce(ctx) do
    {ctx, choice} =
      ctx
      |> lecture(
        "Language is a distinctive feature of human race compared to animals. Every single intellectual life form has their own language."
      )
      |> select(["I am Me!", "I don't have a name to tell you!"])

    case choice do
      1 ->
        ask_purpose(ctx)

      2 ->
        ctx
        |> say(["What the heck?", "If you are so bored, why don't you go fishing?"])
        |> close()

      _ ->
        ctx
    end
  end

  defp ask_purpose(ctx) do
    {ctx, choice} =
      ctx
      |> say(
        "Ah~ I've heard from our Commander about you. You've done much for the Midgard Alliance Camp. Anyways, what brings you here?"
      )
      |> next()
      |> select(["I thought I had confused you a bit...", "What were you doing?"])

    case choice do
      1 ->
        ctx
        |> say(
          "Confusion is a feeling that comes from distraction of one's mind when something that couldn't be predicted happens. I'm not a person who easily gets confused."
        )
        |> next()
        |> request_samples()

      2 ->
        request_samples(ctx)

      _ ->
        ctx
    end
  end

  defp request_samples(ctx) do
    ctx =
      ctx
      |> say([
        "I'm a linguist from Arunafeltz. I'm a scholor who studies a system and a structure of every kinds of language in the world.",
        "And...don't you think the reason man like me is here is that there's a predictable cause?"
      ])
      |> next()
      |> say([
        "From what I heard, you've done much for the Midgard Alliance Research Group.",
        "And while you were helping us, I believe you've seen and visited many places here in the other world."
      ])
      |> next()
      |> say("Have you met the other world's people by any chance?")
      |> next()

    fairy_quest = checkquest(ctx, 2158)
    giant_quest = checkquest(ctx, 2159)

    reaction =
      if fairy_quest == 0 and giant_quest == 0,
        do: "Looks like you haven't encountered them yet.",
        else: "From the look on your face, I think you have something crossed in your mind."

    ctx
    |> say(reaction)
    |> next()
    |> say(
      "Rumor here says that there's a fairy-looking and a giant wood people living out in the fields next to our camp here."
    )
    |> next()
    |> say(
      "Apparently these people are speaking in a strange languages that we humans can't understand...but no one seems to be able to remember how their languages sound like."
    )
    |> next()
    |> say(
      "A NEW language!! This is an exciting discovery for a linguist like myself, but as you know, there's dangerous monsters outside... It's not possible for a mere scholor to go out wandering around."
    )
    |> next()
    |> say("I've said this much, I think you'd be able to guess what I'm going to ask you to do.")
    |> next()
    |> say(
      "The Alliance Research Group has great interest in other intelligent life. Each country's secret agents are making every effort to communicate with those two races, there's just not enough information."
    )
    |> next()
    |> say(
      "Do me a favor and go outside of the camp, find the fairies and wooden giants, and remember everything that they are saying, word for word so that I can hear what their language sounds like."
    )
    |> completequest(8243)
    |> setquest(8244)
    |> set_char_var(:ep13_2_rhea, 2)
    |> close()
  end

  defp review_samples(ctx) do
    fairy_quest = checkquest(ctx, 2158)
    giant_quest = checkquest(ctx, 2159)

    if fairy_quest > 0 and giant_quest > 0 do
      ctx
      |> say("You are back!")
      |> next()
      |> say([
        "So, What were they saying?",
        "Of course you remember them exactly as what they've said, right?"
      ])
      |> next()
      |> say(
        "Now, let's start with the Fairies! What is the fairy's language like? Please write them down here sentence by sentence!"
      )
      |> next()
      |> review_fairy_language()
    else
      repeat_request(ctx)
    end
  end

  defp review_fairy_language(ctx) do
    case transcribe(ctx, @fairy_sentences) do
      {ctx, true} ->
        ctx
        |> say([
          "So...If we put'em together,",
          "RLGHLRXLA TKANTLFDMS",
          "WJACK TNAHRDNJSDMFH",
          "WLSGHKWND !!",
          "It'd be like this."
        ])
        |> next()
        |> say(
          "Good. then next is the Wooden Giants! What's their language like? Write them down sentence by sentence just as you did with the Fairy's."
        )
        |> next()
        |> review_giant_language()

      {ctx, false} ->
        reject_transcription(ctx, "I can't understand anything from this...")
    end
  end

  defp review_giant_language(ctx) do
    case transcribe(ctx, @giant_sentences) do
      {ctx, true} ->
        ctx
        |> say([
          "So, If we put'em together,",
          "TJDTMFJDNS CJFDI",
          "TKADLFDMF QKATOS",
          "EKDTLSDML DLFMADMS..",
          "It will be like this."
        ])
        |> next()
        |> say(".Hmm....Hm..I see...")
        |> next()
        |> say("....Ummmm...")
        |> next()
        |> mes("- Dictionary stared at the paper intently. -")
        |> set_char_var(:ep13_2_rhea, 3)
        |> close()

      {ctx, false} ->
        reject_transcription(ctx, "Hmm...I don't get the idea...")
    end
  end

  defp transcribe(ctx, sentences) do
    {results, ctx} =
      sentences
      |> Enum.with_index()
      |> Enum.map_reduce(ctx, fn {sentence, index}, ctx ->
        {ctx, right?} = transcribe_sentence(ctx, sentence, index == 0)
        {right?, ctx}
      end)

    {ctx, Enum.all?(results)}
  end

  defp transcribe_sentence(ctx, {accepted, correct_reply, wrong_reply}, first?) do
    {ctx, sentence} = input(ctx, :string)
    right? = sentence in accepted
    ctx = if right? and first?, do: mes(ctx, @speaker), else: ctx
    reply = if right?, do: correct_reply, else: wrong_reply

    {ctx |> mes("#{sentence}....") |> mes(reply) |> next(), right?}
  end

  defp reject_transcription(ctx, complaint) do
    ctx
    |> say("Hmm...?")
    |> next()
    |> say(["You sure this is exactly what they've said?", complaint])
    |> next()
    |> say("Would you please go back again and check if it is exactly what they were saying?")
    |> close()
  end

  defp repeat_request(ctx) do
    ctx
    |> say(
      "According to the Expedition Camp's investigation, there is a different ethnic race that is similar to fairy's, along with a different ethnic race that is similar to giants."
    )
    |> next()
    |> say(
      "It is said that they are using a language that cannot be understood by people from Midgard... ...Although we all say this, nobody is able to remember their conversation / words."
    )
    |> next()
    |> say(
      "A New language!!! As a linguist, I cannot sit here. But outside, there are many different monsters, as a scholar, it is too dangerous to go outside."
    )
    |> next()
    |> say(
      "and as our conversation has reached this point, you should have an idea of my request, right?"
    )
    |> next()
    |> say(
      "The Tripple Alliance Research Group is very interested in other intelligent life. In order to try and talk to them, national officials have carried out secret effort in every possible way. However, because of lacking information, they are facing difficulties."
    )
    |> next()
    |> say(
      "If you've encountered those races around the Expedition Camp, you must memorize their conversation! Then report back to me!"
    )
    |> close()
  end

  defp admit_defeat(ctx) do
    {ctx, choice} =
      ctx
      |> say("............................")
      |> next()
      |> mes("- Dictionary stared at the paper intently. -")
      |> next()
      |> select(["He looks serious, Let's leave him alone", "Talk to him"])

    case choice do
      1 -> ctx |> say("............................") |> close()
      2 -> burst_out(ctx)
      _ -> ctx
    end
  end

  defp burst_out(ctx) do
    {ctx, _} =
      ctx
      |> say("Ahhhhhhh!!!!!!!!")
      |> next()
      |> select(["Have you figured something out?"])

    {ctx, choice} =
      ctx
      |> say([
        "I....CAN'T! UNDERSTAND IT!!!",
        "Whaaaat~~iiis~~ thiiis~~~ Just how do you read thisssssss~~~ I can't understand a single rule in this~~~~ Huh?"
      ])
      |> next()
      |> say("..................................")
      |> next()
      |> say(["Hmph!", "Yes?"])
      |> next()
      |> select(["He looks serious. Let's leave him alone.", "Ask him what's going on."])

    case choice do
      1 -> ctx |> say(["............................", "...................Hmph..."]) |> close()
      2 -> send_to_magician(ctx)
      _ -> ctx
    end
  end

  defp send_to_magician(ctx) do
    ctx
    |> say(
      "Ah! Well, It's not as easy as I thought. These languages can't be heard anywhere on the Midgard Continent. No known phonetic rules seem to apply here."
    )
    |> next()
    |> say(
      "It's hard to grasp their rule or system, and before everything else, I don't even know if this pronounciation is right. I've never heard of this kind of pronounciation."
    )
    |> next()
    |> say(
      "Ah, right, I heard that a ^0000ffRune-Midgarts Magician^000000 knows a way to conduct research based on a sample of language, would you go and ask him to help me?"
    )
    |> next()
    |> say("The ^0000ffRune-Midgarts Magician^000000 is wandering inside of the Expedition Camp.")
    |> next()
    |> say(
      "It's difficult to continue on a research without some more samples of language. Please do my favor."
    )
    |> completequest(8244)
    |> setquest(8245)
    |> set_char_var(:ep13_2_rhea, 4)
    |> close()
  end

  defp remind_magician(ctx) do
    ctx
    |> say(
      "I heard that ^0000ffRune-Midgarts Magician^000000 knows a way to conduct a research from a sample of language, would you go see him and ask him to help me?"
    )
    |> next()
    |> say(
      "The ^0000ff Rune-Midgarts Magician^000000 is wandering inside of the Expedition Camp."
    )
    |> next()
    |> say(
      "It's difficult to continue this research without some more samples of language. Please do my favor."
    )
    |> close()
  end

  defp report_decoding(ctx) do
    ctx
    |> mes("- The Linguist is writing on a paper as if he's obsessed by something -")
    |> next()
    |> say("...Oh, Hello there.")
    |> next()
    |> say([
      "I heard that you brought us a Gem with the other world's language recorded within it. Thanks to your help, decoding process is going well.",
      "Actually, it's going TOO well..."
    ])
    |> next()
    |> say(
      "It's a wonder that at the moment when I heard that language first-hand I could decode it flawlessly in spite of myself. It must be the blessing of Goddess Freya."
    )
    |> next()
    |> say([
      "But the problem is...",
      "How are we going to put together this tremendous data and make it into a portable translator... I just can't figure out how."
    ])
    |> next()
    |> say(
      "I wonder what the Mechanic Engineer from the Schwarzwald Republic would think... Would you be kind to go ask him?"
    )
    |> completequest(8247)
    |> setquest(8248)
    |> set_char_var(:ep13_2_rhea, 7)
    |> close()
  end

  defp remind_engineer(ctx) do
    ctx
    |> say(
      "Just how are we going to put together these tremendous data and make it into a portable translator...I just can't figure out how."
    )
    |> next()
    |> say(
      "I wonder what the Mechanic Engineer from the Republic of Schwarzwald would think...Would you be kind to go ask him?"
    )
    |> close()
  end

  defp praise_translator(ctx) do
    ctx
    |> say([
      "So, Finally we were able to make a translator!",
      "How is it working? Isn't there any problem with it?"
    ])
    |> next()
    |> say("I hope this translator would help you with your journey.")
    |> next()
    |> say(
      "However, Although using a translator is important, the basics of language and communication is that you should try to understand others."
    )
    |> next()
    |> say(
      "You should not just rely everything on a mere machine...don't forget to be understanding. Enjoy your journey in the otherworld with that translator."
    )
    |> close()
  end

  defp lecture(ctx, opening) do
    ctx
    |> say(opening)
    |> next()
    |> say(
      "Language is a method / system which delievers one's feeling or thinking by voice or letters. Anyway, its purpose is to communicate."
    )
    |> next()
    |> say(
      "Difference between a language and a sound is that language is a socially implied promise by making common system of communication to make it possible to understand eachother."
    )
    |> next()
    |> say([
      "That Socially implied promise, if we could grasp the meaning of a system and structure, we will be able to understand other intellectual life form's language...",
      "...................................And just who might you be?"
    ])
    |> next()
  end

  defp say(ctx, lines), do: Enum.reduce(List.wrap(lines), mes(ctx, @speaker), &mes(&2, &1))
end
