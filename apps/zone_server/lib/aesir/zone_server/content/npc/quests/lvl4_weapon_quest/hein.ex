defmodule Aesir.ZoneServer.Content.Npc.Quests.Lvl4WeaponQuest.Hein do
  @moduledoc """
  Hein recovers his weaponsmith memories and crafts a level-four sword with the adventurer's help.

  ## Behavior

  - Checks inventory capacity before discussing his lost memories or crafting work.
  - Recognizes his father's saying and collects tools, gold, and one of two ore sets.
  - Tests luck in three rounds of rock, paper, scissors, consuming all ores on success or one ore stack on failure.
  - Awards one of two swords for the chosen ore set and resets the shared quest progress.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Vicious_Pucca
    - Reddozen
    - MasterOfMuppets
    - Silent
    - erKURITA
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "niflheim",
        x: 187,
        y: 280,
        dir: 3,
        sprite: 795,
        name: "Hein",
        scope: :shared,
        unique_name: "Hein#lv4"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case checkweight(ctx, [{908, 300}]) do
      0 -> inventory_full(ctx)
      _ -> quest_stage(ctx, get_char_var(ctx, :lv4_weapon, 0))
    end
  end

  defp quest_stage(ctx, 0), do: introduce(ctx)
  defp quest_stage(ctx, stage) when stage < 40 or stage > 48, do: other_business(ctx)
  defp quest_stage(ctx, stage) when stage in [47, 48], do: finished_weapon(ctx)

  defp quest_stage(ctx, stage) when stage in [44, 45, 46] do
    cond do
      stage == 45 and count_item(ctx, 7294) > 29 and count_item(ctx, 7297) > 29 and
          count_item(ctx, 7293) > 29 ->
        test_luck(ctx)

      stage == 46 and count_item(ctx, 7295) > 29 and count_item(ctx, 7296) > 29 and
          count_item(ctx, 7290) > 29 ->
        test_luck(ctx)

      true ->
        missing_memories(ctx)
    end
  end

  defp quest_stage(ctx, 43) do
    cond do
      count_item(ctx, 1005) > 1 and count_item(ctx, 989) > 0 and count_item(ctx, 710) > 0 and
          count_item(ctx, 969) > 19 ->
        collect_tools(ctx)

      true ->
        remind_tools(ctx)
    end
  end

  defp quest_stage(ctx, 42), do: request_tools(ctx)
  defp quest_stage(ctx, 41), do: recall_saying(ctx)
  defp quest_stage(ctx, 40), do: ctx |> forgotten_saying() |> lament_memory() |> close()
  defp quest_stage(ctx, _), do: introduce(ctx)

  defp inventory_full(ctx) do
    ctx
    |> mes(
      "^3355FFWait a second! Right now, you're carrying too many items with you. Please come back after putting some of your things into Kafra Storage.^000000"
    )
    |> close()
  end

  defp other_business(ctx) do
    ctx
    |> mes("[Hein]")
    |> mes(
      "Mm? I can tell you've here because you've got something to do. It's weird enough to see a living being here, and weirder still to see one who's here for a good reason."
    )
    |> next()
    |> mes("[Hein]")
    |> mes("Do me a favor")
    |> mes("and stay alive.")
    |> mes("Take it from me,")
    |> mes("there's no pleasure")
    |> mes("at all in being dead.")
    |> close()
  end

  defp forgotten_saying(ctx) do
    ctx
    |> mes("[Hein]")
    |> mes(
      "It looks like you want to ask me something. Heh, my customers used to have that look on that faces too when I worked as a weaponsmith..."
    )
    |> next()
    |> mes("[Hein]")
    |> mes("Back during those days,")
    |> mes(
      "I never accepted money for my work. Father always used to say, 'Never accept payment to forge a good weapon. It... It...'"
    )
    |> next()
  end

  defp lament_memory(ctx) do
    ctx
    |> mes("[Hein]")
    |> mes("What was the rest of it?")
    |> mes("Why can't I remember the")
    |> mes("rest of that saying?!")
    |> next()
    |> mes("[Hein]")
    |> mes("It's so weird.")
    |> mes("How could I forget")
    |> mes("something I used to")
    |> mes("say all the time? I...")
    |> mes("I hate being dead!")
  end

  defp introduce(ctx) do
    {ctx, choice} = ctx |> forgotten_saying() |> select(["Show interest.", "Ignore him."])

    case choice do
      1 -> ctx |> lament_memory() |> set_char_var(:lv4_weapon, 40) |> close()
      2 -> ignore_saying(ctx)
      _ -> ctx
    end
  end

  defp ignore_saying(ctx) do
    ctx
    |> mes("[Hein]")
    |> mes("Nuts! Why can't I remember")
    |> mes("the rest of that saying?!")
    |> close()
  end

  defp recall_saying(ctx) do
    {ctx, saying} = ctx |> forgotten_saying() |> input(:string)
    ctx = set_local(ctx, :"input$", saying)

    case saying do
      "It brings bad luck." -> remembered_past(ctx)
      _ -> wrong_saying(ctx)
    end
  end

  defp remembered_past(ctx) do
    ctx
    |> mes("[Hein]")
    |> mes("That's right!")
    |> mes("And you need luck when you're creating high quality weapons!")
    |> next()
    |> mes("[Hein]")
    |> mes("Oh... crap.")
    |> mes("I'm a dead man.")
    |> mes("I just realized.")
    |> mes("Or remembered.")
    |> mes("Perhaps I'm brain")
    |> mes("dead too, huh?")
    |> set_char_var(:lv4_weapon, 42)
    |> next()
    |> mes("[Hein]")
    |> mes("Well, I must be a lucky dead man for remembering some of my past, right? Hahahaha!")
    |> next()
    |> mes("[Hein]")
    |> mes(
      "Right, I died while trying to finish my weapon research. Maybe this is fate's way of allowing me to finish my uncompleted work?"
    )
    |> next()
    |> mes("[Hein]")
    |> mes(
      "Hey, let me ask you a favor. Would you bring the materials I need to finish my research? If I succeed, the finished product is yours to keep. All yours!"
    )
    |> next()
    |> mes("[Hein]")
    |> mes("Take your time")
    |> mes("and think about it.")
    |> mes("It can't be that bad")
    |> mes("of a deal... Right?")
    |> close()
  end

  defp wrong_saying(ctx) do
    ctx
    |> mes("[Hein]")
    |> mes("Wha...?")
    |> mes("What are you talking about?")
    |> mes("What was I going to say?")
    |> mes("Oww... My head hurts!")
    |> close()
  end

  defp request_tools(ctx) do
    ctx
    |> mes("[Hein]")
    |> mes("I take it that you")
    |> mes("really want me to make")
    |> mes("you a weapon. For a former")
    |> mes("weaponsmith like me, that in")
    |> mes("itself is a great compliment.")
    |> next()
    |> mes("[Hein]")
    |> mes("Alright, I'll need...")
    |> mes("1 Emperium Anvil,")
    |> mes("2 Hammer of Blacksmith,")
    |> mes("1 Illusion Flower and")
    |> mes("20 Gold...")
    |> next()
    |> mes("[Hein]")
    |> mes("There were 3 other things,")
    |> mes(
      "but I'm not too sure what they were. I guess a bunch of memories from my life are still missing."
    )
    |> next()
    |> mes("[Hein]")
    |> mes(
      "^333333*Sigh*^000000 I'm sorry to ask this of you, but would you please go out and figure out what those things are? I'm sure you can find some clue in the land of the living."
    )
    |> next()
    |> mes("[Hein]")
    |> mes(
      "While you do that, I'll try my best to remember what else I need to make this weapon."
    )
    |> set_char_var(:lv4_weapon, 43)
    |> close()
  end

  defp remind_tools(ctx) do
    ctx
    |> mes("[Hein]")
    |> mes("For sure I'll need")
    |> mes("2 Hammer of Blacksmith,")
    |> mes("1 Emperium Anvil,")
    |> mes("1 Illusion Flower and")
    |> mes("20 Gold...")
    |> next()
    |> mes("[Hein]")
    |> mes("So for now,")
    |> mes("go ahead and")
    |> mes("bring that stuff")
    |> mes("to me, please.")
    |> close()
  end

  defp collect_tools(ctx) do
    ctx
    |> mes("[Hein]")
    |> mes("Hey, you brought everything I asked for already. You must be ready to get started!")
    |> next()
    |> mes("[Hein]")
    |> mes("Sadly, we can't begin until")
    |> mes(
      "I remember the rest of the things we need. I can't for the life of me remember the most important materials..."
    )
    |> next()
    |> mes("[Hein]")
    |> mes(
      "Well, for now, let me keep the things you've brought to me. I promise that I'll use this stuff to make you a good weapon once everything is ready."
    )
    |> delitem(1005, 2)
    |> delitem(989, 1)
    |> delitem(710, 1)
    |> delitem(969, 20)
    |> set_char_var(:lv4_weapon, 44)
    |> close()
  end

  defp missing_memories(ctx) do
    ctx
    |> mes("[Hein]")
    |> mes(
      "Would you give me more time to remember the materials? I can't seem to focus very well. It might have to do with the fact that I'm dead..."
    )
    |> next()
    |> mes("[Hein]")
    |> mes(
      "I had a much better memory when I was alive I'm sure. My father would quiz me on this stuff all the time..."
    )
    |> close()
  end

  defp finished_weapon(ctx) do
    ctx
    |> mes("[Hein]")
    |> mes("You're here!")
    |> mes("I just finished my work!")
    |> mes("You want to see it, don't you?")
    |> mes("Now, take a deep breath...")
    |> next()
    |> award_weapon(Enum.random(1..2))
    |> set_char_var(:lv4_weapon, 0)
    |> next()
    |> farewell()
  end

  defp award_weapon(ctx, roll) do
    ctx
    |> mes("[Hein]")
    |> mes("Haha~!")
    |> mes("This is great!")
    |> mes("Finally, my life's")
    |> mes("work is complete!")
    |> mes("This weapon's name")
    |> sword_reward(get_char_var(ctx, :lv4_weapon, 0), roll)
  end

  defp sword_reward(ctx, 47, 1), do: ctx |> mes("is Edge!") |> give_item(1132, 1)
  defp sword_reward(ctx, 47, _), do: ctx |> mes("is Excalibur!") |> give_item(1137, 1)
  defp sword_reward(ctx, _, 1), do: ctx |> mes("is Dragon Slayer!") |> give_item(1166, 1)
  defp sword_reward(ctx, _, _), do: ctx |> mes("is Schweizersabel!") |> give_item(1167, 1)

  defp farewell(ctx) do
    ctx
    |> mes("[Hein]")
    |> mes("Well...")
    |> mes(
      "It looks like this is goodbye for now. I can already feel my memory getting hazier. Haha, being dead is definitely not good."
    )
    |> next()
    |> mes("[Hein]")
    |> mes("Thank you for your help. If you come back and help me retrieve")
    |> mes("my memories again, I'll try to help you as well. So long, adventurer...")
    |> close()
  end

  defp test_luck(ctx) do
    ctx
    |> mes("[Hein]")
    |> mes("Mm...?")
    |> mes(
      "The stuff you brought seems to be just what I need to finish my work. Let me have a look at them..."
    )
    |> next()
    |> mes("[Hein]")
    |> mes("Wow...")
    |> mes("How did you know the materials")
    |> mes(
      "I needed? It's almost too good to be true! Alright, we're that much closer to finishing my life's work!"
    )
    |> next()
    |> mes("[Hein]")
    |> mes(
      "Oh, that's right. Skill alone isn't enough to create this. We'll also need your luck. First of all, we need to test if your luck is good today."
    )
    |> next()
    |> mes("[Hein]")
    |> mes(
      "We're going to play '^660000Rock, Paper, Scissors^000000.' If you win at least 2 out of 3, we'll go ahead and start crafting this thing!"
    )
    |> next()
    |> mes("[Hein]")
    |> mes(
      "But if you fail in this game, I'll have to expel your negative luck by throwing out a lot of one of the ores you've brought along."
    )
    |> next()
    |> mes("[Hein]")
    |> mes("Here's a piece of paper.")
    |> mes(
      "When I tell you to, write down 'Rock,' 'Paper' or 'Scissors.' I'll do the same thing, and we'll compare our results at the end, okay? Let's begin!"
    )
    |> next()
    |> choose_hand(:npchand1, :myhand1)
    |> score_round(:npchand1, :myhand1)
    |> mes("[Hein]")
    |> mes("Okay, let's play")
    |> mes("the second round!")
    |> next()
    |> choose_hand(:npchand2, :myhand2)
    |> score_round(:npchand2, :myhand2)
    |> mes("[Hein]")
    |> mes("Okay...")
    |> mes("Last round.")
    |> mes("After this, we")
    |> mes("compare our results.")
    |> next()
    |> choose_hand(:npchand3, :myhand3)
    |> set_local(:aekddam, Enum.random(1..3))
    |> score_round(:npchand3, :myhand3)
    |> consume_ores()
    |> compare_hands()
    |> luck_result()
  end

  defp choose_hand(ctx, npc_key, player_key) do
    {ctx, hand} =
      ctx
      |> set_local(npc_key, Enum.random(1..3))
      |> select(["Scissors", "Rock", "Paper"])

    set_local(ctx, player_key, hand)
  end

  defp score_round(ctx, npc_key, player_key) do
    case {get_local(ctx, player_key, 0), get_local(ctx, npc_key, 0)} do
      {1, 3} -> set_local(ctx, :shobu, get_local(ctx, :shobu, 0) + 1)
      {2, 1} -> set_local(ctx, :shobu, get_local(ctx, :shobu, 0) + 1)
      {3, 2} -> set_local(ctx, :shobu, get_local(ctx, :shobu, 0) + 1)
      _ -> ctx
    end
  end

  defp consume_ores(ctx) do
    ores =
      case get_char_var(ctx, :lv4_weapon, 0) do
        45 -> [7294, 7297, 7293]
        _ -> [7295, 7296, 7290]
      end

    cond do
      get_local(ctx, :shobu, 0) > 1 ->
        ctx = Enum.reduce(ores, ctx, fn ore, ctx -> delitem(ctx, ore, 30) end)
        set_char_var(ctx, :lv4_weapon, get_char_var(ctx, :lv4_weapon, 0) + 2)

      get_local(ctx, :shobu, 0) < 2 ->
        case get_local(ctx, :aekddam, 0) do
          1 -> delitem(ctx, Enum.at(ores, 0), 30)
          2 -> delitem(ctx, Enum.at(ores, 1), 30)
          3 -> delitem(ctx, Enum.at(ores, 2), 30)
          _ -> ctx
        end

      true ->
        ctx
    end
  end

  defp compare_hands(ctx) do
    ctx
    |> mes("[Hein]")
    |> mes("Ready? This is")
    |> mes("what I wrote down...")
    |> show_hand(:npchand1)
    |> show_hand(:npchand2)
    |> show_hand(:npchand3)
    |> next()
    |> mes("[Hein]")
    |> mes("You wrote down")
    |> mes("these answers in")
    |> mes("this order...")
    |> show_hand(:myhand1)
    |> show_hand(:myhand2)
    |> show_hand(:myhand3)
    |> next()
  end

  defp show_hand(ctx, key) do
    case get_local(ctx, key, 0) do
      1 -> mes(ctx, "Scissors")
      2 -> mes(ctx, "Rock")
      3 -> mes(ctx, "Paper")
      _ -> ctx
    end
  end

  defp luck_result(ctx) do
    cond do
      get_local(ctx, :shobu, 0) > 1 -> lucky(ctx)
      get_local(ctx, :shobu, 0) < 2 -> unlucky(ctx)
      true -> missing_memories(ctx)
    end
  end

  defp lucky(ctx) do
    ctx
    |> mes("[Hein]")
    |> mes("Let's see...")
    |> mes("You won #{get_char_var(ctx, :shobu, 0)} times.")
    |> mes("You're really good at game!")
    |> mes("Yes, your luck is at its highest!")
    |> next()
    |> mes("[Hein]")
    |> mes(
      "As promised, I will craft a weapon for you. Give me the materials now, and come back when I'm finished preparing."
    )
    |> close()
  end

  defp unlucky(ctx) do
    ctx
    |> mes("[Hein]")
    |> mes("Well, you lost.")
    |> mes("I'm sorry, but we")
    |> mes("need to expel the")
    |> mes("misfortune around you")
    |> mes("with the ore you've brought...")
    |> next()
    |> mes("[Hein]")
    |> mes("Okay, I'll wait here.")
    |> mes("Come back with the materials")
    |> mes("I need and we'll try this again.")
    |> close()
  end
end
