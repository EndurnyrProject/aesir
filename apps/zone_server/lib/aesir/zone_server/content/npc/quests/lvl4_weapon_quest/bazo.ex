defmodule Aesir.ZoneServer.Content.Npc.Quests.Lvl4WeaponQuest.Bazo do
  @moduledoc """
  Bazo crafts Umbala weapons after testing an adventurer's luck with a mind-reading game.

  ## Behavior

  - Requires inventory capacity and level 70 to begin gathering crafting materials.
  - Takes 10 Gold, 50 Steel and 10 Emperium, then tests luck with five monster guesses.
  - Consumes 30 selected ores on success or 10 on failure; a successful attempt yields a weapon on the next visit.
  - Shares quest progress with the other weapon artisans and resets it after awarding a weapon.

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
        x: 117,
        y: 285,
        dir: 3,
        sprite: 85,
        name: "Bazo",
        scope: :shared,
        unique_name: "Bazo#lv4"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if checkweight(ctx, [{908, 300}]) == 0 do
      ctx
      |> mes(
        "^3355FFWait a second! Right now, you're carrying too many items with you. Please come back after putting some of your things into Kafra Storage.^000000"
      )
      |> close()
    else
      quest_progress(ctx)
    end
  end

  defp quest_progress(ctx) do
    progress = get_char_var(ctx, :lv4_weapon, 0)

    cond do
      progress == 0 ->
        introduction(ctx)

      progress > 7 ->
        other_artisan(ctx)

      progress >= 5 and progress <= 7 ->
        craft_weapon(ctx)

      progress in [2, 3, 4] ->
        check_selected_ore(ctx, progress)

      progress == 1 ->
        check_materials(ctx)

      true ->
        introduction(ctx)
    end
  end

  defp introduction(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Bazo]")
      |> mes("Hello...")
      |> mes("Not from around")
      |> mes("here, are you?")
      |> next()
      |> mes("[Bazo]")
      |> mes(
        "My name is Bazo Heburiech. I'm pleased to make your acquaintance. As you can see, I'm also not from around here either. I feel as if... We were meant to meet."
      )
      |> next()
      |> mes("[Bazo]")
      |> mes(
        "If you don't mind, let me tell you a little about this place. When I first got here, I could tell there was something different about"
      )
      |> mes("this village.")
      |> next()
      |> mes("[Bazo]")
      |> mes("For one thing, Umbala is close")
      |> mes(
        "to Niflheim, realm of the dead. Because it's so near, some of the people here can actually draw evil power from that realm."
      )
      |> next()
      |> mes("[Bazo]")
      |> mes(
        "Don't worry, the locals here only use this power to produce specialty items. During my stay here, I too have learned some of those crafting methods."
      )
      |> next()
      |> mes("[Bazo]")
      |> mes("If you like, I'd be willing to show you my skills. Now how does that sound?")
      |> next()
      |> select(["Sounds good~", "No, thanks."])

    case choice do
      1 -> begin_quest(ctx)
      2 -> decline(ctx)
      _ -> ctx
    end
  end

  defp begin_quest(ctx) do
    if base_level(ctx) < 70 do
      ctx
      |> mes("[Bazo]")
      |> mes("Hmm. For now, you should level")
      |> mes(
        "up and get stronger first. Please understand that I mean well when I say that I don't think you're quite ready for my goods."
      )
      |> next()
      |> mes("[Bazo]")
      |> mes("Like I said before, these")
      |> mes(
        "goods have some evil power. If you're not strong or experienced enough, you'd be driven insane."
      )
      |> next()
      |> mes("[Bazo]")
      |> mes("Once you're ready,")
      |> mes("I'll gladly make you")
      |> mes("something great~")
      |> close()
    else
      ctx
      |> mes("[Bazo]")
      |> mes(
        "Excellent! Let me tell you what materials I'll need. There's not that many, but you might want to write them down."
      )
      |> next()
      |> material_requirements()
      |> set_char_var(:lv4_weapon, 1)
      |> close()
    end
  end

  defp decline(ctx) do
    ctx
    |> mes("[Bazo]")
    |> mes("Oh, okay.")
    |> mes("That's fine with me.")
    |> mes("But I'll be right here if you")
    |> mes("ever change your mind.")
    |> close()
  end

  defp other_artisan(ctx) do
    ctx
    |> mes("[Bazo]")
    |> mes("Hmm...")
    |> mes(
      "I sense something different about you. I can't quite describe it, but I get the distince feeling that there's nothing I can do for you."
    )
    |> next()
    |> mes("[Bazo]")
    |> mes("In any case, I wish you safety in your travels, adventurer.")
    |> close()
  end

  defp craft_weapon(ctx) do
    ctx
    |> mes("[Bazo]")
    |> mes("Great...!")
    |> mes("Now, let's do this!")
    |> mes("Oh, and you should know")
    |> mes(
      "now that I can't tell what kind of thing we might get. But let's hope that it'll be good."
    )
    |> next()
    |> mes("^3355FFYou feel a mysterious energy gathering around the materials")
    |> mes(
      "and the air around them begins to crackle. It seems as if the materials were absorbing"
    )
    |> mes("all of the ambient energy.^000000")
    |> next()
    |> mes(
      "^3355FFWithout any discernable action from Bazo, the materials began to fuse into each other.^000000"
    )
    |> next()
    |> mes("[Bazo]")
    |> mes(
      "Can you feel that? The materials are now gathering power on their own. It's out of my hands now. All we can do now is wait and pray."
    )
    |> next()
    |> mes("^3355FFThe materials finish melding")
    |> mes("and the air grows calm.^000000")
    |> next()
    |> mes("[Bazo]")
    |> mes("Ooooooh! It's done!")
    |> mes("We've succeeded! Ah,")
    |> mes("this is amazing! Our prayers")
    |> mes("must have been answered!")
    |> next()
    |> mes("[Bazo]")
    |> mes(
      "It looks like all those materials turned into some kind of weapon. That ought to be quite useful to you. Now let's see..."
    )
    |> next()
    |> mes("[Bazo]")
    |> award_weapon(get_char_var(ctx, :lv4_weapon, 0))
    |> next()
    |> mes("[Bazo]")
    |> mes(
      "Ah, I'm very satisfied with these results. If you wish to have another one, please feel free to visit me anytime. Alright then, enjoy your travels~"
    )
    |> close()
  end

  defp award_weapon(ctx, 5) do
    ctx
    |> mes("Immaterial Sword!")
    |> mes("This sword was born to be yours!")
    |> mes("Congratulations and hopefully it will be useful to you.")
    |> set_char_var(:lv4_weapon, 0)
    |> give_item(1141, 1)
  end

  defp award_weapon(ctx, 6) do
    ctx
    |> mes("Slash!")
    |> mes("This mace was born to be yours!")
    |> mes("Congratulations and hopefully it will be useful to you.")
    |> set_char_var(:lv4_weapon, 0)
    |> give_item(1526, 1)
  end

  defp award_weapon(ctx, 7) do
    ctx
    |> mes("Quadrille!")
    |> mes("This mace was born to be yours!")
    |> mes("Congratulations and hopefully it will be useful to you.")
    |> set_char_var(:lv4_weapon, 0)
    |> give_item(1527, 1)
  end

  defp award_weapon(ctx, _progress), do: ctx

  defp check_selected_ore(ctx, progress) do
    ore =
      case progress do
        2 -> 7295
        3 -> 7294
        4 -> 7291
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
    |> mes("[Bazo]")
    |> mes("Okay, it seems like you're")
    |> mes(
      "ready so let's get started. Now, my favorite monsters are Poring, Hode, Obeaune and Minorous."
    )
    |> next()
    |> ask_monsters()
    |> mes("[Bazo]")
    |> mes(
      "Okay, let me give you the answers for the questions in the order I was thinking. Now, it might seem like I'm making them up right now, but I'm not. We gotta trust each other on this."
    )
    |> next()
    |> mes("[Bazo]")
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
        |> mes("[Bazo]")
        |> monster_question(question_number)
        |> next()
        |> select(["Poring", "Hode", "Obeaune", "Minorous"])

      if answer == Enum.at(monsters, question_number, 0) do
        set_local(ctx, :dap, get_local(ctx, :dap, 0) + 1)
      else
        ctx
      end
    end)
  end

  defp monster_question(ctx, 1) do
    ctx
    |> mes("Here's the first question.")
    |> mes("What monster am I thinking")
    |> mes("of right now?")
  end

  defp monster_question(ctx, 2) do
    ctx
    |> mes("Alright...")
    |> mes("Now guess which monster")
    |> mes("I'm thinking about right... Now!")
  end

  defp monster_question(ctx, 3) do
    ctx
    |> mes("Now what monster")
    |> mes("am I thinking about?")
  end

  defp monster_question(ctx, 4) do
    ctx
    |> mes("Which monster am")
    |> mes("I thinking about right now?")
  end

  defp monster_question(ctx, 5) do
    ctx
    |> mes("Okay, one last time.")
    |> mes("Guess which monster I'm")
    |> mes("thinking about right now.")
  end

  defp reveal_monsters(ctx) do
    Enum.reduce(1..5, ctx, fn question_number, ctx ->
      case Enum.at(get_local(ctx, :mons, []), question_number, 0) do
        1 -> mes(ctx, "Poring")
        2 -> mes(ctx, "Hode")
        3 -> mes(ctx, "Obeaune")
        4 -> mes(ctx, "Minorous")
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
      |> mes("[Bazo]")
      |> mes(
        "You got the right answer #{get_local(ctx, :dap, 0)} times! Incredible! As promised, I shall create a specialty Umbala item for you. Give me a little time to get ready, and then we'll get started."
      )
      |> close()
    else
      ctx
      |> delitem(get_local(ctx, :itemreq, 0), 10)
      |> next()
      |> mes("[Bazo]")
      |> mes("Huh. You must not be able to")
      |> mes(
        "read minds, or you've got really bad luck. Either way, we can't try this until we drive away the ill fortune around you."
      )
      |> next()
      |> mes("[Bazo]")
      |> mes("Hm, we need at least")
      |> mes("10 #{Rathena.getitemname(get_local(ctx, :itemreq, 0))} to try this")
      |> mes("again, so go ahead")
      |> mes("and give me that.")
      |> next()
      |> mes("[Bazo]")
      |> mes("Well, if you want to try this mind reading game again, just come")
      |> mes("back with the materials. I'll be waiting to gauge your luck.")
      |> close()
    end
  end

  defp missing_materials(ctx) do
    ctx
    |> mes("[Bazo]")
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
        |> mes("[Bazo]")
        |> mes(
          "Oh, you've brought all the basic materials. Now, let me check to see if you brought any of the rare ores I asked for..."
        )
        |> next()

      ores =
        Enum.filter([{7295, "Citrin"}, {7294, "Turquoise"}, {7291, "Agate"}], fn {ore, _name} ->
          count_item(ctx, ore) > 29
        end)

      choose_ore(ctx, ores)
    else
      ctx
      |> mes("[Bazo]")
      |> mes(
        "If you'd like me to make you one of Umbala's specialty items, I'll need you to bring me some stuff so I can craft it for you."
      )
      |> next()
      |> material_requirements()
      |> close()
    end
  end

  defp choose_ore(ctx, []) do
    ctx
    |> mes("[Bazo]")
    |> mes("Please bring me 30 Citrin, Turquoise or Agate. You must")
    |> mes(
      "have forgotten to bring any of those, so please go back and get them so we can begin."
    )
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
          |> mes("[Bazo]")
          |> mes("Hahaha, I asked you to")
          |> mes("bring one kind of ore, not all of them. So which one would you")
          |> mes("like to use?")
          |> next()

        2 ->
          ctx
          |> mes("Hahaha, I asked you to")
          |> mes("bring one kind of ore, not")
          |> mes("two. So which one would")
          |> mes("you like to use?")
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
      |> mes("[Bazo]")
      |> mes("#{Rathena.getitemname(get_local(ctx, :itemreq, 0))}, huh?")
      |> mes(
        "Alright then. Before we start, we must first test your luck. As you may have guessed, item crafting in Umbala is a very delicate process."
      )
      |> next()
      |> mes("[Bazo]")
      |> mes(
        "But if we do this during a time when your luck is high, we'll have a good chance of succeeding in creating something great. That makes sense, right?"
      )
      |> next()
      |> mes("[Bazo]")
      |> mes("Now, we'll test your luck by playing a simple mind reading")
      |> mes("game. I'll think of a specific monster, and you'll have to")
      |> mes("guess what it is from among")
      |> mes("my favorites.")
      |> next()
      |> mes("[Bazo]")
      |> mes(
        "I'll give you five different chances, and if you can guess right once, we'll go ahead and craft the item. But if you get all of them wrong, we've got to drive away all the bad luck!"
      )
      |> next()
      |> mes("[Bazo]")
      |> mes(
        "In order to drive away ill fortune, I'll be taking 10 of the special ore you've brought along. I know it sounds bad, but it's a lot better than losing 30 ores if we failed to create the item, right?"
      )
      |> next()
      |> mes("[Bazo]")
      |> mes("Okay, now I need")
      |> mes("some time to preprare...")
      |> mes("Talk to you later!")
      |> delitem(969, 10)
      |> delitem(999, 50)
      |> delitem(714, 10)

    ctx =
      case get_local(ctx, :itemreq, 0) do
        7295 -> set_char_var(ctx, :lv4_weapon, 2)
        7294 -> set_char_var(ctx, :lv4_weapon, 3)
        7291 -> set_char_var(ctx, :lv4_weapon, 4)
        _ -> ctx
      end

    close(ctx)
  end

  defp material_requirements(ctx) do
    ctx
    |> mes("[Bazo]")
    |> mes("First, I'll need")
    |> mes("some basic materials.")
    |> mes("10 Gold,")
    |> mes("50 Steel and")
    |> mes("10 Emperium.")
    |> next()
    |> mes("[Bazo]")
    |> mes(
      "Then, I'll need some rare ore to enchant this product. The product's trait will depend on the ore that you use."
    )
    |> next()
    |> mes("[Bazo]")
    |> mes(
      "Please bring me 30 of either Citrin, Turquoise or Agate. Well then, I wish you luck in finding those things and I'll be waiting for you~"
    )
  end
end
