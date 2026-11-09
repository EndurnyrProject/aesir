defmodule Aesir.ZoneServer.Content.Npc.Quests.Partyrelay.Lospii do
  @moduledoc """
  Lospii tests teamwork by gathering nearby adventurers during the party relay.

  ## Behavior

  - Exchanges tickets 3, 7, and 11 for gathering missions at relay steps 10, 21, and 31.
  - Starts the first mission for Archers above level 39, the second for Merchants,
    and the third for Archers or Merchants.
  - Checks the first mission at 14:00–17:00 or 18:00–21:00, the second at
    11:00–14:00 or 00:00–03:00, and the third at 08:00–11:00 or from 21:00.
  - Requires more than 9, 11, or 13 nearby players respectively within eight cells.
  - Awards tickets 4, 8, or 12, relay experience, and two Yggdrasilberries,
    two Yggdrasil Leaves, or both respectively, to return through the leader to Ledrion.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/partyrelay.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "payon",
        x: 168,
        y: 314,
        dir: 3,
        sprite: 706,
        name: "Lospii",
        scope: :shared,
        unique_name: "RelayLospii"
      },
      %{
        map: "comodo",
        x: 64,
        y: 219,
        dir: 3,
        sprite: 706,
        name: "Lospii",
        scope: :shared,
        unique_name: "Lospii#comodo"
      },
      %{
        map: "einbroch",
        x: 173,
        y: 72,
        dir: 3,
        sprite: 706,
        name: "Lospii",
        scope: :shared,
        unique_name: "Lospii#einbroch"
      },
      %{
        map: "hugel",
        x: 144,
        y: 201,
        dir: 3,
        sprite: 706,
        name: "Lospii",
        scope: :shared,
        unique_name: "Lospii#hugel"
      },
      %{
        map: "rachel",
        x: 158,
        y: 215,
        dir: 3,
        sprite: 706,
        name: "Lospii",
        scope: :shared,
        unique_name: "Lospii#rachel"
      },
      %{
        map: "veins",
        x: 97,
        y: 245,
        dir: 5,
        sprite: 706,
        name: "Lospii",
        scope: :shared,
        unique_name: "Lospii#veins"
      }
    ]

  import Aesir.ZoneServer.Script.Dsl, warn: false

  alias Aesir.ZoneServer.Content.Npc.Functions.FPartyrelayExp
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{907, 300}]) == 0 ->
        overweight(ctx)

      count_item(ctx, 7730) > 0 or count_item(ctx, 7731) > 0 or
        count_item(ctx, 7734) > 0 or count_item(ctx, 7735) > 0 or
        count_item(ctx, 7738) > 0 or count_item(ctx, 7739) > 0 ->
        not_your_turn(ctx)

      true ->
        hour = gettime(ctx, 3)
        players = nearby_players(ctx)
        relay_mission(ctx, hour, players)
    end
  end

  defp nearby_players(ctx) do
    case getmapxy(ctx, :npc, strnpcinfo(ctx, 3)) do
      {map, x, y} -> getareausers(ctx, map, x - 8, y - 8, x + 8, y + 8)
      :error -> getareausers(ctx, "", -8, -8, 8, 8)
    end
  end

  defp relay_mission(ctx, hour, players) do
    cond do
      get_char_var(ctx, :party_relay, 0) == 32 ->
        return_twelfth_ticket(ctx)

      get_char_var(ctx, :party_relay, 0) == 31 and
        ((hour >= 8 and hour < 11) or hour >= 21) and players > 13 ->
        complete_mission(ctx, players, 32)

      get_char_var(ctx, :party_relay, 0) == 31 ->
        gathering_reminder(ctx, 10)

      count_item(ctx, 7740) > 0 and hour >= 8 and hour < 11 and
          (Rathena.job_id(base_job(ctx)) == Rathena.job_id(:archer) or
             Rathena.job_id(base_job(ctx)) == Rathena.job_id(:merchant)) ->
        start_mission(ctx, 7740, 31, 14)

      count_item(ctx, 7740) > 0 and hour >= 21 and
          (Rathena.job_id(base_class(ctx)) == Rathena.job_id(:archer) or
             Rathena.job_id(base_class(ctx)) == Rathena.job_id(:merchant)) ->
        start_mission(ctx, 7740, 31, 14)

      count_item(ctx, 7740) > 0 and
          (Rathena.job_id(base_class(ctx)) == Rathena.job_id(:archer) or
             Rathena.job_id(base_class(ctx)) == Rathena.job_id(:merchant)) ->
        off_duty(ctx, :later_missions)

      true ->
        merchant_mission(ctx, hour, players)
    end
  end

  defp merchant_mission(ctx, hour, players) do
    cond do
      get_char_var(ctx, :party_relay, 0) == 22 ->
        return_eighth_ticket(ctx)

      get_char_var(ctx, :party_relay, 0) == 21 and
        ((hour >= 11 and hour < 14) or (hour >= 0 and hour < 3)) and players > 11 ->
        complete_mission(ctx, players, 22)

      get_char_var(ctx, :party_relay, 0) == 21 ->
        gathering_reminder(ctx, 12)

      count_item(ctx, 7736) > 0 and
        ((hour >= 11 and hour < 14) or (hour >= 0 and hour < 3)) and
          Rathena.job_id(base_class(ctx)) == Rathena.job_id(:merchant) ->
        start_mission(ctx, 7736, 21, 12)

      count_item(ctx, 7736) > 0 and
          Rathena.job_id(base_class(ctx)) == Rathena.job_id(:merchant) ->
        off_duty(ctx, :later_missions)

      true ->
        archer_mission(ctx, hour, players)
    end
  end

  defp archer_mission(ctx, hour, players) do
    cond do
      get_char_var(ctx, :party_relay, 0) == 11 ->
        return_fourth_ticket(ctx)

      get_char_var(ctx, :party_relay, 0) == 10 and
        ((hour >= 14 and hour < 17) or (hour >= 18 and hour < 21)) and players > 9 ->
        complete_mission(ctx, players, 11)

      get_char_var(ctx, :party_relay, 0) == 10 ->
        first_gathering_reminder(ctx)

      count_item(ctx, 7732) > 0 and base_level(ctx) > 39 and
        ((hour >= 14 and hour < 17) or (hour >= 18 and hour < 21)) and
          Rathena.job_id(base_class(ctx)) == Rathena.job_id(:archer) ->
        start_mission(ctx, 7732, 10, 10)

      count_item(ctx, 7732) > 0 and base_level(ctx) > 39 and
          Rathena.job_id(base_class(ctx)) == Rathena.job_id(:archer) ->
        off_duty(ctx, :first_mission)

      true ->
        greeting(ctx)
    end
  end

  defp overweight(ctx) do
    ctx
    |> mes("^3355FFWait a minute! You're")
    |> mes("carrying too many items")
    |> mes("right now: store some of")
    |> mes("your extra things in Kafra")
    |> mes("Storage, and then come back.^000000")
    |> close()
  end

  defp not_your_turn(ctx) do
    ctx
    |> mes("[Lospii]")
    |> mes("Hey, didn't you figure")
    |> mes("out what you need to do?")
    |> mes("You're not supposed to")
    |> mes("talk to me now! Mmm...")
    |> mes("I don't know who you")
    |> mes("have to meet either, but...")
    |> close()
  end

  defp return_twelfth_ticket(ctx) do
    ctx
    |> mes("[Lospii]")
    |> mes("Hey! Did you give")
    |> mes("that ticket to the")
    |> mes("leader of your group")
    |> mes("yet? The guy that started")
    |> mes("this whole relay thing!")
    |> close()
  end

  defp return_eighth_ticket(ctx) do
    ctx
    |> mes("[Lospii]")
    |> mes("Huh? No, no, you're")
    |> mes("not supposed to be here!")
    |> mes("Give the eighth ticket to")
    |> mes("your leader so he can give")
    |> mes("it to Ledrion! Your leader...")
    |> mes("You know him, right?")
    |> close()
  end

  defp return_fourth_ticket(ctx) do
    ctx
    |> mes("[Lospii]")
    |> mes("Umm... Did you bring")
    |> mes("the fourth ticket to your")
    |> mes("leader yet? You know,")
    |> mes("the leader of the group.")
    |> mes("The one that started this")
    |> mes("whole relay test thingee.")
    |> close()
  end

  defp first_gathering_reminder(ctx) do
    ctx
    |> mes("[Lospii]")
    |> mes("Bring 10 of your friends")
    |> mes("here to me while I'm working,")
    |> mes("okay? Umm... I work frooom...")
    |> mes("2 PM to 5 PM, and 6 PM to 9 PM.")
    |> mes("I think those are the times.")
    |> mes("I... I can't read watches...")
    |> close()
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Lospii]")
    |> mes("Hi! I'm Lospii!")
    |> mes("Hey, does it look like")
    |> mes("I'm at work? Ha ha!")
    |> mes("I got a job! I'm helping")
    |> mes("my friends a lot!")
    |> close()
  end

  defp gathering_reminder(ctx, friends) do
    ctx
    |> mes("[Lospii]")
    |> mes("Okay, you have to bring")
    |> mes("me #{friends} of your friends when")
    |> mes("I'm working, okay? That's, uh,")
    |> mes("3 hours before noon, and then")
    |> mes("another 3 hours after midnight.")
    |> mes("Just only those times, okay?")
    |> close()
  end

  defp introduction(ctx) do
    ctx
    |> mes("[Lospii]")
    |> mes("Hi, I'm Lospii! Maybe")
    |> mes("I'm younger than you, but")
    |> mes("I'm in charge of this mission!")
    |> mes("So you have to listen, okay?")
    |> mes("Heh heh! Don't be scared~")
    |> next()
  end

  defp start_mission(ctx, ticket, stage, friends) do
    ctx
    |> introduction()
    |> mes("[Lospii]")
    |> mes("I'm working now for this")
    |> mes("mission thing so you came")
    |> mes("at a good time! Let's see...")
    |> mes("I need to give you... Some")
    |> mes("mission for you to doooo...")
    |> mes("Oh! I know! I got it!")
    |> next()
    |> mes("[Lospii]")
    |> mes("We're seeing if you")
    |> mes("know about teamwork, right?")
    |> mes("Why don't you show me a lot")
    |> mes("of your friends? Bring me...")
    |> mes("#{friends} of them! Yes, that's good!")
    |> next()
    |> mes("[Lospii]")
    |> mes("I need to be able to")
    |> mes("see them, you know, so")
    |> mes("I know you're not lying")
    |> mes("to me. Bring them reeeally")
    |> mes("close so I know they're your")
    |> mes("friends, not some other guys.")
    |> next()
    |> delitem(ticket, 1)
    |> set_char_var(:party_relay, stage)
    |> mes("[Lospii]")
    |> mes("Okay, I'll be right")
    |> mes("here! Oh! And you have")
    |> mes("to come with your friends")
    |> mes("while I'm at work! That's")
    |> mes("important to know!")
    |> close()
  end

  defp off_duty(ctx, mission) do
    ctx
    |> introduction()
    |> mes("[Lospii]")
    |> mes("Uh oh... I forgot")
    |> mes("that I'm not supposed")
    |> mes("to be working now. Come")
    |> mes("back when I'm working, okay?")
    |> next()
    |> working_hours(mission)
  end

  defp working_hours(ctx, :later_missions) do
    ctx
    |> mes("[Lospii]")
    |> mes("I... I work before")
    |> mes("noon for 3 hours, and")
    |> mes("then... 3 hours after")
    |> mes("midnight? Yes, those")
    |> mes("are the times when")
    |> mes("I'm working!")
    |> close()
  end

  defp working_hours(ctx, :first_mission) do
    ctx
    |> mes("[Lospii]")
    |> mes("I work frooom... Uh...")
    |> mes("2 PM to 5 PM? Oh!")
    |> mes("And also 6 PM to 9 PM.")
    |> mes("I think those are the")
    |> mes("times... I mean, clocks")
    |> mes("are hard to read, man!")
    |> close()
  end

  defp complete_mission(ctx, players, stage) do
    ctx =
      ctx
      |> mes("[Lospii]")
      |> mes("Oh! You brought so many")
      |> mes("friends! One... T-two...")
      |> mes("You brought #{players}?! Hmpf.")
      |> mes("Maybe I gave you something")
      |> mes("too easy to do. I didn't know")
      |> mes("you knew this many people!")
      |> next()
      |> mes("[Lospii]")
      |> mes("Oh well, thanks for")
      |> mes("bringing everyone here.")
      |> mes("For that, you get this")
      |> mes("gift from me. Cool, huh?")
      |> next()
      |> mission_rewards(stage)

    {ctx, _} = FPartyrelayExp.call(ctx, [])

    ctx
    |> mes("[Lospii]")
    |> mes("Okay, now take this")
    |> mes("ticket, and give it to")
    |> mes("your leader, the guy that")
    |> mes("started this whole relay")
    |> mes("thing. He needs to give")
    |> mes("the ticket to Ledrion, okay?")
    |> next()
    |> mes("[Lospii]")
    |> mes("You're almost done!")
    |> mes("...I think. Um, I'm not")
    |> mes("really sure what will")
    |> mes("happen next. I can only")
    |> mes("remember the parts I have")
    |> mes("to do. C'mon! I'm just a kid!")
    |> close()
  end

  defp mission_rewards(ctx, 32) do
    ctx
    |> set_char_var(:party_relay, 32)
    |> give_item(7741, 1)
    |> give_item(610, 2)
    |> give_item(607, 2)
  end

  defp mission_rewards(ctx, 22) do
    ctx
    |> set_char_var(:party_relay, 22)
    |> give_item(7737, 1)
    |> give_item(610, 2)
  end

  defp mission_rewards(ctx, 11) do
    ctx
    |> set_char_var(:party_relay, 11)
    |> give_item(7733, 1)
    |> give_item(607, 2)
  end
end
