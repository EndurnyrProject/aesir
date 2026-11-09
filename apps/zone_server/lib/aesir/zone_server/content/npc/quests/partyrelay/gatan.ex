defmodule Aesir.ZoneServer.Content.Npc.Quests.Partyrelay.Gatan do
  @moduledoc """
  Gatan runs the Swordman and Mage legs of the Party Relay quest with Base Level trials.

  ## Behavior

  - Turns away overweight characters and anyone still holding an unfinished relay ticket.
  - Takes a Swordman's first ticket from Ledrion between 11:00-14:00 or 00:00-03:00 and sets a
    trial of 1-3 Base Levels by level (skipped above level 94), then rewards the second ticket,
    2 Yggdrasil Berries and experience for the Thief to carry to Bafhail.
  - Takes a Mage's fifth ticket between 08:00-11:00 or from 21:00 and sets a similar trial,
    then rewards the sixth ticket, 2 Yggdrasil Leaves and experience for an Acolyte.
  - Takes a Swordman's or Mage's ninth ticket at any hour and sets a similar trial, checked
    between 14:00-17:00 or 18:00-21:00, then rewards the tenth ticket, 2 Yggdrasil Leaves,
    2 Yggdrasil Berries and experience for a Thief or Acolyte.
  - Reminds characters of pending trials and of his working hours, and greets everyone else.

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
        x: 83,
        y: 327,
        dir: 3,
        sprite: 86,
        name: "Gatan",
        scope: :shared,
        unique_name: "RelayGatan"
      },
      %{
        map: "comodo",
        x: 236,
        y: 197,
        dir: 3,
        sprite: 86,
        name: "Gatan",
        scope: :shared,
        unique_name: "Gatan#comodo"
      },
      %{
        map: "einbroch",
        x: 260,
        y: 128,
        dir: 3,
        sprite: 86,
        name: "Gatan",
        scope: :shared,
        unique_name: "Gatan#einbroch"
      },
      %{
        map: "hugel",
        x: 169,
        y: 139,
        dir: 3,
        sprite: 86,
        name: "Gatan",
        scope: :shared,
        unique_name: "Gatan#hugel"
      },
      %{
        map: "rachel",
        x: 45,
        y: 163,
        dir: 3,
        sprite: 86,
        name: "Gatan",
        scope: :shared,
        unique_name: "Gatan#rachel"
      },
      %{
        map: "veins",
        x: 138,
        y: 207,
        dir: 3,
        sprite: 86,
        name: "Gatan",
        scope: :shared,
        unique_name: "Gatan#veins"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FPartyrelayExp
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @pending_tickets [7732, 7733, 7736, 7737, 7740, 7741]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{907, 300}]) == 0 ->
        ctx
        |> mes("^3355FFWait a minute! You're")
        |> mes("carrying too many items")
        |> mes("right now: store some of")
        |> mes("your extra things in Kafra")
        |> mes("Storage, and then come back.^000000")
        |> close()

      Enum.any?(@pending_tickets, &(count_item(ctx, &1) > 0)) ->
        ctx
        |> gatan([
          "Say, aren't you forgetting",
          "something? Try to remember...",
          "Earlier, you received some",
          "instructions, didn't you?"
        ])
        |> close()

      true ->
        ninth_leg(ctx, gettime(ctx, 3))
    end
  end

  defp ninth_leg(ctx, hour) do
    relay = get_char_var(ctx, :party_relay, 0)

    cond do
      relay == 28 ->
        ctx
        |> gatan([
          "Say, I don't think it's",
          "your turn to meet up with",
          "me. I think you need to ask a",
          "Thief or Acolyte Class member",
          "of your group to bring the",
          "tenth ticket to Bafhail."
        ])
        |> close()

      relay == 27 ->
        ctx
        |> gatan([
          "Ah, very nice! Please",
          "give this ticket to a Thief",
          "or Acolyte Class member",
          "of your group, and ask him",
          "to bring it to Bafhail. Ah, and",
          "here's a little reward for you~"
        ])
        |> reward(28, [{7739, 1}, {610, 2}, {607, 2}])
        |> next()
        |> see_you_around()

      relay in [24, 25, 26] ->
        ninth_trial(ctx, relay, hour)

      ninth_ticket_holder?(ctx) ->
        ninth_ticket(ctx, hour)

      true ->
        fifth_leg(ctx, hour)
    end
  end

  defp ninth_trial(ctx, relay, hour) do
    levels = relay - 23

    if base_level(ctx) > get_char_var(ctx, :party_relay_lv, 0) + levels - 1 and
         (between?(hour, 14, 17) or between?(hour, 18, 21)) do
      gained =
        if levels == 1,
          do: ["Great, you gained a", "level, just like I asked."],
          else: ["Great, you gained some", "levels, just like I asked."]

      ctx
      |> gatan(gained ++ next_instructions())
      |> set_char_var(:party_relay, 27)
      |> close()
    else
      ctx
      |> gatan([
        "Your mission is to",
        "gain #{levels} more #{base_levels(levels)}.",
        "Come see me during my",
        "working hours once you",
        "accomplish that, alright?"
      ])
      |> next()
      |> gatan([
        "I can't tell you exactly",
        "when I work, but my work",
        "hours are in the afternoon...",
        "Pacific Standard Time, anyway.",
        "I might not be here if you",
        "come here too late, alright?"
      ])
      |> close()
    end
  end

  defp ninth_ticket_holder?(ctx) do
    count_item(ctx, 7738) > 0 and
      (Rathena.job_id(base_class(ctx)) == Rathena.job_id(:swordman) or
         Rathena.job_id(base_class(ctx)) == Rathena.job_id(:mage))
  end

  defp ninth_ticket(ctx, hour) do
    ctx = ctx |> ticket_greeting() |> next() |> level_test_page()

    cond do
      base_level(ctx) > 39 ->
        take_ticket(ctx, 7738, {27, 24, 25, 26})

      ninth_ticket_holder?(ctx) ->
        ctx
        |> off_shift()
        |> gatan([
          "I can't tell you exactly",
          "when I'm working (^666666well,",
          "I just want to avoid working",
          "altogether to be honest^000000) but",
          "come back in the afternoon,",
          "Pacific Standard Time, that is."
        ])
        |> close()

      true ->
        fifth_leg(ctx, hour)
    end
  end

  defp fifth_leg(ctx, hour) do
    relay = get_char_var(ctx, :party_relay, 0)
    fifth_ticket? = base_level(ctx) > 39 and count_item(ctx, 7734) > 0

    cond do
      relay == 17 ->
        ctx
        |> gatan([
          "Say, it's not time for",
          "you to meet up with me",
          "just yet. I think you need",
          "to ask an Acolyte Class",
          "member in your group to bring",
          "your sixth ticket to Bafhail."
        ])
        |> close()

      relay == 16 ->
        ctx
        |> gatan([
          "Ah, very nice! Please",
          "give this ticket to an",
          "Acolyte Class member",
          "of your group, and ask him",
          "to bring it to Bafhail. Ah, and",
          "here's a little reward for you~"
        ])
        |> reward(17, [{7735, 1}, {610, 2}])
        |> next()
        |> see_you_around()

      relay in [13, 14, 15] ->
        fifth_trial(ctx, relay, hour)

      fifth_ticket? and (between?(hour, 8, 11) or hour >= 21) and job?(ctx, :mage) ->
        ctx
        |> ticket_greeting()
        |> next()
        |> level_test_page()
        |> take_ticket(7734, {16, 13, 14, 15})

      fifth_ticket? and job?(ctx, :mage) ->
        ctx
        |> off_shift()
        |> lunch_and_midnight_hours()
        |> close()

      true ->
        first_leg(ctx, hour)
    end
  end

  defp fifth_trial(ctx, relay, hour) do
    levels = relay - 12

    if base_level(ctx) > get_char_var(ctx, :party_relay_lv, 0) + levels - 1 and
         fifth_trial_hours?(relay, hour) do
      ctx
      |> gatan(["Great, you gained some", "levels, just like I asked."] ++ next_instructions())
      |> set_char_var(:party_relay, 16)
      |> close()
    else
      ctx
      |> gatan([
        "Your mission is to",
        "gain #{levels} more #{base_levels(levels)}.",
        "Come see me during my",
        "working hours once you",
        "accomplish that, alright?"
      ])
      |> next()
      |> lunch_and_midnight_hours()
      |> close()
    end
  end

  defp fifth_trial_hours?(15, hour), do: between?(hour, 8, 11) or (hour >= 21 and hour < 1)
  defp fifth_trial_hours?(14, hour), do: hour >= 8 or hour >= 21
  defp fifth_trial_hours?(13, hour), do: between?(hour, 8, 11) or hour >= 21

  defp first_leg(ctx, hour) do
    relay = get_char_var(ctx, :party_relay, 0)
    first_ticket? = base_level(ctx) > 39 and count_item(ctx, 7730) > 0

    cond do
      relay == 6 ->
        ctx
        |> gatan([
          "Did you give that ticket",
          "to the Thief Class member",
          "of your group? ^666666*Yawn*^000000 If you",
          "wanna finish all of these",
          "challenges, then that's",
          "what you gotta do~"
        ])
        |> close()

      relay == 5 ->
        ctx
        |> gatan([
          "Ah, very nice!",
          "Now please give this",
          "ticket to the Thief Class",
          "member of the your group,",
          "and ask him to deliver",
          "it to Bafhail. Easy, right?"
        ])
        |> next()
        |> gatan(["Here you are...", "Just a little", "something for", "your troubles~"])
        |> reward(6, [{7731, 1}, {607, 2}])
        |> next()
        |> gatan([
          "Don't forget to make",
          "sure that Bafhail gets",
          "that ticket from a Thief",
          "Class character in your",
          "group. I'll see you around."
        ])
        |> close()

      relay in [3, 4, 99] ->
        first_trial(ctx, relay, hour)

      first_ticket? and between?(hour, 11, 14) and job?(ctx, :swordman) ->
        ctx
        |> swordman_test_pages()
        |> take_ticket(7730, {5, 99, 3, 4})

      first_ticket? and between?(hour, 0, 3) and job?(ctx, :swordman) ->
        ctx
        |> swordman_test_pages()
        |> take_ticket(7730, {5, 99, 3, 4}, :keep_ticket)

      first_ticket? and job?(ctx, :swordman) ->
        ctx
        |> ticket_greeting()
        |> next()
        |> gatan([
          "Hate to tell you, but",
          "I'm not on duty right now.",
          "You should really come back",
          "and talk to me during my",
          "work hours, okay? I need",
          "my rest from work, you know?"
        ])
        |> next()
        |> gatan([
          "I'll tell you when I work,",
          "just don't forget: come from",
          "11 AM to 2 PM, or 12 AM to",
          "3 AM, Pacific Standard Time.",
          "Good luck to you, alright?"
        ])
        |> close()

      true ->
        ctx
        |> gatan([
          "Hey, nice meeting you.",
          "I'm Gatan. I'm not up to",
          "much, just helping out",
          "a friend. He's loaded, but",
          "he's also a really good guy.",
          "Working me to the bone, though."
        ])
        |> close()
    end
  end

  defp first_trial(ctx, relay, hour) do
    levels = %{99 => 1, 3 => 2, 4 => 3}[relay]

    if base_level(ctx) > get_char_var(ctx, :party_relay_lv, 0) + levels - 1 and
         (between?(hour, 11, 14) or between?(hour, 0, 3)) do
      ctx
      |> gatan([
        "Nice work. I guess",
        "that Ledrion really knows",
        "good adventurers when he",
        "sees them. Now, you mind",
        "waiting a bit? Um, there's",
        "something I have to give you..."
      ])
      |> set_char_var(:party_relay, 5)
      |> close()
    else
      ctx
      |> gatan([
        "You didn't forget that",
        "you had to gain #{levels} more",
        "#{base_levels(levels)}, did you?",
        "Oh, and come back during",
        "my regular working hours.",
        "Don't bother me when I'm off~"
      ])
      |> next()
      |> gatan([
        "I'll tell you when I work",
        "one more time: come from",
        "11 AM to 2 PM, or 12 AM to",
        "3 AM, Pacific Standard Time.",
        "Good luck to you, alright?"
      ])
      |> close()
    end
  end

  defp swordman_test_pages(ctx) do
    ctx
    |> ticket_greeting()
    |> next()
    |> gatan([
      "Ledrion wanted me to give",
      "a little test if any Swordman",
      "Class guys brought me a ticket,",
      "and were working with a group.",
      "Ready? Increasing your Base",
      "Level will be my test for you."
    ])
    |> next()
  end

  defp take_ticket(ctx, ticket, {skipped, one_level, two_levels, three_levels}, closing \\ nil) do
    level = base_level(ctx)

    cond do
      level > 94 ->
        ctx
        |> gatan([
          "Actually, you're already",
          "pretty strong. I don't feel",
          "like doing much work either,",
          "so we'll just say that you",
          "finished my test, alright?",
          "Just don't tell anyone!"
        ])
        |> next()
        |> delitem(ticket, 1)
        |> set_char_var(:party_relay, skipped)
        |> gatan([
          "Hold on a second...",
          "I'm supposed to tell",
          "you something... Give",
          "me a minute, will you?"
        ])
        |> close()

      level > 79 ->
        ctx
        |> gatan(pretty_strong(1))
        |> assign_trial(ticket, one_level, nil)

      level > 59 ->
        ctx
        |> gatan(pretty_strong(2))
        |> assign_trial(ticket, two_levels, nil)

      level > 49 ->
        ctx
        |> gatan(little_stronger())
        |> assign_trial(ticket, three_levels, nil)

      true ->
        ctx
        |> gatan(little_stronger())
        |> assign_trial(ticket, three_levels, closing)
    end
  end

  defp assign_trial(ctx, ticket, relay, closing) do
    ctx =
      ctx
      |> next()
      |> delitem(ticket, 1)
      |> set_char_var(:party_relay, relay)

    ctx = set_char_var(ctx, :party_relay_lv, base_level(ctx))

    case closing do
      :keep_ticket ->
        ctx
        |> gatan(["I'll keep your ticket.", "When you're finished, please come back."])
        |> close()

      nil ->
        ctx
        |> gatan([
          "I'll go ahead and take",
          "your ticket now. Come",
          "back after you finish what",
          "I've asked, and then we can",
          "move on to the next part."
        ])
        |> close()
    end
  end

  defp pretty_strong(levels) do
    [
      "You're pretty strong,",
      "but it wouldn't kill",
      "you to gain #{levels} more",
      "#{base_levels(levels)}. Go ahead",
      "and do that, alright?"
    ]
  end

  defp little_stronger do
    [
      "You know, you'd probably",
      "benefit from being just",
      "a little bit stronger. Now",
      "go out and gain 3 Base",
      "Levels for me, okay?"
    ]
  end

  defp ticket_greeting(ctx) do
    gatan(ctx, [
      "Oh, um... Is that...?",
      "That's a ticket from",
      "Ledrion, huh? (^666666Nuts! I've",
      "got to work now?^000000) It's nice",
      "to meet you. I'm Gatan."
    ])
  end

  defp level_test_page(ctx) do
    ctx
    |> gatan([
      "Well, now I've got a little",
      "test for you. You ready?",
      "Your objective is to gain",
      "more levels! Let's see...",
      "What would be fair?"
    ])
    |> next()
  end

  defp off_shift(ctx) do
    ctx
    |> gatan([
      "Oh, um... Is that...?",
      "That's a ticket from",
      "Ledrion, huh? It's nice",
      "to meet you. I'm Gatan."
    ])
    |> next()
    |> gatan([
      "I'm not on shift right",
      "now, though: even I need",
      "to take some off time to",
      "avoid getting swamped with",
      "work. Come back to me during",
      "my work hours, alright?"
    ])
    |> next()
  end

  defp lunch_and_midnight_hours(ctx) do
    gatan(ctx, [
      "Now I work three hours",
      "just before I have lunch,",
      "and three hours around",
      "midnight. Go ahead and",
      "look me up around those",
      "times. A bit confusing, I know~"
    ])
  end

  defp next_instructions do
    [
      "Let me find your next--I swore",
      "I left it around somewhere--",
      "and I'll give you your next set",
      "of instructions. Hang on..."
    ]
  end

  defp see_you_around(ctx) do
    ctx
    |> gatan(["Alright, get that done.", "I'll see you around."])
    |> close()
  end

  defp reward(ctx, relay, items) do
    ctx = set_char_var(ctx, :party_relay, relay)
    ctx = Enum.reduce(items, ctx, fn {item, amount}, ctx -> give_item(ctx, item, amount) end)
    {ctx, _} = FPartyrelayExp.call(ctx, [])
    ctx
  end

  defp gatan(ctx, lines), do: Enum.reduce(lines, mes(ctx, "[Gatan]"), &mes(&2, &1))

  defp job?(ctx, job), do: Rathena.job_id(base_class(ctx)) == Rathena.job_id(job)

  defp between?(hour, from, to), do: hour >= from and hour < to

  defp base_levels(1), do: "Base Level"
  defp base_levels(_), do: "Base Levels"
end
