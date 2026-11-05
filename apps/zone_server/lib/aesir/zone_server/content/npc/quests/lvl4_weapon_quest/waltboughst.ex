defmodule Aesir.ZoneServer.Content.Npc.Quests.Lvl4WeaponQuest.Waltboughst do
  @moduledoc """
  A deceased weaponsmith completes his unfinished experiment with an adventurer's help.

  ## Behavior

  - Requires inventory capacity and base level 80 before discussing his research.
  - Recovers his memories through his father's saying and collects basic forging materials.
  - Tests luck over three rounds of Rock, Paper, Scissors, consuming all ores on success or one ore type on failure.
  - Awards one of two weapons for the chosen recipe and resets the shared quest progress.

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
        x: 331,
        y: 72,
        dir: 3,
        sprite: 795,
        name: "Waltboughst",
        scope: :shared,
        unique_name: "Waltboughst#lv4"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{908, 300}]) == 0 ->
        ctx
        |> mes(
          "^3355FFWait a second! Right now, you're carrying too many items with you. Please come back after putting some of your things into Kafra Storage.^000000"
        )
        |> close()

      base_level(ctx) < 80 ->
        warn_survival(ctx)

      true ->
        research(ctx, get_char_var(ctx, :lv4_weapon, 0))
    end
  end

  defp research(ctx, stage) do
    cond do
      stage == 0 ->
        introduction(ctx)

      stage < 49 or stage > 57 ->
        ctx
        |> mes("[Waltboughst]")
        |> mes(
          "It doesn't look like you're just wandering around. You're here for something specific, aren't you? But what does the realm of the dead have to offer the living?"
        )
        |> close()

      stage in [56, 57] ->
        finished_weapon(ctx, stage)

      ores_ready?(ctx, stage) ->
        luck_trial(ctx)

      stage in [53, 54, 55] ->
        forgotten_materials(ctx)

      stage == 52 and basic_materials_ready?(ctx) ->
        take_basic_materials(ctx)

      stage == 52 ->
        ctx |> basic_materials() |> close()

      stage == 51 ->
        request_basic_materials(ctx)

      stage == 50 ->
        recall_saying(ctx)

      stage == 49 ->
        ctx |> lost_memory() |> repeat_saying() |> memory_lapse() |> close()

      true ->
        introduction(ctx)
    end
  end

  defp warn_survival(ctx) do
    ctx
    |> mes("[Waltboughst]")
    |> mes("Hah...!")
    |> mes("A living person!")
    |> mes("But not for long!")
    |> next()
    |> mes("[Waltboughst]")
    |> mes(
      "I hope you came here with some strong allies. Judging from your strength, there's no way you'll survive in this kind of place on"
    )
    |> mes("your own, you know.")
    |> close()
  end

  defp forgotten_materials(ctx) do
    ctx
    |> mes("[Waltboughst]")
    |> mes("Why can't I remember...?!")
    |> mes("A good weaponsmith is supposed")
    |> mes("to know these things by heart!")
    |> mes("When I was alive, I had no such recall problems...")
    |> next()
    |> mes("[Waltboughst]")
    |> mes("If Father were")
    |> mes("to see me now, I'm")
    |> mes("sure he'd be ashamed...")
    |> close()
  end

  defp take_basic_materials(ctx) do
    ctx
    |> mes("[Waltboughst]")
    |> mes(
      "You brought everything I needed already? That's great, but somehow, I can't still remember the other materials I need..."
    )
    |> next()
    |> mes("[Waltboughst]")
    |> mes(
      "Tell you what. Let me hold on to these things, and I promise you that I'll use them to create a weapon for you. In the meantime, we need to figure out the rest of the necessary materials..."
    )
    |> delitem(1005, 2)
    |> delitem(989, 1)
    |> delitem(710, 1)
    |> delitem(969, 20)
    |> set_char_var(:lv4_weapon, 53)
    |> close()
  end

  defp lost_memory(ctx) do
    ctx
    |> mes("[Waltboughst]")
    |> mes("It's so frustrating being dead.")
    |> mes("I can't do anything without a body, no matter how hard I try.")
    |> next()
    |> mes("[Waltboughst]")
    |> mes(
      "It's funny, you know. My father always used to say, 'Trying your best won't always result in success...' Um, that's ... Huh? There was more, I think."
    )
    |> next()
  end

  defp repeat_saying(ctx) do
    ctx
    |> mes("[Waltboughst]")
    |> mes("Let me try it again.")
    |> mes("'Trying your best won't")
    |> mes("always result in success...'")
    |> mes("I'm sure that's not all of it...")
  end

  defp memory_lapse(ctx) do
    ctx
    |> next()
    |> mes("[Waltboughst]")
    |> mes("I...")
    |> mes("I can't think!")
    |> mes("What was supposed")
    |> mes("to come after that part?")
  end

  defp introduction(ctx) do
    {ctx, choice} = ctx |> lost_memory() |> select(["Show interest.", "Ignore him."])
    interest(ctx, choice)
  end

  defp interest(ctx, 1) do
    ctx
    |> repeat_saying()
    |> memory_lapse()
    |> set_char_var(:lv4_weapon, 49)
    |> close()
  end

  defp interest(ctx, 2), do: ctx |> repeat_saying() |> close()
  defp interest(ctx, _), do: ctx

  defp recall_saying(ctx) do
    {ctx, saying} = ctx |> lost_memory() |> input(:string)
    ctx = set_local(ctx, :"input$", saying)
    remembered_saying(ctx, saying)
  end

  defp remembered_saying(ctx, "But that's no excuse!") do
    ctx
    |> mes("[Waltboughst]")
    |> mes("Yes! That was it!")
    |> mes("But that's no excuse!")
    |> mes("Every successful man in")
    |> mes("history has tried his best!")
    |> set_char_var(:lv4_weapon, 51)
    |> next()
    |> mes("[Waltboughst]")
    |> mes("I remember now...")
    |> mes("I got myself killed trying to make some kind of special weapon.")
    |> mes("Heh heh, but not this time!")
    |> next()
    |> mes("[Waltboughst]")
    |> mes(
      "We must have been fated to meet. Yes, adventurers of great strength and men of genius naturally attract each other."
    )
    |> next()
    |> mes("[Waltboughst]")
    |> mes("Lend me your power.")
    |> mes("Help me complete the experiment")
    |> mes(
      "I left unfinished in life, and I will let you keep the finished product. All I wish to do is complete my life's work."
    )
    |> next()
    |> mes("[Waltboughst]")
    |> mes(
      "It seems that being deceased has impaired my rententive faculties. Give me some time to remember the things I'll need to conduct my experiment. We shall talk later."
    )
    |> close()
  end

  defp remembered_saying(ctx, _) do
    ctx
    |> mes("[Waltboughst]")
    |> mes("What...?")
    |> mes("No, no. That")
    |> mes("wasn't it at all...")
    |> mes("Hmmm.")
    |> close()
  end

  defp basic_materials(ctx) do
    ctx
    |> mes("[Waltboughst]")
    |> mes("For now, bring")
    |> mes("the basic things...")
    |> mes("1 Emperium Anvil,")
    |> mes("2 Hammer of Blacksmith,")
    |> mes("1 Illusion Flower and")
    |> mes("20 Gold...")
  end

  defp request_basic_materials(ctx) do
    ctx
    |> mes("[Waltboughst]")
    |> mes(
      "I just remembered some of the most basic materials we need for me to make a weapon for you."
    )
    |> next()
    |> basic_materials()
    |> next()
    |> mes("[Waltboughst]")
    |> mes(
      "There were a few other necessary materials, but I need some time to focus and remember what they were."
    )
    |> set_char_var(:lv4_weapon, 52)
    |> close()
  end

  defp basic_materials_ready?(ctx) do
    count_item(ctx, 1005) > 1 and count_item(ctx, 989) > 0 and
      count_item(ctx, 710) > 0 and count_item(ctx, 969) > 19
  end

  defp ores_ready?(ctx, 54) do
    count_item(ctx, 7292) > 29 and count_item(ctx, 7291) > 29 and count_item(ctx, 7295) > 29
  end

  defp ores_ready?(ctx, 55) do
    count_item(ctx, 7296) > 29 and count_item(ctx, 7294) > 29 and count_item(ctx, 7290) > 29
  end

  defp ores_ready?(_ctx, _stage), do: false

  defp finished_weapon(ctx, stage) do
    ctx =
      ctx
      |> mes("[Waltboughst]")
      |> mes("Take a look at this!")
      |> mes(
        "In just a short time, I made something with the materials you've given me. You're curious what the result is, aren't you?"
      )
      |> next()

    roll = Enum.random(1..2)

    ctx
    |> mes("[Waltboughst]")
    |> mes("Waltboughst never fails!")
    |> award_weapon(roll, stage)
    |> farewell()
  end

  defp award_weapon(ctx, 1, 56) do
    ctx
    |> mes(
      "With my skill and your luck, there was zero probability for failure. Behold... Byeollungum!"
    )
    |> give_item(1140, 1)
  end

  defp award_weapon(ctx, 1, 57) do
    ctx
    |> mes(
      "With my skill and your luck, there was zero probability for failure. Behold... Exorcise!"
    )
    |> give_item(1233, 1)
  end

  defp award_weapon(ctx, 2, 56) do
    ctx
    |> mes(
      "With my skill and your luck, there was zero probability for failure. Behold... Combat Knife!"
    )
    |> give_item(1228, 1)
  end

  defp award_weapon(ctx, 2, 57) do
    ctx
    |> mes(
      "With my skill and your luck, there was zero probability for failure. Behold...Grand Cross!!"
    )
    |> give_item(1528, 1)
  end

  defp farewell(ctx) do
    ctx
    |> set_char_var(:lv4_weapon, 0)
    |> next()
    |> mes("[Waltboughst]")
    |> mes("I'm a genius!")
    |> mes("Hahahahahahahaha!")
    |> mes("I succeeded where my brothers")
    |> mes("could not! Mwahahahaha ha ha ...ha?")
    |> next()
    |> mes("[Waltboughst]")
    |> mes(
      "Damn, I can feel that fuzziness in my head again. This can't be good. But still, I was able to prove my genius even after I died."
    )
    |> next()
    |> mes("[Waltboughst]")
    |> mes(
      "I'm sure that if you come back and help me retrieve my memories, I can be of service to you again. But for now, I must thank you, even if I do end up forgetting everything..."
    )
    |> next()
    |> mes("[Waltboughst]")
    |> mes("Yes...")
    |> mes(
      "It will be your job to remember the accomplishments of Waltboughst, and that he was a weaponsmith ahead of his time. Good bye for now, adventurer..."
    )
    |> close()
  end

  defp luck_trial(ctx) do
    ctx
    |> mes("[Waltboughst]")
    |> mes("Wait, what's that you're holding?")
    |> mes("I think those are the exact things we need for me to make you a weapon...")
    |> next()
    |> mes("[Waltboughst]")
    |> mes("Yes...!")
    |> mes("This is perfect.")
    |> mes("It looks like I'll")
    |> mes("be able to start work")
    |> mes("on this really soon.")
    |> next()
    |> mes("[Waltboughst]")
    |> mes(
      "Now we need to test your luck. And to do that, we need to play '^660000Rock, Paper, Scissors^000000.' I'm serious about this..."
    )
    |> next()
    |> mes("[Waltboughst]")
    |> mes(
      "If your luck is strong today, there'll be less risk of failing the weapon creation process. You need to win 2 out of 3 times for us to begin."
    )
    |> next()
    |> mes("[Waltboughst]")
    |> mes("But if you lose...")
    |> mes(
      "We'll need to expel your bad luck by getting rid of a good amount of one of the ores you brought."
    )
    |> next()
    |> mes("[Waltboughst]")
    |> mes("Take this piece of paper.")
    |> mes("Now, when I tell you to, write down 'Rock,' 'Paper' or 'Scissors.' Let's begin...!")
    |> next()
    |> play_hand(:npchand1, :myhand1)
    |> mes("[Waltboughst]")
    |> mes("Alright...")
    |> mes("Now, let's play")
    |> mes("a second time.")
    |> next()
    |> play_hand(:npchand2, :myhand2)
    |> mes("[Waltboughst]")
    |> mes("One last time.")
    |> mes("After this, we")
    |> mes("compare results")
    |> mes("and check your luck.")
    |> next()
    |> play_hand(:npchand3, :myhand3)
    |> set_local(:aekddam, Enum.random(1..3))
    |> consume_ores()
    |> compare_hands()
    |> luck_result()
  end

  defp play_hand(ctx, npc_key, player_key) do
    {ctx, hand} =
      ctx
      |> set_local(npc_key, Enum.random(1..3))
      |> select(["Scissors", "Rock", "Paper"])

    ctx = set_local(ctx, player_key, hand)
    npc_hand = get_local(ctx, npc_key, 0)

    if {hand, npc_hand} in [{1, 3}, {2, 1}, {3, 2}] do
      set_local(ctx, :shobu, get_local(ctx, :shobu, 0) + 1)
    else
      ctx
    end
  end

  defp consume_ores(ctx) do
    ores =
      case get_char_var(ctx, :lv4_weapon, 0) do
        54 -> [7292, 7295, 7291]
        55 -> [7296, 7294, 7290]
      end

    if get_local(ctx, :shobu, 0) > 1 do
      ctx = Enum.reduce(ores, ctx, fn ore, ctx -> delitem(ctx, ore, 30) end)
      set_char_var(ctx, :lv4_weapon, get_char_var(ctx, :lv4_weapon, 0) + 2)
    else
      ore = Enum.at(ores, get_local(ctx, :aekddam, 0) - 1)
      delitem(ctx, ore, 30)
    end
  end

  defp compare_hands(ctx) do
    ctx
    |> mes("[Waltboughst]")
    |> mes("Okay...")
    |> mes("I wrote down...")
    |> show_hand(:npchand1)
    |> show_hand(:npchand2)
    |> show_hand(:npchand3)
    |> next()
    |> mes("[Waltboughst]")
    |> mes("Now, you wrote...")
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
    if get_local(ctx, :shobu, 0) > 1 do
      luck_success(ctx)
    else
      luck_failure(ctx)
    end
  end

  defp luck_success(ctx) do
    ctx
    |> mes("[Waltboughst]")
    |> mes("Excellent. You won #{get_char_var(ctx, :shobu, 0)} times,")
    |> mes("so your luck must be really high.")
    |> mes("That means we can begin~!")
    |> next()
    |> mes("[Waltboughst]")
    |> mes("Leave the ores here and give")
    |> mes("me some time to complete my preparations. Come back later, and I should be finished.")
    |> close()
  end

  defp luck_failure(ctx) do
    ctx
    |> mes("[Waltboughst]")
    |> mes("You lost...")
    |> mes("I'm sorry, but we")
    |> mes("need to repel the bad")
    |> mes("luck by throwing away")
    |> mes("some of your ores...")
    |> next()
    |> mes("[Waltboughst]")
    |> mes("Gather the required ores again,")
    |> mes("and come back to me so we can test your luck. I'll be waiting right here.")
    |> close()
  end
end
