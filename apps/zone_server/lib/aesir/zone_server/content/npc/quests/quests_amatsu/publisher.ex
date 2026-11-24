defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.Publisher do
  @moduledoc """
  Introduces the Momotaro field trip and awards its participants.

  ## Behavior

  - Explains the story and admits eligible participants.
  - Completes the field trip quests and awards a random gift.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - MasterOfMuppets
    - L0ne_W0lf
    - Gepard
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "amatsu",
        x: 223,
        y: 236,
        dir: 3,
        sprite: 763,
        name: "Publisher",
        scope: :shared,
        unique_name: "Publisher#ama"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{1201, 1}]) == 0 -> overweight(ctx)
      get_char_var(ctx, :event_momo, 0) < 2 -> introduce(ctx)
      get_char_var(ctx, :event_momo, 0) == 4 -> finished(ctx)
      get_char_var(ctx, :event_momo, 0) > 1 -> reward(ctx)
      true -> ctx
    end
  end

  defp overweight(ctx) do
    ctx
    |> mes("- Wait a moment!! -")
    |> mes("- Currently you are carrying -")
    |> mes("- too many items with you. -")
    |> mes("- Please store some items into your Kafra storage -")
    |> mes("- and try again. -")
    |> close()
  end

  defp introduce(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Publisher]")
      |> mes("Hello~!!")
      |> mes("Our ^009CFFScroll Publishing Company^000000")
      |> mes("is professionally publishing")
      |> mes("tales.")
      |> mes(" ")
      |> next()
      |> mes("[Publisher]")
      |> mes("We established")
      |> mes("^3163FFMomotaro Field Trip^000000")
      |> mes("to celebrate ^009CFF<Momotaro Story>^000000 selling over a million copies.")
      |> next()
      |> mes("[Publisher]")
      |> mes("Become Momotaro and eliminate")
      |> mes("Dokebis, just like in the story!")
      |> mes("There will also be rewards.")
      |> next()
      |> select(["What is Momotaro Story?", "I want to try!", "I'm busy right now..."])

    case choice do
      1 -> story(ctx)
      2 -> register(ctx)
      3 -> busy(ctx)
      _ -> ctx
    end
  end

  defp story(ctx) do
    ctx
    |> mes("[Publisher]")
    |> mes("Eh~!? How can you not know about")
    |> mes("Momotaro? Don't they have this")
    |> mes("tale in Midgard?? Well...")
    |> mes("Let me tell you the story.")
    |> next()
    |> mes("[Publisher]")
    |> mes(
      "Long ago, there lived an old married couple. They were happy, but didn't have any children."
    )
    |> next()
    |> mes("[Publisher]")
    |> mes("One day, while old lady was doing the laundy, she found a humongous")
    |> mes("peach. She cut it in half and...")
    |> mes("'Poof!' There was a baby inside!")
    |> next()
    |> mes("[Publisher]")
    |> mes("The old man and lady were shocked.")
    |> mes("They decided to adopt that baby,")
    |> mes("and give him their love...")
    |> next()
    |> mes("[Publisher]")
    |> mes(
      "That baby grew so fast, like that beanstalk from 'Jack and Beanstalk,' and became a strong boy in only a few days."
    )
    |> mes(" ")
    |> next()
    |> mes("[Publisher]")
    |> mes("That boy's name was...")
    |> mes("<Momotaro>!!!")
    |> mes("Momotaro traveled to eliminate")
    |> mes("dokebis that were harassing")
    |> mes("the towners.")
    |> next()
    |> mes("[Publisher]")
    |> mes("He became friends with")
    |> mes("^3163FFYoyo, Picky, and Desert Wolf^000000")
    |> mes(
      "and eliminated all of the Dokebis. Then he lived happily ever after with the old couple."
    )
    |> next()
    |> mes("[Publisher]")
    |> mes("How was it?")
    |> mes("Great, right?")
    |> mes("I mean, this story sold a million copies!")
    |> close()
  end

  defp register(ctx) do
    if base_level(ctx) > 29 do
      ctx
      |> mes("[Publisher]")
      |> mes("Yay-! You look excited!")
      |> mes("You'll be ready to go soon.")
      |> mes("Please fill out this registration card.")
      |> next()
      |> mes("[Publisher]")
      |> mes("....................")
      |> mes("......Mm.....Let's see.....")
      |> mes(".............Good!")
      |> mes("Alright, then!")
      |> mes("Let it begin~~~!!!!!!!!!")
      |> mes("<Momotaro Field Trip>~!")
      |> next()
      |> warp("ama_test", 52, 35)
    else
      ctx
      |> mes("[Publisher]")
      |> mes("Hmm~")
      |> mes("Why don't you train yourself more")
      |> mes("and come back?")
      |> close()
    end
  end

  defp busy(ctx) do
    ctx
    |> mes("[Publisher]")
    |> mes("Eh?")
    |> mes("...But there are sweet rewards waiting...")
    |> close()
  end

  defp finished(ctx) do
    ctx
    |> mes("[Publisher]")
    |> mes("Ah~ What nice weather!")
    |> mes("This is the perfect weather to do some reading.")
    |> close()
  end

  defp reward(ctx) do
    ctx =
      ctx
      |> mes("[Publisher]")
      |> mes("How was it? Did you have fun?")
      |> mes("I hope you had a good time")
      |> mes("during the field trip.")
      |> mes(" ")
      |> mes(" ")
      |> next()
      |> mes("[Publisher]")
      |> mes("This is your reward for you.")
      |> mes("Please continue to enjoy stories~")
      |> mes(" ")

    ctx =
      ctx
      |> set_local(:event_momo, get_char_var(ctx, :event_momo, 0))
      |> set_char_var(:event_momo, 4)
      |> completequest(8128)
      |> completequest(8129)
      |> completequest(8130)

    ctx =
      if get_local(ctx, :event_momo, 0) == 3 do
        gift(ctx, :gift_1, [659, 633, 634, 639, 636, 628, 637, 635, 626, 641])
      else
        gift(ctx, :gift_2, [622, 627, 629, 632, 623, 619, 621, 620, 625, 624])
      end

    close(ctx)
  end

  defp gift(ctx, key, items) do
    ctx = set_local(ctx, key, Enum.random(1..10))
    give_item(ctx, Enum.at(items, get_local(ctx, key, 0) - 1), 1)
  end
end
