defmodule Aesir.ZoneServer.Content.Npc.Quests.Lvl4WeaponQuest.Kayron do
  @moduledoc """
  Kayron is a ghostly weaponsmith who needs help recovering his memories before forging rare weapons.

  ## Behavior

  - Requires inventory capacity and level 80, and recalls his past when given his father's exact phrase.
  - Collects smithing tools, Gold and special ores as his memories return.
  - Tests luck with three rock-paper-scissors matches, consuming all ores on success or one random ore on failure.
  - Awards one of two weapons for the prepared ore set and forgets the commission afterward.

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
        x: 240,
        y: 193,
        dir: 3,
        sprite: 794,
        name: "Kayron",
        scope: :shared,
        unique_name: "Kayron#lv4"
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
        ctx
        |> mes("[Kayron]")
        |> mes("Hey...")
        |> mes("How did somebody like")
        |> mes("you get all the way over here?")
        |> next()
        |> mes("[Kayron]")
        |> mes(
          "Just by looking at that tender face of yours, I can tell you're a little weak. You better get out of here and get real strong in a hurry before you even think of coming back."
        )
        |> close()

      true ->
        commission(ctx, get_char_var(ctx, :lv4_weapon, 0))
    end
  end

  defp commission(ctx, 0), do: introduce(ctx)

  defp commission(ctx, stage) when stage < 22 or stage > 30 do
    ctx
    |> mes("[Kayron]")
    |> mes("I sense something from")
    |> mes("you. Almost as if you were")
    |> mes("here with some sort of goal.")
    |> next()
    |> mes("[Kayron]")
    |> mes("I'm surprised...")
    |> mes("And a little envious.")
    |> mes("It can be said that most")
    |> mes("in Niflheim come here with")
    |> mes("little or no purpose.")
    |> close()
  end

  defp commission(ctx, stage) when stage in [29, 30], do: reveal_weapon(ctx, stage)

  defp commission(ctx, stage) when stage in [26, 27, 28] do
    ores = required_ores(stage)

    if ores != [] and Enum.all?(ores, fn item -> count_item(ctx, item) > 29 end) do
      luck_game(ctx, ores)
    else
      ctx
      |> mes("[Kayron]")
      |> mes("I can't seem to recall the rest")
      |> mes("of the materials I need. This is beginning to get really frustrating.")
      |> next()
      |> mes("[Kayron]")
      |> mes(
        "I mean, me and my father used to know this stuff like it was second nature. What's wrong with me...?"
      )
      |> close()
    end
  end

  defp commission(ctx, 25) do
    if count_item(ctx, 1005) > 1 and count_item(ctx, 989) > 0 and count_item(ctx, 710) > 0 and
         count_item(ctx, 969) > 19 do
      accept_tools(ctx)
    else
      remind_tools(ctx)
    end
  end

  defp commission(ctx, 24), do: request_tools(ctx)
  defp commission(ctx, 23), do: recall_father(ctx)
  defp commission(ctx, 22), do: ctx |> lament() |> forgotten_memory() |> close()

  defp lament(ctx) do
    ctx
    |> mes("[Kayron]")
    |> mes("In life, I was known as Kayron.")
    |> mes("But now I'm just another ghost wandering around this realm of")
    |> mes("the dead. Without a body, I feel")
    |> mes("so useless.")
    |> next()
  end

  defp forgotten_memory(ctx) do
    ctx
    |> mes("[Kayron]")
    |> mes("Huh...?")
    |> mes(
      "I can't remember what I was going to say. M-my memories! I... I can't seem to recollect..."
    )
  end

  defp introduce(ctx) do
    {ctx, choice} = ctx |> lament() |> select(["Show interest.", "Ignore him."])

    case choice do
      1 ->
        ctx |> forgotten_memory() |> set_char_var(:lv4_weapon, 22) |> close()

      2 ->
        ctx |> mes("[Kayron]") |> mes("Useless...") |> mes("Absolutely useless...") |> close()

      _ ->
        ctx
    end
  end

  defp reveal_weapon(ctx, stage) do
    ctx =
      ctx
      |> mes("[Kayron]")
      |> mes("Heh heh heh...")
      |> mes("You're just in time.")
      |> mes("The time has come for")
      |> mes("me to reveal the results")
      |> mes("of my work...")
      |> next()

    {name, item} =
      case {Enum.random(1..2), stage} do
        {1, 29} -> {"Great Axe", 1364}
        {1, 30} -> {"Longinus's Spear", 1469}
        {2, 29} -> {"Guillotine", 1369}
        {2, 30} -> {"Brionac", 1470}
      end

    ctx
    |> mes("[Kayron]")
    |> mes("It's a success!")
    |> mes("I completed the experiment")
    |> mes("that got me killed! I almost")
    |> mes("can't believe it! I created")
    |> mes("this... #{name}!")
    |> give_item(item, 1)
    |> set_char_var(:lv4_weapon, 0)
    |> next()
    |> mes("[Kayron]")
    |> mes("I'm so glad that my years of research haven't been wasted.")
    |> mes("If only Father were able to see this, he'd be really happy for me.")
    |> next()
    |> mes("[Kayron]")
    |> mes("Oh no...")
    |> mes(
      "^333333*Sigh*^000000 I can feel my memories beginning to fade again. If you ever see me, please let me"
    )
    |> mes("remember my past again.")
    |> mes("Thank you...")
    |> close()
  end

  defp required_ores(26), do: []
  defp required_ores(27), do: [7289, 7294, 7291]
  defp required_ores(28), do: [7290, 7296, 7293]

  defp luck_game(ctx, ores) do
    {ctx, first_match} =
      ctx
      |> mes("[Kayron]")
      |> mes("What's this?")
      |> mes("The stuff you're carrying")
      |> mes("around looks awfully familiar.")
      |> mes("Hm, let me take a look, please...")
      |> next()
      |> mes("[Kayron]")
      |> mes("Yes, I was right!")
      |> mes(
        "I can use these to smith a weapon! How did you know these were the materials I need? In any case, this is great!"
      )
      |> next()
      |> mes("[Kayron]")
      |> mes(
        "Oh, but first, we need to test your luck. No matter how good my skills may be, we need to make sure your luck is good today, or else we can't proceed."
      )
      |> next()
      |> mes("[Kayron]")
      |> mes("We're gonna play '^660000Rock, Paper, Scissors^000000.' We can go ahead and")
      |> mes("make the item if you win 2 out of 3 matches.")
      |> next()
      |> mes("[Kayron]")
      |> mes(
        "But if you lose 2 out of 3, your luck isn't strong enough for me to even attempt smithing. We'll need to dump a huge amount of one of the materials you brought to repel your bad luck."
      )
      |> next()
      |> mes("[Kayron]")
      |> mes("Here's a piece of paper.")
      |> mes(
        "You'll write 'Rock,' 'Paper,' or 'Scissors,' and I'll do the same. Then we'll compare our results and see what happens. Alright, let's do the first match!"
      )
      |> next()
      |> play_match()

    {ctx, second_match} =
      ctx
      |> mes("[Kayron]")
      |> mes("Now...")
      |> mes("Let's play")
      |> mes("the second match~")
      |> next()
      |> play_match()

    {ctx, last_match} =
      ctx
      |> mes("[Kayron]")
      |> mes("Alright...")
      |> mes("One last time.")
      |> mes("Write down 'Rock,'")
      |> mes("'Paper' or 'Scissors.'")
      |> next()
      |> play_match()

    penalty = Enum.random(1..3)
    matches = [first_match, second_match, last_match]
    wins = Enum.count(matches, &won_match?/1)

    ctx
    |> consume_test_ores(ores, wins, penalty)
    |> mes("[Kayron]")
    |> mes("We're done!")
    |> mes("Now, I wrote down...")
    |> show_hands(matches, :npc)
    |> next()
    |> mes("[Kayron]")
    |> mes("You wrote down...")
    |> show_hands(matches, :player)
    |> next()
    |> fortune_result(wins)
  end

  defp play_match(ctx) do
    npc_hand = Enum.random(1..3)
    {ctx, player_hand} = select(ctx, ["Scissors", "Rock", "Paper"])
    {ctx, {npc_hand, player_hand}}
  end

  defp won_match?({3, 1}), do: true
  defp won_match?({1, 2}), do: true
  defp won_match?({2, 3}), do: true
  defp won_match?(_), do: false

  defp consume_test_ores(ctx, ores, wins, _penalty) when wins > 1 do
    ores
    |> Enum.reduce(ctx, fn item, ctx -> delitem(ctx, item, 30) end)
    |> set_char_var(:lv4_weapon, get_char_var(ctx, :lv4_weapon, 0) + 2)
  end

  defp consume_test_ores(ctx, ores, _wins, penalty) do
    delitem(ctx, Enum.at(ores, penalty - 1), 30)
  end

  defp show_hands(ctx, matches, :npc) do
    Enum.reduce(matches, ctx, fn {hand, _player_hand}, ctx -> show_hand(ctx, hand) end)
  end

  defp show_hands(ctx, matches, :player) do
    Enum.reduce(matches, ctx, fn {_npc_hand, hand}, ctx -> show_hand(ctx, hand) end)
  end

  defp show_hand(ctx, 1), do: mes(ctx, "Scissors")
  defp show_hand(ctx, 2), do: mes(ctx, "Rock")
  defp show_hand(ctx, 3), do: mes(ctx, "Paper")
  defp show_hand(ctx, _), do: ctx

  defp fortune_result(ctx, wins) when wins > 1 do
    ctx
    |> mes("[Kayron]")
    |> mes("Let's see...")
    |> mes("You won #{wins} times.")
    |> mes("You must be really")
    |> mes("Without a doubt, you've")
    |> mes("got some pretty good luck~")
    |> next()
    |> mes("[Kayron]")
    |> mes("Alright, I'll keep my end of the bargain. Give me the materials")
    |> mes("and some time to finish preparing. I'll talk to you later, okay?")
    |> close()
  end

  defp fortune_result(ctx, _wins) do
    ctx
    |> mes("[Kayron]")
    |> mes(
      "Well, I'm sorry to say that you lost. We have no choice but to drive away your bad luck with"
    )
    |> mes("some of the ore you brought!")
    |> next()
    |> mes("[Kayron]")
    |> mes("Alright, let's try this again. Go and get the materials we need")
    |> mes("and come back to me.")
    |> close()
  end

  defp accept_tools(ctx) do
    ctx
    |> mes("[Kayron]")
    |> mes("Oh...!")
    |> mes(
      "I had no idea you were such a reliable person! You brought the things I've asked for pretty quickly!"
    )
    |> next()
    |> mes("[Kayron]")
    |> mes(
      "But I still can't remember the rest of the things that I'll be needing. I'm really sorry..."
    )
    |> next()
    |> mes("[Kayron]")
    |> mes(
      "Is there any way to get more of my memory back? In the meantime, let me keep these materials. I promise they'll be used to make a good weapon for you."
    )
    |> delitem(1005, 2)
    |> delitem(989, 1)
    |> delitem(710, 1)
    |> delitem(969, 20)
    |> set_char_var(:lv4_weapon, 26)
    |> close()
  end

  defp remind_tools(ctx) do
    ctx
    |> mes("[Kayron]")
    |> mes("I'll need a lot of materials, but let me remind you of some of")
    |> mes("the necessary things that I can actually remember.")
    |> next()
    |> tool_list()
    |> next()
    |> mes("[Kayron]")
    |> mes("I know there were a few more")
    |> mes("things that are crucial to this weapon's construction, but...")
    |> mes("I can't seem to concentrate hard enough to remember.")
    |> close()
  end

  defp tool_list(ctx) do
    ctx
    |> mes("[Kayron]")
    |> mes("So far, I know I'll need")
    |> mes("2 Hammer of Blacksmith")
    |> mes("1 Emperium Anvil")
    |> mes("1 Illusion Flower and")
    |> mes("20 Gold.")
  end

  defp request_tools(ctx) do
    ctx
    |> mes("[Kayron]")
    |> mes("Alright...")
    |> mes("I just remembered")
    |> mes("most of the things")
    |> mes("I need to make you")
    |> mes("a great weapon.")
    |> next()
    |> mes("[Kayron]")
    |> mes(
      "I believe it's fair to let you know that I can't guarantee what weapon will be produced from this work since, quite frankly, I can't remember."
    )
    |> next()
    |> tool_list()
    |> next()
    |> mes("[Kayron]")
    |> mes(
      "Bring those items to me first. I'm pretty sure there was something else I'll be needing, but I can't seem to remember. This memory"
    )
    |> mes("of mine is beginning to worry me a little bit...")
    |> next()
    |> mes("[Kayron]")
    |> mes(
      "Anyway, I'll be waiting for you here while you go out and collect those things. Be careful, alright?"
    )
    |> set_char_var(:lv4_weapon, 25)
    |> close()
  end

  defp recall_father(ctx) do
    {ctx, phrase} =
      ctx
      |> lament()
      |> mes("[Kayron]")
      |> mes("There's nothing I can do.")
      |> mes("I'm... Um... I'm...?")
      |> input(:string)

    ctx = ctx |> set_local(:"input$", phrase) |> next()
    remember_past(ctx, phrase)
  end

  defp remember_past(ctx, "I'm utterly helpless here.") do
    ctx
    |> mes("[Kayron]")
    |> mes("I'm utterly helpless here.")
    |> mes(
      "Right, right! My father always used to say that! I guess my brothers and I take after our father in a lot of ways."
    )
    |> next()
    |> mes("[Kayron]")
    |> mes("My mind's been so hazy.")
    |> mes("I forgot that I even used")
    |> mes("to be a living human.")
    |> mes("^333333*Sigh...*^000000")
    |> next()
    |> mes("[Kayron]")
    |> mes("Still, that little memory has brought me a little peace of")
    |> mes("mind. I really appreciate that.")
    |> next()
    |> mes("[Kayron]")
    |> mes("I used to be a weaponsmith")
    |> mes(
      "when I was alive, so if you like, I can forge something nice for you. You'll have to bring me the materials, though."
    )
    |> next()
    |> mes("[Kayron]")
    |> mes("You understand that being")
    |> mes(
      "dead sort of restricts my mobility. Still, it's actually useful to be stuck in Niflheim. This place is filled with some strange energy that will help in my smithing."
    )
    |> next()
    |> mes("[Kayron]")
    |> mes("Even though experimental")
    |> mes(
      "smithing got me killed, I won't have to worry about it this time. After all, I'm already dead! Hahahah~"
    )
    |> next()
    |> mes("[Kayron]")
    |> mes(
      "Alright, just give me a little time so that I can try to remember the things that I'll need, alright?"
    )
    |> set_char_var(:lv4_weapon, 24)
    |> close()
  end

  defp remember_past(ctx, _phrase) do
    ctx
    |> mes("[Kayron]")
    |> mes("Huh...?")
    |> mes("What did you just say?")
    |> mes("I'm sorry, I'm trying to remember something my father always used")
    |> mes("to say...")
    |> close()
  end
end
