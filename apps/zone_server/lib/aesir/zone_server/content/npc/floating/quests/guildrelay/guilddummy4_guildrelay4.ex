defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Guildrelay.Guilddummy4Guildrelay4 do
  @moduledoc """
  Castle stronghold member who runs the closing trials of the Guild Relay quest.

  ## Behavior

  - Turns away players who carry too much weight or who stand in an ownerless castle.
  - A guild member holding the Spirit of Peace is sent to form a party of 6, 8 or 10 members
    (drawn at random) before a Priest can be entrusted with the Spirit of Determination.
  - Priests holding the Spirit of Determination are set a level-up trial sized to their level, or
    are handed the Spirit of Service outright above level 96.
  - Crusaders holding the Spirit of Service must come back at the right hour of the day; the
    Spirit of Glory is theirs only inside that window.
  - Monks holding the Spirit of Glory gather 30 each of three randomly drawn items.
  - Delivering the items earns the Spirit of Victory for the guild master.
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
        x: 59,
        y: 224,
        dir: 3,
        sprite: 754,
        name: "Pariz",
        scope: :shared,
        unique_name: "Pariz#01"
      },
      %{
        map: "aldeg_cas02",
        x: 62,
        y: 201,
        dir: 3,
        sprite: 754,
        name: "Pariz",
        scope: :shared,
        unique_name: "Pariz#02"
      },
      %{
        map: "aldeg_cas03",
        x: 188,
        y: 181,
        dir: 3,
        sprite: 754,
        name: "Pariz",
        scope: :shared,
        unique_name: "Pariz#03"
      },
      %{
        map: "aldeg_cas04",
        x: 181,
        y: 97,
        dir: 3,
        sprite: 754,
        name: "Pariz",
        scope: :shared,
        unique_name: "Pariz#04"
      },
      %{
        map: "aldeg_cas05",
        x: 165,
        y: 51,
        dir: 3,
        sprite: 754,
        name: "Pariz",
        scope: :shared,
        unique_name: "Pariz#05"
      },
      %{
        map: "gefg_cas01",
        x: 35,
        y: 34,
        dir: 6,
        sprite: 754,
        name: "Gen Garish",
        scope: :shared,
        unique_name: "Gen Garish#01"
      },
      %{
        map: "gefg_cas02",
        x: 18,
        y: 159,
        dir: 5,
        sprite: 754,
        name: "Gen Garish",
        scope: :shared,
        unique_name: "Gen Garish#02"
      },
      %{
        map: "gefg_cas03",
        x: 124,
        y: 24,
        dir: 3,
        sprite: 754,
        name: "Gen Garish",
        scope: :shared,
        unique_name: "Gen Garish#03"
      },
      %{
        map: "gefg_cas04",
        x: 73,
        y: 38,
        dir: 6,
        sprite: 754,
        name: "Gen Garish",
        scope: :shared,
        unique_name: "Gen Garish#04"
      },
      %{
        map: "gefg_cas05",
        x: 46,
        y: 28,
        dir: 3,
        sprite: 754,
        name: "Gen Garish",
        scope: :shared,
        unique_name: "Gen Garish#05"
      },
      %{
        map: "payg_cas01",
        x: 91,
        y: 49,
        dir: 3,
        sprite: 59,
        name: "Ashin",
        scope: :shared,
        unique_name: "Ashin#01"
      },
      %{
        map: "payg_cas02",
        x: 289,
        y: 264,
        dir: 3,
        sprite: 59,
        name: "Ashin",
        scope: :shared,
        unique_name: "Ashin#02"
      },
      %{
        map: "payg_cas03",
        x: 10,
        y: 266,
        dir: 3,
        sprite: 59,
        name: "Ashin",
        scope: :shared,
        unique_name: "Ashin#03"
      },
      %{
        map: "payg_cas04",
        x: 18,
        y: 239,
        dir: 3,
        sprite: 59,
        name: "Ashin",
        scope: :shared,
        unique_name: "Ashin#04"
      },
      %{
        map: "payg_cas05",
        x: 276,
        y: 287,
        dir: 3,
        sprite: 59,
        name: "Ashin",
        scope: :shared,
        unique_name: "Ashin#05"
      },
      %{
        map: "prtg_cas01",
        x: 125,
        y: 191,
        dir: 3,
        sprite: 754,
        name: "Diligo",
        scope: :shared,
        unique_name: "Diligo#01"
      },
      %{
        map: "prtg_cas02",
        x: 100,
        y: 62,
        dir: 3,
        sprite: 754,
        name: "Diligo",
        scope: :shared,
        unique_name: "Diligo#02"
      },
      %{
        map: "prtg_cas03",
        x: 183,
        y: 215,
        dir: 3,
        sprite: 754,
        name: "Diligo",
        scope: :shared,
        unique_name: "Diligo#03"
      },
      %{
        map: "prtg_cas04",
        x: 59,
        y: 282,
        dir: 5,
        sprite: 754,
        name: "Diligo",
        scope: :shared,
        unique_name: "Diligo#04"
      },
      %{
        map: "prtg_cas05",
        x: 211,
        y: 36,
        dir: 3,
        sprite: 754,
        name: "Diligo",
        scope: :shared,
        unique_name: "Diligo#05"
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
      |> mes("You might be the master")
      |> mes("of a guild, but you and I")
      |> mes("have nothing to do with")
      |> mes("each other. I'm sorry.")
      |> next()
      |> mes(header(ctx))
      |> mes("Then again, I suppose")
      |> mes("you came here to see")
      |> mes("how a real guild operates.")
      |> mes("If that's the case, you're")
      |> mes("welcome to stay and observe.")
      |> close()
    else
      ctx
      |> mes(header(ctx))
      |> mes(".........................")
      |> next()
      |> mes(header(ctx))
      |> mes(".........................")
      |> next()
      |> mes(header(ctx))
      |> mes("What brings you here?")
      |> mes("I don't think I've seen")
      |> mes("you around before. Hm.")
      |> close()
    end
  end

  defp guild_master(ctx) do
    if count_item(ctx, 7246) > 0 do
      ctx
      |> mes(header(ctx))
      |> mes("Hm? That spirit that")
      |> mes("you've brought with you...")
      |> mes("I'm sorry, but it's useless")
      |> mes("for you to carry it around.")
      |> next()
      |> mes(header(ctx))
      |> mes("Please give that to")
      |> mes("a ^FF0000Rogue^000000 or ^FF0000Stalker^000000")
      |> mes("in your guild, and then")
      |> mes("ask him bring it to me.")
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
    if job?(ctx, :rogue) and count_item(ctx, 7246) > 0 do
      assign_party_trial(ctx)
    else
      guild_member_progress(ctx)
    end
  end

  defp assign_party_trial(ctx) do
    ctx =
      ctx
      |> mes(header(ctx))
      |> mes("So you're the one that's")
      |> mes("been entrusted with the")
      |> mes("Spirit of Peace? Well then...")
      |> mes("My task for you is to ^FF0000form")

    {party_size, quest} = Enum.random([{6, 91}, {8, 92}, {10, 93}])

    ctx
    |> mes("a party with #{party_size} members^000000.")
    |> mes("No more and no less.")
    |> next()
    |> mes(header(ctx))
    |> mes("This is a strange test,")
    |> mes("but if you can do this, it")
    |> mes("will clearly demonstrate")
    |> mes("to me that your people")
    |> mes("skills are up to par.")
    |> delitem(7246, 1)
    |> set_char_var(:guildrelay_q, quest)
    |> close()
  end

  defp guild_member_progress(ctx) do
    {ctx, _party} = getpartymember(ctx, getcharid(ctx, 1))
    party_size = get_server_temp_var(ctx, "partymembercount", 0)
    quest = get_char_var(ctx, :guildrelay_q, 0)

    cond do
      quest == 91 ->
        party_size_check(ctx, party_size, 6)

      quest == 92 ->
        party_size_check(ctx, party_size, 8)

      quest == 93 ->
        party_size_check(ctx, party_size, 10)

      job?(ctx, :priest) and count_item(ctx, 7247) > 0 ->
        level_trial(ctx)

      job?(ctx, :crusader) and count_item(ctx, 7249) > 0 ->
        start_waiting_trial(ctx)

      job?(ctx, :crusader) and quest == 21 ->
        waiting_trial_progress(ctx)

      job?(ctx, :monk) and count_item(ctx, 7250) > 0 ->
        assign_gathering_trial(ctx)

      quest == 23 and gathered?(ctx, [7165, 1021, 1023]) ->
        items_delivered(ctx, [7165, 1021, 1023])

      quest == 24 and gathered?(ctx, [1048, 1013, 7200]) ->
        items_delivered(ctx, [1048, 1013, 7200])

      quest == 94 and gathered?(ctx, [7003, 7101, 7153]) ->
        items_delivered(ctx, [7003, 7101, 7153])

      job?(ctx, :monk) and quest == 23 ->
        dokebi_reminder(ctx)

      job?(ctx, :monk) and quest == 24 ->
        gathering_reminder(ctx, ["Rainbow Shells", "Elastic Bands", "Horrendous Hairs"])

      job?(ctx, :monk) and quest == 94 ->
        gathering_reminder(ctx, ["Worn-out Kimonos", "Anolian Skins", "PecoPeco Feathers"])

      quest == 95 and count_item(ctx, 7247) > 0 ->
        spirit_reminder(
          ctx,
          "Spirit of Determination",
          "to a ^FF0000Priest^000000 or ^FF0000High Priest^000000."
        )

      quest == 95 ->
        rest_reminder(ctx)

      quest == 98 and count_item(ctx, 7249) > 0 ->
        spirit_reminder(
          ctx,
          "Spirit of Service to",
          "a ^FF0000Crusader^000000 or ^FF0000Paladin^000000."
        )

      quest == 98 ->
        wait_reminder(ctx)

      quest == 96 and count_item(ctx, 7250) > 0 ->
        spirit_reminder(
          ctx,
          "Spirit of Glory to",
          "a ^FF0000Monk^000000 or ^FF0000Champion^000000."
        )

      quest == 96 ->
        potential_reminder(ctx)

      quest == 97 and count_item(ctx, 7251) > 0 ->
        victory_reminder(ctx)

      quest == 97 ->
        explorer_reminder(ctx)

      true ->
        no_business(ctx)
    end
  end

  defp party_size_check(ctx, party_size, expected_size) do
    if party_size == expected_size do
      ctx
      |> mes(header(ctx))
      |> mes("I see that you've")
      |> mes("formed a party with")
      |> mes("the exact number of")
      |> mes("people that I asked. Hmm.")
      |> mes("I guess you can be trusted")
      |> mes("to lead when you must.")
      |> next()
      |> mes(header(ctx))
      |> mes("Here. I want you to take")
      |> mes("this spirit, and then give")
      |> mes("it to a Priest or High")
      |> mes("Priest in your guild.")
      |> set_char_var(:guildrelay_q, 95)
      |> give_item(7247, 1)
      |> close()
    else
      ctx
      |> mes(header(ctx))
      |> mes("I thought I asked you to")
      |> mes("^FF0000form a party of #{expected_size} members^000000?")
      |> mes("No more and no less. Hmm.")
      |> mes("Come back to me after you've")
      |> mes("finished this simple task.")
      |> close()
    end
  end

  defp level_trial(ctx) do
    ctx =
      ctx
      |> mes(header(ctx))
      |> mes("Good work getting the")
      |> mes("Spirit of Determination,")
      |> mes("but I want you to work on")
      |> mes("getting stronger. If you")
      |> mes("intend to protect others,")
      |> mes("you can't afford to lose.")
      |> next()

    assign_level_trial(ctx, base_level(ctx))
  end

  defp assign_level_trial(ctx, level) when level > 1 and level < 61 do
    level_trial_task(ctx, 3, "Base Levels", 18)
  end

  defp assign_level_trial(ctx, level) when level > 60 and level < 76 do
    level_trial_task(ctx, 2, "Base Levels", 19)
  end

  defp assign_level_trial(ctx, level) when level > 75 and level < 97 do
    level_trial_task(ctx, 1, "Base Level", 20)
  end

  defp assign_level_trial(ctx, level) when level > 96 do
    ctx
    |> mes(header(ctx))
    |> mes("Hum, You are stronger than")
    |> mes("I was expected.")
    |> mes("You don't need any more quests")
    |> mes("for becoming stronger.")
    |> mes("But, do not be so proud of yourself.")
    |> next()
    |> mes(header(ctx))
    |> entrust_spirit_to_crusader()
    |> delitem(7247, 1)
    |> set_char_var(:guildrelay_q, 98)
    |> give_item(7249, 1)
    |> close()
  end

  defp assign_level_trial(ctx, _level), do: ctx

  defp level_trial_task(ctx, levels, unit, quest) do
    ctx
    |> mes(header(ctx))
    |> mes("I want you to gain")
    |> mes("^FF0000#{levels} #{unit}^000000 for the")
    |> mes("sake of strengthening")
    |> mes("yourself and your guild.")
    |> mes("This is my test for you.")
    |> next()
    |> mes(header(ctx))
    |> mes("Try not to worry")
    |> mes("over this task so much.")
    |> mes("I'm certain you can do")
    |> mes("this. Come back to me")
    |> mes("when you are ready.")
    |> delitem(7247, 1)
    |> set_char_var(:guildrelay_q, quest)
    |> close()
  end

  defp start_waiting_trial(ctx) do
    ctx =
      ctx
      |> mes(header(ctx))
      |> mes("I see that you possess")
      |> mes("the Spirit of Service. Hmm.")
      |> mes("Good job. Now, your next")
      |> mes("task will test your patience.")
      |> mes("All you have to do is ^FF0000wait^000000.")
      |> mes("Wait until the time is right.")
      |> next()
      |> mes(header(ctx))
      |> mes("I want you to spend this")
      |> mes("time to look into yourself,")
      |> mes("and examine your relationship")
      |> mes("with your guild members.")
      |> mes("When you feel that the time")
      |> mes("is right, come talk to me.")
      |> next()
      |> mes(header(ctx))
      |> mes("I'm not going to tell you")
      |> mes("when you should come back.")
      |> mes("I'll merely confirm whether")
      |> mes("you've come early or on time.")
      |> mes("You'll need to really listen")
      |> mes("to your feelings this time...")
      |> delitem(7249, 1)
      |> set_char_var(:guildrelay_q, 21)

    ctx
    |> set_char_var(:guildtime, Rathena.atoi(gettimestr(ctx, "%H%M", 5)))
    |> close()
  end

  defp waiting_trial_progress(ctx) do
    time = Rathena.atoi(gettimestr(ctx, "%H%M", 5))
    visit_hour = get_char_var(ctx, :guildtime, 0)

    cond do
      visit_hour > 2259 -> waiting_outcome(ctx, time > 201 and time < visit_hour)
      visit_hour > 2159 -> waiting_outcome(ctx, time > 101 and time < visit_hour)
      visit_hour > 2059 -> waiting_outcome(ctx, time > 1 and time < visit_hour)
      time - visit_hour > 300 -> spirit_of_glory(ctx)
      true -> not_yet(ctx)
    end
  end

  defp waiting_outcome(ctx, true), do: spirit_of_glory(ctx)
  defp waiting_outcome(ctx, false), do: too_early(ctx)

  defp spirit_of_glory(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("Yes. You've come at just")
    |> mes("the right time. Remember")
    |> mes("that feeling in your heart,")
    |> mes("and trust it when it comes")
    |> mes("again. Now give this spirit to")
    |> mes("a ^FF0000Monk^000000 or ^FF0000Champion^000000 for me...")
    |> set_char_var(:guildrelay_q, 96)
    |> give_item(7250, 1)
    |> close()
  end

  defp too_early(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("Too early.")
    |> mes("Still too early.")
    |> mes("Have you been listening")
    |> mes("to your heart? Listen harder.")
    |> close()
  end

  defp not_yet(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("Not yet. Just wait")
    |> mes("a little longer. Relax,")
    |> mes("and come back later.")
    |> close()
  end

  defp assign_gathering_trial(ctx) do
    ctx =
      ctx
      |> mes(header(ctx))
      |> mes("Most of the souls have")
      |> mes("been shared, and there is")
      |> mes("but one thing I want to ask")
      |> mes("you to do. Please bring me")
      |> mes("some items. Having your friends")
      |> mes("help you do this is acceptable.")
      |> next()

    {materials, quest} =
      Enum.random([
        {["Dokebi Horns", "Fish Tails", "Celestial Robes"], 23},
        {["Rainbow Shells", "Elastic Bands", "Horrendous Hairs"], 24},
        {["Worn-out Kimonos", "Anolian Skins", "PecoPeco Feathers"], 94}
      ])

    ctx
    |> list_materials(materials)
    |> delitem(7250, 1)
    |> set_char_var(:guildrelay_q, quest)
    |> close()
  end

  defp dokebi_reminder(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("You have to give ^FF0000Transparent Celestial Robe ^00000030ea,")
    |> mes("^FF0000Dokebi Horn ^00000030ea, ^FF0000Fish Tail ^00000030ea.")
    |> mes("You know that, right?")
    |> mes("Good luck~")
    |> close()
  end

  defp gathering_reminder(ctx, materials) do
    ctx
    |> list_materials(materials)
    |> close()
  end

  defp list_materials(ctx, [first, second, third]) do
    ctx
    |> mes(header(ctx))
    |> mes("Please bring")
    |> mes("^FF000030 #{first}^000000,")
    |> mes("^FF000030 #{second}^000000, and")
    |> mes("^FF000030 #{third}^000000.")
    |> mes("I shall be waiting")
    |> mes("for you right here.")
  end

  defp gathered?(ctx, item_ids) do
    Enum.all?(item_ids, &(count_item(ctx, &1) > 29))
  end

  defp items_delivered(ctx, [first, second, third]) do
    ctx
    |> mes(header(ctx))
    |> mes("Well, well. You've")
    |> mes("gathered those items")
    |> mes("more quickly that I thought")
    |> mes("you would. Good job. Now,")
    |> mes("please give this to your ^FF0000Guild")
    |> mes("Master^000000 as soon as you can.")
    |> delitem(first, 30)
    |> delitem(second, 30)
    |> delitem(third, 30)
    |> set_char_var(:guildrelay_q, 97)
    |> give_item(7251, 1)
    |> close()
  end

  defp spirit_reminder(ctx, spirit_line, recipient_line) do
    ctx
    |> mes(header(ctx))
    |> mes("Please give the")
    |> mes(spirit_line)
    |> mes(recipient_line)
    |> mes("You knew that already,")
    |> mes("didn't you? Please hurry")
    |> mes("and deliver it soon.")
    |> close()
  end

  defp rest_reminder(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("For now, it would be")
    |> mes("best for you to rest and")
    |> mes("recoup your strength. Your")
    |> mes("chance to help your guild")
    |> mes("will come soon enough so")
    |> mes("there's no need to rush.")
    |> close()
  end

  defp wait_reminder(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("Hmm. You need to wait")
    |> mes("for the right time to act.")
    |> mes("Why don't you help out")
    |> mes("your guild in the meantime?")
    |> close()
  end

  defp potential_reminder(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("I see that you have")
    |> mes("the potential to become")
    |> mes("a great leader. Be sure")
    |> mes("not to waste it, and lead")
    |> mes("your guild as well as you can.")
    |> close()
  end

  defp victory_reminder(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("You need to give")
    |> mes("the ^FF0000Spirit of Victory^000000")
    |> mes("to your Guild Master.")
    |> mes("Please make sure that")
    |> mes("it gets delivered soon.")
    |> close()
  end

  defp explorer_reminder(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("You're a nenown explorer,")
    |> mes("and I see in you the potential")
    |> mes("to accomplish even more")
    |> mes("great things. However,")
    |> mes("I doubt there is anything")
    |> mes("more that you can do here.")
    |> close()
  end

  defp no_business(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("Hmm. You have no business")
    |> mes("being here. Why don't you")
    |> mes("find something productive")
    |> mes("to do? There is nothing")
    |> mes("for you here, I assure you.")
    |> close()
  end

  # Second page of the "entrust the spirit to a Crusader or Paladin" dialogue.
  defp entrust_spirit_to_crusader(ctx) do
    ctx
    |> mes("Alright then...")
    |> mes("I entrust you with")
    |> mes("this spirit. Please be")
    |> mes("sure to give it to a")
    |> mes("^4D4DFFCrusader^000000 or ^4D4DFFPaladin^000000")
    |> mes("in your guild.")
  end

  defp header(ctx), do: "[#{get_local(ctx, :npc_name, "")}]"

  defp job?(ctx, job), do: base_job(ctx) == job
end
