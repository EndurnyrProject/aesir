defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsGonryun.ManInHangover do
  @moduledoc """
  Xue Bong is a hungover witness to the theft of the chief’s belongings.

  ## Behavior

  - Requests a Green Potion and shares what he saw near the chief’s house.
  - Responds differently as the investigation progresses or if the player refuses him.

  ## Credits

  - Original from rAthena, authors and Contributors
    - KarLaeda
    - L0ne_W0lf
    - Paradox924X

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "gon_in",
        x: 165,
        y: 16,
        dir: 4,
        sprite: 748,
        name: "Man in hangover",
        scope: :shared,
        unique_name: "Man in hangover#gon"
      }
    ]

  @green_potion 506

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :b_sword, 0) do
      stage when stage < 4 -> hungover(ctx)
      4 -> request_potion(ctx)
      5 -> returning_player(ctx)
      stage when stage < 11 -> hopeful(ctx)
      11 -> sick_again(ctx)
      12 -> merciless(ctx)
      13 -> coldhearted(ctx)
      _ -> congratulates(ctx)
    end
  end

  defp hungover(ctx) do
    ctx
    |> mes("[Xue Bong]")
    |> mes("Ahhh.. my stomach.. my head..")
    |> mes("I shouldn't drink so much..")
    |> mes("Ehhhh....")
    |> emotion(:profusely_sweat)
    |> close()
  end

  defp request_potion(ctx) do
    if count_item(ctx, @green_potion) < 1 do
      needs_potion(ctx)
    else
      offer_potion(ctx)
    end
  end

  defp needs_potion(ctx) do
    ctx
    |> mes("[Xue Bong]")
    |> mes("*Urk!* I feel sick...")
    |> mes("Can somebody bring me a potion?")
    |> mes("*Groan*....")
    |> emotion(:profusely_sweat)
    |> close()
  end

  defp offer_potion(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Xue Bong]")
      |> mes("Ohhh...my stomach...")
      |> mes("I need something...")
      |> mes("Moan~ Uh, hey you!")
      |> mes("Could you give me one")
      |> mes("of your ^00FF00Green_Potion^000000s?")
      |> mes("I think I'm going to barf...")
      |> next()
      |> select(["No.", "Here, drink this!"])

    case choice do
      1 -> reconsider(ctx)
      2 -> accepts_potion(ctx)
      _ -> ctx
    end
  end

  defp reconsider(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Xue Bong]")
      |> mes("Uhh...")
      |> mes("Are you sure?")
      |> next()
      |> select(["Sorry, I don't have any.", "Here, you can have it!"])

    case choice do
      1 -> refused(ctx)
      2 -> accepts_after_refusal(ctx)
      _ -> ctx
    end
  end

  defp refused(ctx) do
    ctx
    |> mes("[Xue Bong]")
    |> mes("C'mon, man...")
    |> mes("I...I'm in freakin' pain here...")
    |> set_char_var(:b_sword, 12)
    |> close()
  end

  defp accepts_after_refusal(ctx) do
    {ctx, choice} =
      ctx
      |> delitem(@green_potion, 1)
      |> set_char_var(:b_sword, 5)
      |> mes("[Xue Bong]")
      |> mes("Oh man...thanks.")
      |> mes("I thought you were teasing me.")
      |> mes("I feel much better now.")
      |> mes("So...uh, what brings you here?")
      |> next()
      |> select(["Heard about the thief?", "Nothing."])

    if choice == 1, do: reluctant_testimony(ctx), else: thanks_again(ctx)
  end

  defp reluctant_testimony(ctx) do
    ctx
    |> mes("[Xue Bong]")
    |> mes("Ah, a thief~")
    |> mes("Hmm...let me see..")
    |> mes("I went out for walk in the middle")
    |> mes("of the night while I was drinking.")
    |> mes("And I heard a noise.")
    |> next()
    |> mes("[Xue Bong]")
    |> mes("I looked around and found that the")
    |> mes("area near the chief's house was")
    |> mes("brighter than any other area...")
    |> mes("It was odd...")
    |> mes("[Xue Bong]")
    |> mes("So I kept watching it and")
    |> mes("all of a sudden, I saw something")
    |> mes("moving on the rooftops...")
    |> next()
    |> mes("[Xue Bong]")
    |> mes("It disappeared in a second.")
    |> mes("I was drunk, and it was dark")
    |> mes("outside. I have no idea")
    |> mes("whether it was a man,")
    |> mes("a poring, or if I had just")
    |> mes("drank too much..eheh.")
    |> set_char_var(:b_sword, 6)
    |> close()
  end

  defp thanks_again(ctx) do
    ctx
    |> mes("[Xue Bong]")
    |> mes("Okay then, thanks again.")
    |> mes("Don't be a drinker like me,")
    |> mes("unless you want to suffer from")
    |> mes("serious hangovers. See you later~")
    |> close()
  end

  defp accepts_potion(ctx) do
    {ctx, choice} =
      ctx
      |> delitem(@green_potion, 1)
      |> set_char_var(:b_sword, 5)
      |> emotion(:thanks)
      |> mes("[Xue Bong]")
      |> mes("Whew, Thanks!")
      |> mes("I feel much better now.")
      |> mes("Hmm...you seem new around here.")
      |> mes("Anything you wanna know?")
      |> next()
      |> select([
        "About a thief...",
        "How much have you been drinking?",
        "Nothing~"
      ])

    case choice do
      1 -> rooftop_sighting(ctx)
      2 -> drinking(ctx)
      3 -> goodbye(ctx)
      _ -> ctx
    end
  end

  defp rooftop_sighting(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Xue Bong]")
      |> mes("Ah, a thief, eh? Let's see...")
      |> mes("I went out for walk in the middle")
      |> mes("of the night while I was drinking.")
      |> mes("All of a sudden, I heard a strange noise...")
      |> next()
      |> mes("[Xue Bong]")
      |> mes("I looked around and found that the")
      |> mes("area near the chief's house was")
      |> mes("brighter than any other area. It was odd...")
      |> next()
      |> mes("[Xue Bong]")
      |> mes("So I kept watching it and,")
      |> mes("all of a sudden, I saw something moving on the rooftops...")
      |> next()
      |> select(["Where to?", "Probably a Wild Rose."])

    if choice == 1, do: shrine_sighting(ctx), else: wild_rose(ctx)
  end

  defp shrine_sighting(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Xue Bong]")
      |> mes("Umm?")
      |> mes("Well..let me see..")
      |> mes("It came from... and head to...um...")
      |> mes("murmur..")
      |> next()
      |> mes("^3355FFHe started mumbling for a bit^000000")
      |> mes("......")
      |> next()
      |> mes("[Xue Bong]")
      |> mes("Ah ha!! Right...")
      |> mes("A shrine, yeah, the thief was")
      |> mes("heading to a shrine and")
      |> mes("disappeared. I'm not")
      |> mes("sure if it was a human or an")
      |> mes("animal...")
      |> set_char_var(:b_sword, 6)
      |> next()
      |> mes("[Xue Bong]")
      |> mes("Anything else I can help you with?")
      |> mes("I appreciate the potion.")
      |> next()
      |> select([
        "Thanks for the information.",
        "Stop drinking so much.",
        "Okay, bye"
      ])

    case choice do
      1 -> see_you_later(ctx)
      2 -> social_drinker(ctx)
      3 -> come_again(ctx)
      _ -> ctx
    end
  end

  defp see_you_later(ctx) do
    ctx
    |> mes("[Xue Bong]")
    |> mes("I'll see you later then.")
    |> mes("I'm always be here drinking..eheh.")
    |> close()
  end

  defp social_drinker(ctx) do
    ctx
    |> mes("[Xue Bong]")
    |> mes("Ehh..Don't mind me.")
    |> mes("I'm a social drinker...")
    |> mes(" ")
    |> mes("It's just I don't got nobody to be social with.")
    |> close()
  end

  defp come_again(ctx) do
    ctx
    |> mes("[Xue Bong]")
    |> mes("Alright.")
    |> mes("Come again whenever you have")
    |> mes("any other questions.")
    |> close()
  end

  defp wild_rose(ctx) do
    ctx
    |> mes("[Xue Bong]")
    |> mes("Yeah..maybe.")
    |> mes("It was so dark outside and I was")
    |> mes("drunk so I don't remember")
    |> mes("clearly. I'm pretty sure it was bigger than that, though.")
    |> close()
  end

  defp drinking(ctx) do
    ctx
    |> mes("[Xue Bong]")
    |> mes("Ah..um....I..I don't remember.")
    |> mes("When I woke up, There were tons of")
    |> mes("empty bottles around me.")
    |> mes("...")
    |> next()
    |> mes("^3355FF.......")
    |> mes("For some reason, you can't discern his testimony's reliability...^000000")
    |> close()
  end

  defp goodbye(ctx) do
    ctx
    |> mes("[Xue Bong]")
    |> mes("Alrighty then.")
    |> mes("Hope you don't ever drink like me")
    |> mes("in the future. You'll suffer")
    |> mes("for a long time if you do.")
    |> mes("You know what a hangover is, right?")
    |> close()
  end

  defp returning_player(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Xue Bong]")
      |> mes("Oh, it's you. Hey.")
      |> mes("Thanks for the potion last time.")
      |> mes("What are you up to?")
      |> mes("Got any questions for me?")
      |> next()
      |> select(["About a thief last night...", "Nope, just passing by.."])

    case choice do
      1 -> later_testimony(ctx)
      2 -> later_farewell(ctx)
      _ -> ctx
    end
  end

  defp later_testimony(ctx) do
    ctx
    |> mes("[Xue Bong]")
    |> mes("Ah~ a thief...?")
    |> mes("Hmm...let me see...")
    |> mes("I went out for walk in the middle")
    |> mes("of the night while I was drinking.")
    |> mes("All of a sudden, I heard a strange noise...")
    |> next()
    |> mes("[Xue Bong]")
    |> mes("I looked around and found that the")
    |> mes("area near the chief's house was")
    |> mes("brighter than any other area. It was odd...")
    |> next()
    |> mes("[Xue Bong]")
    |> mes("So I kept watching it and,")
    |> mes("all of a sudden, I saw something moving on the rooftops...")
    |> next()
    |> mes("[Xue Bong]")
    |> mes("It disappeared in a second.")
    |> mes("I was drunk, and it was dark")
    |> mes("outside. I have no idea")
    |> mes("whether it was a man, a poring,")
    |> mes("or if I just had too much to drink...heheh~")
    |> set_char_var(:b_sword, 6)
    |> close()
  end

  defp later_farewell(ctx) do
    ctx
    |> mes("[Xue Bong]")
    |> mes("Okay, then, thanks again.")
    |> mes("Don't be a drinker like me,")
    |> mes("unless you want to suffer from")
    |> mes("serious hangovers. See you later~")
    |> close()
  end

  defp hopeful(ctx) do
    ctx
    |> mes("[Xue Bong]")
    |> mes("Well, hopefully you can find")
    |> mes("those thieves. To keep the")
    |> mes("peace in our village, we need to help out our chief...")
    |> close()
  end

  defp sick_again(ctx) do
    ctx
    |> mes("[Xue Bong]")
    |> mes("Ahhh.. my stomach.. my head..")
    |> mes("I shouldn't drink so much..")
    |> mes("ughh....")
    |> emotion(:profusely_sweat)
    |> close()
  end

  defp merciless(ctx) do
    ctx
    |> mes("[Xue Bong]")
    |> mes("Enhhhh..go away.")
    |> mes("You're merciless...")
    |> mes("How could you turn a")
    |> mes("blind eye to a")
    |> mes("boozer's suffering?")
    |> mes("Urk...!")
    |> emotion(:fret)
    |> close()
  end

  defp coldhearted(ctx) do
    ctx
    |> mes("[Xue Bong]")
    |> mes("Enhhhh...go away.")
    |> mes("You're so coldhearted...")
    |> mes("How could you turn away")
    |> mes("a drunk in need...?")
    |> mes("*Groan*...")
    |> emotion(:fret)
    |> close()
  end

  defp congratulates(ctx) do
    ctx
    |> mes("[Xue Bong]")
    |> mes("So you found the chief's")
    |> mes("belongings?! I knew it!")
    |> mes("I knew you could do it!")
    |> mes("You're brave enough")
    |> mes("to do anything!")
    |> mes("Good job!")
    |> close()
  end
end
