defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.WornOutBook do
  @moduledoc """
  A worn-out book leads the reader into an encounter with its author.

  ## Behavior

  - At the right quest stage, Oliver offers to exchange a picture book for items and a clue.

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
        map: "yuno_in04",
        x: 167,
        y: 120,
        dir: 3,
        sprite: 111,
        name: "Worn-out Book",
        scope: :shared,
        unique_name: "Worn-out Book#garas"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{617, 3}]) == 0 ->
        ctx
        |> mes("- You have too many items in your inventory to proceed with this quest. -")
        |> close()

      get_char_var(ctx, :barmunt_crow, 0) != 12 ->
        ctx
        |> mes(
          "^660000The book's cover was seriously damaged, considering its recent publishing date. Many people must have turned its pages.^000000"
        )
        |> close()

      count_item(ctx, 7795) < 1 ->
        ctx |> mes("- You felt as if you have left something important behind. -") |> close()

      true ->
        read_book(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp read_book(ctx) do
    ctx =
      ctx
      |> mes(
        "^660000The book's cover was seriously damaged, considering its recent publishing date. Many people must have turned its pages.^000000"
      )
      |> next()
      |> mes(
        "^660000You carefully turned the first page, worrying that you might have another crazy dream.^000000"
      )
      |> next()
      |> mes(".........................")
      |> mes(".........................")
      |> mes(".........................")
      |> next()
      |> mes(
        "< Since he was young - it was before he could even remember exactly how young he was - his dreams have filled his brain with immense knowledge that he had never seen or learned from anywhere else."
      )
      |> mes(
        "He was a little boy outside, but wiser than any grown sage. He spoke many languages so fluently that they sounded like Edda chanted by Odin."
      )
      |> mes(
        "To him, his small and dark underground village was a prison blocking him from satisfying his curiosity and desire for freedom."
      )
      |> mes(
        "He expressed his desire to learn more knowledge of the outside world to stepmother Eva, but she always ignored his wish with a stern look."
      )
      |> mes(
        "Eventually, her unreasonable dissuasion could no longer stop him from escaping his reality."
      )
      |> mes(" ")
      |> mes("- Gasp! Gasp! -")
      |> mes(
        "He ran through the darkness which seemed to have no end. He was running away from everything that tried to confine him.>"
      )
      |> next()
      |> mes(".........................")
      |> mes(".........................")
      |> mes(".........................")
      |> next()
      |> mes("< - Umm...-")
      |> mes("-...He's awake.-")
      |> mes("- Hello, can you see me? How do you feel? -")
      |> mes(
        "An old man slowly walked into the room. With a smile on the face, he sat down on a chair. The little boy felt afraid for a little while after seeing people outside his village for the first time,"
      )
      |> mes("but then he forced himself up from the bed, and looked around.")
      |> mes(" ")
      |> mes("- Where am I? Why am I here? - ")
      |> mes(
        "- I was riding a carriage last night, and found you lying in the street. My name is Haeji. You may call me Mr. Haeji, son.-"
      )
      |> mes("-.......-")
      |> mes("- What's your name? -")
      |> mes("-......Al.-")
      |> mes(
        "- Do you know why you're on the street? Where do you live? Your parents must be dying to see you.-"
      )
      |> mes(
        "Haeji's comment instantly brought the monsterous image of Eva to Al's mind. Inwardly, he screamed in fear."
      )
      |> mes("- I live nowhere, and I don't have parents. -")
      |> mes(
        "Al had to lie no matter how long, he thought. The old man seemed to understand him: his eyes showed sympathy for the little boy. Haeji insisted that Al could stay in his mansion as long as he wanted."
      )
      |> mes(
        "Later, after learning that Haeji was a professor of Juno City University, Al was convinced that the fates were on his side.>"
      )
      |> next()
      |> mes(".........................")
      |> mes(".........................")
      |> mes(".........................")
      |> next()
      |> mes(
        "^660000You felt somebody staring at you reading the book. You turned your head, and found a dandy and yet suspicious-looking young man.^000000"
      )
      |> next()
      |> cutin("oliver_pre", 2)
      |> mes(
        "^660000The young man approached and shook your hand with a grin on his face.^000000"
      )
      |> next()
      |> mes("[Suspicious-Looking Man]")
      |> mes("Hey, you're reading <The Trace of the Fate>!")
      |> mes(
        "Hahaha, nice to meet you. I'm the author of that book. I've come by to check how well my new book, <The Crow of the Fate>, is doing, and it's a great honor to meet a fan of mine! I feel embarrassed, but thanks! Hehe."
      )
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Cough, no, I'm not a fa...")
      |> next()
      |> mes("[Oliver Hilpert]")
      |> mes("Oh, right! Do you want my autograph?")
      |> next()
      |> mes("(Scribble)")
      |> next()
      |> mes("[Oliver Hilpert]")
      |> mes(
        "^660000He took out a big piece of paper from his bag, drew something really fast, and then handed it to you.^000000"
      )
      |> next()
      |> mes(
        "Haha, look. I've signed it as big as I could so that you can brag about this to your friends!"
      )
      |> next()
      |> mes("[Oliver Hilpert]")
      |> mes(
        "You know, I just wrote what I saw in my dream; I didn't know people would love my stories so much! It's very surprising to me."
      )
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Dream?")
      |> next()
      |> cutin("oliver_think", 2)
      |> mes("[Oliver Hilpert]")
      |> mes("Yes, I've been having dreams that are so vivid, they feel like reality.")
      |> mes(
        "I was told great writers usually find their inspiration from their dreams. I guess I was born to be one of them. Hahaha!"
      )
      |> next()
      |> mes(
        "You felt something uncomfortable about this so-called dream. You wanted to understand the meaning of what you've seen while reading the book."
      )
      |> mes(
        "If Oliver was dreaming exactly the same things as you, that might mean he and you are sharing dreams. Then again, you've discovered the cave village in the book actually exists."
      )
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("The hero Al was having dreams...")
      |> next()
      |> cutin("oliver_pre", 2)
      |> mes("[Oliver Hilpert]")
      |> mes("Wah!")
      |> mes("Isn't that over there?!")
      |> emotion(:huk)
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Huh?")
      |> next()
      |> mes(
        "^660000You quickly turned your head following his eyes. There was nothing but your bag.^000000"
      )
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes(
        "Ah... Ahchoo! Mr. Hilpert, are you interested in my bag? It's just a simple bag I got from the Novice Training Grounds..."
      )
      |> specialeffect2(:venomdust)
      |> next()
      |> mes("[Oliver Hilpert]")
      |> mes("No, no!")
      |> next()
      |> mes("[Oliver Hilpert]")
      |> mes("I was looking at the thing shining under the cover of the bag!")
      |> next()
      |> mes("^660000You checked what the thing in your bag was, and it was...^000000")
      |> next()
      |> cutin("oliver_smile", 2)
      |> mes("[Oliver Hilpert]")
      |> mes("Lady Mammi!")
      |> emotion(:bigthrob)
      |> next()
      |> mes(
        "^660000Yes, it was the picture book of Mammi, an idol whom Benjamin of Morocc insists to be one of the three greatest idols in the Rune-Midgarts Kingdom. That must be why Oliver is squealing in delight.^000000"
      )
      |> emotion(:think, playerattached(ctx))
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Ahchoo! Are you also a Mammi fan?")
      |> specialeffect2(:venomdust)
      |> next()
      |> mes("[Oliver Hilpert]")
      |> mes("Are you kidding?! Of course!")
      |> mes("Tell me, where you can find another intelligent and beautiful woman like her?")
      |> mes(
        "I believe she's the reincarnation of the Wisdom Goddess who was expelled to the Midgard Continent by jealous goddesses."
      )
      |> next()
      |> mes(
        "^660000Mammi seems to have a strange level of popularity that you can never understand.^000000"
      )
      |> next()
      |> mes("[Oliver Hilpert]")
      |> mes("May I see?")
      |> next()
      |> mes("^660000You have given him Mammi's picture book.^000000")
      |> next()
      |> mes("[Oliver Hilpert]")
      |> mes(".................")
      |> next()
      |> mes("[Oliver Hilpert]")
      |> mes("...Oh!")
      |> cutin("mami01", 4)
      |> emotion(:throb)
      |> next()
      |> mes("[Oliver Hilpert]")
      |> mes("...Ooooh!")
      |> cutin("mami02", 4)
      |> emotion(:throb)
      |> next()
      |> cutin("oliver_smile", 2)
      |> mes("[Oliver Hilpert]")
      |> mes("Ah... This is why I'm in love with Lady Mammi.")
      |> mes(
        "Adventurer, you must be an enthusiastic fan of her as well. Where did you find this rare picture book?"
      )
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("No, I got it as a gift from someone... Ahchoo!")
      |> specialeffect2(:venomdust)
      |> next()
      |> mes("[Oliver Hilpert]")
      |> mes("What? Now I'm shocked!")
      |> mes("It's shocking to see you unimpressed by the beauty of Lady Mammi,")
      |> mes("but it is more shocking that God has given such a rare picture book of her")
      |> mes("to someone like you who does not appreciate its value!")
      |> mes("I flew over to the Rune-Midgarts Kingdom on the earliest airship")
      |> mes(
        "to get this book on the day it was released, but the books were sold out. The person right in front of me got the last one!"
      )
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("...............")
      |> mes("I... I see...")

    {ctx, choice} =
      ctx
      |> emotion(:sweat, playerattached(ctx))
      |> next()
      |> mes("[Oliver Hilpert]")
      |> mes("Umm...")
      |> mes("If you don't really like that book, why don't you sell it to me?")
      |> next()
      |> mes("[Oliver Hilpert]")
      |> mes(
        "As I told you earlier, it's something I'm willing to cross continents to get. Please?"
      )
      |> mes("I really want to buy your book!")
      |> next()
      |> select(["Sell", "Don't Sell"])

    case choice do
      1 ->
        sell_book(ctx)

      2 ->
        ctx
        |> mes("[Oliver Hilpert]")
        |> mes("Okay... I see...")
        |> emotion(:cry)
        |> set_char_var(:barmunt_crow, 13)
        |> close2()
        |> cutin("", 255)

      _ ->
        ctx
    end
  end

  defp sell_book(ctx) do
    ctx
    |> mes("[Oliver Hilpert]")
    |> mes("Wow, thanks!")
    |> next()
    |> mes("[Oliver Hilpert]")
    |> mes(
      "Umm... I haven't received my publishing advance yet, but do you mind taking this instead?"
    )
    |> next()
    |> mes("[Oliver Hilpert]")
    |> mes(
      "I haven't had a chance to open it, but my publisher said it has something very rare inside. I hope that it's enough to pay you for your book."
    )
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Haha, thanks.")
    |> mes(
      "You know, in Morocc... Ahchoo! ...There's someone who's as big a fan of Mammi's as you... Ahchoo! So why don't you go meet him?"
    )
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("I got that book from him as a gift. He may have more rare books of her... Ahchoo!")
    |> next()
    |> mes("[Oliver Hilpert]")
    |> mes("Oh, thank you so much for such valuable information!")
    |> next()
    |> mes("[Oliver Hilpert]")
    |> mes("Wah! I must write down the story that I saw in my dream last night before I forget!")
    |> next()
    |> mes("[Oliver Hilpert]")
    |> mes(
      "I hope you'll also like my next book. Then I must go... Thank you for the picture book!"
    )
    |> cutin("oliver_smile", 255)
    |> next()
    |> mes(
      "^660000He started running around like a chicken with its head cut off. He quickly opened his bag, took out his notebook, ran to a table, and then started writing down something at a fast speed."
    )
    |> mes(
      "At first, he looked pretty silly, but now he strikes you as a man that's very serious about his writing.^000000"
    )
    |> next()
    |> mes("^660000You were about to leave when you found a piece of paper on the ground.^000000")
    |> next()
    |> mes(
      "^660000The piece of paper is covered with scribbles, and is labeled <The Crow of the Fate> at the top. Oliver must have dropped this note containing information about his novel, <The Crow of the Fate>.^000000"
    )
    |> next()
    |> mes("^3131FFAncient weapon = Some kind of power source^000000")
    |> mes("^3131FFSeclusion - A female disciple's letter^000000")
    |> mes("^3131FFThe stepmother = Lover from a past life?!^000000")
    |> close2()
    |> specialeffect2(:enhance)
    |> delitem(7795, 1)
    |> set_char_var(:barmunt_crow, 14)
    |> give_item(7796, 1)
    |> give_item(7797, 1)
    |> give_item(617, 1)
    |> warp("que_ba", 270, 270)
    |> cutin("", 255)
  end
end
