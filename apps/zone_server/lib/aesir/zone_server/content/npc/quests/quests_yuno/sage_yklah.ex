defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsYuno.SageYklah do
  @moduledoc """
  Sage Yklah guides the bearer of the Stamp of Muriniel.

  ## Behavior

  - Explains the doomed sword and exchanges materials for a clue leading to Syklah.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - L0ne_W0lf
    - kobra_k88
    - Darkchild
    - Lupus
    - Samuray22
    - akrus

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno",
        x: 261,
        y: 99,
        dir: 4,
        sprite: 735,
        name: "Sage Yklah",
        scope: :shared,
        unique_name: "Sage Yklah#juno"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :dmdswrd_Q, 0) do
      23 ->
        {ctx, choice} =
          ctx
          |> mes("[Yklah]")
          |> mes("- ! ! ! -")
          |> next()
          |> mes("[Yklah]")
          |> mes("That item...")
          |> mes(
            "That shining item you're carrying, isn't that...? ^3355FFStamp of Muriniel^000000?! Oh! What a surprise!"
          )
          |> next()
          |> mes("[Yklah]")
          |> mes(
            "I've heard that it's from a hot and dry land, but I never dreamed I'd be able to see it with my own eyes!"
          )
          |> next()
          |> mes("[Yklah]")
          |> mes("Who are you...? Who are you carrying this legendary item for?")
          |> next()
          |> select(["(Show him the slate)", "I'm a genius!", "I'm a GM!"])

        case choice do
          1 ->
            ctx
            |> mes("[Yklah]")
            |> mes(
              "...I can't believe my eyes! Only a chosen few can possess the Stamp of Muriniel..."
            )
            |> next()
            |> mes("[Yklah]")
            |> mes(
              "Oh yes. That's right, that's right. As far as I can tell, you don't seem to understand how to use this item..."
            )
            |> next()
            |> mes("[Yklah]")
            |> mes(
              "There is one old song in Juno, about ^3355FF'The Doomed Sword'^000000 that you may have been looking for."
            )
            |> next()
            |> mes("[Yklah]")
            |> mes(
              "'Even if you're running toward a light on the other side of the mist, you can't reach it.'"
            )
            |> next()
            |> mes("[Yklah]")
            |> mes("'The chime of the bell from across the valley cannot be held in your hand.'")
            |> next()
            |> mes("[Yklah]")
            |> mes(
              "Yes, it's sort of a difficult song to understand, but it's supposed to express how Sages in ancient times feel about obtaining the doomed swords."
            )
            |> next()
            |> mes("[Yklah]")
            |> mes(
              "If you're still set on the idea of obtaining the doomed sword, come and talk to me sometime."
            )
            |> next()
            |> mes("[Yklah]")
            |> mes(
              "As you already possess the Stamp of Muriniel, I am more than willing to help you."
            )
            |> set_char_var(:dmdswrd_Q, 24)
            |> close()

          2 ->
            ctx
            |> mes("[Yklah]")
            |> mes("Hmm?")
            |> mes(
              "A genius you say? How can you say that in a city full of wise men? That's nothing special."
            )
            |> next()
            |> mes("[Yklah]")
            |> mes(
              "Plus, if you're a colleague, I think I would remember you. I don't tend to forget people that I've met at least once."
            )
            |> close()

          3 ->
            ctx
            |> mes("[Yklah]")
            |> mes("A...")
            |> mes("GM?")
            |> next()
            |> mes("[Yklah]")
            |> mes(
              "I don't understand what you're talking about. But there's an ancient Juno song about this GM you speak of..."
            )
            |> next()
            |> mes("[Yklah]")
            |> mes(
              "'^FF3355Impersonating GMs is punishable with a permanent account block^000000.' But what could it possibly mean?"
            )
            |> next()
            |> mes("^3355FFHow depressing!^000000")
            |> close()

          _ ->
            ctx
        end

      24 ->
        if count_item(ctx, 7030) > 2 and count_item(ctx, 913) > 9 and
             count_item(ctx, 7032) > 0 do
          ctx
          |> mes("[Yklah]")
          |> mes(
            "Hmm! Good job, you brought all of the items. Try inserting them in the grooves."
          )
          |> next()
          |> mes("[Yklah]")
          |> mes(
            "To be honest, I thought about it before, but this is the first time that I'll actually try this experiment. Go ahead, I want to see what happens!"
          )
          |> next()
          |> mes("^3355FFYou inserted items")
          |> mes("in the grooves .^000000")
          |> delitem(7030, 3)
          |> delitem(913, 10)
          |> delitem(7032, 1)
          |> next()
          |> mes("^3355FF*Crank Crank*^000000")
          |> mes("^3355FFYou hear a strange sound come from inside the statue.^000000")
          |> next()
          |> mes("^3355FF*Click*")
          |> mes("*Click Click*^000000")
          |> next()
          |> mes(
            "^3355FFA small hole opened near the foot of the statue, and a ^9999FF Stamp of Muriniel^3355FF came out of the hole.^000000"
          )
          |> next()
          |> mes("^3355FFYou got ^9999FFA piece from the Stamp of Muriniel^3355FF.^000000")
          |> next()
          |> mes("[Yklah]")
          |> mes(
            "Huh?! That piece seems to fit to the stamp you have. Why don't you try joining them together?"
          )
          |> next()
          |> mes("^3355FFYou join the two stamps together.^000000")
          |> next()
          |> mes("^3355FFYou got the")
          |> mes("True Stamp of Muriniel.^000000")
          |> set_char_var(:dmdswrd_Q, 25)
          |> next()
          |> mes("[Yklah]")
          |> mes("Oh? This pattern is...!! Ah, now I see how it works. Now, please listen...")
          |> next()
          |> mes("[Yklah]")
          |> mes(
            "I'd like you to bring the slate to Snotora, the island of knowledge, that is a part of Juno. You will find a Statue of the Goddess Snotora somewhere on the island."
          )
          |> next()
          |> mes("[Yklah]")
          |> mes(
            "Near the statue, you will find ^3355FFSyklah^000000, one of well-known 3 sages in Juno. Speak to him, he will tell you something about the pattern on the slate."
          )
          |> next()
          |> mes("[Yklah]")
          |> mes("May God")
          |> mes("light your way...")
          |> close()
        else
          ctx
          |> mes("[Yklah]")
          |> mes(
            "Let me tell you everything I know about the doomed sword. There's an old song about the legendary doomed sword..."
          )
          |> next()
          |> mes("[Yklah]")
          |> mes(
            "^3355FFYou, the one with sincere faith, who humbly accepts the prosperity of Mineta, the knowledge of Snotora and the honor of Solomon...^000000"
          )
          |> next()
          |> mes("[Yklah]")
          |> mes(
            "^3355FFI hereby grant you this column of light. The Three Sages of Juno will be your guide^000000."
          )
          |> next()
          |> mes("[Yklah]")
          |> mes(
            "Well, if you already know a little bit about Juno, you'd know that Juno consists of 3 islands that represent propsperity, knowledge and honor."
          )
          |> next()
          |> mes("[Yklah]")
          |> mes(
            "The 3 sages described in the song represent each island. By now, you've probably guessed that I am one of them."
          )
          |> next()
          |> mes("[Yklah]")
          |> mes(
            "There is a Juno tradition in which the three best Sages are chosen to represent each of Juno's islands."
          )
          |> next()
          |> mes("[Yklah]")
          |> mes(
            "As one of the three, I will serve as one of your guides in this part of your journey for the doomed sword."
          )
          |> next()
          |> mes(
            "^3355FFYklah pointed at a pole of the statue with his finger, and you see that there is a strange pattern engraved on the pole.^000000"
          )
          |> next()
          |> mes("[Yklah]")
          |> mes(
            "Now, look at this. This statue was erected to pay tribute to one of the first 3 sages. When you look into the bottom of the pole, you will see several small grooves."
          )
          |> next()
          |> mes("[Yklah]")
          |> mes(
            "If you insert some items in the grooves, we may get some more clues relating to the doomed sword."
          )
          |> next()
          |> describe_materials()
        end

      25 ->
        describe_materials(ctx)

      _ ->
        ctx
        |> mes("[Yklah]")
        |> mes("^3355FFJuphero^000000...")
        |> mes("That was the name of the city that once existed in ancient times.")
        |> next()
        |> mes("[Yklah]")
        |> mes(
          "The most intelligent and talented people of that time lived there, harnessing the pieces of Ymir's heart to power their civilization."
        )
        |> next()
        |> mes("[Yklah]")
        |> mes(
          "Unfortunately, they happened to abuse that great power and somehow destroyed themselves."
        )
        |> next()
        |> mes("[Yklah]")
        |> mes("If you long to acquire God's knowledge, you must first be humble. Otherwise...")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp describe_materials(ctx) do
    ctx
    |> mes("[Yklah]")
    |> mes(
      "From the stories that I've been told by great Sages, I've figured exactly which items you'll need to place into those grooves."
    )
    |> next()
    |> mes("[Yklah]")
    |> mes("You will need...")
    |> mes("^3355FF3 Claw of Desert Wolf^000000")
    |> mes("^3355FF10 Tooth of Bat^000000")
    |> mes("^3355FF1 Piece of Egg Shell^000000.")
    |> next()
    |> mes("[Yklah]")
    |> mes(
      "Return once you have obtained those items, and we will speak of the doomed sword again."
    )
    |> next()
    |> mes("[Yklah]")
    |> mes(
      "For your information, you can obtain the claw of desert wolf from the Morocc desert, and the tooth of bat can be found in most caves around the world."
    )
    |> next()
    |> mes("[Yklah]")
    |> mes(
      "Lastly, the piece of egg shell can be found from solid egg monsters in the Payon cave."
    )
    |> close()
  end
end
