defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Guildrelay.Relaydummy3Guildrelay3 do
  @moduledoc """
  Castle stronghold member who runs the closing legs of the Guild Relay quest chain.

  ## Behavior

  - Turns away players who carry too much weight or who stand in an ownerless castle.
  - Sages holding the Spirit of Trust are told to spend time bonding with their guild, and must
    come back at the right hour of the day to receive the Spirit of Agreement.
  - Bards and Dancers holding the Spirit of Agreement gather 30 each of three randomly drawn items
    before the Spirit of Combination can be earned.
  - Assassins holding the Spirit of Combination trade it for the Spirit of Unity.
  - Wizards holding the Spirit of Unity are set a level-up trial sized to their level, or are
    handed the Spirit of Friendship outright above level 96.
  - Whoever carries an unfinished spirit is reminded which guild job it belongs to.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - NoHealing

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """
  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "aldeg_cas01",
        x: 200,
        y: 175,
        dir: 3,
        sprite: 754,
        name: "Gealuve",
        scope: :shared,
        unique_name: "Gealuve#01"
      },
      %{
        map: "aldeg_cas02",
        x: 62,
        y: 65,
        dir: 3,
        sprite: 754,
        name: "Gealuve",
        scope: :shared,
        unique_name: "Gealuve#02"
      },
      %{
        map: "aldeg_cas03",
        x: 114,
        y: 119,
        dir: 3,
        sprite: 754,
        name: "Gealuve",
        scope: :shared,
        unique_name: "Gealuve#03"
      },
      %{
        map: "aldeg_cas04",
        x: 24,
        y: 80,
        dir: 3,
        sprite: 754,
        name: "Gealuve",
        scope: :shared,
        unique_name: "Gealuve#04"
      },
      %{
        map: "aldeg_cas05",
        x: 148,
        y: 224,
        dir: 3,
        sprite: 754,
        name: "Gealuve",
        scope: :shared,
        unique_name: "Gealuve#05"
      },
      %{
        map: "gefg_cas01",
        x: 184,
        y: 40,
        dir: 3,
        sprite: 754,
        name: "Vers",
        scope: :shared,
        unique_name: "Vers#01"
      },
      %{
        map: "gefg_cas02",
        x: 178,
        y: 38,
        dir: 3,
        sprite: 754,
        name: "Vers",
        scope: :shared,
        unique_name: "Vers#02"
      },
      %{
        map: "gefg_cas03",
        x: 158,
        y: 57,
        dir: 3,
        sprite: 754,
        name: "Vers",
        scope: :shared,
        unique_name: "Vers#03"
      },
      %{
        map: "gefg_cas04",
        x: 55,
        y: 70,
        dir: 5,
        sprite: 754,
        name: "Vers",
        scope: :shared,
        unique_name: "Vers#04"
      },
      %{
        map: "gefg_cas05",
        x: 87,
        y: 31,
        dir: 3,
        sprite: 754,
        name: "Vers",
        scope: :shared,
        unique_name: "Vers#05"
      },
      %{
        map: "payg_cas01",
        x: 13,
        y: 146,
        dir: 5,
        sprite: 741,
        name: "Yayula",
        scope: :shared,
        unique_name: "Yayula#01"
      },
      %{
        map: "payg_cas02",
        x: 252,
        y: 287,
        dir: 3,
        sprite: 741,
        name: "Yayula",
        scope: :shared,
        unique_name: "Yayula#02"
      },
      %{
        map: "payg_cas03",
        x: 16,
        y: 16,
        dir: 5,
        sprite: 741,
        name: "Yayula",
        scope: :shared,
        unique_name: "Yayula#03"
      },
      %{
        map: "payg_cas04",
        x: 69,
        y: 270,
        dir: 3,
        sprite: 741,
        name: "Yayula",
        scope: :shared,
        unique_name: "Yayula#04"
      },
      %{
        map: "payg_cas05",
        x: 283,
        y: 24,
        dir: 3,
        sprite: 741,
        name: "Yayula",
        scope: :shared,
        unique_name: "Yayula#05"
      },
      %{
        map: "prtg_cas01",
        x: 149,
        y: 78,
        dir: 3,
        sprite: 92,
        name: "Cecil",
        scope: :shared,
        unique_name: "Cecil#01"
      },
      %{
        map: "prtg_cas02",
        x: 52,
        y: 63,
        dir: 3,
        sprite: 92,
        name: "Cecil",
        scope: :shared,
        unique_name: "Cecil#02"
      },
      %{
        map: "prtg_cas03",
        x: 71,
        y: 81,
        dir: 5,
        sprite: 92,
        name: "Cecil",
        scope: :shared,
        unique_name: "Cecil#03"
      },
      %{
        map: "prtg_cas04",
        x: 6,
        y: 281,
        dir: 5,
        sprite: 92,
        name: "Cecil",
        scope: :shared,
        unique_name: "Cecil#04"
      },
      %{
        map: "prtg_cas05",
        x: 276,
        y: 93,
        dir: 3,
        sprite: 92,
        name: "Cecil",
        scope: :shared,
        unique_name: "Cecil#05"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = set_local(ctx, :npc_name, strnpcinfo(ctx, 1))
    {castle_map, _x, _y} = getmapxy(ctx, :npc)
    castle_id = castle_data(ctx, castle_map, 1)

    cond do
      checkweight(ctx, [{1201, 1}]) == 0 -> encumbered(ctx)
      castle_id == 0 -> ownerless_castle(ctx)
      getcharid(ctx, 2) != castle_id -> outsider(ctx, castle_id)
      is_guild_leader(ctx) == 1 -> guild_master(ctx)
      true -> guild_member(ctx)
    end
  end

  defp encumbered(ctx) do
    ctx
    |> mes("^3355FFWait a minute! You're")
    |> mes("carrying too many items")
    |> mes("right now: store some of")
    |> mes("your extra things in Kafra")
    |> mes("Storage, and then come back.^000000")
    |> close()
  end

  defp ownerless_castle(ctx) do
    ctx
    |> mes("^3355FFThis exhausted man")
    |> mes("notices you staring at")
    |> mes("him, but chooses to leave")
    |> mes("you alone. There's no one")
    |> mes("else in this stronghold so")
    |> mes("there's no reason to be here.^000000")
    |> close()
  end

  defp outsider(ctx, castle_id) do
    if is_guild_leader(ctx, castle_id) == 1 do
      ctx
      |> mes(header(ctx))
      |> mes("Hm. You're the master")
      |> mes("of another guild, aren't")
      |> mes("you? I have no loyalty")
      |> mes("towards you. Please...")
      |> mes("Leave this place.")
      |> close()
    else
      ctx
      |> mes(header(ctx))
      |> mes("Hm? You have no reason")
      |> mes("to linger in this stronghold.")
      |> mes("Please leave this place now.")
      |> close()
    end
  end

  defp guild_master(ctx) do
    if count_item(ctx, 7240) > 0 do
      ctx
      |> mes(header(ctx))
      |> mes("Hm? What are you doing?")
      |> mes("You're not supposed to")
      |> mes("be the one holding onto")
      |> mes("this soul. A Sage or a")
      |> mes("Professor was supposed")
      |> mes("to come here with it.")
      |> next()
      |> mes(header(ctx))
      |> mes("Make sure you give")
      |> mes("that soul you're holding")
      |> mes("to a ^FF0000Sage^000000 or ^FF0000Professor^000000, and")
      |> mes("then have him bring it to me.")
      |> close()
    else
      ctx
      |> mes(header(ctx))
      |> mes("Our business together")
      |> mes("has concluded. If you're")
      |> mes("not busy, why don't you try")
      |> mes("helping out your guild? Yes,")
      |> mes("I'm sure they'd appreciate it.")
      |> close()
    end
  end

  defp guild_member(ctx) do
    quest = get_char_var(ctx, :guildrelay_q, 0)

    cond do
      job?(ctx, :sage) and count_item(ctx, 7240) > 0 ->
        assign_bonding_trial(ctx)

      job?(ctx, :sage) and quest == 9 ->
        bonding_trial_progress(ctx)

      (job?(ctx, :bard) or job?(ctx, :dancer)) and count_item(ctx, 7241) > 0 ->
        assign_gathering_test(ctx)

      quest == 10 and gathered?(ctx, [7097, 7172, 920]) ->
        items_delivered(ctx, [7097, 7172, 920])

      quest == 11 and gathered?(ctx, [7189, 7194, 7155]) ->
        items_delivered(ctx, [7189, 7194, 7155])

      quest == 80 and gathered?(ctx, [7106, 7121, 1027]) ->
        items_delivered(ctx, [7106, 7121, 1027])

      quest == 10 ->
        gathering_reminder(ctx, ["Burning Hearts", "Wolf Claws", "Leopard Claws"])

      quest == 11 ->
        gathering_reminder(ctx, ["Soft Blades of Grass", "Wooden Hearts", "Poisonous Toad Skins"])

      quest == 80 ->
        gathering_reminder(ctx, ["Antelope Horns", "Honey Pots", "Porcupine Quills"])

      job?(ctx, :assassin) and count_item(ctx, 7242) > 0 ->
        accept_combination_spirit(ctx)

      job?(ctx, :wizard) and count_item(ctx, 7244) > 0 ->
        level_trial(ctx)

      quest == 12 and job?(ctx, :wizard) ->
        not_strong_enough(ctx)

      quest == 13 and job?(ctx, :wizard) ->
        not_strong_enough(ctx)

      quest == 14 and job?(ctx, :wizard) ->
        still_leveling(ctx)

      quest == 71 and count_item(ctx, 7241) > 0 ->
        union_reminder(ctx)

      quest == 71 ->
        scholar_support(ctx)

      quest == 72 and count_item(ctx, 7242) > 0 ->
        combination_reminder(ctx)

      quest == 72 ->
        performer_support(ctx, "Your songs bolster your")

      quest == 73 and count_item(ctx, 7242) > 0 ->
        combination_reminder(ctx)

      quest == 73 ->
        performer_support(ctx, "Your dances bolster your")

      quest == 74 and count_item(ctx, 7244) > 0 ->
        solidarity_reminder(ctx)

      quest == 74 ->
        wizard_support(ctx)

      quest == 75 and count_item(ctx, 7245) > 0 ->
        friendship_reminder(ctx)

      quest == 75 ->
        loyal_support(ctx)

      true ->
        no_business(ctx)
    end
  end

  defp assign_bonding_trial(ctx) do
    ctx =
      ctx
      |> mes(header(ctx))
      |> mes("I see that you've brought")
      |> mes("the ^42426FSpirit of Trust^000000. Now, the")
      |> mes("first thing I want you to do is")
      |> mes("to build the trust between you")
      |> mes("and your guild members.")
      |> mes("Spend time with them.")
      |> next()

    ctx =
      ctx
      |> mes(header(ctx))
      |> mes("I want you to build")
      |> mes("up some friendly bonds")
      |> mes("within your guild before")
      |> mes("coming back to me. Your")
      |> mes("guild must have solidarity")
      |> mes("in order to be successful.")
      |> delitem(7240, 1)
      |> set_char_var(:guildrelay_q, 9)

    ctx
    |> set_char_var(:guildtime, Rathena.atoi(gettimestr(ctx, "%H%M", 5)))
    |> close()
  end

  defp bonding_trial_progress(ctx) do
    time = Rathena.atoi(gettimestr(ctx, "%H%M", 5))
    visit_hour = get_char_var(ctx, :guildtime, 0)

    cond do
      visit_hour > 2259 -> bonding_outcome(ctx, time > 201 and time < visit_hour, 81)
      visit_hour > 2159 -> bonding_outcome(ctx, time > 101 and time < visit_hour, 71)
      visit_hour > 2059 -> bonding_outcome(ctx, time > 1 and time < visit_hour, 71)
      time - visit_hour > 300 -> bonding_completed(ctx)
      true -> back_too_soon(ctx)
    end
  end

  defp bonding_outcome(ctx, true, quest) do
    ctx
    |> mes(header(ctx))
    |> mes("So did you spend some")
    |> mes("quality time with your")
    |> mes("guild members, and get")
    |> mes("a chance to really learn")
    |> mes("who they are? You must")
    |> mes("love your comrades.")
    |> next()
    |> mes(header(ctx))
    |> mes("Now you know how")
    |> mes("important bonding truly")
    |> mes("is. Please give this spirit")
    |> mes("to a ^42426FBard^000000, ^42426FMinstrel^000000, ^42426FDancer^000000,")
    |> mes("or ^42426FGypsy^000000. Good luck to you.")
    |> set_char_var(:guildrelay_q, quest)
    |> give_item(7241, 1)
    |> close()
  end

  defp bonding_outcome(ctx, false, _quest), do: back_too_soon(ctx)

  defp bonding_completed(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("So did you spend some")
    |> mes("quality time with your")
    |> mes("guild members, and get")
    |> mes("a chance to really learn")
    |> mes("who they are? You must")
    |> mes("love your comrades.")
    |> next()
    |> mes(header(ctx))
    |> mes("You have done")
    |> mes("what you had to do for now.")
    |> mes("Please give it to a ^42426FBard^000000 or ^42426FClown^000000")
    |> mes("You can also give it to ^42426FDancer^000000 or ^42426FGypsy^000000")
    |> mes("Good luck.")
    |> set_char_var(:guildrelay_q, 71)
    |> give_item(7241, 1)
    |> close()
  end

  defp back_too_soon(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("Hm? Back so soon?")
    |> mes("That hasn't been enough")
    |> mes("time for you to really bond")
    |> mes("with your guild members.")
    |> mes("Go back, ask them about their")
    |> mes("dreams, passions, and goals!")
    |> close()
  end

  defp assign_gathering_test(ctx) do
    ctx =
      ctx
      |> mes(header(ctx))
      |> mes("For the sake of promoting")
      |> mes("teamwork amongst your guild,")
      |> mes("my test will be for you to")
      |> mes("gather specific items for me.")
      |> next()
      |> mes(header(ctx))
      |> mes("This is a difficult task")
      |> mes("to complete alone, but it")
      |> mes("will be much easier if you")
      |> mes("and your guild cooperate to")
      |> mes("get all the items. Now listen,")
      |> mes("this is what I want you to get.")
      |> next()

    {materials, quest} =
      Enum.random([
        {["Burning Hearts", "Wolf Claws", "Leopard Claws"], 10},
        {["Soft Blades of Grass", "Wooden Hearts", "Poisonous Toad Skins"], 11},
        {["Antelope Horns", "Honey Pots", "Porcupine Quills"], 80}
      ])

    ctx
    |> materials_page(materials)
    |> delitem(7241, 1)
    |> set_char_var(:guildrelay_q, quest)
    |> next()
    |> mes(header(ctx))
    |> mes("You should be bonding")
    |> mes("with your guild while you")
    |> mes("gather those items I asked")
    |> mes("you to bring. I know enough")
    |> mes("time hasn't passed for your")
    |> mes("guild to work together on this.")
    |> close()
  end

  defp gathering_reminder(ctx, materials) do
    ctx
    |> mes(header(ctx))
    |> mes("Hm? You still haven't")
    |> mes("gathered all the items")
    |> mes("with your guild yet?")
    |> mes("Let me remind you what")
    |> mes("you need to bring me.")
    |> next()
    |> materials_page(materials)
    |> close()
  end

  defp materials_page(ctx, [first, second, third]) do
    ctx
    |> mes(header(ctx))
    |> mes("^8C171730 #{first}^000000,")
    |> mes("^8C171730 #{second}^000000, and")
    |> mes("^8C171730 #{third}^000000.")
    |> mes("You might want to write")
    |> mes("these down so you don't")
    |> mes("forget. Good luck to you.")
  end

  defp gathered?(ctx, item_ids) do
    Enum.all?(item_ids, &(count_item(ctx, &1) > 29))
  end

  defp items_delivered(ctx, [first, second, third]) do
    ctx
    |> mes(header(ctx))
    |> mes("Oh, perfect! You brought")
    |> mes("all the items. Well then,")
    |> mes("I guess you're ready to")
    |> mes("take this spirit now. Please")
    |> mes("give it to an ^42426FAssassin^000000 or an")
    |> mes("^42426FAssassin Cross^000000. Thank you.")
    |> delitem(first, 30)
    |> delitem(second, 30)
    |> delitem(third, 30)
    |> set_char_var(:guildrelay_q, 72)
    |> give_item(7242, 1)
    |> close()
  end

  defp accept_combination_spirit(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("You brought the")
    |> mes("Spirit of Combination?")
    |> mes("Make sure that you give")
    |> mes("that to a ^2F4F2FWizard^000000 or")
    |> mes("a ^2F4F2FHigh Wizard^000000.")
    |> delitem(7242, 1)
    |> set_char_var(:guildrelay_q, 74)
    |> give_item(7244, 1)
    |> close()
  end

  defp level_trial(ctx) do
    ctx =
      ctx
      |> mes(header(ctx))
      |> mes("For the sake of your")
      |> mes("guild, you must become")
      |> mes("stronger. Sometimes")
      |> mes("your spells will make the")
      |> mes("difference between victory")
      |> mes("and defeat. Remember that.")
      |> next()
      |> mes(header(ctx))
      |> mes("Hey,#{char_name(ctx, 0)},")
      |> mes("if you really want to become")
      |> mes("strong enough to protect your")
      |> mes("guild, then you must level up.")
      |> mes("Come back to me once you've")
      |> mes("raised your Base Level.")
      |> next()

    assign_level_trial(ctx, base_level(ctx))
  end

  defp assign_level_trial(ctx, level) when level > 0 and level < 61 do
    level_trial_task(ctx, "^FF00003 Base Levels^000000", 12)
  end

  defp assign_level_trial(ctx, level) when level > 60 and level < 76 do
    level_trial_task(ctx, "^FF00002 Base Levels^000000", 13)
  end

  defp assign_level_trial(ctx, level) when level > 75 and level < 97 do
    level_trial_task(ctx, "^FF00001 Base Level^000000", 14)
  end

  defp assign_level_trial(ctx, level) when level > 96 do
    ctx
    |> mes(header(ctx))
    |> mes("Hm. You're much stronger")
    |> mes("that I expected. There's no")
    |> mes("need for me to encourage")
    |> mes("you to develop your strength.")
    |> mes("I admit that you are strong.")
    |> next()
    |> mes(header(ctx))
    |> mes("Acknowledge the extent and")
    |> mes("limits of your strength, but")
    |> mes("never allow conceit to pollute")
    |> mes("your heart. Pride will always")
    |> mes("shackle your power if you")
    |> mes("let it. Remember humility.")
    |> next()
    |> mes(header(ctx))
    |> mes("You qualified enough")
    |> mes("for me to trust you.")
    |> mes("Please give this spirit")
    |> mes("to your ^FF0000Guild Master^000000.")
    |> mes("You're done for now.")
    |> delitem(7244, 1)
    |> set_char_var(:guildrelay_q, 75)
    |> give_item(7245, 1)
    |> close()
  end

  defp assign_level_trial(ctx, _level), do: ctx

  defp level_trial_task(ctx, level_gain, quest) do
    ctx
    |> mes(header(ctx))
    |> mes("You will be ready")
    |> mes("for your task after you")
    |> mes("gain #{level_gain}.")
    |> mes("Don't despair: I know")
    |> mes("you'll be able to reach")
    |> mes("this goal. Good luck to you.")
    |> delitem(7244, 1)
    |> set_char_var(:guildrelay_q, quest)
    |> close()
  end

  defp not_strong_enough(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("You're not strong enough")
    |> mes("yet for your guild to fully")
    |> mes("rely on you in a crisis.")
    |> mes("You must level up!")
    |> close()
  end

  defp still_leveling(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("Hmm... I don't think you've")
    |> mes("spent enough time leveling")
    |> mes("up yet. Keep working on it.")
    |> close()
  end

  defp union_reminder(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("There's no need for you")
    |> mes("to hold onto that Spirit")
    |> mes("of Union. Please give it to")
    |> mes("a Bard, Minstrel, Dancer")
    |> mes("or Gypsy in your guild.")
    |> close()
  end

  defp combination_reminder(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("There's no need for you")
    |> mes("to hold onto that Spirit of")
    |> mes("Combination. Please give")
    |> mes("it to an Assassin or Assassin")
    |> mes("Cross in your guild.")
    |> close()
  end

  defp solidarity_reminder(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("There's no need for you")
    |> mes("to hold onto that Spirit")
    |> mes("of Solidarity. Please give")
    |> mes("it to a Wizard or High")
    |> mes("Wizard in your guild.")
    |> close()
  end

  defp friendship_reminder(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("There's no need for you")
    |> mes("to hold onto that Spirit of")
    |> mes("Friendship. Please give")
    |> mes("it to your Guild Master.")
    |> close()
  end

  defp scholar_support(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("When you improve yourself,")
    |> mes("you'll also be strengthening")
    |> mes("your guild. Always devote some")
    |> mes("time for yourself and for your")
    |> mes("team. You cannot have one")
    |> mes("without the other.")
    |> next()
    |> mes(header(ctx))
    |> offer_support()
    |> close()
  end

  defp performer_support(ctx, first_line) do
    ctx
    |> mes(header(ctx))
    |> mes(first_line)
    |> mes("guild's morale, and will")
    |> mes("help them stand and fight,")
    |> mes("no matter how desperate")
    |> mes("the situation may seem.")
    |> mes("Your voice can make miracles.")
    |> next()
    |> mes(header(ctx))
    |> offer_support()
    |> close()
  end

  defp wizard_support(ctx) do
    ctx
    |> mes(header(ctx))
    |> offer_support()
    |> next()
    |> mes(header(ctx))
    |> mes("Know who your enemies are.")
    |> mes("If anybody opposes your guild,")
    |> mes("you must crush them without")
    |> mes("any hesitation. Your justice")
    |> mes("must be meted swiftly!")
    |> close()
  end

  defp loyal_support(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("I can tell that you're")
    |> mes("always trying to help all")
    |> mes("the members of your guild.")
    |> mes("Your loyalty will bring them")
    |> mes("to your side in times of")
    |> mes("joy and of tribulation.")
    |> next()
    |> mes(header(ctx))
    |> offer_support()
    |> close()
  end

  defp offer_support(ctx) do
    ctx
    |> mes("I suppose you really")
    |> mes("don't have much use")
    |> mes("for me anymore... But I'll")
    |> mes("always offer my support.")
  end

  defp no_business(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("We have nothing to")
    |> mes("do with each other.")
    |> mes("Leave me be, and")
    |> mes("just go on your way.")
    |> close()
  end

  defp header(ctx), do: "[#{get_local(ctx, :npc_name, "")}]"

  defp job?(ctx, job), do: base_job(ctx) == job
end
