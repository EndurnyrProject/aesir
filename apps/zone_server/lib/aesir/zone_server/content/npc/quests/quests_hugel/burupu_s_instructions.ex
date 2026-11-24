defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.BurupuSInstructions do
  @moduledoc """
  A notebook explains how to milk Booboo the cow.

  ## Behavior

  - Reveals milking instructions after Burupu is given a rapier.
  - Clears the instructions quest after a chapter is read.

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
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "hugel",
        x: 72,
        y: 101,
        dir: 0,
        sprite: 111,
        name: "Burupu's Instructions",
        scope: :shared
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :hg_milk, 0) < 6 do
      ctx
      |> mes("^3355FFYou've found a small^000000")
      |> mes("^3355FFnotebook on the ground.^000000")
      |> close()
    else
      read_instructions(ctx)
    end
  end

  defp read_instructions(ctx) do
    {ctx, chapter} =
      ctx
      |> mes("^804000This small notebook^000000")
      |> mes("^804000contains Burupu's detailed^000000")
      |> mes("^804000instructions for milking^000000")
      |> mes("^804000Booboo the cow. Although^000000")
      |> mes("^804000it is written by hand, it^000000")
      |> mes("^804000is very well organized.^000000")
      |> next()
      |> mes("[Table of Contents]")
      |> mes(" ")
      |> mes("Chapter 1: How to Milk Booboo")
      |> mes("Chapter 2: How to Treat Booboo")
      |> mes("Chapter 3: Before You Begin")
      |> next()
      |> select(["Chapter 1", "Chapter 2", "Chapter 3"])

    case chapter do
      1 ->
        ctx
        |> mes("[Chapter 1]")
        |> mes("Booboo is a very emotionally")
        |> mes("sensitive cow that expresses")
        |> mes("herself through the power of")
        |> mes("song. You must listen to her")
        |> mes("song, determine how she feels,")
        |> mes("and then comb her just right.")
        |> next()
        |> mes("[Chapter 1]")
        |> mes("Basically, depending on")
        |> mes("how Booboo feels, you must")
        |> mes("give her the number of brush")
        |> mes("strokes that correspond to")
        |> mes("her song. I'll explain more")
        |> mes("about that in Chapter 2.")
        |> finish_reading()

      2 ->
        {ctx, part} =
          ctx
          |> mes("[Chapter 2 Contents]")
          |> mes(" ")
          |> mes("Part 1: How to Respond to")
          |> mes("Booboo the Cow's Feelings")
          |> mes("Part 2: Booboo's Songs")
          |> next()
          |> select(["Part 1", "Part 2"])

        case part do
          1 ->
            ctx
            |> mes("[Chapter 2, Part 1]")
            |> mes("Booboo the Cow usually")
            |> mes("expresses five different")
            |> mes("feelings through her songs:")
            |> mes("these are joy, sadness, anger,")
            |> mes("love, and neutral contentment.")
            |> next()
            |> mes("[Chapter 2, Part 1]")
            |> mes("^800080She is so happy^000000!")
            |> mes("When Booboo the Cow")
            |> mes("feels joy, then you go")
            |> mes("ahead and brush her")
            |> mes("hair 3 times before")
            |> mes("you can milk her.")
            |> mes("^800080 3 times^000000.")
            |> next()
            |> mes("[Chapter 2, Part 1]")
            |> mes("^800080She is as usual^000000.")
            |> mes("When she feels so-so, you need to")
            |> mes("comb her hair ^800080 5 times^000000.")
            |> next()
            |> mes("[Chapter 2, Part 1]")
            |> mes("If Booboo the cow feels")
            |> mes("sad, then you need to make")
            |> mes("her feel more loved. How")
            |> mes("do you do this? Just brush")
            |> mes("her hair at least 10 times.")
            |> next()
            |> mes("[Chapter 2, Part 1]")
            |> mes("Now, remember that when")
            |> mes("Booboo the cow is angry,")
            |> mes("you shouldn't touch her")
            |> mes("at all. Just say, ''No!'' to")
            |> mes("brushing her hair, okay?")
            |> next()
            |> mes("[Chapter 2, Part 1]")
            |> mes("If you happen to see")
            |> mes("Booboo the cow in love,")
            |> mes("then just brush her hair")
            |> mes("once. Just look for the")
            |> mes("hearts, and you'll know")
            |> mes("that she's in love, okay?")
            |> next()
            |> mes("[Chapter 2, Part 1]")
            |> mes("Whenever Booboo the")
            |> mes("cow is just feeling")
            |> mes("neutral contentment,")
            |> mes("then just brush her")
            |> mes("5 times. That's all~")
            |> finish_reading()

          2 ->
            ctx
            |> mes("[Chapter 2, Part 2]")
            |> mes("Booboo the cow will")
            |> mes("always sing this song.")
            |> mes("Keep these sounds in")
            |> mes("mind when she sings them...")
            |> next()
            |> mes("^ff0000Brr~ Brrbrr~ Boobooboo~^000000")
            |> mes("^0000ffBrrrrrr~ Booboo~ Boorrboo~^000000")
            |> mes("^ff0000Booruboorubrr~ Rrrrboo~^000000")
            |> mes("^0000ffRrrr~ Booboorrrr~ Boobooru~^000000")
            |> mes("^ff0000Boobooboo~ Rururu~ Booruboorub~^000000")
            |> mes("^0000ffBoo! B! Boo~^000000")
            |> next()
            |> mes("[Chapter 2, Part 2]")
            |> mes("When you try to milk")
            |> mes("Booboo, she will sing this")
            |> mes("song with a slight difference.")
            |> mes("Look for the difference in")
            |> mes("Booboo's song, and then")
            |> mes("hum the correct word to her.")
            |> finish_reading()

          _ ->
            ctx
        end

      3 ->
        ctx
        |> mes("[Chapter 3]")
        |> mes("If you want to milk")
        |> mes("Booboo the cow, you")
        |> mes("must first get permission")
        |> mes("from Kurupe. You will also")
        |> mes("need 3 Concentration Potions")
        |> mes("to insert into Booboo's comb.")
        |> finish_reading()

      _ ->
        ctx
    end
  end

  defp finish_reading(ctx) do
    ctx = close(ctx)

    if checkquest(ctx, 12042) > -1 do
      erasequest(ctx, 12042)
    else
      ctx
    end
  end
end
