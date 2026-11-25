defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.SuspiciousMan do
  @moduledoc """
  Oliver Hilpert continues the Crow of Fate quest.

  ## Behavior

  - He offers a picture-book exchange and, after the dream, concludes the quest.

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
        x: 169,
        y: 123,
        dir: 3,
        sprite: 407,
        name: "Suspicious Man",
        scope: :shared,
        unique_name: "Suspicious Man#oliver_h"
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

      get_char_var(ctx, :barmunt_crow, 0) > 14 ->
        writing(ctx)

      get_char_var(ctx, :barmunt_crow, 0) == 13 ->
        offer_book(ctx)

      get_char_var(ctx, :barmunt_crow, 0) == 14 ->
        return_note(ctx)

      true ->
        ctx
        |> mes(
          "^660000A suspicious-looking young man is searching passing faces as if he is looking for someone.^000000"
        )
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp writing(ctx) do
    ctx
    |> mes("^660000The writer was writing in the notebook at an extremely fast pace.^000000")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes(
      "Let's not disturb him, especially when he is full of creative ideas. That doesn't happen very often."
    )
    |> close()
  end

  defp offer_book(ctx) do
    ctx = cutin(ctx, "oliver_pre", 2)

    if count_item(ctx, 7795) < 1 do
      ctx |> mes("[Oliver Hilpert]") |> mes("Lady Mammi...") |> close2() |> cutin("", 255)
    else
      ask_to_sell(ctx)
    end
  end

  defp ask_to_sell(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Oliver Hilpert]")
      |> mes("Did you change your mind about selling Lady Mammi's picture book to me?")
      |> next()
      |> select(["Yes", "No"])

    case choice do
      1 ->
        sell_book(ctx)

      2 ->
        ctx
        |> mes("[Oliver Hilpert]")
        |> mes("Okay... I see...")
        |> emotion(:cry)
        |> close2()
        |> cutin("", 255)

      _ ->
        ctx
    end
  end

  defp sell_book(ctx) do
    ctx
    |> cutin("oliver_smile", 2)
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
    |> next()
    |> cutin("oliver_smile", 255)
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
  end

  defp return_note(ctx) do
    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("This dream seems pretty meaningful somehow.")
      |> mes("I'd better give him this note back.")
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Excuse me, Mr. Hilpert.")
      |> next()
      |> cutin("oliver_think", 2)
      |> mes("[Oliver Hilpert]")
      |> mes(".................")
      |> mes(".................")
      |> mes("...........Huh?")
      |> next()
      |> cutin("oliver_think", 255)
      |> mes("You felt sorry for interrupting him from writing.")
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("I think you've dropped this.")
      |> next()
      |> mes(
        "^660000You rummaged your pocket to find the memo, and then happened to drop the crow feather which you picked up outside the library. Then suddenly...^000000"
      )
      |> next()
      |> mes("(WHACK)")
      |> specialeffect(:venomdust)
      |> specialeffect2(:detoxication)
      |> next()
      |> mes(
        "^660000Oliver picked up the feather more quickly than you could, and then tore it into pieces before you could even say anything.^000000"
      )
      |> next()
      |> mes(
        "^660000You looked angrily at him, and found out that he turned into a completely different person; he no longer looked stupid or serious but extremely coldhearted.^000000"
      )
      |> next()
      |> cutin("oliver_hum", 2)
      |> mes("[Oliver Hilpert]")
      |> mes("Errr?!")
      |> mes("What's happened to this feather?")
      |> next()
      |> mes("[Oliver Hilpert]")
      |> emotion(:kek)
      |> mes("Wah! Did I do this?")
      |> mes("Oh my god, I'm sorry! I'm so sorry!")
      |> next()
      |> mes(
        "^660000He changed back to himself, and started apologizing to you for his sudden rage.^000000"
      )
      |> next()
      |> emotion(:cry)
      |> mes("[Oliver Hilpert]")
      |> mes("I... I don't know how to apologize...")
      |> mes("It's just that... I became so angry that I--! Argh, I'm sorry!")
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes(
        "Well, it's okay. I happened to pick it up from the street. You don't have to apologize."
      )
      |> next()
      |> mes("[Oliver Hilpert]")
      |> mes("If you say so, thank you for your understanding.")
      |> mes("Phew, I felt so guilty...")
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Here, take your memo back.")
      |> next()
      |> mes("[Oliver Hilpert]")
      |> mes("Oh, you can just throw it away. It's no longer useful.")
      |> mes("Phew...")
      |> next()
      |> cutin("oliver_pre", 2)
      |> mes("[Oliver Hilpert]")
      |> mes("I'm having great ideas right now. I'm sorry, but I should go.")
      |> next()
      |> cutin("oliver_pre", 255)
      |> mes(
        "^660000As soon as he talked to you, he went back to his writing and became completely absorbed in his work.^000000"
      )
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("He has such amazing concentration.")
      |> mes("I guess not everyone can make bestselling books, huh?")
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("...Wait, I'm not sneezing anymore...")
      |> mes("The headache and the heavy feeling in my chest is gone too!")
      |> next()

    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("What if it was all caused by that crow feather? What if...?")
      |> next()
      |> select([
        "It was cursed by the pebble.",
        "The crow has something to do with Oliver."
      ])

    case choice do
      1 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Ah, I see.")
        |> mes(
          "I think when the crow was hit by the pebble, its wisdom must have turned into disaster."
        )
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Argh, that was all because of the library master!")
        |> mes("Luckily the feather is gone, so hopefuly I won't suffer any more disaster.")
        |> next()
        |> finish_quest()

      2 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("I remember Mr. Zid saying Eva had left a black feather behind her.")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes(
          "Also, the female assistant turned into a crow flying away, and then the crow feather made me sneeze and cough."
        )
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("..................")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Yes, Mr. Hilpert's soul is cursed by the Crow!")
        |> mes("I wonder if he threw rocks at crows like the library master...")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("..................")
        |> mes("I guess it's a stupid idea.")
        |> next()
        |> finish_quest()

      _ ->
        ctx
    end
  end

  defp finish_quest(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Oh well, whatever.")
    |> mes("What matters is that I'm cured!")
    |> mes("If I have another dream, I'll deal with it then~")
    |> next()
    |> mes(
      "^660000As you left the library, you thought that thinking Mr. Oliver is your half would be a better idea.^000000"
    )
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes(
      "That was pretty fun, but also pretty tiring. Where should I head for my next adventure?"
    )
    |> set_char_var(:barmunt_crow, 15)
    |> completequest(2068)
    |> close2()
    |> cutin("", 255)
  end
end
