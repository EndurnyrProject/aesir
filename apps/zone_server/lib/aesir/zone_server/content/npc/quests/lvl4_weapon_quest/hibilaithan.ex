defmodule Aesir.ZoneServer.Content.Npc.Quests.Lvl4WeaponQuest.Hibilaithan do
  @moduledoc """
  Hibilaithan crafts Umbala weapons for adventurers who can understand him and pass his luck test.

  ## Behavior

  - Requires inventory capacity, knowledge of the Umbala language and level 70 to begin.
  - Takes 10 Gold, 50 Steel and 10 Emperium before a five-question monster guessing game.
  - Uses Muscovite, Biotite or Pyroxene; success consumes 30 ores and failure consumes 10.
  - Awards a weapon on the next visit after success, then resets the shared artisan quest progress.

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
        map: "umbala",
        x: 163,
        y: 257,
        dir: 3,
        sprite: 785,
        name: "Hibilaithan",
        scope: :shared,
        unique_name: "Hibilaithan#lv4"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

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

      get_char_var(ctx, :event_umbala, 0) < 3 ->
        ctx
        |> mes("[Hibilaithan]")
        |> mes("Umba! Umbaba...umum! Baumba!")
        |> mes("Umumumbababaumumbabaumba!")
        |> mes("Umbaumbaumbaumbaumhah!")
        |> mes("Umumumumumbababababab!")
        |> close()

      true ->
        quest_progress(ctx)
    end
  end

  defp quest_progress(ctx) do
    progress = get_char_var(ctx, :lv4_weapon, 0)

    cond do
      progress == 0 ->
        introduction(ctx)

      progress < 8 or progress > 14 ->
        unavailable(ctx)

      progress in [12, 13, 14] ->
        craft_weapon(ctx)

      progress in [9, 10, 11] ->
        check_selected_ore(ctx, progress)

      progress == 8 ->
        check_materials(ctx)

      true ->
        introduction(ctx)
    end
  end

  defp introduction(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hibilaithan]")
      |> mes("Eh heh heh...")
      |> mes("At long last, this")
      |> mes("day has come. Finally,")
      |> mes("I've earned recognition as")
      |> mes("Umbala's greatest artisan!")
      |> next()
      |> mes("[Hibilaithan]")
      |> mes("Yes yes, I'm ^802A2Athat^000000 Hibilaithan.")
      |> mes(
        "And if you bring me the materials, I shall deign to craft one of my masterpieces for you. Bwahahaha~!"
      )
      |> next()
      |> mes("[Hibilaithan]")
      |> mes("Hm? What was that?")
      |> mes("Never heard of me?")
      |> mes("Please, enough jesting!")
      |> mes(
        "I mean, even though I may be a maestro at my craft, there's no need to feel intimidated."
      )
      |> next()
      |> mes("[Hibilaithan]")
      |> mes("Now be honest...")
      |> mes("Do you want to be")
      |> mes("the recipient of my")
      |> mes("inspired and oft imitated")
      |> mes("handiwork or not?")
      |> next()
      |> select(["Yes. Yes, I do.", "Sorry, I don't need it!"])

    case choice do
      1 -> begin_quest(ctx)
      2 -> decline(ctx)
      _ -> ctx
    end
  end

  defp begin_quest(ctx) do
    if base_level(ctx) < 70 do
      ctx
      |> mes("[Hibilaithan]")
      |> mes("Ooh...")
      |> mes(
        "Your mind is too weak to handle the power of my creations. I'm sorry, but you need more training."
      )
      |> next()
      |> mes("[Hibilaithan]")
      |> mes(
        "I know it must be unbearable, waiting to own one of my creations. But for your own sake, get stronger first and then come back to me."
      )
      |> close()
    else
      ctx
      |> mes("[Hibilaithan]")
      |> mes("Hahahaha!")
      |> mes("Of course you do!")
      |> mes("That was a rhetorical question!")
      |> mes("But I like your attitude. Now I'm going to tell you what you need")
      |> mes("to bring me, so don't forget.")
      |> next()
      |> material_requirements()
      |> set_char_var(:lv4_weapon, 8)
      |> close()
    end
  end

  defp decline(ctx) do
    ctx
    |> mes("[Hibilaithan]")
    |> mes("Hahahahaha~!")
    |> mes("There's no need")
    |> mes("to be modest!")
    |> mes("Oh, you adventurers")
    |> mes("can be so silly sometimes.")
    |> next()
    |> mes("[Hibilaithan]")
    |> mes(
      "Well, if you ever muster up the courage to ask me of this favor, come back anytime. Give me the chance to show you my genius!"
    )
    |> close()
  end

  defp unavailable(ctx) do
    ctx
    |> mes("[Hibilaithan]")
    |> mes("...")
    |> mes("Ah... I don't feel")
    |> mes("like doing ^820A2Aanything^000000")
    |> mes("right now. Come back later, alright?")
    |> close()
  end

  defp craft_weapon(ctx) do
    ctx
    |> mes("[Hibilaithan]")
    |> mes("Ah, I sense that all is in readiness. Good, good,")
    |> mes("I can begin! Now, don't peek.")
    |> mes("I can't risk sharing my")
    |> mes("awesome secrets!")
    |> next()
    |> mes(
      "^3355FFHibilaithan picked up all the materials and turned his back to you. Although you couldn't get a clear look at what he was doing, his motions were deceptively simple and clumsy looking as you feel a strange energy gather around him.^000000"
    )
    |> next()
    |> mes("[Hibilaithan]")
    |> mes("Umm~ umm~ umm~")
    |> mes("Aww~ aww~ aww~")
    |> mes("Phew~ phew~ phew~")
    |> mes("Woo~ woo~ woo~")
    |> mes("Ho~ ho~ ho~")
    |> next()
    |> mes("[Hibilaithan]")
    |> mes("Haha, it's done!")
    |> mes(
      "^333333*Phew*^000000 That was pretty tough, but I'm sure you can't wait to see what we've made. Okay, let's take a look..."
    )
    |> next()
    |> mes("[Hibilaithan]")
    |> award_weapon(get_char_var(ctx, :lv4_weapon, 0))
    |> next()
    |> mes("[Hibilaithan]")
    |> mes(
      "Ah, yet another creation that's a testament to my awesome skills! Come back to me whenever you want me to make something truly great for you. See you around~"
    )
    |> close()
  end

  defp award_weapon(ctx, 12) do
    ctx
    |> mes(
      "Ooh, this is a huge success! But of course, since it's my handiwork, that goes without saying. Hey, this is a weapon... Some sort of... Mailbreaker!"
    )
    |> set_char_var(:lv4_weapon, 0)
    |> give_item(1225, 1)
  end

  defp award_weapon(ctx, 13) do
    ctx
    |> mes(
      "Ooh, this is a huge success! But of course, since it's my handiwork, that goes without saying. Hey, this is a weapon... Some sort of... Swordbreaker!"
    )
    |> set_char_var(:lv4_weapon, 0)
    |> give_item(1224, 1)
  end

  defp award_weapon(ctx, 14) do
    ctx
    |> mes(
      "Ooh, this is a huge success! But of course, since it's my handiwork, that goes without saying. Hey, this is a weapon... Some sort of... Slaughter!"
    )
    |> set_char_var(:lv4_weapon, 0)
    |> give_item(1367, 1)
  end

  defp award_weapon(ctx, _progress), do: ctx

  defp check_selected_ore(ctx, progress) do
    ore =
      case progress do
        9 -> 7292
        10 -> 7297
        11 -> 7296
      end

    if count_item(ctx, ore) > 29 do
      ctx
      |> set_local(:itemreq, ore)
      |> test_luck()
    else
      missing_materials(ctx)
    end
  end

  defp test_luck(ctx) do
    ctx
    |> mes("[Hibilaithan]")
    |> mes("Okay, let's get started!")
    |> mes("First, we're going to see how")
    |> mes("lucky you are today. We'll play this simple game where you guess")
    |> mes("which monster I'm thinking of.")
    |> next()
    |> mes("[Hibilaithan]")
    |> mes(
      "Don't worry, I'll tell you which monsters are my favorite, so this game isn't impossible. If you can guess just one of them right, we'll know your luck is good today!"
    )
    |> next()
    |> ask_monsters()
    |> mes("[Hibilaithan]")
    |> mes("Alright, that's it!")
    |> mes("Now, this is the order")
    |> mes("of the monsters that")
    |> mes("I was thinking about...")
    |> next()
    |> mes("[Hibilaithan]")
    |> reveal_monsters()
    |> resolve_luck()
  end

  defp ask_monsters(ctx) do
    Enum.reduce(1..5, ctx, fn question_number, ctx ->
      monsters =
        Rathena.put_at(get_local(ctx, :mons, []), question_number, Enum.random(1..4), 0)

      {ctx, answer} =
        ctx
        |> set_local(:mons, monsters)
        |> mes("[Hibilaithan]")
        |> monster_question(question_number)
        |> next()
        |> select(["Zealotus", "Alice", "Munak", "Isis"])

      if answer == Enum.at(monsters, question_number, 0) do
        set_local(ctx, :dap, get_local(ctx, :dap, 0) + 1)
      else
        ctx
      end
    end)
  end

  defp monster_question(ctx, 1) do
    ctx
    |> mes("Alright...")
    |> mes("My favorite monsters are")
    |> mes("Zealotus, Alice, Munak and")
    |> mes("Isis. Now... Guess which one")
    |> mes("I'm thinking about right now!")
  end

  defp monster_question(ctx, 2) do
    ctx
    |> mes("Okay...")
    |> mes("Now I'm thinking about a different monster. Or am I? Guess which one!")
  end

  defp monster_question(ctx, 3) do
    ctx
    |> mes("Now...")
    |> mes("Which monster am")
    |> mes("I thinking about?")
  end

  defp monster_question(ctx, 4) do
    ctx
    |> mes("Can you guess which")
    |> mes("monster is on my mind now?")
  end

  defp monster_question(ctx, 5) do
    ctx
    |> mes("One more time!")
    |> mes("What monster")
    |> mes("am I thinking of?")
  end

  defp reveal_monsters(ctx) do
    Enum.reduce(1..5, ctx, fn question_number, ctx ->
      case Enum.at(get_local(ctx, :mons, []), question_number, 0) do
        1 -> mes(ctx, "Zealotus")
        2 -> mes(ctx, "Alice")
        3 -> mes(ctx, "Munak")
        4 -> mes(ctx, "Isis")
        _ -> ctx
      end
    end)
  end

  defp resolve_luck(ctx) do
    if get_local(ctx, :dap, 0) > 0 do
      ctx
      |> delitem(get_local(ctx, :itemreq, 0), 30)
      |> set_char_var(:lv4_weapon, get_char_var(ctx, :lv4_weapon, 0) + 3)
      |> next()
      |> mes("[Hibilaithan]")
      |> mes("Amazing...")
      |> mes("You must have mental powers or something. You answered correctly")
      |> mes("#{get_local(ctx, :dap, 0)} times! Wow, you must have really good luck today!")
      |> next()
      |> mes("[Hibilaithan]")
      |> mes("In that case, there's no reason")
      |> mes(
        "to delay. Give me a little time to prepare, and then we'll get started on making you something, okay?"
      )
      |> close()
    else
      ctx
      |> delitem(get_local(ctx, :itemreq, 0), 10)
      |> next()
      |> mes("[Hibilaithan]")
      |> mes("Oooh...")
      |> mes("This isn't good.")
      |> mes("You got all of them ^660000wrong^000000.")
      |> mes(
        "We better drive away all of your bad luck with 10 #{Rathena.getitemname(get_local(ctx, :itemreq, 0))}."
      )
      |> next()
      |> mes("[Hibilaithan]")
      |> mes(
        "We can't get started until your luck is strong enough, so we'll need to play this game again. If you don't have enough ores, just get some more before coming back."
      )
      |> next()
      |> mes("[Hibilaithan]")
      |> mes("I'm not going anywhere,")
      |> mes("so there's no rush. Take")
      |> mes("your time, I'll be waiting!")
      |> close()
    end
  end

  defp missing_materials(ctx) do
    ctx
    |> mes("[Hibilaithan]")
    |> mes("Hmm. Something doesn't")
    |> mes("feel right. We must be missing")
    |> mes("something. Would you check the")
    |> mes("materials you've brought again?")
    |> close()
  end

  defp check_materials(ctx) do
    if count_item(ctx, 969) > 9 and count_item(ctx, 999) > 49 and count_item(ctx, 714) > 9 do
      ctx =
        ctx
        |> mes("[Hibilaithan]")
        |> mes(
          "Ooh, you're back earlier than I expected. I see that you have all the basic materials, but did you bring the most important thing...?"
        )
        |> next()

      ores =
        Enum.filter([{7292, "Muscovite"}, {7297, "Biotite"}, {7296, "Pyroxene"}], fn {ore, _name} ->
          count_item(ctx, ore) > 29
        end)

      choose_ore(ctx, ores)
    else
      ctx |> material_requirements() |> close()
    end
  end

  defp choose_ore(ctx, []) do
    ctx
    |> mes("[Hibilaithan]")
    |> mes("Hm...?")
    |> mes("It looks like you didn't")
    |> mes("bring any of that special")
    |> mes("ore I asked for.")
    |> next()
    |> mes("[Hibilaithan]")
    |> mes("Please bring 30 of")
    |> mes("either, Biotite, Muscovite")
    |> mes("or Pyroxene since we need")
    |> mes("one of those kinds of ores")
    |> mes("for me to start crafting.")
    |> close()
  end

  defp choose_ore(ctx, [{ore, _name}]) do
    ctx |> set_local(:itemreq, ore) |> prepare_luck_test()
  end

  defp choose_ore(ctx, ores) do
    ctx =
      case length(ores) do
        3 ->
          ctx
          |> mes("[Hibilaithan]")
          |> mes(
            "Whoa, you brought all three kinds of those ores I asked for? Haha, we can only use one of them, so go ahead and choose."
          )
          |> next()

        2 ->
          ctx
          |> mes("[Hibilaithan]")
          |> mes(
            "Hahaha, you only needed to bring one kind of ore, not two. Now, which ore would you like to use?"
          )
          |> next()
      end

    {ctx, choice} = select(ctx, Enum.map(ores, fn {_ore, name} -> name end))

    case Enum.at(ores, choice - 1) do
      {ore, _name} -> ctx |> set_local(:itemreq, ore) |> prepare_luck_test()
      nil -> ctx
    end
  end

  defp prepare_luck_test(ctx) do
    ctx =
      ctx
      |> mes("[Hibilaithan]")
      |> mes("#{Rathena.getitemname(get_local(ctx, :itemreq, 0))}, eh?")
      |> mes(
        "Alright, before we start, we need to minimize as much of your negative fortune as we can."
      )
      |> next()
      |> mes("[Hibilaithan]")
      |> mes(
        "We're investing a lot of material and energy into this, so it'd be a pity if we fail, right?"
      )
      |> next()
      |> mes("[Hibilaithan]")
      |> mes(
        "Now, if I can craft you something on a day on which your fortune is strong, it should be okay. In order to measure your luck, we'll play a mind reading game."
      )
      |> next()
      |> mes("[Hibilaithan]")
      |> mes(
        "It's simple. You simply guess the name of the monster I'm thinking about among four choices. If you guess correctly once, then we can get started!"
      )
      |> next()
      |> mes("[Hibilaithan]")
      |> mes(
        "I'll be giving you five chances. However, if you get all five wrong, I need to take 10 of the special ore that you brought in order to drive away your misfortune."
      )
      |> next()
      |> mes("[Hibilaithan]")
      |> mes("Sure, that might sound bad,")
      |> mes(
        "but it's a small price to pay for insuring success in crafting your special item, right?"
      )
      |> next()
      |> mes("[Hibilaithan]")
      |> mes(
        "Okay, I'll need some time to get ready. Come back to me a little later so that I can judge your"
      )
      |> mes("luck today~")
      |> delitem(969, 10)
      |> delitem(999, 50)
      |> delitem(714, 10)

    ctx =
      cond do
        count_item(ctx, 7292) > 29 -> set_char_var(ctx, :lv4_weapon, 9)
        count_item(ctx, 7297) > 29 -> set_char_var(ctx, :lv4_weapon, 10)
        count_item(ctx, 7296) > 29 -> set_char_var(ctx, :lv4_weapon, 11)
        true -> ctx
      end

    close(ctx)
  end

  defp material_requirements(ctx) do
    ctx
    |> mes("[Hibilaithan]")
    |> mes("Now, I'll need")
    |> mes("10 Gold,")
    |> mes("50 Steel and")
    |> mes("10 Emperium")
    |> mes("for the basic materials.")
    |> next()
    |> mes("[Hibilaithan]")
    |> mes(
      "I'll also need some rare ore to endow my creation with power. Muscovite, Biotite or Pyroxene. Just bring me 30 of one of those kinds of ores."
    )
    |> next()
    |> mes("[Hibilaithan]")
    |> mes(
      "Okay, I wish you good luck! In the meantime, I shall relax here and wait for your return."
    )
  end
end
