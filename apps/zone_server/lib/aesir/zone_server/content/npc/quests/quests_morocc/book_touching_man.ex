defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.BookTouchingMan do
  @moduledoc """
  Benjamin asks the player to find a book for his favorite celebrity.

  ## Behavior

  - Offers the book quest to eligible players and follows its progress.
  - Gives a picture book and rewards the player for bringing the author’s keepsakes.

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
      %{
        map: "moc_ruins",
        x: 137,
        y: 70,
        dir: 3,
        sprite: 48,
        name: "Book-Touching Man",
        scope: :shared,
        unique_name: "Book-Touching Man#garas"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      base_level(ctx) <= 59 ->
        ctx |> mes("With dreamy eyes, the man is looking down at a book in his hand.") |> close()

      checkweight(ctx, [{703, 3}]) == 0 ->
        ctx
        |> mes("- You have too many items in your inventory to proceed with this quest. -")
        |> close()

      true ->
        talk_at_progress(ctx, get_char_var(ctx, :barmunt_crow, 0))
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp talk_at_progress(ctx, 0) do
    {ctx, choice} =
      ctx
      |> mes(
        "^660000Morocc, the City of the Desert, has been completely devastated by Satan Morocc.^000000"
      )
      |> next()
      |> mes(
        "^660000The people of Morocc were resilient enough to endure the region's harsh weather, but their toughness to the weather could not prepare them enough as they witnessed the destruction brought down upon the city by Satan Morocc.^000000"
      )
      |> next()
      |> mes(
        "^660000This man, who looks as dry and thin as a fish dried up under the sun, still has a smile that reminds you of a benevolent god, and is touching a book in his hand.^000000"
      )
      |> next()
      |> mes(
        "^660000Watching him makes you giggle, he looks no better than the dried corpses in the pyramid, but he is obviously alive and doesn't appear to be a monster. Somehow, you find yourself compelled to approach this interesting looking man.^000000"
      )
      |> next()
      |> emotion(:throb)
      |> mes("[Book-Touching Man]")
      |> mes("Ah... Mammi...")
      |> next()
      |> mes("[Book-Touching Man]")
      |> mes("Your healthy golden skin is glowing under the blessed sunlight of Morocc.")
      |> next()
      |> emotion(:cry)
      |> mes("[Book-Touching Man]")
      |> mes(
        "Your smile outshines the aura of the gods of Valhalla. You are a living gospel. Your smile even makes Goddess Freya hide in the shadows in shame! Ah.... Mammi, my Mammi!"
      )
      |> next()
      |> mes(
        "^660000You wave your hand close to his face to get his attention. He seems, however, to be in his own dreams, completely oblivious of your presense.^000000"
      )
      |> next()
      |> select(["Speak", "Pass Him By"])

    case choice do
      1 -> speak_to_benjamin(ctx)
      2 -> ctx |> mes("[Benjamin]") |> mes("Oh... Mammi... My Mammi...") |> close()
      _ -> ctx
    end
  end

  defp talk_at_progress(ctx, 1) do
    ctx
    |> mes("[Benjamin]")
    |> mes(
      "Don't you forget this title: 'The Crow of the Fate' written by 'Oliver Hilpert.' I'm sure you can find it in Prontera Library."
    )
    |> close()
  end

  defp talk_at_progress(ctx, 10), do: return_book(ctx)

  defp talk_at_progress(ctx, 11) do
    ctx
    |> mes(
      "^660000You have embarked on a journey to Juno to read the prequel of <The Crow of the Fate>: <The Trace of the Fate>.^000000"
    )
    |> close()
  end

  defp talk_at_progress(ctx, 15) do
    if count_item(ctx, 7797) == 1 and count_item(ctx, 7796) == 1 do
      offer_keepsakes(ctx)
    else
      dream_of_mammi(ctx)
    end
  end

  defp talk_at_progress(ctx, _), do: dream_of_mammi(ctx)

  defp dream_of_mammi(ctx) do
    ctx |> mes("[Benjamin]") |> mes("Oh... Mammi... Oh...") |> close()
  end

  defp speak_to_benjamin(ctx) do
    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Are you talking to yourself?")
      |> next()
      |> emotion(:huk)
      |> mes("[Book-Touching Man]")
      |> mes(
        "Wah! Oh, my god, you must be a messenger of the devil trying to interrupt me from feeling Mammi!"
      )
      |> mes("I'm not afraid of you, so bring it on!")
      |> next()
      |> mes("^660000Surprised by your voice, he yelled at you, which seemed bizarre.")
      |> mes(
        "You wonder what he meant by feeling her when he was just watching and touching a book.^000000"
      )
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Who's Mammi?")
      |> next()
      |> emotion(:huk)
      |> mes("[Book-Touching Man]")
      |> mes("What? Don't you know Mammi, one of the three greatest Rune-Midgarts' idols?")
      |> next()
      |> emotion(:ohno)
      |> mes("[Book-Touching Man]")
      |> mes(
        "Man, you don't know anything, do you?! Well, judging by the stupid look on your face, I guess you're an adventurer running around on meaningless errands for others. Heh heh!"
      )
      |> next()
      |> mes("^660000Umm... You now regret speaking to him in the first place.^000000")
      |> next()
      |> mes("[Book-Touching Man]")
      |> mes(
        "My Mammi is different from those other celebrities that only rely on their beauty and lack any real substance."
      )
      |> mes(
        "She always carries books with her despite her hectic schedule. That alone should tell you that she's more intelligent than all the others! Ah... Mammi..."
      )
      |> next()
      |> mes("[Book-Touching Man]")
      |> mes(
        "She even mentioned in an interview in 'Morocc Times' that she wants to meet a man that loves books."
      )
      |> next()
      |> emotion(:cool)
      |> mes("[Book-Touching Man]")
      |> mes("That means... She's waiting for someone like me. Hehehe!")
      |> mes(
        "You see, every book in Rune-Midgarts' Library has the name Benjamin written on them... That's me!"
      )
      |> next()
      |> mes(
        "^660000This Benjamin seems to be a huge fan of a female celebrity called Mammi. He didn't shut his mouth and worshipped her beauty for a while, but then he suddenly stopped and looked depressed.^000000"
      )
      |> next()
      |> mes("[Benjamin]")
      |> mes("I have a problem....")
      |> next()
      |> mes("[Benjamin]")
      |> mes(
        "My Mammi said that she's fallen in love with a book written by ^FF0000'Oliver Hilpert'^000000 of Schwarzwald: ^FF0000'The Crow of the Fate,'^000000 but I didn't have a chance of even looking at it!"
      )
      |> next()
      |> mes("^660000The Crow of the Fate^000000?")
      |> next()
      |> mes("[Benjamin]")
      |> mes("Unless you're blind, you know how terrible Morocc is nowadays.")
      |> next()
      |> mes("[Benjamin]")
      |> mes(
        "I really need to read that book and tell her that I'm here for her, but I don't even have the time to regain my breath because of this situation in our hands!"
      )
      |> next()
      |> emotion(:cry)
      |> mes("[Benjamin]")
      |> mes("My Mammi pillow cover is buried under debris... Gasp!")
      |> mes("Mammi, I'm coming! Don't you die yet!")
      |> next()
      |> mes(
        "^660000He seems to see an image of Mammi, and he shouted her name, gasping with anxiety. You feel so sorry for his agony.^000000"
      )
      |> next()
      |> mes("^660000He inhaled deeply, and then suddenly turned his head toward you.^000000")
      |> next()
      |> emotion(:aha)
      |> mes("[Benjamin]")
      |> mes("....Ye... Yes, you!")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Huh?")

    ctx =
      ctx
      |> emotion(:profusely_sweat, playerattached(ctx))
      |> next()
      |> mes("[Benjamin]")
      |> mes("You look bored. You must be waiting for someone to give you something to do!")
      |> mes(
        "Help me connect with Mammi. Who knows? I may let you have a conversation with Mammi, whom everyone in Rune-Midgarts adores."
      )
      |> next()
      |> mes(
        "^660000Didn't you just call me an adventurer that runs around on meaningless errands for others...?^000000"
      )
      |> next()
      |> mes("[Benjamin]")
      |> mes(
        "All I'm asking is to check out a book from Prontera Library for me. It sounds easy, doesn't it?"
      )
      |> mes(
        "Well, you don't look like someone who loves reading, but I hope you at least know how to check out a book from a library."
      )
      |> next()

    ctx =
      if sex(ctx) == 1 do
        ctx
        |> mes("[Benjamin]")
        |> mes(
          "If you help me, I'll show you a limited picture book edition of Mammi... Once. Hehehehe."
        )
        |> mes("What do you say? You do want to help me, right?")
        |> next()
      else
        ctx
        |> mes("[Benjamin]")
        |> mes(
          "If you help me, I'll show you a limited picture book edition of Mammi... Once. Hehehehe."
        )
        |> mes(
          "So, aren't you interested in looking at another girl's pictures? Umm, if you want, I can introduce you to a handsome guard in Morocc..."
        )
        |> mes("What do you say? You do want to help me, right?")
        |> next()
      end

    {ctx, choice} =
      ctx
      |> mes("^660000What do you want to do?^000000")
      |> next()
      |> select(["Help him", "Don't help him"])

    case choice do
      1 ->
        ctx
        |> mes("[Benjamin]")
        |> mes("Wow, are you really going to help me?")
        |> next()
        |> mes("[Benjamin]")
        |> mes(
          "Thank you so much! Then remember this title: 'The Crow of the Fate' written by 'Oliver Hilpert.' I'm sure you can find it in Prontera Library."
        )
        |> mes("Hehehe, Mammi! I'm almost there!")
        |> set_char_var(:barmunt_crow, 1)
        |> setquest(2063)
        |> close()

      2 ->
        ctx
        |> mes("[Benjamin]")
        |> mes("What, don't you know how to check out a book from a library? Oh, my...")
        |> close()

      _ ->
        ctx
    end
  end

  defp return_book(ctx) do
    ctx =
      ctx
      |> mes("[Benjamin]")
      |> mes("Oh... Mammi... My Mammi...")
      |> next()
      |> mes(
        "^660000Just like the last time that you saw him, Bejamin is living in his dreams, rubbing a book on his face.^000000"
      )
      |> next()
      |> mes(
        "^660000You carefully approached him, and then gave him a pat on the shoulder.^000000"
      )
      |> next()
      |> emotion(:huk)
      |> mes("[Benjamin]")
      |> mes("Grrrr! Who dares touch me?!")
      |> next()
      |> mes("^660000...Umm... Obviously you weren't careful enough... ^000000")
      |> next()
      |> mes("[Benjamin]")
      |> mes("Who dares interrupt me from feeling Mammi? Do you want a piece of me... Err?")
      |> mes(
        "Gosh, it's you. What took you so long? Wasn't Prontera Library, like, five minutes away?"
      )
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes(
        "Ahchoo! Thanks to you, I couldn't find it from the library. So I travelled all the way up to Schwarzwald... Ahchoo!"
      )
      |> specialeffect2(:venomdust)
      |> next()
      |> mes(
        "^660000Feeling angry at him, you exaggerated a fit of sneezing which you have had for quite a while.^000000"
      )
      |> next()
      |> mes("[Benjamin]")
      |> mes("Oh... you did?")
      |> mes(
        "Hehehe, you're more reliable than I thought. Thanks for the book... Wait, does that mean I have to go up to Schwarzwald to return this? Man!"
      )
      |> next()
      |> mes("[Benjamin]")
      |> mes(
        "...No, I can do anything as long as it's for Mammi. Heh heh, you're a kind adventurer. Thanks."
      )
      |> mes(
        "Was it cold up there? I guess it is since Schwarzwald is located up north from here."
      )
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("..................")
      |> next()
      |> mes("[Benjamin]")
      |> mes(
        "Let me think. If this book is not yet available in Prontera Library, it must mean that not many people of Rune-Midgarts have read this book."
      )
      |> next()
      |> mes("[Benjamin]")
      |> mes(
        "Grrrr... Mammi! Here I am, following your noble tastes to read such a rare book! Mammi...!"
      )
      |> emotion(:bigthrob)
      |> next()
      |> mes("[Benjamin]")
      |> mes(
        "I feel so excited to think about having a deep conversation with Mammi about literature! Yay!"
      )
      |> mes("I should go read this book right away. Hehehe!")
      |> emotion(:delight)
      |> next()
      |> mes("[Benjamin]")
      |> mes("Oops, I must not forget to repay you. You know, I'm a polite man.")
      |> next()
      |> mes("[Benjamin]")
      |> mes("Look, it's the picture book of Mammi I told you about.")
      |> next()
      |> cutin("mami01", 4)
      |> mes("[Benjamin]")
      |> mes(
        "Ah... Look at this picture of her wearing the rolled-up puppy ears! Doesn't she look like a sad puppy wandering Comodo, the City of Lovers, all by herself?!"
      )
      |> mes(
        "How could no one shed a tear after watching this sad picture of her?! Argh, Mammi! I'm coming to make you the happiest woman in the world!"
      )
      |> next()
      |> cutin("mami02", 4)

    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes(
        "'She looks different than I thought with these glasses and pony tails... She really looks like someone who loves literature."
      )
      |> mes(
        "Wait, when did people start calling Comodo the City of Lovers? Hmm... This guy really thinks weird things!'"
      )
      |> next()
      |> mes("[Benjamin]")
      |> mes(
        "I've decided to give you this <Angel Mammi's Special picture book: In Comodo> which is full of her beautiful pictures in return of your favor. Ahem... What do you say?"
      )
      |> next()
      |> mes(
        "^660000He is staring at you arrogantly. Obviously, he doesn't care if you like the book or not.^000000"
      )
      |> next()
      |> select(["I'll take it.", "No, thanks."])

    case choice do
      1 ->
        ctx
        |> mes("'^660000Well, if it's for free, and there's no harm keeping it.'^000000")
        |> next()
        |> accept_picture_book()

      2 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("No, thanks. I'm not interested in her as much as you.")
        |> next()
        |> mes(
          "...^660000Was what you were about to say, but you could not refuse his offer. Looking at his fanatical eyes, burning with love for her, even Odin could not refuse...^000000"
        )
        |> next()
        |> accept_picture_book()

      _ ->
        ctx
    end
  end

  defp accept_picture_book(ctx) do
    ctx =
      ctx
      |> mes(
        "^660000Quickly blinking his eyes, he made you take Mammi's picture book in your arms"
      )
      |> mes("demanding that you must encase the book so it would not be damaged.^000000")
      |> set_char_var(:barmunt_crow, 11)
      |> give_item(7795, 1)
      |> next()
      |> mes("[Benjamin]")
      |> mes(
        "Oh, right. If you're interested in this author, Oliver Hilpert, I suggest you read the prequel of <The Crow of the Fate>, ^3131FF<The Trace of the Fate>^000000 as well as the sequel."
      )
      |> next()
      |> mes("[Benjamin]")
      |> mes("That was also a bestseller.")
      |> next()
      |> mes("[Benjamin]")
      |> mes(
        "Now I need to start reading this book for the moment that I'll meet my Mammi, so please leave me alone."
      )
      |> next()
      |> mes(
        "^660000As soon as he finished, he returned to escaping reality by indulging himself in his dreams of Mammi.^000000"
      )
      |> next()
      |> mes("^660000The Trace of the Fate, huh?")
      |> mes("Well, I don't have anything else to do. I might want to read the book...^000000")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Wait, does it mean that I have to go back to Juno Library?")
    |> next()
    |> mes("^660000Thinking of travelling back to Juno made you sigh in frustration.^000000")
    |> changequest(2067, 2068)
    |> close2()
    |> cutin("", 255)
  end

  defp offer_keepsakes(ctx) do
    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Hey, Benjamin!")
      |> mes("I've got the perfect thing to help you appeal to Mammi. Do you want to see?")
      |> next()
      |> mes("[Benjamin]")
      |> mes("WH... WHAT?!")
      |> mes("What is they? Show me!?")
      |> next()
      |> mes(
        "^660000You have shown him an autograph and a written note by Oliver Hilpert.^000000"
      )
      |> next()
      |> mes("[Benjamin]")
      |> mes("Oh, my god!")
      |> mes("These will surely help me get closer to Mammi!")
      |> mes("Give them to me!")
      |> next()
      |> select(["Give", "Don't Give"])

    case choice do
      1 ->
        ctx = mes(ctx, "[Benjamin]")

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("Oh, ", char_name(ctx, 0)), "!"))
          |> mes("You are the best! Thanks!")
          |> next()
          |> mes("[Benjamin]")
          |> mes("Maaaammmiii!")
          |> mes("I'm going to see her tomorrow as soon as the morning comes! Mammi, I'm coming!")
          |> delitem(7797, 1)
          |> delitem(7796, 1)
          |> set_char_var(:barmunt_crow, 16)

        ctx =
          if Rathena.truthy?(checkre(ctx, 3)) do
            getexp(ctx, 90_000, 90_000)
          else
            getexp(ctx, 900_000, 900_000)
          end

        close(ctx)

      2 ->
        ctx
        |> mes("[Benjamin]")
        |> mes("Huh? What, are you kidding me?")
        |> close()

      _ ->
        ctx
    end
  end
end
