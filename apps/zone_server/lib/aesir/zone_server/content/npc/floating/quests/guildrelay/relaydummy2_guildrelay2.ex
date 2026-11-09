defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Guildrelay.Relaydummy2Guildrelay2 do
  @moduledoc """
  Castle stronghold member who runs the middle legs of the Guild Relay quest chain.

  ## Behavior

  - Turns away players who carry too much weight or who stand in an ownerless castle.
  - A guild member holding the Spirit of Courage is sent to collect 30 each of three randomly
    drawn items before the Spirit of Charge can be earned.
  - Blacksmiths holding the Spirit of Charge must kill time and come back at the right hour of
    the day to receive the Spirit of Partnership.
  - Alchemists holding the Spirit of Partnership are set a level-up trial sized to their level,
    or are handed the Spirit of Coordination outright above level 93.
  - Hunters holding the Spirit of Coordination are asked to donate their Falcon; the Spirit of
    Advance is only handed over once the Falcon is actually present.
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
        x: 75,
        y: 39,
        dir: 3,
        sprite: 754,
        name: "Lenya",
        scope: :shared,
        unique_name: "Lenya#01"
      },
      %{
        map: "aldeg_cas02",
        x: 180,
        y: 184,
        dir: 3,
        sprite: 754,
        name: "Lenya",
        scope: :shared,
        unique_name: "Lenya#02"
      },
      %{
        map: "aldeg_cas03",
        x: 72,
        y: 115,
        dir: 3,
        sprite: 754,
        name: "Lenya",
        scope: :shared,
        unique_name: "Lenya#03"
      },
      %{
        map: "aldeg_cas04",
        x: 66,
        y: 117,
        dir: 3,
        sprite: 754,
        name: "Lenya",
        scope: :shared,
        unique_name: "Lenya#04"
      },
      %{
        map: "aldeg_cas05",
        x: 140,
        y: 196,
        dir: 3,
        sprite: 754,
        name: "Lenya",
        scope: :shared,
        unique_name: "Lenya#05"
      },
      %{
        map: "gefg_cas01",
        x: 67,
        y: 83,
        dir: 3,
        sprite: 754,
        name: "Ron Haware",
        scope: :shared,
        unique_name: "Ron Haware#01"
      },
      %{
        map: "gefg_cas02",
        x: 23,
        y: 22,
        dir: 3,
        sprite: 754,
        name: "Ron Haware",
        scope: :shared,
        unique_name: "Ron Haware#02"
      },
      %{
        map: "gefg_cas03",
        x: 110,
        y: 91,
        dir: 3,
        sprite: 754,
        name: "Ron Haware",
        scope: :shared,
        unique_name: "Ron Haware#03"
      },
      %{
        map: "gefg_cas04",
        x: 34,
        y: 16,
        dir: 1,
        sprite: 754,
        name: "Ron Haware",
        scope: :shared,
        unique_name: "Ron Haware#04"
      },
      %{
        map: "gefg_cas05",
        x: 65,
        y: 28,
        dir: 3,
        sprite: 754,
        name: "Ron Haware",
        scope: :shared,
        unique_name: "Ron Haware#05"
      },
      %{
        map: "payg_cas01",
        x: 129,
        y: 29,
        dir: 3,
        sprite: 754,
        name: "Dosuhlji",
        scope: :shared,
        unique_name: "Dosuhlji#01"
      },
      %{
        map: "payg_cas02",
        x: 77,
        y: 229,
        dir: 3,
        sprite: 754,
        name: "Dosuhlji",
        scope: :shared,
        unique_name: "Dosuhlji#02"
      },
      %{
        map: "payg_cas03",
        x: 7,
        y: 265,
        dir: 5,
        sprite: 754,
        name: "Dosuhlji",
        scope: :shared,
        unique_name: "Dosuhlji#03"
      },
      %{
        map: "payg_cas04",
        x: 21,
        y: 16,
        dir: 3,
        sprite: 754,
        name: "Dosuhlji",
        scope: :shared,
        unique_name: "Dosuhlji#04"
      },
      %{
        map: "payg_cas05",
        x: 273,
        y: 15,
        dir: 3,
        sprite: 754,
        name: "Dosuhlji",
        scope: :shared,
        unique_name: "Dosuhlji#05"
      },
      %{
        map: "prtg_cas01",
        x: 157,
        y: 117,
        dir: 3,
        sprite: 728,
        name: "Atila",
        scope: :shared,
        unique_name: "Atila#01"
      },
      %{
        map: "prtg_cas02",
        x: 43,
        y: 41,
        dir: 5,
        sprite: 728,
        name: "Atila",
        scope: :shared,
        unique_name: "Atila#02"
      },
      %{
        map: "prtg_cas03",
        x: 18,
        y: 109,
        dir: 3,
        sprite: 728,
        name: "Atila",
        scope: :shared,
        unique_name: "Atila#03"
      },
      %{
        map: "prtg_cas04",
        x: 259,
        y: 251,
        dir: 3,
        sprite: 728,
        name: "Atila",
        scope: :shared,
        unique_name: "Atila#04"
      },
      %{
        map: "prtg_cas05",
        x: 253,
        y: 91,
        dir: 3,
        sprite: 728,
        name: "Atila",
        scope: :shared,
        unique_name: "Atila#05"
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
    |> mes("^3355FFYou're not sure why, but")
    |> mes("this guy seems to be pretty")
    |> mes("depressed. He briefly makes")
    |> mes("eye contact with you, but then")
    |> mes("breaks it off. Apparently,")
    |> mes("he wants to be left alone.^000000")
    |> next()
    |> mes("^3355FFThere's no reason for you")
    |> mes("to stick around an ownerless")
    |> mes("stronghold. You may as well")
    |> mes("head on your way.^000000")
    |> close()
  end

  defp outsider(ctx, castle_id) do
    if is_guild_leader(ctx, castle_id) == 1 do
      ctx
      |> mes(header(ctx))
      |> mes("Hm? What brings you")
      |> mes("here? Feel free to take")
      |> mes("your time and look around")
      |> mes("if that's what pleases you.")
      |> close()
    else
      ctx
      |> mes(header(ctx))
      |> mes("There isn't much to see")
      |> mes("around here, but you're")
      |> mes("welcome to stay and look")
      |> mes("around here if you wish.")
      |> close()
    end
  end

  defp guild_master(ctx) do
    if count_item(ctx, 7234) > 0 do
      ctx
      |> mes(header(ctx))
      |> mes("Hm. You can't just keep")
      |> mes("that spirit to yourself.")
      |> mes("Give it to a ^FF0000Knight^000000 or")
      |> mes("a ^FF0000Lord Knight^000000. Hurry it up!")
      |> mes("You need to work fast to")
      |> mes("expand your guild.")
      |> close()
    else
      ctx
      |> mes(header(ctx))
      |> mes("Hm. You seem awfully")
      |> mes("busy. Why don't you just")
      |> mes("take a break, and relax?")
      |> mes("It's alright to have fun")
      |> mes("if you're feeling a lot of")
      |> mes("pressure. Heh heh heh~")
      |> close()
    end
  end

  defp guild_member(ctx) do
    quest = get_char_var(ctx, :guildrelay_q, 0)

    cond do
      job?(ctx, :knight) and count_item(ctx, 7234) > 0 ->
        assign_gathering_test(ctx)

      quest == 2 and gathered?(ctx, [1015, 7196, 7157]) ->
        items_delivered(ctx, [1015, 7196, 7157])

      quest == 3 and gathered?(ctx, [1097, 1017, 1096]) ->
        items_delivered(ctx, [1097, 1017, 1096])

      quest == 89 and gathered?(ctx, [7112, 1012, 1040]) ->
        items_delivered(ctx, [7112, 1012, 1040])

      job?(ctx, :knight) and quest == 2 ->
        materials_reminder(ctx, ["Tongues", "Dark Masks", "Shoulder Protectors"])

      job?(ctx, :knight) and quest == 3 ->
        materials_reminder(ctx, ["Worn Out Pages", "Round Shells", "Mole Whiskers"])

      job?(ctx, :knight) and quest == 89 ->
        materials_reminder(ctx, ["Frills", "Sharp Papers", "Elder Pixie's Moustaches"])

      job?(ctx, :blacksmith) and count_item(ctx, 7235) > 0 ->
        start_waiting_trial(ctx)

      job?(ctx, :blacksmith) and quest == 4 ->
        waiting_progress(ctx)

      job?(ctx, :alchemist) and count_item(ctx, 7237) > 0 ->
        level_trial(ctx)

      quest in [5, 6, 7] ->
        not_strong_enough(ctx)

      job?(ctx, :hunter) and count_item(ctx, 7238) > 0 ->
        falcon_request(ctx)

      quest == 88 and count_item(ctx, 7235) > 0 ->
        spirit_reminder(
          ctx,
          "Spirit of Charge to",
          "a ^FF0000Blacksmith^000000 or ^FF0000Mastersmith^000000."
        )

      quest == 88 ->
        bored_reminder(ctx)

      quest == 87 and count_item(ctx, 7237) > 0 ->
        spirit_reminder(
          ctx,
          "Spirit of Association to",
          "an ^FF0000Alchemist^000000 or ^FF0000Biochemist^000000."
        )

      quest == 87 ->
        busy_reminder(ctx)

      quest == 86 and count_item(ctx, 7238) > 0 ->
        spirit_reminder(
          ctx,
          "Spirit of Coordination",
          "to a ^FF0000Hunter^000000 or ^FF0000Sniper^000000."
        )

      quest == 86 ->
        rest_reminder(ctx)

      quest == 85 and count_item(ctx, 7239) > 0 ->
        spirit_reminder(ctx, "Spirit of Advance", "to your ^FF0000guild master^000000.")

      quest == 85 ->
        falcon_reminder(ctx)

      true ->
        no_business(ctx)
    end
  end

  defp assign_gathering_test(ctx) do
    ctx =
      ctx
      |> mes(header(ctx))
      |> mes("For your first test,")
      |> mes("I'll start you off with")
      |> mes("something pretty simple.")
      |> mes("Just collect some items,")
      |> mes("and bring them to me. Ah, and")
      |> mes("your guild can help you too.")
      |> next()

    {materials, quest} =
      Enum.random([
        {["Tongues", "Dark Masks", "Shoulder Protectors"], 2},
        {["Worn Out Pages", "Round Shells", "Mole Whiskers"], 3},
        {["Frills", "Sharp Papers", "Elder Pixie's Moustaches"], 89}
      ])

    ctx
    |> mes(header(ctx))
    |> materials(materials)
    |> mes("That shouldn't be too")
    |> mes("hard now, right?")
    |> delitem(7234, 1)
    |> set_char_var(:guildrelay_q, quest)
    |> close()
  end

  defp materials_reminder(ctx, materials) do
    ctx
    |> mes(header(ctx))
    |> mes("Did you forget what")
    |> mes("to bring me? I wanted")
    |> materials(materials)
    |> mes("Don't forget this time.")
    |> close()
  end

  defp materials(ctx, [first, second, third]) do
    ctx
    |> mes("^FF000030 #{first}^000000,")
    |> mes("^FF000030 #{second}^000000, and")
    |> mes("^FF000030 #{third}^000000.")
  end

  defp gathered?(ctx, item_ids) do
    Enum.all?(item_ids, &(count_item(ctx, &1) > 29))
  end

  defp items_delivered(ctx, [first, second, third]) do
    ctx
    |> mes(header(ctx))
    |> mes("Huh. I didn't actually")
    |> mes("expect that you'd collect")
    |> mes("all these items. Good job.")
    |> mes("Now, take this and give it to")
    |> mes("a Blacksmith or Mastersmith.")
    |> mes("Your guild's pretty good...")
    |> delitem(first, 30)
    |> delitem(second, 30)
    |> delitem(third, 30)
    |> set_char_var(:guildrelay_q, 88)
    |> give_item(7235, 1)
    |> close()
  end

  defp start_waiting_trial(ctx) do
    ctx =
      ctx
      |> mes(header(ctx))
      |> mes("Wow, you brought the")
      |> mes("items sooner than I had")
      |> mes("expected. Great! Well then,")
      |> mes("your next task for me will")
      |> mes("be to... Wait. Wait and")
      |> mes("kill some time. Easy, huh?")
      |> next()
      |> mes(header(ctx))
      |> mes("^FF0000just waiting.^000000")
      |> mes("Justing wait and kill")
      |> mes("some time. You can do")
      |> mes("whatever you want to")
      |> mes("do during that time.")
      |> next()
      |> mes(header(ctx))
      |> mes("Come back after you've")
      |> mes("relaxed and enjoyed yourself.")
      |> mes("We can continue the testing")
      |> mes("when the time is right so")
      |> mes("don't you worry about it.")
      |> delitem(7235, 1)
      |> set_char_var(:guildrelay_q, 4)

    ctx
    |> set_char_var(:guildtime, Rathena.atoi(gettimestr(ctx, "%H%M", 5)))
    |> close()
  end

  defp waiting_progress(ctx) do
    time = Rathena.atoi(gettimestr(ctx, "%H%M", 5))
    visit_hour = get_char_var(ctx, :guildtime, 0)

    cond do
      visit_hour > 2259 and time > 201 and time < visit_hour -> resume_testing(ctx)
      visit_hour > 2159 and time > 101 and time < visit_hour -> resume_testing(ctx)
      visit_hour > 2059 and time > 1 and time < visit_hour -> resume_testing(ctx)
      time - visit_hour > 300 -> resume_testing(ctx)
      true -> still_waiting(ctx)
    end
  end

  defp resume_testing(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("I guess enough time")
    |> mes("has passed. You ready")
    |> mes("to resume the testing?")
    |> mes("Please give this to an")
    |> mes("Alchemist or Biochemist.")
    |> mes("Your work here is done.")
    |> set_char_var(:guildrelay_q, 87)
    |> give_item(7237, 1)
    |> close()
  end

  defp still_waiting(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("You must be rarin'")
    |> mes("to take on the next")
    |> mes("test. Please be patient,")
    |> mes("kill some time, and just")
    |> mes("come back to me later.")
    |> close()
  end

  defp level_trial(ctx) do
    ctx =
      ctx
      |> mes(header(ctx))
      |> mes("Oh, you got it, eh?")
      |> mes("You might not think this")
      |> mes("will be so hard, but I'm")
      |> mes("going to give you a much")
      |> mes("different challenge now.")
      |> mes("Are you ready for it?")
      |> next()

    assign_level_trial(ctx, base_level(ctx))
  end

  defp assign_level_trial(ctx, level) when level > 1 and level < 58 do
    level_trial_task(ctx, "gain 3 more levels.", 5)
  end

  defp assign_level_trial(ctx, level) when level > 57 and level < 76 do
    level_trial_task(ctx, "gain 2 more levels.", 6)
  end

  defp assign_level_trial(ctx, level) when level > 75 and level < 94 do
    level_trial_task(ctx, "gain 1 more level.", 7)
  end

  defp assign_level_trial(ctx, level) when level > 93 do
    ctx
    |> mes(header(ctx))
    |> mes("Wait a minute. Forget it!")
    |> mes("I was going to ask you to")
    |> mes("raise your Base Level, but")
    |> mes("you're tough enough as it is.")
    |> mes("Fine, fine. You pass! Give this")
    |> mes("to a ^FF0000Hunter^000000 or ^FF0000Sniper^000000 now~")
    |> delitem(7237, 1)
    |> set_char_var(:guildrelay_q, 86)
    |> give_item(7238, 1)
    |> close()
  end

  defp assign_level_trial(ctx, _level), do: ctx

  defp level_trial_task(ctx, level_gain, quest) do
    ctx
    |> mes(header(ctx))
    |> mes("Your test will be to")
    |> mes("grow a little stronger!")
    |> mes("You'll pass once you")
    |> mes(level_gain)
    |> mes("How about that, eh?")
    |> delitem(7237, 1)
    |> set_char_var(:guildrelay_q, quest)
    |> close()
  end

  defp not_strong_enough(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("You're still not strong")
    |> mes("enough to pass this test.")
    |> mes("Hurry up, kill some monsters,")
    |> mes("and gain some ^FF0000Base Levels^000000.")
    |> mes("You have to become stronger!")
    |> close()
  end

  defp falcon_request(ctx) do
    {ctx, choice} =
      ctx
      |> mes(header(ctx))
      |> mes("Ah, good, you're here.")
      |> mes("Now, my request for you")
      |> mes("is this: please donate")
      |> mes("your Falcon for the")
      |> mes("sake of your guild.")
      |> next()
      |> select(["Donate Falcon", "No way!"])

    case choice do
      1 -> donate_falcon(ctx)
      2 -> keep_falcon(ctx)
      _ -> ctx
    end
  end

  defp donate_falcon(ctx) do
    if Rathena.truthy?(checkfalcon(ctx)) do
      ctx
      |> mes(header(ctx))
      |> mes("Great! Don't worry,")
      |> mes("your Falcon will be safe")
      |> mes("under our care, and will")
      |> mes("be use to scout areas and")
      |> mes("deliver mail. That's why")
      |> mes("I asked you for it.")
      |> next()
      |> mes(header(ctx))
      |> mes("Now, please take this")
      |> mes("spirit, and give it to")
      |> mes("your guild master as")
      |> mes("soon as you can, alright?")
      |> setfalcon(true)
      |> delitem(7238, 1)
      |> set_char_var(:guildrelay_q, 85)
      |> give_item(7239, 1)
      |> close()
    else
      ctx
      |> mes(header(ctx))
      |> mes("I'm glad that you're")
      |> mes("willing to part with your")
      |> mes("Falcon, but it doesn't seem")
      |> mes("to be with you right now.")
      |> mes("Go get one, and come back.")
      |> close()
    end
  end

  defp keep_falcon(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("Well, I can't help it if you")
    |> mes("really want to keep your")
    |> mes("Falcon, but please come")
    |> mes("back if you change your mind.")
    |> mes("I can't do anything for you")
    |> mes("unless you cooperate.")
    |> close()
  end

  defp spirit_reminder(ctx, spirit_line, recipient_line) do
    ctx
    |> mes(header(ctx))
    |> mes("Please give the")
    |> mes(spirit_line)
    |> mes(recipient_line)
    |> mes("It won't do any good in the")
    |> mes("hands of anybody else.")
    |> close()
  end

  defp bored_reminder(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("You don't have")
    |> mes("anything to do?")
    |> mes("Why don't you help")
    |> mes("your guild hunt monsters?")
    |> mes("It'll be a good chance to")
    |> mes("show them your skills~")
    |> close()
  end

  defp busy_reminder(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("Hm. Don't you have")
    |> mes("anything to do? I suppose")
    |> mes("it's better to be bored")
    |> mes("than to be overwhelmed.")
    |> mes("Oh well, you'll figure")
    |> mes("something out.")
    |> close()
  end

  defp rest_reminder(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("Good work. Please")
    |> mes("go ahead and take a rest,")
    |> mes("and then come back to me")
    |> mes("later. I'll have something")
    |> mes("to give you by then.")
    |> close()
  end

  defp falcon_reminder(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("Your falcon's been")
    |> mes("a great help in the")
    |> mes("guild. Hm? You already")
    |> mes("miss it? Hahahaha!")
    |> close()
  end

  defp no_business(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("Hm? What brings you")
    |> mes("here? I don't think we")
    |> mes("have any business to")
    |> mes("conduct. Am I mistaken?")
    |> close()
  end

  defp header(ctx), do: "[#{get_local(ctx, :npc_name, "")}]"

  defp job?(ctx, job), do: base_job(ctx) == job
end
