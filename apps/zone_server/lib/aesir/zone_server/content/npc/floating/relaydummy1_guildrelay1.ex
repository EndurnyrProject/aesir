defmodule Aesir.ZoneServer.Content.Npc.Floating.Relaydummy1Guildrelay1 do
  @moduledoc """
  Guild sage who starts and closes the Guild Relay quest chain in every stronghold.

  ## Behavior

  - Turns away players who carry too much weight, who stand in an ownerless castle, or who
    belong to another guild; invited guests are recognised by a menu and strangers are warped out.
  - Guild masters are taken through the trials: the Spirit of Guild, the rest timer, the Spirit of
    Trust, the Spirit of Peace, the Spirit of Victory and the three item rewards.
  - Each trial grants a spirit that must be carried by a member of one guild job line and passed
    on to the next relay NPC; the master is told which of their members to send.
  - Guild members carrying a spirit are told who it belongs to, or congratulated and sent to the
    next person once the leg is done.

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
        x: 51,
        y: 102,
        dir: 5,
        sprite: 754,
        name: "Buzz",
        scope: :shared,
        unique_name: "Buzz#01"
      },
      %{
        map: "aldeg_cas02",
        x: 120,
        y: 51,
        dir: 5,
        sprite: 754,
        name: "Buzz",
        scope: :shared,
        unique_name: "Buzz#02"
      },
      %{
        map: "aldeg_cas03",
        x: 70,
        y: 252,
        dir: 5,
        sprite: 754,
        name: "Buzz",
        scope: :shared,
        unique_name: "Buzz#03"
      },
      %{
        map: "aldeg_cas04",
        x: 31,
        y: 116,
        dir: 5,
        sprite: 754,
        name: "Buzz",
        scope: :shared,
        unique_name: "Buzz#04"
      },
      %{
        map: "aldeg_cas05",
        x: 31,
        y: 191,
        dir: 5,
        sprite: 754,
        name: "Buzz",
        scope: :shared,
        unique_name: "Buzz#05"
      },
      %{
        map: "gefg_cas01",
        x: 85,
        y: 47,
        dir: 4,
        sprite: 754,
        name: "Jody",
        scope: :shared,
        unique_name: "Jody#01"
      },
      %{
        map: "gefg_cas02",
        x: 15,
        y: 69,
        dir: 4,
        sprite: 754,
        name: "Jody",
        scope: :shared,
        unique_name: "Jody#02"
      },
      %{
        map: "gefg_cas03",
        x: 257,
        y: 41,
        dir: 4,
        sprite: 754,
        name: "Jody",
        scope: :shared,
        unique_name: "Jody#03"
      },
      %{
        map: "gefg_cas04",
        x: 26,
        y: 73,
        dir: 4,
        sprite: 754,
        name: "Jody",
        scope: :shared,
        unique_name: "Jody#04"
      },
      %{
        map: "gefg_cas05",
        x: 47,
        y: 47,
        dir: 4,
        sprite: 754,
        name: "Jody",
        scope: :shared,
        unique_name: "Jody#05"
      },
      %{
        map: "payg_cas01",
        x: 87,
        y: 35,
        dir: 3,
        sprite: 106,
        name: "Chungye",
        scope: :shared,
        unique_name: "Chungye#01"
      },
      %{
        map: "payg_cas02",
        x: 34,
        y: 253,
        dir: 3,
        sprite: 106,
        name: "Chungye",
        scope: :shared,
        unique_name: "Chungye#02"
      },
      %{
        map: "payg_cas03",
        x: 48,
        y: 265,
        dir: 3,
        sprite: 106,
        name: "Chungye",
        scope: :shared,
        unique_name: "Chungye#03"
      },
      %{
        map: "payg_cas04",
        x: 24,
        y: 285,
        dir: 3,
        sprite: 106,
        name: "Chungye",
        scope: :shared,
        unique_name: "Chungye#04"
      },
      %{
        map: "payg_cas05",
        x: 277,
        y: 271,
        dir: 3,
        sprite: 106,
        name: "Chungye",
        scope: :shared,
        unique_name: "Chungye#05"
      },
      %{
        map: "prtg_cas01",
        x: 96,
        y: 205,
        dir: 5,
        sprite: 754,
        name: "Hermod",
        scope: :shared,
        unique_name: "Hermod#01"
      },
      %{
        map: "prtg_cas02",
        x: 73,
        y: 35,
        dir: 5,
        sprite: 754,
        name: "Hermod",
        scope: :shared,
        unique_name: "Hermod#02"
      },
      %{
        map: "prtg_cas03",
        x: 5,
        y: 68,
        dir: 5,
        sprite: 754,
        name: "Hermod",
        scope: :shared,
        unique_name: "Hermod#03"
      },
      %{
        map: "prtg_cas04",
        x: 39,
        y: 263,
        dir: 3,
        sprite: 754,
        name: "Hermod",
        scope: :shared,
        unique_name: "Hermod#04"
      },
      %{
        map: "prtg_cas05",
        x: 52,
        y: 70,
        dir: 5,
        sprite: 754,
        name: "Hermod",
        scope: :shared,
        unique_name: "Hermod#05"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = set_local(ctx, :npc_name, strnpcinfo(ctx, 1))
    {ctx, castle_id} = relay_identity(ctx)
    guild_id = getcharid(ctx, 2)

    cond do
      checkweight(ctx, [{908, 630}]) == 0 -> encumbered(ctx)
      castle_id == 0 -> ownerless_castle(ctx)
      guild_id != castle_id -> outsider(ctx, guild_id)
      is_guild_leader(ctx) == 1 -> guild_master(ctx)
      true -> guild_courier(ctx)
    end
  end

  # The four castle leagues have their own sage and guide names; every relay NPC is a
  # duplicate of this script under one of these four names.
  defp relay_identity(ctx) do
    case get_local(ctx, :npc_name, "") do
      "Buzz" ->
        ctx = relay_names(ctx, "Lenya", "Gealuve", "Pariz")
        {ctx, castle_data(ctx, "aldeg_cas#{strnpcinfo(ctx, 2)}", 1)}

      "Jody" ->
        ctx = relay_names(ctx, "Ron Haware", "Vers", "Gen Garish")
        {ctx, castle_data(ctx, "gefg_cas#{strnpcinfo(ctx, 2)}", 1)}

      "Chungye" ->
        ctx = relay_names(ctx, "Dosuhlji", "Yayula", "Ashin")
        {ctx, castle_data(ctx, "payg_cas#{strnpcinfo(ctx, 2)}", 1)}

      "Hermod" ->
        ctx = relay_names(ctx, "Atila", "Cecil", "Diligo")
        {ctx, castle_data(ctx, "prtg_cas#{strnpcinfo(ctx, 2)}", 1)}

      _ ->
        {ctx, 0}
    end
  end

  defp relay_names(ctx, knight, sage, rogue) do
    ctx
    |> set_local(:knight_name, knight)
    |> set_local(:sage_name, sage)
    |> set_local(:rogue_name, rogue)
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

  defp outsider(ctx, 0) do
    ctx
    |> mes(header(ctx))
    |> mes("You haven't joined")
    |> mes("a guild yet? Why don't")
    |> mes("you think about joining")
    |> mes("one? Well, it's your decision,")
    |> mes("but I don't think you'd regret")
    |> mes("being part of a strong guild.")
    |> close()
  end

  defp outsider(ctx, _guild_id) do
    {ctx, choice} =
      ctx
      |> mes(header(ctx))
      |> mes("Ah, I see that you are")
      |> mes("affiliated with a guild.")
      |> mes("Have you come here")
      |> mes("as an invited guest?")
      |> next()
      |> select(["No, not really...", "I was invited by the guild master."])

    case choice do
      1 ->
        ctx
        |> mes(header(ctx))
        |> mes("Oh, really?")
        |> mes("That's too bad...")
        |> mes("My apologies, but")
        |> mes("I can't allow strangers")
        |> mes("to simply come and go")
        |> mes("around here. Farewell, then.")
        |> next()
        |> warp("alde_gld", 186, 157)
        |> close()

      2 ->
        ctx
        |> mes(header(ctx))
        |> mes("Oh, really? Ah, now")
        |> mes("I recognize you, ^4d4dff#{char_name(ctx, 0)}^000000.")
        |> mes("Please come in, and make")
        |> mes("yourself comfortable.")
        |> close()

      _ ->
        ctx
    end
  end

  defp guild_master(ctx) do
    time = Rathena.atoi(gettimestr(ctx, "%H%M", 5))

    case get_char_var(ctx, :guildrelay_q, 0) do
      100 -> rest_check(ctx, time)
      150 -> peace_trial_ready(ctx, time)
      25 -> final_report(ctx, time)
      999 -> retry_offer(ctx)
      1 -> first_test_progress(ctx, time)
      8 -> second_test_progress(ctx)
      15 -> third_test_progress(ctx)
      _ -> introduce_trials(ctx)
    end
  end

  defp rest_check(ctx, time) do
    visit_hour = get_char_var(ctx, :guildtime, 0)

    cond do
      visit_hour > 2299 -> rest_outcome(ctx, time > 101 and time < visit_hour, "^4D4DFF")
      visit_hour > 2200 -> rest_outcome(ctx, time > 1 and time < visit_hour, "^4D4DFF")
      time - visit_hour > 200 -> rest_outcome(ctx, true, "^4D4DFFY")
      true -> rest_outcome(ctx, false, "^4D4DFF")
    end
  end

  defp rest_outcome(ctx, true, castle_color), do: trust_trial_assigned(ctx, castle_color)
  defp rest_outcome(ctx, false, _castle_color), do: too_pale(ctx)

  # `castle_color` is `"^4D4DFFY"` on rAthena's `time - guildtime > 200` branch; the stray
  # `Y` is kept verbatim so the relay shows the same text as the reference.
  defp trust_trial_assigned(ctx, castle_color) do
    ctx =
      ctx
      |> mes(header(ctx))
      |> mes("Oh, you're back. So did you")
      |> mes("rest up enough? I'm sure the")
      |> mes("other guild members are")
      |> mes("feeling refreshed by now.")
      |> mes("From the looks of it, you're")
      |> mes("ready for your next mission.")
      |> next()

    ctx =
      ctx
      |> mes(header(ctx))
      |> mes("The next step for")
      |> mes("you is to take this, the")
      |> mes("''Spirit of Trust.'' If this")
      |> mes("guild is going to be solid,")
      |> mes("you need to think how much")
      |> mes("trust there is in the guild.")
      |> set_char_var(:guildrelay_q, 8)
      |> give_item(7240, 1)
      |> next()

    ctx
    |> mes(header(ctx))
    |> mes("Your second test will be")
    |> mes("to give that ^4D4DFFSpirit of Trust^000000")
    |> mes("to a sage that can manipulate")
    |> mes("nature's attributes. In other")
    |> mes("words, a Sage or Scholar")
    |> mes("must carry out this task.")
    |> next()
    |> mes(header(ctx))
    |> mes("The Spirit of Trust must")
    |> mes("be delivered to #{castle_color}#{sage_name(ctx)}^000000,")
    |> mes("so don't forget to relay")
    |> mes("that information to your")
    |> mes("Sage or Scholar. Very well,")
    |> mes("good luck on your journey.")
    |> close()
  end

  defp too_pale(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("Ah, did you rest we-- Oh.")
    |> mes("Why do you look so pale?")
    |> mes("You can't accomplish great")
    |> mes("deeds when you're overworked!")
    |> mes("Rest. Your guild must be able")
    |> mes("to depend on your strength.")
    |> emotion(:surprise)
    |> next()
    |> mes(header(ctx))
    |> mes("Your determination and")
    |> mes("spirit is commendable, but")
    |> mes("have the patience to recollect")
    |> mes("yourself when you must. I will")
    |> mes("be waiting here, so please")
    |> mes("come back to me later.")
    |> close()
  end

  defp peace_trial_ready(ctx, time) do
    visit_hour = get_char_var(ctx, :guildtime, 0)

    rested? =
      (visit_hour > 2299 and time > 101 and time < visit_hour) or
        (visit_hour > 2199 and time > 1 and time < visit_hour) or
        time - visit_hour > 200

    if rested?, do: peace_trial_assigned(ctx), else: too_pale(ctx)
  end

  defp peace_trial_assigned(ctx) do
    ctx =
      ctx
      |> mes(header(ctx))
      |> mes("Ah, you look well rested,")
      |> mes("master. It is now time for")
      |> mes("you to proceed with the third")
      |> mes("test. Let me remind you that")
      |> mes("these spirits are incredibly")
      |> mes("precious. Do not lose them.")
      |> next()

    ctx =
      ctx
      |> mes(header(ctx))
      |> mes("Like all the other spirits,")
      |> mes("please keep this one safely.")
      |> mes("This is the ^4D4DFFSpirit of Peace^000000.")
      |> mes("It seems contradictive that")
      |> mes("strongholds and might can")
      |> mes("bring peace, but it's true.")
      |> set_char_var(:guildrelay_q, 15)
      |> give_item(7246, 1)
      |> next()

    ctx =
      ctx
      |> mes(header(ctx))
      |> mes("If power isn't used to")
      |> mes("protect the weak, then")
      |> mes("some bully, in one form or")
      |> mes("another, will always come")
      |> mes("to exploit them. That is why")
      |> mes("Tristan III built the strongholds.")
      |> next()
      |> mes(header(ctx))
      |> mes("Please dispatch a Rogue")
      |> mes("or Stalker to bring this")
      |> mes("Spirit of Peace to ^4D4DFF#{rogue_name(ctx)}^000000.")
      |> mes("If you don't know any Rogues")
      |> mes("or Stalkers, then it would be")
      |> mes("prudent for you to meet one.")
      |> next()

    ctx
    |> mes(header(ctx))
    |> mes("Yes, there's no substitute")
    |> mes("for the subterfuge and intel")
    |> mes("gathering that a Rogue can")
    |> mes("provide. Anyway, #{rogue_name(ctx)} will")
    |> mes("guide you on your third test.")
    |> close()
  end

  defp final_report(ctx, time) do
    visit_hour = get_char_var(ctx, :guildtime, 0)

    rested? =
      (visit_hour > 2299 and time > 401 and time < visit_hour) or
        (visit_hour > 2199 and time > 301 and time < visit_hour) or
        (visit_hour > 2059 and time > 201 and time < visit_hour) or
        (visit_hour > 1999 and time > 101 and time < visit_hour) or
        (visit_hour > 1899 and time > 1 and time < visit_hour) or
        time - visit_hour > 500

    if rested?, do: trials_completed(ctx), else: busy_reporting(ctx)
  end

  defp trials_completed(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("Ah, have you rested well,")
    |> mes("master? Please excuse my")
    |> mes("manners a while ago. I had")
    |> mes("to report your trial results,")
    |> mes("and lost my composure for a")
    |> mes("moment. It won't happen again.")
    |> set_char_var(:guildrelay_q, 999)
    |> close()
  end

  defp busy_reporting(ctx) do
    ctx
    |> mes("...............................")
    |> mes("...............................")
    |> next()
    |> mes("...............................")
    |> mes("...............................")
    |> mes("...............................")
    |> next()
    |> mes(header(ctx))
    |> emotion(:huk)
    |> mes("Oh! M-master? Wh-when")
    |> mes("did you...? I'm so sorry.")
    |> mes("I was busy working.")
    |> next()
    |> mes(header(ctx))
    |> mes("It's only been a few days")
    |> mes("since you finished the trials.")
    |> mes("For now, you should rest and")
    |> mes("take care of your guild, okay?")
    |> mes("Please come back later.")
    |> mes("I've got much to attend to...")
    |> close()
  end

  defp retry_offer(ctx) do
    {ctx, choice} =
      ctx
      |> mes(header(ctx))
      |> mes("Good day, master.")
      |> mes("Is something wrong?")
      |> mes("You look as though")
      |> mes("something is on your mind.")
      |> next()
      |> select(["N-no, nothing.", "I want to take a lesson."])

    case choice do
      1 ->
        ctx
        |> mes(header(ctx))
        |> mes("Hm? That's strange.")
        |> emotion(:sweat)
        |> mes("You didn't want to take")
        |> mes("the trials again, did you?")
        |> close()

      2 ->
        first_test_spirit(ctx)

      _ ->
        ctx
    end
  end

  defp first_test_spirit(ctx) do
    ctx =
      ctx
      |> mes(header(ctx))
      |> mes("I see. You know it won't")
      |> mes("be easy, but I suppose you")
      |> mes("are prepared. Here, take")
      |> mes("the ^4D4DFFSpirit of Guild^000000, and")
      |> mes("give it to your most trusted")
      |> mes("Knight or Lord Knight.")
      |> set_char_var(:guildrelay_q, 1)
      |> give_item(7234, 1)
      |> next()

    ctx
    |> mes(header(ctx))
    |> mes("This Knight should take")
    |> mes("the Spirit of Guild over")
    |> mes("to ^4D4DFF#{knight_name(ctx)}^000000. Good luck, and")
    |> mes("may the gods be with you.")
    |> close()
  end

  defp first_test_progress(ctx, time) do
    if count_item(ctx, 7234) > 0 do
      ctx
      |> mes(header(ctx))
      |> mes("You still have the Spirit of")
      |> mes("Guild I gave you? I suppose")
      |> mes("you haven't found a Knight or")
      |> mes("Lord Knight to which it can")
      |> mes("be entrusted. It is imperative")
      |> mes("that you find someone soon.")
      |> next()
      |> mes(header(ctx))
      |> mes("For the sake of the guild, it")
      |> mes("will be advantageous to have")
      |> mes("a Knight or Lord Knight on")
      |> mes("your side: their combat skills")
      |> mes("can turn the tide of battles.")
      |> next()
      |> mes(header(ctx))
      |> mes("When you do find a Knight,")
      |> mes("give him the Spirit of Guild")
      |> mes("and ask him to find #{knight_name(ctx)}")
      |> mes("since he will conducting")
      |> mes("the trial. Good luck")
      |> mes("to you, master.")
      |> close()
    else
      if count_item(ctx, 7239) > 0 do
        claim_first_test_reward(ctx, time)
      else
        ctx
        |> mes(header(ctx))
        |> mes("If you're not busy, then")
        |> mes("why don't you spend your")
        |> mes("time increasing morale")
        |> mes("among your guild members?")
        |> mes("Perhaps some team building")
        |> mes("exercise can be of help.")
        |> close()
      end
    end
  end

  defp claim_first_test_reward(ctx, time) do
    ctx =
      ctx
      |> mes(header(ctx))
      |> mes("Ah, is this the Spirit")
      |> mes("of Advance? This must mean")
      |> mes("that you completed the first")
      |> mes("test. Keep up the good work.")
      |> mes("Hand me the spirit, and allow")
      |> mes("me to give you your guild's reward.")
      |> delitem(7239, 1)

    ctx =
      ctx
      |> set_char_var(:guildtime, time)
      |> set_char_var(:guildrelay_q, 100)
      |> first_test_reward()

    ctx
    |> next()
    |> mes(header(ctx))
    |> mes("You've done well, but")
    |> mes("there are more trials")
    |> mes("ahead of you. For now,")
    |> mes("you should rest before")
    |> mes("undertaking the second test.")
    |> mes("Please come when you are ready.")
    |> close()
  end

  defp first_test_reward(ctx) do
    case Enum.random(1..100) do
      roll when roll > 0 and roll < 25 ->
        ctx |> give_item(608, 20) |> give_item(678, 2)

      roll when roll > 24 and roll < 50 ->
        ctx |> give_item(607, 10) |> give_item(678, 2)

      roll when roll > 50 and roll < 75 ->
        ctx |> give_item(644, 5) |> give_item(678, 2)

      roll when roll > 74 and roll < 101 ->
        ctx |> give_item(603, 3) |> give_item(678, 2)

      _roll ->
        ctx
    end
  end

  defp second_test_progress(ctx) do
    if count_item(ctx, 7240) > 0 do
      ctx
      |> mes(header(ctx))
      |> mes("You must be having")
      |> mes("trouble finding #{sage_name(ctx)}.")
      |> mes("Make sure that you have")
      |> mes("a Sage or Scholar friend")
      |> mes("give that Spirit of Trust to")
      |> mes("him once you locate him.")
      |> close()
    else
      if count_item(ctx, 7245) > 0 do
        claim_second_test_reward(ctx)
      else
        ctx
        |> mes(header(ctx))
        |> mes("If you're not busy, then")
        |> mes("why don't you spend your")
        |> mes("time increasing morale")
        |> mes("among your guild members?")
        |> mes("Perhaps some team building")
        |> mes("exercise can be of help.")
        |> next()
        |> mes(header(ctx))
        |> mes("If it suits your fancy,")
        |> mes("you may simply come here")
        |> mes("and join me for a cup of tea.")
        |> close()
      end
    end
  end

  defp claim_second_test_reward(ctx) do
    ctx =
      ctx
      |> mes(header(ctx))
      |> mes("Ah, so you already completed")
      |> mes("the test and earned the Spirit")
      |> mes("of Friendship? Good work.")
      |> mes("You must now recognize the")
      |> mes("value of teamwork. Please give")
      |> mes("the Spirit of Friendship to me.")
      |> next()

    ctx =
      ctx
      |> mes(header(ctx))
      |> mes("Now, please take this")
      |> mes("reward and share it with")
      |> mes("your guild members. This")
      |> mes("may come in handy in future")
      |> mes("challenges that you will all")
      |> mes("face together. Good work!")
      |> delitem(7245, 1)

    ctx =
      ctx
      |> set_char_var(:guildtime, Rathena.atoi(gettimestr(ctx, "%H%M", 5)))
      |> set_char_var(:guildrelay_q, 150)
      |> second_test_reward()

    ctx
    |> next()
    |> mes(header(ctx))
    |> mes("You should rest and")
    |> mes("recuperate before you")
    |> mes("undertake the third test.")
    |> mes("I too would benefit from")
    |> mes("a brief respite. Please come")
    |> mes("back to me when you are ready.")
    |> close()
  end

  defp second_test_reward(ctx) do
    case Enum.random(1..100) do
      roll when roll > 0 and roll < 16 ->
        ctx |> give_item(607, 10) |> give_item(644, 5) |> give_item(678, 3)

      roll when roll > 14 and roll < 31 ->
        ctx |> give_item(607, 10) |> give_item(603, 3) |> give_item(678, 3)

      roll when roll > 29 and roll < 46 ->
        ctx |> give_item(607, 10) |> give_item(617, 3) |> give_item(678, 3)

      roll when roll > 44 and roll < 61 ->
        ctx |> give_item(644, 4) |> give_item(603, 2) |> give_item(678, 3)

      roll when roll > 59 and roll < 76 ->
        ctx |> give_item(644, 3) |> give_item(617, 2) |> give_item(678, 3)

      roll when roll > 74 and roll < 91 ->
        ctx |> give_item(603, 2) |> give_item(617, 2) |> give_item(678, 3)

      roll when roll > 89 and roll < 101 ->
        ctx |> give_item(607, 10) |> give_item(644, 3) |> give_item(603, 2) |> give_item(617, 1)

      _roll ->
        ctx
    end
  end

  defp third_test_progress(ctx) do
    if count_item(ctx, 7246) > 0 do
      ctx
      |> mes(header(ctx))
      |> mes("You still have the")
      |> mes("Spirit of Peace? If you")
      |> mes("don't have any Rogues or")
      |> mes("Stalkers in your guild, now")
      |> mes("would be the time to recruit")
      |> mes("them. Heed my advice...")
      |> close()
    else
      if count_item(ctx, 7251) > 0 do
        claim_final_reward(ctx)
      else
        ctx
        |> mes(header(ctx))
        |> mes("If you aren't particularly")
        |> mes("busy, then why don't you")
        |> mes("spend some time with your")
        |> mes("guild members? Building")
        |> mes("strong camaraderie never")
        |> mes("fails to pay off. Never.")
        |> close()
      end
    end
  end

  defp claim_final_reward(ctx) do
    ctx =
      ctx
      |> mes(header(ctx))
      |> mes("I see that you've completed")
      |> mes("the last test and received")
      |> mes("the Spirit of Victory. Heh.")
      |> mes("Victory is the natural result")
      |> mes("when your guild works together")
      |> mes("in harmony as a united team.")
      |> next()

    ctx =
      ctx
      |> mes(header(ctx))
      |> mes("Congratulations on")
      |> mes("completing all the trials.")
      |> mes("Please accept this reward,")
      |> mes("given on the behalf of King")
      |> mes("Tristan III, and share it with")
      |> mes("guild. Once again, good work.")
      |> delitem(7251, 1)

    ctx =
      ctx
      |> set_char_var(:guildtime, Rathena.atoi(gettimestr(ctx, "%H%M", 5)))
      |> set_char_var(:guildrelay_q, 25)
      |> final_reward()

    ctx
    |> next()
    |> mes(header(ctx))
    |> mes("You and your guild must be")
    |> mes("quite tired now. Your rooms")
    |> mes("are ready for you if you decide")
    |> mes("to rest. Please visit me again")
    |> mes("if you wish to take the trials")
    |> mes("again. I'll see you later.")
    |> close()
  end

  defp final_reward(ctx) do
    case Enum.random(1..100) do
      roll when roll > 0 and roll < 26 ->
        ctx |> give_item(608, 10) |> give_item(607, 5) |> give_item(644, 4)

      roll when roll > 25 and roll < 51 ->
        ctx |> give_item(608, 10) |> give_item(607, 5) |> give_item(603, 3)

      roll when roll > 50 and roll < 76 ->
        ctx |> give_item(608, 10) |> give_item(617, 2) |> give_item(607, 5)

      roll when roll > 75 and roll < 91 ->
        ctx |> give_item(608, 10) |> give_item(644, 4) |> give_item(603, 2) |> give_item(617, 1)

      roll when roll > 90 and roll < 101 ->
        give_item(ctx, 5074, 1)

      _roll ->
        ctx
    end
  end

  defp introduce_trials(ctx) do
    ctx =
      ctx
      |> mes(header(ctx))
      |> mes("Greetings, master.")
      |> mes("I am #{get_local(ctx, :npc_name, "")}, one of the four")
      |> mes("Great Sages, and I am here")
      |> mes("to serve you under the orders")
      |> mes("of wise and benevolent")
      |> mes("King Tristan III.")
      |> next()

    ctx =
      ctx
      |> mes(header(ctx))
      |> mes("We test guilds that own")
      |> mes("strongholds, and see if they")
      |> mes("are qualified to be considered")
      |> mes("elite guilds. Our goal is to")
      |> mes("train guilds to strengthen")
      |> mes("our military forces.")
      |> next()

    ctx =
      ctx
      |> mes(header(ctx))
      |> mes("Although your guild has the")
      |> mes("strength and courage to conquer")
      |> mes("a stronghold, we want you to")
      |> mes("prove that your guild has")
      |> mes("a strong sense of justice,")
      |> mes("honor, and compassion.")
      |> next()

    {ctx, choice} =
      ctx
      |> mes(header(ctx))
      |> mes("It is up to you. Will")
      |> mes("you take the test I have")
      |> mes("for you? I will do my best to")
      |> mes("help your guild grow stronger")
      |> mes("so that you will be better")
      |> mes("able to protect the weak.")
      |> next()
      |> select(["I want to take the test.", "Let me think about it."])

    case choice do
      1 -> trials_rules(ctx)
      2 -> pending_decision(ctx)
      _ -> ctx
    end
  end

  defp trials_rules(ctx) do
    ctx =
      ctx
      |> mes(header(ctx))
      |> mes("Is that so? In this test,")
      |> mes("you will be given orders")
      |> mes("and special spirits. These")
      |> mes("spirits will only be given")
      |> mes("once: you must not lose them.")
      |> next()

    ctx =
      ctx
      |> mes(header(ctx))
      |> mes("If you lose the spirit,")
      |> mes("you will be judged as")
      |> mes("irresponsible, and will be")
      |> mes("unable to complete the tests.")
      |> mes("You must find any lost spirit to")
      |> mes("proceed. There's no second chance.")
      |> next()

    ctx =
      ctx
      |> mes(header(ctx))
      |> mes("There are a few things you")
      |> mes("should know. Firstly, you can")
      |> mes("only take care of one spirit")
      |> mes("at a time. Secondly, you need")
      |> mes("to do the tests in order and")
      |> mes("follow the guide's instructions.")
      |> next()

    ctx
    |> mes(header(ctx))
    |> mes("Thirdly, the spirit should")
    |> mes("be given to the type of person")
    |> mes("specified in the test. Those")
    |> mes("are the rules. Remember them.")
    |> next()
    |> mes(header(ctx))
    |> mes("Okay, this is the first")
    |> mes("spirit that will be entrusted")
    |> mes("to you. Make sure to give this")
    |> mes("to a Knight or Lord Knight.")
    |> mes("The test has now officially")
    |> mes("begun. Good luck to you.")
    |> set_char_var(:guildrelay_q, 1)
    |> give_item(7234, 1)
    |> close()
  end

  defp pending_decision(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("I suppose it would be")
    |> mes("a good idea to discuss")
    |> mes("this with your guild before")
    |> mes("you decide to commit to")
    |> mes("taking the test. Feel free")
    |> mes("free to visit me again later.")
    |> close()
  end

  defp guild_courier(ctx) do
    cond do
      count_item(ctx, 7234) > 0 -> carried_guild_spirit(ctx)
      count_item(ctx, 7235) > 0 -> carried_charge_spirit(ctx)
      count_item(ctx, 7237) > 0 -> carried_association_spirit(ctx)
      count_item(ctx, 7238) > 0 -> carried_coordination_spirit(ctx)
      count_item(ctx, 7239) > 0 -> carried_advance_spirit(ctx)
      count_item(ctx, 7240) > 0 -> carried_trust_spirit(ctx)
      count_item(ctx, 7241) > 0 -> carried_union_spirit(ctx)
      count_item(ctx, 7242) > 0 -> carried_combination_spirit(ctx)
      count_item(ctx, 7244) > 0 -> carried_solidarity_spirit(ctx)
      count_item(ctx, 7245) > 0 -> carried_friendship_spirit(ctx)
      count_item(ctx, 7246) > 0 -> carried_peace_spirit(ctx)
      count_item(ctx, 7247) > 0 -> carried_determination_spirit(ctx)
      count_item(ctx, 7249) > 0 -> carried_service_spirit(ctx)
      count_item(ctx, 7250) > 0 -> carried_glory_spirit(ctx)
      count_item(ctx, 7251) > 0 -> carried_victory_spirit(ctx)
      true -> too_busy(ctx)
    end
  end

  defp carried_guild_spirit(ctx) do
    if job?(ctx, :knight) do
      ctx
      |> mes(header(ctx))
      |> mes("Hello,#{char_name(ctx, 0)}.")
      |> mes("So you were the one chosen")
      |> mes("by your guild master? I see.")
      |> mes("You should deliver that Spirit")
      |> mes("of Guild over to #{knight_name(ctx)}.")
      |> mes("He'll instruct you further.")
      |> close()
    else
      ctx
      |> mes(header(ctx))
      |> mes("The Spirit of Guild is")
      |> mes("useless unless it is in the")
      |> mes("hands of a Knight or Lord")
      |> mes("Knight. You should speak")
      |> mes("to #{knight_name(ctx)} to learn more.")
      |> close()
    end
  end

  defp carried_charge_spirit(ctx) do
    cond do
      get_char_var(ctx, :guildrelay_q, 0) == 88 and job?(ctx, :knight) ->
        spirit_passed_directly(
          ctx,
          "Ah,#{char_name(ctx, 0)}",
          [
            "Congratulations. It looks",
            "like you did a good job.",
            "Please give the Spirit of",
            "Charge to the next person",
            "to continue the testing."
          ],
          knight_name(ctx)
        )

      job?(ctx, :blacksmith) ->
        spirit_hello(ctx, "Hello,#{char_name(ctx, 0)}.", [
          "Ah, I see that you have",
          "the Spirit of Charge.",
          "Heh heh, it's always exciting",
          "to charge into battle, isn't",
          "it? Well then, do your best."
        ])

      true ->
        spirit_useless(ctx, [
          "#{knight_name(ctx)} knows more about the",
          "Spirit of Charge, so you should",
          "ask him more about that spirit."
        ])
    end
  end

  defp carried_association_spirit(ctx) do
    cond do
      get_char_var(ctx, :guildrelay_q, 0) == 87 and job?(ctx, :blacksmith) ->
        spirit_passed_directly(
          ctx,
          "Hello,#{char_name(ctx, 0)}.",
          commend_work(),
          knight_name(ctx)
        )

      job?(ctx, :alchemist) ->
        spirit_hello(ctx, "Hello, #{char_name(ctx, 0)}.", [
          "I see that you posess",
          "the Spirit of Association.",
          "Good luck with your test."
        ])

      true ->
        spirit_useless(ctx, [
          "Talk to #{knight_name(ctx)} if you want",
          "to know more about the",
          "Spirit of Association."
        ])
    end
  end

  defp carried_coordination_spirit(ctx) do
    cond do
      get_char_var(ctx, :guildrelay_q, 0) == 86 and job?(ctx, :alchemist) ->
        spirit_passed_directly(
          ctx,
          "Hello,#{char_name(ctx, 0)}.",
          commend_work(),
          knight_name(ctx)
        )

      job?(ctx, :hunter) ->
        spirit_hello(ctx, "Hello, #{char_name(ctx, 0)}.", [
          "I see that you posess",
          "the Spirit of Coordination.",
          "Good luck on your test."
        ])

      true ->
        spirit_useless(ctx, [
          "#{knight_name(ctx)} will know more about",
          "the Spirit of Coordination",
          "so you should consult him."
        ])
    end
  end

  defp carried_advance_spirit(ctx) do
    cond do
      get_char_var(ctx, :guildrelay_q, 0) == 85 and job?(ctx, :hunter) ->
        spirit_hello(ctx, "Hello, #{char_name(ctx, 0)}.", [
          "Congratulations, it looks",
          "like you finished the test.",
          "You may now give the Spirit of",
          "Advance to your guild master."
        ])

      true ->
        spirit_useless(ctx, [
          "#{knight_name(ctx)} will know more about",
          "the Spirit of Advance so",
          "you should consult him."
        ])
    end
  end

  defp carried_trust_spirit(ctx) do
    cond do
      job?(ctx, :sage) ->
        spirit_hello(ctx, "Hello, #{char_name(ctx, 0)}.", [
          "I see that you possess",
          "the Spirit of Trust.",
          "Good luck, and do not",
          "fail the trust placed in",
          "you by your guild."
        ])

      true ->
        spirit_useless(ctx, [
          "#{sage_name(ctx)} will know more",
          "about the Spirit of Trust",
          "so you should consult him."
        ])
    end
  end

  defp carried_union_spirit(ctx) do
    cond do
      get_char_var(ctx, :guildrelay_q, 0) == 71 and job?(ctx, :sage) ->
        spirit_passed(ctx, "Hello,#{char_name(ctx, 0)}.", commend_work(), sage_name(ctx))

      job?(ctx, :bard) or job?(ctx, :dancer) ->
        spirit_hello(ctx, "Ah, #{char_name(ctx, 0)},", [
          "I see that you have the",
          "Spirit of Union. Always keep",
          "in mind that the strength of",
          "your guild is directly",
          "related to its unity."
        ])

      true ->
        spirit_useless(ctx, [
          "#{sage_name(ctx)} will know more",
          "about the Spirit of Union",
          "so you should consult him."
        ])
    end
  end

  defp carried_combination_spirit(ctx) do
    cond do
      get_char_var(ctx, :guildrelay_q, 0) == 72 and (job?(ctx, :bard) or job?(ctx, :dancer)) ->
        spirit_passed(ctx, "Hello,#{char_name(ctx, 0)}.", commend_work(), sage_name(ctx))

      job?(ctx, :assassin) ->
        spirit_hello(ctx, "Ah, #{char_name(ctx, 0)},", [
          "I see that you have the Spirit",
          "of Combination. Remember that",
          "working in tandem, combining",
          "your guild's skills and talents,",
          "will realize your true potential."
        ])

      true ->
        spirit_useless(ctx, [
          "#{sage_name(ctx)} will know more about",
          "the Spirit of Combination so",
          "you should consult him."
        ])
    end
  end

  defp carried_solidarity_spirit(ctx) do
    cond do
      get_char_var(ctx, :guildrelay_q, 0) == 74 and job?(ctx, :assassin) ->
        spirit_passed(
          ctx,
          "Greetings, #{char_name(ctx, 0)},",
          [
            "did you rest well? Please",
            "give that spirit to the next",
            "person so that the testing",
            "of your guild may continue."
          ],
          sage_name(ctx)
        )

      job?(ctx, :wizard) ->
        spirit_hello(ctx, "Hello, #{char_name(ctx, 0)},", [
          "I see that you've been",
          "entrusted with the Spirit",
          "of Solidarity. Do your best",
          "on this test for the sake",
          "of your guild, alright?"
        ])

      true ->
        spirit_useless(ctx, [
          "#{sage_name(ctx)} will know more",
          "about the Spirit of Solidarity",
          "so you should consult him."
        ])
    end
  end

  defp carried_friendship_spirit(ctx) do
    cond do
      get_char_var(ctx, :guildrelay_q, 0) == 75 and job?(ctx, :wizard) ->
        spirit_hello(ctx, "Ah, #{char_name(ctx, 0)},", [
          "congratulations on a job",
          "well done. Please give the",
          "Spirit of Friendship to your",
          "guild master to continue",
          "the guild testing."
        ])

      true ->
        spirit_useless(ctx, [
          "#{sage_name(ctx)} will know more",
          "about the Spirit of Friendship",
          "so you should consult him."
        ])
    end
  end

  defp carried_peace_spirit(ctx) do
    cond do
      job?(ctx, :rogue) ->
        spirit_hello(ctx, "Ah, #{char_name(ctx, 0)},", [
          "I see that you have the",
          "Spirit of Peace. Please",
          "do your best for the sake",
          "of the guild, though I do not",
          "doubt you'll pass this test."
        ])

      true ->
        spirit_useless(ctx, [
          "#{rogue_name(ctx)} will know more",
          "about the Spirit of Peace",
          "so you should consult him."
        ])
    end
  end

  defp carried_determination_spirit(ctx) do
    cond do
      get_char_var(ctx, :guildrelay_q, 0) == 95 and job?(ctx, :priest) ->
        spirit_passed(ctx, "Hello,#{char_name(ctx, 0)}.", commend_work(), rogue_name(ctx))

      job?(ctx, :priest) ->
        spirit_hello(ctx, "Ah, #{char_name(ctx, 0)},", [
          "please take good care of",
          "that Spirit of Determination."
        ])

      true ->
        spirit_useless(ctx, [
          "#{rogue_name(ctx)} will know more about",
          "the Spirit of Determination",
          "so you should consult him."
        ])
    end
  end

  defp carried_service_spirit(ctx) do
    cond do
      get_char_var(ctx, :guildrelay_q, 0) == 98 and job?(ctx, :priest) ->
        spirit_passed(ctx, "Hello,#{char_name(ctx, 0)}.", commend_work(), rogue_name(ctx))

      job?(ctx, :crusader) ->
        spirit_hello(ctx, "Ah, #{char_name(ctx, 0)},", [
          "please take good care",
          "of that Spirit of Service."
        ])

      true ->
        spirit_useless(ctx, [
          "#{rogue_name(ctx)} will know more about",
          "the Spirit of Service so",
          "you should consult him."
        ])
    end
  end

  defp carried_glory_spirit(ctx) do
    cond do
      get_char_var(ctx, :guildrelay_q, 0) == 96 and job?(ctx, :crusader) ->
        spirit_passed(ctx, "Hello,#{char_name(ctx, 0)}.", commend_work(), rogue_name(ctx))

      job?(ctx, :monk) ->
        spirit_hello(ctx, "Ah, #{char_name(ctx, 0)},", [
          "please take good care",
          "of that Spirit of Glory."
        ])

      true ->
        spirit_useless(ctx, [
          "#{rogue_name(ctx)} will know more about",
          "the Spirit of Glory so you",
          "should consult him."
        ])
    end
  end

  defp carried_victory_spirit(ctx) do
    if get_char_var(ctx, :guildrelay_q, 0) == 97 and class?(ctx, :monk) do
      spirit_hello(ctx, "Ah, #{char_name(ctx, 0)},", [
        "congratulations on a job",
        "well done. Please give",
        "the Spirit of Victory to your",
        "guild master. That's it for now.",
        "Good luck to you in the future."
      ])
    else
      spirit_useless(ctx, [
        "#{rogue_name(ctx)} will know more about",
        "the Spirit of Victory so you",
        "should consult him."
      ])
    end
  end

  defp too_busy(ctx) do
    ctx
    |> mes(header(ctx))
    |> mes("I'm sorry, but I'm too")
    |> mes("busy with my work to offer")
    |> mes("you any help right now.")
    |> mes("You'll have to forgive me.")
    |> close()
  end

  defp spirit_passed(ctx, greeting, body, teacher) do
    ctx
    |> mes(header(ctx))
    |> mes(greeting)
    |> then(fn ctx -> Enum.reduce(body, ctx, &mes(&2, &1)) end)
    |> next()
    |> mes(header(ctx))
    |> mes("If you don't remember")
    |> mes("#{teacher}'s explanation,")
    |> mes("then you might want to")
    |> mes("go back to him and ask")
    |> mes("him to tell you again.")
    |> close()
  end

  defp spirit_passed_directly(ctx, greeting, body, teacher) do
    ctx
    |> mes(header(ctx))
    |> mes(greeting)
    |> then(fn ctx -> Enum.reduce(body, ctx, &mes(&2, &1)) end)
    |> next()
    |> mes(header(ctx))
    |> mes("#{teacher} should have")
    |> mes("explained everything, but")
    |> mes("if you forgot, then please")
    |> mes("go and ask him again.")
    |> close()
  end

  defp spirit_hello(ctx, greeting, body) do
    ctx
    |> mes(header(ctx))
    |> mes(greeting)
    |> then(fn ctx -> Enum.reduce(body, ctx, &mes(&2, &1)) end)
    |> close()
  end

  defp spirit_useless(ctx, tail_lines) do
    ctx
    |> mes(header(ctx))
    |> mes("That spirit won't be very")
    |> mes("useful if it's not in the")
    |> mes("hands of the right person.")
    |> then(fn ctx -> Enum.reduce(tail_lines, ctx, &mes(&2, &1)) end)
    |> close()
  end

  defp commend_work do
    [
      "I commend you on your work.",
      "Please give that spirit to",
      "the next person so that the",
      "testing can continue."
    ]
  end

  defp header(ctx), do: "[#{get_local(ctx, :npc_name, "")}]"

  defp knight_name(ctx), do: get_local(ctx, :knight_name, "")
  defp sage_name(ctx), do: get_local(ctx, :sage_name, "")
  defp rogue_name(ctx), do: get_local(ctx, :rogue_name, "")

  defp job?(ctx, job), do: base_job(ctx) == job
  defp class?(ctx, job), do: class(ctx) == job
end
