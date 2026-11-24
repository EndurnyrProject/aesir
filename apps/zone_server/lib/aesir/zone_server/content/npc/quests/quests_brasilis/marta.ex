defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.Marta do
  @moduledoc """
  Marta tells the story of the Brasilis water lily.

  ## Behavior

  - Tells Naia’s story to adventurers who have begun the Water Lily quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - og2
    - Euphy
    - Capuche
    - Daegaladh

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "bra_in01",
        x: 142,
        y: 27,
        dir: 5,
        sprite: 474,
        name: "Marta",
        scope: :shared,
        unique_name: "Marta#bra"
      },
      %{
        map: "bra_in01",
        x: 145,
        y: 27,
        dir: 3,
        sprite: 472,
        name: "Brasilis Boy",
        scope: :shared,
        unique_name: "Brasilis Boy#bra"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :brazil_regia, 0) do
      1 -> tell_story(ctx)
      progress when progress > 1 -> busy(ctx)
      _ -> greet(ctx)
    end
  end

  defp tell_story(ctx) do
    ctx
    |> mes("[Brasilis Boy]")
    |> mes("Grandma! That person has a weird smell.")
    |> next()
    |> mes("[Marta]")
    |> mes("This person isn't from here.")
    |> mes("Say hello to our guest.")
    |> next()
    |> mes("[Brasilis Boy]")
    |> mes("heee~ hi!!")
    |> mes("I am Kaka!!")
    |> mes("Whats your name?")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("I am #{char_name(ctx, 0)}.")
    |> next()
    |> mes("[Brasilis Boy]")
    |> mes("The outsider has a weird name!")
    |> mes("Thas ok! If we keep talking we'll be friends! Cheer up!")
    |> next()
    |> mes("[Marta]")
    |> mes("Hehe...")
    |> mes("So, why have you come here stranger~?")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("I heard you knows lots of stories, is that true?")
    |> next()
    |> mes("[Kaka]")
    |> mes("Wooo! how you know my grandma knows lots of stories, amazing~?")
    |> mes("Grandma is really wise and kind so, I heard lotsa things.")
    |> next()
    |> mes("[Marta]")
    |> mes("Hehe. Kaka always listens to many stories every night, he really likes my stories.")
    |> mes(
      "Kaka always makes me happy because he asks so many curious things. That is pure happiness."
    )
    |> next()
    |> mes("[Marta]")
    |> mes("Ok, Kaka why don't you invite our guest today to our small meeting?")
    |> next()
    |> mes("[Kaka]")
    |> mes("Ok grandma~!!")
    |> next()
    |> mes("[Marta]")
    |> mes("Hey~ do you have special story that you want to listen to?")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("About the mysterious water lily?")
    |> next()
    |> mes("[Marta]")
    |> mes("Water lily....")
    |> mes("It's from a long long time ago.")
    |> next()
    |> mes("[Marta]")
    |> mes("Before Brasilis was established.")
    |> mes(
      "A tribe that lived with the giant waterfall and jungle as friends spent their whole time with nature."
    )
    |> next()
    |> mes("[Marta]")
    |> mes("One of tribe chiefs had a pretty daughter called 'Naia'.")
    |> next()
    |> mes("[Marta]")
    |> mes(
      "Naia liked listening to stories like Kaka so, her mom told her stories every night about nature and gods."
    )
    |> next()
    |> mes("[Kaka]")
    |> mes("Woooa, she's just like me!")
    |> mes("Maybe she would be pretty... hehe.")
    |> next()
    |> mes("[Marta]")
    |> mes("According to her mother...")
    |> mes(
      "If the moon in the sky loves some woman in the earth, he turns her into a star so that they can stay together forever."
    )
    |> next()
    |> mes("[Marta]")
    |> mes("After Naia heard this story, she went to her dad to ask if it was true or not.")
    |> next()
    |> mes("[Kaka]")
    |> mes("So, what did he say?")
    |> next()
    |> mes("[Marta]")
    |> mes(
      "^3131FF'My dear, Naia the moon is one of the bravest men. But he can no longer have a bride. So you can't become a star... Sorry~.^000000"
    )
    |> next()
    |> mes("[Kaka]")
    |> mes("Did Naia wants to be the bride of the man?")
    |> next()
    |> mes("[Marta]")
    |> mes(
      "Yes Kaka, imagine the moon how beautiful and mysterious, that's just ideal for girls."
    )
    |> next()
    |> mes("[Kaka]")
    |> mes("But the moon doesn't meet a human as his wife anymore? What was going on with Naia?")
    |> next()
    |> mes("[Marta]")
    |> mes("Naia was really a nice girl.")
    |> next()
    |> mes("[Marta]")
    |> mes(
      "Although her parents tried to prevent her, she still went to the forest to meet the moon every night."
    )
    |> mes("Sadly, even with all of her effort, the moon didn't show any reaction to her.")
    |> next()
    |> mes("[Marta]")
    |> mes(
      "One day she also went to the top of the mountain to be closer to him. She decided to take a rest for a while around the lake."
    )
    |> next()
    |> mes("[Marta]")
    |> mes("That's when.. Naia saw it.")
    |> mes("It was the moon he was shining beautifully over the waving lake lightly.")
    |> next()
    |> mes("[Kaka]")
    |> mes("I know, it's just the moon reflecting on the water. Right?!")
    |> next()
    |> mes("[Marta]")
    |> mes(
      "Yes, but to her, the image made her fall into the lake without hesitating and drowned."
    )
    |> next()
    |> mes("[Kaka]")
    |> mes("Oh no.")
    |> next()
    |> mes("[Marta]")
    |> mes("The moon was also watching her from the sky.")
    |> mes(
      "He felt sad and pitied her. So he decided to turn her into a beautiful flower to thank her for her love."
    )
    |> next()
    |> mes("[Marta]")
    |> mes("That is the story of the mysterious flower people called the Brasilis Water Flower.")
    |> mes(
      "This Naia flower appears as light white during daytime but in the night turns into red due to it's love connection to the moon."
    )
    |> next()
    |> mes("[Kaka]")
    |> mes("How sad but beautiful!")
    |> next()
    |> mes("[Marta]")
    |> mes("How about you stranger?")
    |> mes("Did you enjoy this story?")
    |> mes("If you want to listen to another story, just come to me.")
    |> mes("If you don't mind playing with my grandson a ~ little. hoohoo.")
    |> set_char_var(:brazil_regia, 2)
    |> close()
  end

  defp busy(ctx) do
    ctx
    |> mes("[Kaka]")
    |> mes("My grandma is really a bit tired doing some tribe stuff!")
    |> mes("Could you come another day?")
    |> close()
  end

  defp greet(ctx) do
    ctx
    |> mes("[Marta]")
    |> mes("You are not from around here.")
    |> mes("I can sense a strange earth smell.")
    |> next()
    |> mes("[Marta]")
    |> mes("But your eyes shine with strength.")
    |> mes("Indeed you are spreading out spirit and will from your whole body.")
    |> next()
    |> mes("[Marta]")
    |> mes("If you work at it you will be a great person someday.")
    |> close()
  end
end
