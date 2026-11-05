defmodule Aesir.ZoneServer.Content.Npc.Quests.Lvl4WeaponQuest.Reyghema do
  @moduledoc """
  Reyghema recovers his weaponsmith memories and completes his final weapon experiment with an adventurer's help.

  ## Behavior

  - Requires spare carrying capacity and base level 80 before discussing his work.
  - Recognizes his father's saying and collects tools, gold, and one of two ore sets.
  - Tests luck in three rounds of rock, paper, scissors, consuming all ores on success or one ore stack on failure.
  - Awards one of two weapons for the chosen ore set and resets the shared quest progress.

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
        x: 99,
        y: 268,
        dir: 5,
        sprite: 794,
        name: "Reyghema",
        scope: :shared,
        unique_name: "Reyghema#lv4"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :MaxWeight, 0) - weight(ctx) < 3000 -> inventory_full(ctx)
      base_level(ctx) < 80 -> warn_living(ctx)
      true -> quest_stage(ctx, get_char_var(ctx, :lv4_weapon, 0))
    end
  end

  defp quest_stage(ctx, 0), do: introduce(ctx)
  defp quest_stage(ctx, stage) when stage < 31 or stage > 39, do: other_business(ctx)
  defp quest_stage(ctx, stage) when stage in [38, 39], do: finished_weapon(ctx)

  defp quest_stage(ctx, stage) when stage in [35, 36, 37] do
    cond do
      stage == 36 and count_item(ctx, 7292) > 29 and count_item(ctx, 7293) > 29 and
          count_item(ctx, 7289) > 29 ->
        test_luck(ctx)

      stage == 37 and count_item(ctx, 7297) > 29 and count_item(ctx, 7291) > 29 and
          count_item(ctx, 7295) > 29 ->
        test_luck(ctx)

      true ->
        missing_memories(ctx)
    end
  end

  defp quest_stage(ctx, 34) do
    cond do
      count_item(ctx, 1005) > 1 and count_item(ctx, 989) > 0 and count_item(ctx, 710) > 0 and
          count_item(ctx, 969) > 19 ->
        collect_tools(ctx)

      true ->
        remind_tools(ctx)
    end
  end

  defp quest_stage(ctx, 33), do: request_tools(ctx)
  defp quest_stage(ctx, 32), do: recall_saying(ctx)
  defp quest_stage(ctx, 31), do: ctx |> forgotten_saying() |> lament_memory() |> close()
  defp quest_stage(ctx, _), do: introduce(ctx)

  defp inventory_full(ctx) do
    ctx
    |> mes(
      "^3355FFWait a second! Right now, you're carrying too many items with you. Please come back after putting some of your things into Kafra Storage.^000000"
    )
    |> close()
  end

  defp warn_living(ctx) do
    ctx
    |> mes("[Reyghema]")
    |> mes("How...")
    |> mes("the hell...?")
    |> next()
    |> mes("[Reyghema]")
    |> mes(
      "What's a living person doing here? Stick around and I guarantee that you won't be alive much longer. Come on, you don't want to end up like me. Hurry and get out of here!"
    )
    |> close()
  end

  defp other_business(ctx) do
    ctx
    |> mes("[Reyghema]")
    |> mes("Hey...")
    |> mes("It feels like you came")
    |> mes("here to finish something.")
    |> mes(
      "Yeah, there's a complete difference between someone who's aimless and someone with a purpose."
    )
    |> next()
    |> mes("[Reyghema]")
    |> mes(
      "I almost feel sorry for you though, if you have business to finish in a place like Niflheim."
    )
    |> close()
  end

  defp forgotten_saying(ctx) do
    ctx
    |> mes("[Reyghema]")
    |> mes("Damn it...")
    |> mes("I didn't want to die!")
    |> next()
    |> mes("[Reyghema]")
    |> mes(
      "Well, nothing that's alive really wants to die, but I was so close to finishing what I wanted to do. Ah, youth..."
    )
    |> next()
    |> mes("[Reyghema]")
    |> mes("Youth...")
    |> mes("Enjoy your youth...")
    |> mes("I remember hearing")
    |> mes("something like that,")
    |> mes("but there was more to it...")
    |> next()
  end

  defp lament_memory(ctx) do
    ctx
    |> mes("[Reyghema]")
    |> mes("Enjoy your youth...")
    |> mes("Enjoy your youth...")
    |> mes("...What came after that?")
    |> next()
    |> mes("[Reyghema]")
    |> mes("Argh!")
    |> mes("I can't remember!")
    |> mes("Everything in my")
    |> mes("head is so cloudy!")
  end

  defp introduce(ctx) do
    {ctx, choice} = ctx |> forgotten_saying() |> select(["Show interest.", "Ignore him."])

    case choice do
      1 -> ctx |> lament_memory() |> set_char_var(:lv4_weapon, 31) |> close()
      2 -> ignore_saying(ctx)
      _ -> ctx
    end
  end

  defp ignore_saying(ctx) do
    ctx
    |> mes("[Reyghema]")
    |> mes("Enjoy your youth...")
    |> mes("Enjoy your youth...")
    |> mes("...What came after that?")
    |> close()
  end

  defp recall_saying(ctx) do
    {ctx, saying} = ctx |> forgotten_saying() |> input(:string)
    ctx = set_local(ctx, :"input$", saying)

    case saying do
      "Live without regret." -> remembered_past(ctx)
      _ -> wrong_saying(ctx)
    end
  end

  defp remembered_past(ctx) do
    ctx
    |> mes("[Reyghema]")
    |> mes("...")
    |> next()
    |> mes("[Reyghema]")
    |> mes("...")
    |> mes(".......")
    |> mes("Enjoy your youth.")
    |> mes("Live without regret.")
    |> next()
    |> mes("[Reyghema]")
    |> mes("Of course...")
    |> mes("My father, Bill Thayer used to say that all the time! That's right!")
    |> next()
    |> mes("[Reyghema]")
    |> mes(
      "Hey you, thanks for refreshing my memory. It's all coming back to me. I used to be a weaponsmith, but I regret never finishing my final project..."
    )
    |> next()
    |> mes("[Reyghema]")
    |> mes("You just gotta help me realize")
    |> mes("my final goal. Even if I am dead,")
    |> mes("I really wanna complete the experiment that got me killed.")
    |> next()
    |> mes("[Reyghema]")
    |> mes(
      "All you need to do for now is bring me the things I need. I don't think I'll be able to gather much, being here in Niflheim and all."
    )
    |> next()
    |> mes("[Reyghema]")
    |> mes("Come back a little later.")
    |> mes("By then, I should remember what kinds of things I'll need.")
    |> set_char_var(:lv4_weapon, 33)
    |> close()
  end

  defp wrong_saying(ctx) do
    ctx
    |> mes("[Reyghema]")
    |> mes("What...?")
    |> mes("You playin' games")
    |> mes("with me or what?")
    |> mes("Get outta my face~")
    |> close()
  end

  defp request_tools(ctx) do
    ctx
    |> mes("[Reyghema]")
    |> mes(
      "Alright, you're back. I remember most of the things I'll be needing. Go ahead and note this down."
    )
    |> next()
    |> mes("[Reyghema]")
    |> mes("1 Emperium Anvil,")
    |> mes("2 Hammer of Blacksmith,")
    |> mes("1 Illusion Flower")
    |> mes("and 20 Gold...")
    |> next()
    |> mes("[Reyghema]")
    |> mes("There were a few other")
    |> mes(
      "important things, but I can't seem to remember what they were. Hopefully, by the time you come back with the items I'll know by then."
    )
    |> next()
    |> mes("[Reyghema]")
    |> mes(
      "For now, just go and bring back the things I asked for. The sooner, the better. Hurry, I don't know how long my memories will last..."
    )
    |> set_char_var(:lv4_weapon, 34)
    |> close()
  end

  defp remind_tools(ctx) do
    ctx
    |> mes("[Reyghema]")
    |> mes("I better remind")
    |> mes("you what things I'll")
    |> mes("be needing. If you need")
    |> mes("to, write it all down.")
    |> next()
    |> mes("[Reyghema]")
    |> mes("1 Emperium Anvil,")
    |> mes("2 Hammer of Blacksmith,")
    |> mes("1 Illusion Flower")
    |> mes("and 20 Gold...")
    |> next()
    |> mes("[Reyghema]")
    |> mes(
      "There were a few more critically important things, but I can't seem to recall them right now..."
    )
    |> close()
  end

  defp collect_tools(ctx) do
    ctx
    |> mes("[Reyghema]")
    |> mes(
      "Good work, you've brought everything I asked for. However, there's been a bit of a snafu in the plans..."
    )
    |> next()
    |> mes("[Reyghema]")
    |> mes(
      "The original plan was that I'd remember everything else I need once you came back with this stuff. But I didn't."
    )
    |> next()
    |> mes("[Reyghema]")
    |> mes("Just give me some time to think about it some more. For now, let")
    |> mes(
      "me hold on to the things you've brought. You've got my word that I'll be using these to make a weapon for you."
    )
    |> delitem(1005, 2)
    |> delitem(989, 1)
    |> delitem(710, 1)
    |> delitem(969, 20)
    |> set_char_var(:lv4_weapon, 35)
    |> close()
  end

  defp missing_memories(ctx) do
    ctx
    |> mes("[Reyghema]")
    |> mes("Arrrgh!")
    |> mes("I still can't")
    |> mes("remember what")
    |> mes("I need yet! I swear,")
    |> mes("this is killing me!")
    |> next()
    |> mes("[Reyghema]")
    |> mes("...")
    |> next()
    |> mes("[Reyghema]")
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes("[Reyghema]")
    |> mes("Damn.")
    |> mes("Damn, damn, damn!")
    |> mes("'Killing me?!' I'm already dead!")
    |> close()
  end

  defp finished_weapon(ctx) do
    ctx
    |> mes("[Reyghema]")
    |> mes("...")
    |> mes("...Finally.")
    |> next()
    |> award_weapon(Enum.random(1..2))
    |> set_char_var(:lv4_weapon, 0)
    |> next()
    |> farewell()
  end

  defp award_weapon(ctx, roll) do
    ctx
    |> mes("[Reyghema]")
    |> mes("I did it!")
    |> mes("I died trying to make this,")
    |> mes("but I finally finished it!")
    |> weapon_reward(get_char_var(ctx, :lv4_weapon, 0), roll)
  end

  defp weapon_reward(ctx, 38, 1), do: ctx |> mes("This is... Berserk!") |> give_item(1814, 1)

  defp weapon_reward(ctx, 38, _),
    do: ctx |> mes("This is... the Rudra Bow!") |> give_item(1720, 1)

  defp weapon_reward(ctx, _, 1), do: ctx |> mes("This is... Tjungkuletti!") |> give_item(1416, 1)

  defp weapon_reward(ctx, _, _),
    do: ctx |> mes("This is... Brocca! Weee~ I made it!") |> give_item(1415, 1)

  defp farewell(ctx) do
    ctx
    |> mes("[Reyghema]")
    |> mes(
      "^333333*Sigh*^000000 I can feel it happening again. My memories are starting to slip away. Can't I be allowed to hold on to this memory?"
    )
    |> next()
    |> mes("[Reyghema]")
    |> mes(
      "I guess the dead aren't supposed to remember their past. But thank you for letting achieve my life long desire, even if this moment is short lived."
    )
    |> next()
    |> mes("[Reyghema]")
    |> mes("If you ever get the chance, come back and help me remember my")
    |> mes(
      "past so that I can experience the joy of weapon crafting again. Farewell, adventurer..."
    )
    |> close()
  end

  defp test_luck(ctx) do
    ctx
    |> mes("[Reyghema]")
    |> mes("Wait...")
    |> mes(
      "The stuff that you have. Those are things I'll need for my creation! Let me take a look..."
    )
    |> next()
    |> mes("[Reyghema]")
    |> mes("Yes, this is perfect!")
    |> mes(
      "But how did you know exactly what materials I needed? Oh, it doesn't matter, I guess."
    )
    |> next()
    |> mes("[Reyghema]")
    |> mes("Now it's time for the hardest,")
    |> mes(
      "or easiest, part. It's time to test your luck. We can't go through with this if your luck is too weak."
    )
    |> next()
    |> mes("[Reyghema]")
    |> mes(
      "Alright, we're going to play '^660000Rock, Paper, Scissors^000000.' You've gotta win 2 out of 3 for us to go ahead with the forging."
    )
    |> next()
    |> mes("[Reyghema]")
    |> mes(
      "If your luck is bad and you lose, we'll need to dump a bunch of one of the ores your brought to get rid of your bad luck. That's how it works."
    )
    |> next()
    |> mes("[Reyghema]")
    |> mes(
      "Alright, here's a piece of paper. When I say so, you write down 'Rock,' 'Paper' or 'Scissors.' Alright? Let's start."
    )
    |> next()
    |> choose_hand(:npchand1, :myhand1)
    |> score_round(:npchand1, :myhand1)
    |> mes("[Reyghema]")
    |> mes("Okay, now let's")
    |> mes("try this again.")
    |> next()
    |> choose_hand(:npchand2, :myhand2)
    |> score_round(:npchand2, :myhand2)
    |> mes("[Reyghema]")
    |> mes("Last time.")
    |> mes("Write down 'Rock,'")
    |> mes("'Paper' or 'Scissors.'")
    |> next()
    |> choose_hand(:npchand3, :myhand3)
    |> score_round(:npchand3, :myhand3)
    |> set_local(:aekddam, Enum.random(1..3))
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
        36 -> [7292, 7293, 7289]
        _ -> [7297, 7291, 7295]
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
    |> mes("[Reyghema]")
    |> mes("Alright, now")
    |> mes("I wrote down...")
    |> show_hand(:npchand1)
    |> show_hand(:npchand2)
    |> show_hand(:npchand3)
    |> next()
    |> mes("[Reyghema]")
    |> mes("You wrote down...")
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
    |> mes("[Reyghema]")
    |> mes(
      "Nice. You won #{get_local(ctx, :shobu, 0)} times. Your luck is really good, so now we're finally finished with this nonsense."
    )
    |> next()
    |> mes("[Reyghema]")
    |> mes("Give me some time to get some things ready. Hand me the ores")
    |> mes("now, and talk to me a little later, alright?")
    |> close()
  end

  defp unlucky(ctx) do
    ctx
    |> mes("[Reyghema]")
    |> mes("Damn...")
    |> mes("I should be happy I won, but that just means your luck is bad and")
    |> mes("we need to do this again.")
    |> next()
    |> mes("[Reyghema]")
    |> mes(
      "I'm sorry, but I'll need to take a bunch of one of your ores to get rid of your bad luck. Come back with all of the ore we'll need so we can test your luck again, alright?"
    )
    |> close()
  end
end
