defmodule Aesir.ZoneServer.Content.Npc.Quests.Lvl4WeaponQuest.Tabezthan do
  @moduledoc """
  Tabezthan crafts rare weapons by testing an adventurer's fortune with a mind-reading game.

  ## Behavior

  - Requires inventory capacity and knowledge of Umbala's language; starting a commission requires level 70.
  - Takes Gold, Steel and Emperium, then tests five monster guesses using special ore.
  - Consumes 30 ore on a successful test or 10 on failure and awards the prepared weapon on a later visit.

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
        map: "um_in",
        x: 156,
        y: 77,
        dir: 5,
        sprite: 788,
        name: "Tabezthan",
        scope: :shared,
        unique_name: "Tabezthan#lv4"
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
        |> mes("[Tabezthan]")
        |> mes("Umba! Umbaba...umum! Baumba!")
        |> mes("Umumumbababaumumbabaumba!")
        |> mes("Umbaumbaumbaumbaumhah!")
        |> mes("Umumumumumbababababab!")
        |> close()

      true ->
        commission(ctx, get_char_var(ctx, :lv4_weapon, 0))
    end
  end

  defp commission(ctx, 0), do: introduce(ctx)

  defp commission(ctx, stage) when stage < 15 or stage > 21 do
    ctx
    |> mes("[Tabezthan]")
    |> mes("Hm...?")
    |> mes("You don't have any")
    |> mes("business with me, do you?")
    |> next()
    |> mes("[Tabezthan]")
    |> mes(
      "Please do not disregard me as merely an old fool. When a man gets older, he can see more clearly into the hearts of others. Please continue what you have been doing, and I wish you good fortune on your journeys."
    )
    |> close()
  end

  defp commission(ctx, stage) when stage in [19, 20, 21], do: craft_weapon(ctx, stage)

  defp commission(ctx, stage) when stage in [16, 17, 18] do
    ore = required_ore(stage)

    if Rathena.truthy?(count_item(ctx, ore)) do
      ctx |> set_local(:itemreq, ore) |> mind_reading_game()
    else
      ctx
      |> mes("[Tabezthan]")
      |> mes("Umm...")
      |> mes("You do not seem to")
      |> mes("have enough Rose Quartz.")
      |> mes("Please try to gather at")
      |> mes("least 30 of them and then")
      |> mes("return to me.")
      |> close()
    end
  end

  defp commission(ctx, 15) do
    if count_item(ctx, 969) > 9 and count_item(ctx, 999) > 49 and count_item(ctx, 714) > 9 do
      offer_ores(ctx)
    else
      ctx
      |> mes("[Tabezthan]")
      |> mes("[Tabezthan]")
      |> mes("Bring me...")
      |> mes("10 Gold,")
      |> mes("50 Steel")
      |> mes("and 10 Emperium.")
      |> mes("I'll also need a rare ore to enchant my creation.")
      |> next()
      |> mes("[Tabezthan]")
      |> mes(
        "In addition, please bring me 30 of either Phlogopite, Peridot or Rose Quartz. Depending on the ore that you choose, my creation will possess a different trait."
      )
      |> close()
    end
  end

  defp introduce(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Tabezthan]")
      |> mes("Hmm...")
      |> mes("I feel something different from you. You are a stranger around here, are you not?")
      |> next()
      |> mes("[Tabezthan]")
      |> mes(
        "Allow me to introduce myself. I am Tabezthan, a veritable fountain of knowledge and a renown genius in Umbala. Ha ha ha!"
      )
      |> next()
      |> mes("[Tabezthan]")
      |> mes(
        "I have two disciples: Hibilaithan, who is a fool, and Bazo, who is quite intelligent and shows potential."
      )
      |> next()
      |> mes("[Tabezthan]")
      |> mes(
        "Of course, both are very talented and skilled, but I worry about Hibilaithan. He makes many stupid mistakes but he is fairly shameless about his errors."
      )
      |> next()
      |> mes("[Tabezthan]")
      |> mes("I have taught them how to manipulate the ambient energy")
      |> mes(
        "here in Umbala in order to create objects. I hear that there is a similar skill in the outside world known to you as alchemy."
      )
      |> next()
      |> mes("[Tabezthan]")
      |> mes("In any case, do have any use")
      |> mes(
        "for my skills? If so, please bring me the materials that I need so that I may be of service to you."
      )
      |> next()
      |> select(["Yes, please.", "No, thank you."])

    commission_request(ctx, choice)
  end

  defp commission_request(ctx, 1) do
    if base_level(ctx) < 70 do
      ctx
      |> mes("[Tabezthan]")
      |> mes(
        "I regret to say that you are not yet capable of handling my crafts. Please train and acquire greater strength before returning to me. I wish you safety in your travels."
      )
      |> close()
    else
      ctx
      |> mes("[Tabezthan]")
      |> mes("Good. I ask that you")
      |> mes("remember what you need")
      |> mes("to bring me so that I may craft something for you. I shall need...")
      |> next()
      |> mes("[Tabezthan]")
      |> mes("10 Gold,")
      |> mes("50 Steel")
      |> mes("and 10 Emperium")
      |> mes("for the basic materials.")
      |> mes("I'll also need a rare ore to enchant my creation.")
      |> next()
      |> mes("[Tabezthan]")
      |> mes(
        "In addition, please bring me 30 of either Phlogopite, Peridot or Rose Quartz. Depending on the ore that you choose, my creation will possess a different trait."
      )
      |> next()
      |> mes("[Tabezthan]")
      |> mes(
        "Please be aware that I do not know exactly what item will be produced. There are too many factors in alchemy and there is a limit to anyone's knowledge."
      )
      |> next()
      |> mes("[Tabezthan]")
      |> mes(
        "In other words, we will have to trust to luck. However, we'll have time to talk about that later. For now, please go and gather the necessary materials. I shall be waiting here."
      )
      |> set_char_var(:lv4_weapon, 15)
      |> close()
    end
  end

  defp commission_request(ctx, 2) do
    ctx
    |> mes("[Tabezthan]")
    |> mes("Oh... I see.")
    |> mes("It is a little disappointing to hear that, but please return")
    |> mes("if you believe that I can be")
    |> mes("of service to you.")
    |> close()
  end

  defp commission_request(ctx, _), do: ctx

  defp craft_weapon(ctx, stage) do
    ctx
    |> mes("[Tabezthan]")
    |> mes(
      "Great, I'm ready to begin. Give me a minute to arrange these materials into a mystic circle."
    )
    |> next()
    |> mes(
      "^3355FFHe arranged the materials in a strange circle and began chanting. The air around Tabezthan grew ominously heavy and the materials seemed to surge with newfound energy.^000000"
    )
    |> next()
    |> mes("[Tabezthan]")
    |> mes(
      "Please understand that this power is not coming from me. I am merely using my skills to gather power from the realm of the dead and infusing them into these materials."
    )
    |> next()
    |> mes("[Tabezthan]")
    |> mes("Let us pray for good results.")
    |> mes("All we can do now is leave the")
    |> mes("final result to fate.")
    |> next()
    |> mes("^3355FFThe materials slowly melded")
    |> mes("into each other, combining into a completely new object. It is only")
    |> mes(
      "a matter of time before we learn whether you and Tabezthan have succeeded or failed.^000000"
    )
    |> next()
    |> mes("[Tabezthan]")
    |> award_weapon(stage)
    |> next()
    |> mes("[Tabezthan]")
    |> mes("This mighty weapon is yours to keep. Feel free to come back to me")
    |> mes("if you think that I can be of service to you once again.")
    |> mes("Farewell for now, brave adventurer.")
    |> close()
  end

  defp award_weapon(ctx, stage) do
    {name, item} =
      case stage do
        19 -> {"Caesar's Sword", 1134}
        20 -> {"Tirfing", 1139}
        21 -> {"Sabbath", 1365}
      end

    ctx
    |> mes("I don't believe it!")
    |> mes(
      "This is such an incredibly rare weapon! Yes, I remember its name from what my late father told me. This is... #{name}!"
    )
    |> set_char_var(:lv4_weapon, 0)
    |> give_item(item, 1)
  end

  defp required_ore(16), do: 7290
  defp required_ore(17), do: 7289
  defp required_ore(18), do: 7293

  defp mind_reading_game(ctx) do
    ctx
    |> mes("[Tabezthan]")
    |> mes("Shall we begin?")
    |> mes(
      "I will tell you the names of 4 different monsters. You will be given five chances to predict which monster I am thinking about."
    )
    |> next()
    |> mes("[Tabezthan]")
    |> mes(
      "This mind reading game is an effective method of determining whether your fortune is good or bad. Get ready now..."
    )
    |> next()
    |> set_local(:i, 1)
    |> guess_monsters()
    |> mes("[Tabezthan]")
    |> mes(
      "That's the end of the game. Now, this is the order of the monsters that I had in mind..."
    )
    |> next()
    |> mes("[Tabezthan]")
    |> set_local(:i, 1)
    |> reveal_monsters()
    |> consume_test_ore()
    |> next()
    |> mes("[Tabezthan]")
    |> fortune_result()
  end

  defp guess_monsters(ctx) do
    round = get_local(ctx, :i, 0)

    if round <= 5 do
      {ctx, answer} =
        ctx
        |> set_local(
          :mons,
          Rathena.put_at(get_local(ctx, :mons, []), round, Enum.random(1..4), 0)
        )
        |> mes("[Tabezthan]")
        |> monster_prompt(round)
        |> next()
        |> select(["Baphomet", "Dark Lord", "Bloody Knight", "Stormy Knight"])

      ctx =
        if answer == Enum.at(get_local(ctx, :mons, []), round, 0) do
          set_local(ctx, :dap, get_local(ctx, :dap, 0) + 1)
        else
          ctx
        end

      ctx |> set_local(:i, round + 1) |> guess_monsters()
    else
      ctx
    end
  end

  defp monster_prompt(ctx, 1) do
    ctx
    |> mes("My favorite monsters are")
    |> mes("Baphomet, Dark Lord, Bloody")
    |> mes("Knight and Stormy Knight. Now,")
    |> mes("try to guess which one I am")
    |> mes("thinking about.")
  end

  defp monster_prompt(ctx, 2) do
    ctx
    |> mes("Please try to determine")
    |> mes("which monster I'm thinking")
    |> mes("of right this moment.")
  end

  defp monster_prompt(ctx, 3) do
    ctx
    |> mes("Now, try to sense")
    |> mes("which monster I am")
    |> mes("visualizing in my mind.")
  end

  defp monster_prompt(ctx, 4) do
    ctx
    |> mes("Once again, try")
    |> mes("and guess what monster")
    |> mes("I'm thinking about right now.")
  end

  defp monster_prompt(ctx, 5) do
    ctx
    |> mes("Alright, this is")
    |> mes("your last chance to")
    |> mes("correctly guess which")
    |> mes("monster I'm thinking of.")
  end

  defp reveal_monsters(ctx) do
    round = get_local(ctx, :i, 0)

    if round <= 5 do
      ctx
      |> reveal_monster(Enum.at(get_local(ctx, :mons, []), round, 0))
      |> set_local(:i, round + 1)
      |> reveal_monsters()
    else
      ctx
    end
  end

  defp reveal_monster(ctx, 1), do: mes(ctx, "Baphomet")
  defp reveal_monster(ctx, 2), do: mes(ctx, "Dark Lord")
  defp reveal_monster(ctx, 3), do: mes(ctx, "Bloody Knight")
  defp reveal_monster(ctx, 4), do: mes(ctx, "Stormy Knight")
  defp reveal_monster(ctx, _), do: ctx

  defp consume_test_ore(ctx) do
    if get_local(ctx, :dap, 0) > 0 do
      ctx
      |> delitem(get_local(ctx, :itemreq, 0), 30)
      |> set_char_var(:lv4_weapon, get_char_var(ctx, :lv4_weapon, 0) + 3)
    else
      delitem(ctx, get_local(ctx, :itemreq, 0), 10)
    end
  end

  defp fortune_result(ctx) do
    if get_local(ctx, :dap, 0) > 0 do
      ctx
      |> mes(
        "You have answered #{get_local(ctx, :dap, 0)} times correctly. It appears that your luck is at a high point, and it is an ideal time for me to craft something for you. Give me a little time to prepare, and return to me."
      )
      |> close()
    else
      ctx
      |> mes(
        "Unfortunately, you weren't able to guess any of them correctly. It seems that your luck is charged with negative energy. We'll need to expel this bad luck with 10 of your Phologopite."
      )
      |> next()
      |> mes("[Tabezthan]")
      |> mes(
        "Do not be disheartened. Losing 10 #{Rathena.getitemname(get_local(ctx, :itemreq, 0))} is much better than losing 30 on a failed crafting attempt."
      )
      |> next()
      |> mes("[Tabezthan]")
      |> mes(
        "Please come back with 30 Phologopite, and we shall try this mind reading game once again. I shall be waiting for you right here."
      )
      |> close()
    end
  end

  defp offer_ores(ctx) do
    ctx =
      ctx
      |> mes("[Tabezthan]")
      |> mes(
        "You've returned to me earlier than I've expected. I sense that you've brought all the basic materials, but did you bring enough special ore as well?"
      )
      |> next()

    ores =
      Enum.filter(
        [{7290, "Phlogopite"}, {7289, "Peridot"}, {7293, "Rose Quartz"}],
        fn {item, _name} -> count_item(ctx, item) > 29 end
      )

    choose_ore(ctx, ores)
  end

  defp choose_ore(ctx, []) do
    ctx
    |> mes("[Tabezthan]")
    |> mes("Hmmm...")
    |> mes(
      "It doesn't look like it. Remember, I need 30 of either Phlogopite, Peridot or Rose Quartz before I can begin crafting."
    )
    |> close()
  end

  defp choose_ore(ctx, [{item, _name}]) do
    ctx |> set_local(:itemreq, item) |> prepare_test()
  end

  defp choose_ore(ctx, ores) do
    {ctx, choice} =
      ctx
      |> ore_choice_prompt(length(ores))
      |> next()
      |> select(Enum.map(ores, fn {_item, name} -> name end))

    case Enum.at(ores, choice - 1) do
      {item, _name} -> ctx |> set_local(:itemreq, item) |> prepare_test()
      nil -> ctx
    end
  end

  defp ore_choice_prompt(ctx, 3) do
    ctx
    |> mes("[Tabezthan]")
    |> mes(
      "Ah, you've brought all three. However, we can only use one kind of ore at a time, so please choose just one."
    )
  end

  defp ore_choice_prompt(ctx, 2) do
    ctx
    |> mes("[Tabezthan]")
    |> mes("Hahaha, you didn't need")
    |> mes("to bring more than one kind")
    |> mes("of ore. Now, which one would")
    |> mes("you like to use?")
  end

  defp prepare_test(ctx) do
    ctx
    |> mes("[Tabezthan]")
    |> mes("Good, #{Rathena.getitemname(get_local(ctx, :itemreq, 0))}.")
    |> mes("Now, before I can begin crafting,")
    |> mes("I must first determine whether or not you have enough luck for me")
    |> mes("to proceed.")
    |> next()
    |> mes("[Tabezthan]")
    |> mes("We will play a mind reading game")
    |> mes(
      "so that I can measure your luck and see if it is high enough to avoid the possibility of crafting failure."
    )
    |> next()
    |> mes("[Tabezthan]")
    |> mes(
      "You will have 5 chances to guess which one of my four favorite monsters that I am thinking of. If you can answer correctly even just once, I can begin crafting."
    )
    |> next()
    |> mes("[Tabezthan]")
    |> mes(
      "However, if you answer incorrectly all five times, I must take 10 of your special ore in order to expel your misfortune."
    )
    |> next()
    |> mes("[Tabezthan]")
    |> mes(
      "Now, please give me a little time to finish my preparations. I shall speak to you later."
    )
    |> delitem(999, 50)
    |> delitem(969, 10)
    |> delitem(714, 10)
    |> record_ore_priority()
    |> close()
  end

  defp record_ore_priority(ctx) do
    cond do
      count_item(ctx, 7290) > 29 -> set_char_var(ctx, :lv4_weapon, 16)
      count_item(ctx, 7289) > 29 -> set_char_var(ctx, :lv4_weapon, 17)
      count_item(ctx, 7293) > 29 -> set_char_var(ctx, :lv4_weapon, 18)
      true -> ctx
    end
  end
end
