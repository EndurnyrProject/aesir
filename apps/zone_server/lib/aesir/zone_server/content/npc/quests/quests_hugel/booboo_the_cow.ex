defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.BoobooTheCow do
  @moduledoc """
  Booboo the cow offers a milking challenge based on her mood and song.

  ## Behavior

  - Consumes three Concentration Potions for each attempt.
  - Requires the correct brush count and missing song word to complete milking.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  - Corrected song 2's `Brrboo` to `Brrbrr` so only the intended word differs.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "hugel", x: 68, y: 99, dir: 3, sprite: 889, name: "Booboo the Cow", scope: :shared}
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :hg_milk, 0) in [7, 12] do
      {ctx, choice} =
        ctx
        |> mes("[Booboo]")
        |> mes("Boop boop boo~")
        |> mes("Booboo Boop boo!")
        |> next()
        |> mes("^804000It seems that")
        |> mes("Booboo the cow")
        |> mes("has something that")
        |> mes("she wants to tell you.^000000")
        |> next()
        |> select(["Attempt to Milk Booboo", "It's not the right time!"])

      case choice do
        1 ->
          attempt_milking(ctx)

        2 ->
          ctx
          |> mes("^3355FFMaybe you should learn more")
          |> mes("about Booboo the cow, and")
          |> mes("get more information before")
          |> mes("you can attempt to milk her.^000000")
          |> close()

        _ ->
          ctx
      end
    else
      ctx
      |> mes("[Booboo]")
      |> mes("Booo~Boooo!!")
      |> mes("Boobooboo Booo~~~")
      |> mes("Booboo Boop~")
      |> close()
    end
  end

  defp attempt_milking(ctx) do
    if count_item(ctx, 645) > 2 do
      {sound, strokes} =
        case Enum.random(1..5) do
          1 -> {"cow_01.wav", 3}
          2 -> {"cow_02.wav", 5}
          3 -> {"cow_03.wav", 10}
          4 -> {"cow_04.wav", 0}
          5 -> {"cow_05.wav", 1}
        end

      milk_cow(ctx, sound, strokes)
    else
      ctx
      |> mes("^3355FFTo use this comb to")
      |> mes("brush Booboo the cow,")
      |> mes("you will need to insert")
      |> mes("3 Concentration Potions.")
      |> mes("You can only brush Booboo")
      |> mes("with this luxurious magic comb.^000000")
      |> close()
    end
  end

  defp milk_cow(ctx, sound, strokes) do
    {ctx, brush_count} =
      ctx
      |> mes("^3355FFThis giant magic comb was")
      |> mes("specially ordered from Geffen's")
      |> mes("Magic Academy. It is designed")
      |> mes("to operate after inserting")
      |> mes("3 Concentration Potions")
      |> mes("into its special slots.^000000")
      |> next()
      |> mes("^3355FFOnce you place your")
      |> mes("3 Concentration Potions")
      |> mes("into the comb, it begins")
      |> mes("to chime, and Booboo the")
      |> mes("cow beings to express her^FFFFFF ^3355FF feelings in the center of Hugel.^000000")
      |> delitem(645, 3)
      |> soundeffect(sound, 0)
      |> next()
      |> soundeffect(sound, 0)
      |> mes("^3355FFNow it's time for you")
      |> mes("to brush Booboo the cow.")
      |> mes("Depending on her mood,")
      |> mes("you need to brush her a")
      |> mes("certain number of times.^000000")
      |> next()
      |> input(:int)

    ctx = set_local(ctx, :cowbrush, brush_count)

    if get_local(ctx, :cowbrush, 0) != strokes do
      ctx
      |> soundeffect("taming_fail.wav", 0)
      |> mes("^3355FFAwwww...")
      |> mes("Booboo the cow looks")
      |> mes("so disappointed. She")
      |> mes("looks like she wants")
      |> mes("to close herself off")
      |> mes("from the rest of the world...^000000")
      |> close()
    else
      sing_song(ctx)
    end
  end

  defp sing_song(ctx) do
    ctx =
      ctx
      |> soundeffect("cow_06.wav", 0)
      |> mes("^3355FFBooboo the cow")
      |> mes("seems fairly content,")
      |> mes("and is singing a serenade.^000000")
      |> next()
      |> soundeffect("cow_06.wav", 0)
      |> mes("[Mrs. Booboo]")

    song = Enum.random(1..6)

    ctx =
      case song do
        1 ->
          ctx
          |> set_local(:"cowsong$", "Brrbrr")
          |> mes("^ff0000Brr~ Brrboo~ Boobooboo~^000000")
          |> mes("^0000ffBrrrrrr~ Booboo~ Boorrboo~^000000")
          |> mes("^ff0000Booruboorubrr~ Rrrrboo~^000000")
          |> mes("^0000ffRrrr~ Booboorrrr~ Boobooru~^000000")
          |> mes("^ff0000Boobooboo~ Rururu~ Booruboorub~^000000")
          |> mes("^0000ffBoo! B! Boo~~~^000000")

        2 ->
          ctx
          |> set_local(:"cowsong$", "Brrrrrr")
          |> mes("^ff0000Brr~ Brrbrr~ Boobooboo~^000000")
          |> mes("^0000ffRrrururu~ Booboo~ Boorrboo~^000000")
          |> mes("^ff0000Booruboorubrr~ Rrrrboo~^000000")
          |> mes("^0000ffRrrr~ Booboorrrr~ Boobooru~^000000")
          |> mes("^ff0000Boobooboo~ Rururu~ Booruboorub~^000000")
          |> mes("^0000ffBoo! B! Boo~~~^000000")

        3 ->
          ctx
          |> set_local(:"cowsong$", "Rrrrboo")
          |> mes("^ff0000Brr~ Brrbrr~ Boobooboo~^000000")
          |> mes("^0000ffBrrrrrr~ Booboo~ Boorrboo~^000000")
          |> mes("^ff0000Booruboorubrr~ Rurub~^000000")
          |> mes("^0000ffRrrr~ Booboorrrr~ Boobooru~^000000")
          |> mes("^ff0000Boobooboo~ Rururu~ Booruboorub~^000000")
          |> mes("^0000ffBoo! B! Boo~^000000")

        4 ->
          ctx
          |> set_local(:"cowsong$", "Boobooru")
          |> mes("^ff0000Brr~ Brrbrr~ Boobooboo~^000000")
          |> mes("^0000ffBrrrrrr~ Booboo~ Boorrboo~^000000")
          |> mes("^ff0000Booruboorubrr~ Rrrrboo~^000000")
          |> mes("^0000ffRrrr~ Booboorrrr~ Bbrrrr~^000000")
          |> mes("^ff0000Boobooboo~ Rururu~ Booruboorub~^000000")
          |> mes("^0000ffBoo! B! Boo~^000000")

        5 ->
          ctx
          |> set_local(:"cowsong$", "Boobooboo")
          |> mes("^ff0000Brr~ Brrbrr~ Boobooboo~^000000")
          |> mes("^0000ffBrrrrrr~ Booboo~ Boorrboo~^000000")
          |> mes("^ff0000Booruboorubrr~ Rrrrboo~^000000")
          |> mes("^0000ffRrrr~ Booboorrrr~ Boobooru~^000000")
          |> mes("^ff0000Bbb~ Rururu~ Booruboorub~^000000")
          |> mes("^0000ffBoo! B! Boo~^000000")

        6 ->
          ctx
          |> set_local(:"cowsong$", "B")
          |> mes("^ff0000Brr~ Brrbrr~ Boobooboo~^000000")
          |> mes("^0000ffBrrrrrr~ Booboo~ Boorrboo~^000000")
          |> mes("^ff0000Booruboorubrr~ Rrrrboo~^000000")
          |> mes("^0000ffRrrr~ Booboorrrr~ Boobooru~^000000")
          |> mes("^ff0000Boobooboo~ Rururu~ Booruboorub~^000000")
          |> mes("^0000ffBoo! Boo! Boo~^000000")

        _ ->
          ctx
      end

    {ctx, answer} =
      ctx
      |> next()
      |> mes("^3355FFHurry, respond to Booboo's song! Look for the word that is slightly")
      |> mes("different than Booboo's normal")
      |> mes("song in Burupu's notes, and then tell her the correct world without")
      |> mes("the tilde character (''~'').^000000")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"cowanswer$", answer)

    if get_local(ctx, :"cowanswer$", "") == get_local(ctx, :"cowsong$", "") do
      ctx =
        ctx
        |> soundeffect("tming_success.wav", 0)
        |> mes("^3355FFSuccess!")
        |> mes("Booboo the cow")
        |> mes("is quite happy, and")
        |> mes("you were able to milk")
        |> mes("her. Now, you should")
        |> mes("report to Kurupe.^000000")

      ctx =
        if get_char_var(ctx, :hg_milk, 0) == 12 do
          set_char_var(ctx, :hg_milk, 13)
        else
          set_char_var(ctx, :hg_milk, 8)
        end

      ctx |> setquest(12043) |> close()
    else
      ctx
      |> soundeffect("taming_fail.wav", 0)
      |> mes("^3355FFUh oh...")
      |> mes("Booboo the cow is starting")
      |> mes("to snort violently! She seems")
      |> mes("pretty angry with you, so you")
      |> mes("better get away for now...^000000")
      |> close()
    end
  end
end
