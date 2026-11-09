defmodule Aesir.ZoneServer.Content.Npc.Quests.Partyrelay.Bafhail do
  @moduledoc """
  Bafhail administers timed item-collection legs of the party relay quest.

  ## Behavior

  - Accepts ticket 7731 from Thief classes above level 39 for steps 7/8, during
    08:00–11:00 or from 21:00 onward; issues ticket 7732 for an Archer.
  - Accepts ticket 7735 from Acolyte classes for steps 18/19, during
    14:00–17:00 or 18:00–21:00; issues ticket 7736 for a Merchant.
  - Accepts ticket 7739 from Thief or Acolyte classes for step 29, during
    00:00–03:00 or 11:00–14:00; issues ticket 7740 for an Archer or Merchant.
  - Requires the assigned materials during the collection windows. Step 8 awards
    two Yggdrasil Berries and relay EXP; steps 18/19 award two Yggdrasil Leaves
    and relay EXP; step 29 awards both and relay EXP. Step 7 awards only a ticket.

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
        x: 204,
        y: 221,
        dir: 3,
        sprite: 731,
        name: "Bafhail",
        scope: :shared,
        unique_name: "RelayBafhail"
      },
      %{
        map: "comodo",
        x: 152,
        y: 184,
        dir: 3,
        sprite: 731,
        name: "Bafhail",
        scope: :shared,
        unique_name: "Bafhail#comodo"
      },
      %{
        map: "einbroch",
        x: 251,
        y: 178,
        dir: 3,
        sprite: 731,
        name: "Bafhail",
        scope: :shared,
        unique_name: "Bafhail#einbroch"
      },
      %{
        map: "hugel",
        x: 55,
        y: 200,
        dir: 3,
        sprite: 731,
        name: "Bafhail",
        scope: :shared,
        unique_name: "Bafhail#hugel"
      },
      %{
        map: "rachel",
        x: 245,
        y: 132,
        dir: 3,
        sprite: 731,
        name: "Bafhail",
        scope: :shared,
        unique_name: "Bafhail#rachel"
      },
      %{
        map: "veins",
        x: 202,
        y: 235,
        dir: 3,
        sprite: 731,
        name: "Bafhail",
        scope: :shared,
        unique_name: "Bafhail#veins"
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

      count_item(ctx, 7730) > 0 or count_item(ctx, 7733) > 0 or count_item(ctx, 7734) > 0 or
        count_item(ctx, 7737) > 0 or count_item(ctx, 7738) > 0 or count_item(ctx, 7741) > 0 ->
        wrong_ticket(ctx)

      true ->
        final_relay(ctx, gettime(ctx, 3))
    end
  end

  defp final_relay(ctx, hour) do
    relay = get_char_var(ctx, :party_relay, 0)

    cond do
      relay == 30 ->
        ticket_reminder(ctx)

      relay == 29 and (between?(hour, 0, 3) or between?(hour, 11, 14)) and
        count_item(ctx, 1012) > 19 and count_item(ctx, 1048) > 19 and count_item(ctx, 7003) > 19 ->
        complete_final(ctx)

      relay == 29 ->
        remind_final(ctx)

      count_item(ctx, 7739) > 0 and between?(hour, 11, 14) and
          (job?(ctx, :thief) or job?(ctx, :acolyte)) ->
        accept_final_midday(ctx)

      count_item(ctx, 7739) > 0 and between?(hour, 0, 3) and
          (job?(ctx, :thief) or job?(ctx, :acolyte)) ->
        accept_final_midnight(ctx)

      count_item(ctx, 7739) > 0 and (job?(ctx, :thief) or job?(ctx, :acolyte)) ->
        wait_for_midday(ctx)

      true ->
        middle_relay(ctx, hour)
    end
  end

  defp middle_relay(ctx, hour) do
    relay = get_char_var(ctx, :party_relay, 0)
    afternoon? = between?(hour, 14, 17) or between?(hour, 18, 21)

    cond do
      relay == 20 ->
        ticket_reminder(ctx)

      relay == 19 and afternoon? and
        count_item(ctx, 1015) > 9 and count_item(ctx, 7172) > 9 and count_item(ctx, 7155) > 9 ->
        complete_tongues(ctx)

      relay == 19 ->
        remind_tongues(ctx)

      relay == 18 and afternoon? and
        count_item(ctx, 7157) > 9 and count_item(ctx, 1021) > 9 and count_item(ctx, 7101) > 9 ->
        complete_masks(ctx)

      relay == 18 ->
        remind_masks(ctx)

      count_item(ctx, 7735) > 0 and between?(hour, 14, 17) and job?(ctx, :acolyte) ->
        accept_masks(ctx)

      count_item(ctx, 7735) > 0 and between?(hour, 18, 21) and job?(ctx, :acolyte) ->
        accept_tongues(ctx)

      count_item(ctx, 7735) > 0 and job?(ctx, :acolyte) ->
        wait_for_midday(ctx)

      true ->
        first_relay(ctx, hour)
    end
  end

  defp first_relay(ctx, hour) do
    relay = get_char_var(ctx, :party_relay, 0)
    first_ticket? = count_item(ctx, 7731) > 0 and base_level(ctx) > 39

    cond do
      relay == 9 ->
        ticket_delivered(ctx)

      relay == 8 and between?(hour, 8, 11) and
        count_item(ctx, 7196) > 9 and count_item(ctx, 7184) > 9 and count_item(ctx, 920) > 9 ->
        complete_hearts_morning(ctx)

      relay == 8 and hour >= 21 and
        count_item(ctx, 7196) > 9 and count_item(ctx, 7184) > 9 and count_item(ctx, 920) > 9 ->
        complete_hearts_night(ctx)

      relay == 8 ->
        remind_hearts(ctx)

      relay == 7 and (between?(hour, 8, 11) or hour >= 21) and
        count_item(ctx, 1027) > 9 and count_item(ctx, 1040) > 9 and count_item(ctx, 1023) > 9 ->
        complete_fish(ctx)

      relay == 7 ->
        remind_fish(ctx)

      first_ticket? and between?(hour, 8, 11) and job?(ctx, :thief) ->
        accept_hearts(ctx)

      first_ticket? and hour >= 21 and job?(ctx, :thief) ->
        accept_fish(ctx)

      first_ticket? and job?(ctx, :thief) ->
        wait_for_first_relay(ctx)

      true ->
        idle(ctx)
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

  defp wrong_ticket(ctx) do
    ctx
    |> mes("[Bafhail]")
    |> mes("You must be confused...")
    |> mes("It's not time for you")
    |> mes("to see me just yet.")
    |> mes("Have you tried meeting")
    |> mes("with any of the other guys?")
    |> close()
  end

  defp ticket_reminder(ctx) do
    ctx
    |> mes("[Bafhail]")
    |> mes("Did you give that ticket")
    |> mes("to an Archer or Merchant")
    |> mes("Class member of your group?")
    |> mes("Just a reminder in case")
    |> mes("you've already forgotten.")
    |> close()
  end

  defp complete_final(ctx) do
    ctx
    |> reward_message()
    |> next()
    |> delitem(1012, 20)
    |> delitem(1048, 20)
    |> delitem(7003, 20)
    |> reward_final()
    |> final_handoff()
  end

  defp remind_final(ctx) do
    ctx
    |> mes("[Bafhail]")
    |> mes("My mission for you is")
    |> mes("to bring me some items")
    |> mes("at the right time. I'll only")
    |> mes("accept your items for 3 hours")
    |> mes("once the day starts, and for 3")
    |> mes("hours in the middle of the day.")
    |> next()
    |> mes("[Bafhail]")
    |> mes("I need")
    |> final_materials()
    |> mes("Don't forget now, alright?")
    |> close()
  end

  defp accept_final_midday(ctx) do
    ctx
    |> ticket_introduction()
    |> mes("Now, let's get to business.")
    |> next()
    |> mes("[Bafhail]")
    |> mes("My mission is")
    |> mes("for you to collect")
    |> final_materials()
    |> next()
    |> delitem(7739, 1)
    |> set_char_var(:party_relay, 29)
    |> collection_accepted()
  end

  defp accept_final_midnight(ctx) do
    ctx
    |> ticket_introduction()
    |> mes("Now, let's get to business.")
    |> next()
    |> mes("[Bafhail]")
    |> mes("My mission is")
    |> mes("for you to collect")
    |> final_materials()
    |> next()
    |> delitem(7739, 1)
    |> set_char_var(:party_relay, 29)
    |> mes("[Bafhail]")
    |> mes("Understood?")
    |> mes("Understood?")
    |> mes("Alright then, if you'll")
    |> mes("just hand me your ticket,")
    |> mes("you can start gathering")
    |> mes("those items I listed.")
    |> mes("I'll see you later~")
    |> close()
  end

  defp wait_for_midday(ctx) do
    ctx
    |> ticket_introduction()
    |> return_at_midday()
  end

  defp complete_tongues(ctx) do
    ctx
    |> reward_message()
    |> next()
    |> delitem(1015, 10)
    |> delitem(7172, 10)
    |> delitem(7155, 10)
    |> reward_acolyte()
    |> merchant_handoff()
  end

  defp remind_tongues(ctx) do
    ctx
    |> mes("[Bafhail]")
    |> mes("Remember to bring me")
    |> mes("the items I requested")
    |> mes("at the right time, during")
    |> mes("the 3 hours after noon or")
    |> mes("3 hours in the early evening.")
    |> mes("Now, I want you to bring...")
    |> next()
    |> mes("[Bafhail]")
    |> tongue_materials()
    |> mes("I'll be waiting for you here")
    |> mes("and will accept those items")
    |> mes("when the time is right.")
    |> close()
  end

  defp complete_masks(ctx) do
    ctx
    |> reward_message()
    |> next()
    |> delitem(7157, 10)
    |> delitem(1021, 10)
    |> delitem(7101, 10)
    |> reward_acolyte()
    |> merchant_handoff()
  end

  defp remind_masks(ctx) do
    ctx
    |> mes("[Bafhail]")
    |> mes("Remember that your")
    |> mes("mission from me is")
    |> mes("to collect some items,")
    |> mes("and to bring them to")
    |> mes("me at the right time.")
    |> next()
    |> mes("[Bafhail]")
    |> mes("I'll only accept your")
    |> mes("items for 3 hours after")
    |> mes("the day starts, and for")
    |> mes("3 hours during midday.")
    |> mes("These are the items")
    |> mes("that I want you to bring...")
    |> next()
    |> mes("[Bafhail]")
    |> mask_materials()
    |> mes("I'll be here waiting for")
    |> mes("you during the hours")
    |> mes("I just described, okay?")
    |> close()
  end

  defp accept_masks(ctx) do
    ctx
    |> ticket_introduction()
    |> collection_introduction()
    |> mask_materials()
    |> next()
    |> delitem(7735, 1)
    |> set_char_var(:party_relay, 18)
    |> collection_accepted()
  end

  defp accept_tongues(ctx) do
    ctx
    |> ticket_introduction()
    |> collection_introduction()
    |> tongue_materials()
    |> next()
    |> delitem(7735, 1)
    |> set_char_var(:party_relay, 19)
    |> collection_accepted()
  end

  defp ticket_delivered(ctx) do
    ctx
    |> mes("[Bafhail]")
    |> mes("Oh, did you already")
    |> mes("deliver the ticket that")
    |> mes("I gave you? If that's the")
    |> mes("case, we won't have any")
    |> mes("business with each other")
    |> mes("for a while, I suppose.")
    |> close()
  end

  defp complete_hearts_morning(ctx) do
    ctx
    |> reward_message()
    |> next()
    |> reward_hearts()
    |> archer_handoff()
  end

  defp complete_hearts_night(ctx) do
    ctx
    |> reward_message()
    |> reward_hearts()
    |> next()
    |> archer_handoff()
  end

  defp reward_hearts(ctx) do
    ctx =
      ctx
      |> delitem(7196, 10)
      |> delitem(7189, 10)
      |> delitem(920, 10)
      |> set_char_var(:party_relay, 9)
      |> give_item(7732, 1)
      |> give_item(607, 2)

    {ctx, _} = FPartyrelayExp.call(ctx, [])
    ctx
  end

  defp remind_hearts(ctx) do
    ctx
    |> mes("[Bafhail]")
    |> mes("Your mission")
    |> mes("is to bring me")
    |> heart_materials()
    |> first_relay_hours()
  end

  defp complete_fish(ctx) do
    ctx
    |> reward_message()
    |> next()
    |> delitem(1027, 10)
    |> delitem(1040, 10)
    |> delitem(1023, 10)
    |> set_char_var(:party_relay, 9)
    |> give_item(7732, 1)
    |> archer_handoff()
  end

  defp remind_fish(ctx) do
    ctx
    |> mes("[Bafhail]")
    |> mes("Your mission")
    |> mes("is to bring me")
    |> fish_materials()
    |> first_relay_hours()
  end

  defp accept_hearts(ctx) do
    ctx
    |> ticket_introduction()
    |> collection_introduction()
    |> heart_materials()
    |> next()
    |> delitem(7731, 1)
    |> set_char_var(:party_relay, 8)
    |> collection_hours_warning()
  end

  defp accept_fish(ctx) do
    ctx
    |> ticket_introduction()
    |> collection_introduction()
    |> fish_materials()
    |> next()
    |> delitem(7731, 1)
    |> set_char_var(:party_relay, 7)
    |> collection_hours_warning()
  end

  defp wait_for_first_relay(ctx) do
    ctx
    |> ticket_introduction()
    |> next()
    |> mes("[Bafhail]")
    |> mes("Would you mind coming")
    |> mes("back to me later? Now")
    |> mes("isn't the right time to")
    |> mes("talk to me. I'm available")
    |> mes("from 8 AM to 11 AM, and")
    |> mes("from 9 PM to 12 AM.")
    |> close()
  end

  defp idle(ctx) do
    ctx
    |> mes("[Bafhail]")
    |> mes("...Hm? I don't think")
    |> mes("we have any business")
    |> mes("with each other. You mind")
    |> mes("leaving me alone? I'm pretty")
    |> mes("busy administering a bunch")
    |> mes("of these missions for a friend.")
    |> next()
    |> mes("[Bafhail]")
    |> mes("If we're lucky, maybe")
    |> mes("you'll be one of those")
    |> mes("adventurers that'll carry")
    |> mes("out these fun little missions")
    |> mes("for my friend Ledrion.")
    |> close()
  end

  defp reward_message(ctx) do
    ctx
    |> mes("[Bafhail]")
    |> mes("Well, it looks like you came")
    |> mes("at the right time and brought")
    |> mes("everything I asked. Good work.")
    |> mes("Please take your next ticket")
    |> mes("and this small reward for you.")
  end

  defp ticket_introduction(ctx) do
    ctx
    |> mes("[Bafhail]")
    |> mes("Oh, isn't that ticket...?")
    |> mes("Ah, good, good. Judging")
    |> mes("from your Job, Gatan must")
    |> mes("have sent you, right? Nice")
    |> mes("to meet you, I'm Bafhail~")
  end

  defp archer_handoff(ctx) do
    ctx
    |> mes("[Bafhail]")
    |> mes("Please give that")
    |> mes("ticket to the Archer")
    |> mes("Class member of your")
    |> mes("group, and have him")
    |> mes("deliver it to Lospii, okay?")
    |> mes("Good luck on your travels~")
    |> close()
  end

  defp merchant_handoff(ctx) do
    ctx
    |> mes("[Bafhail]")
    |> mes("Do me a favor and make")
    |> mes("sure that the Merchant")
    |> mes("Class character in your")
    |> mes("group delivers that ticket")
    |> mes("to Lospii. Alright, I guess")
    |> mes("I'll see you later, then.")
    |> close()
  end

  defp final_handoff(ctx) do
    ctx
    |> mes("[Bafhail]")
    |> mes("Make sure that you give")
    |> mes("that ticket to an Archer")
    |> mes("or Merchant Class member")
    |> mes("of your group, and have him")
    |> mes("bring it to a boy named Lospii.")
    |> mes("Goodbye now, and good luck~")
    |> close()
  end

  defp collection_accepted(ctx) do
    ctx
    |> mes("[Bafhail]")
    |> mes("Understood?")
    |> mes("Alright then, if you'll")
    |> mes("just hand me your ticket,")
    |> mes("you can start gathering")
    |> mes("those items I listed.")
    |> mes("I'll see you later~")
    |> close()
  end

  defp reward_acolyte(ctx) do
    ctx =
      ctx
      |> set_char_var(:party_relay, 20)
      |> give_item(7736, 1)
      |> give_item(610, 2)

    {ctx, _} = FPartyrelayExp.call(ctx, [])
    ctx
  end

  defp reward_final(ctx) do
    ctx =
      ctx
      |> set_char_var(:party_relay, 30)
      |> give_item(7740, 1)
      |> give_item(610, 2)
      |> give_item(607, 2)

    {ctx, _} = FPartyrelayExp.call(ctx, [])
    ctx
  end

  defp final_materials(ctx) do
    ctx
    |> mes("^4D4DFF20 Frills^000000,")
    |> mes("^4D4DFF20 Anolian Skins^000000, and")
    |> mes("^4D4DFF20 Horrendous Hairs^000000.")
  end

  defp tongue_materials(ctx) do
    ctx
    |> mes("^4D4DFF10 Tongues^000000,")
    |> mes("^4D4DFF10 Leopard Claws^000000, and")
    |> mes("^4D4DFF10 Poisonous Toad Skins^000000.")
  end

  defp mask_materials(ctx) do
    ctx
    |> mes("^4D4DFF10 Dark Masks^000000,")
    |> mes("^4D4DFF10 Dokebi Horns^000000, and")
    |> mes("^4D4DFF10 PecoPeco Feathers^000000.")
  end

  defp heart_materials(ctx) do
    ctx
    |> mes("^4D4DFF10 Wooden Hearts^000000,")
    |> mes("^4D4DFF10 Wolf Claws^000000, and")
    |> mes("^4D4DFF10 Shoulder Protectors^000000")
  end

  defp fish_materials(ctx) do
    ctx
    |> mes("^4D4DFF10 Fish Tails^000000,")
    |> mes("^4D4DFF10 Porcupine Quills^000000, and")
    |> mes("^4D4DFF10 Elder Pixie's Moustaches^000000")
  end

  defp first_relay_hours(ctx) do
    ctx
    |> mes("during hours I accept items.")
    |> next()
    |> mes("[Bafhail]")
    |> mes("Remember that I only")
    |> mes("accept items from 8 AM")
    |> mes("to 11 AM, and from 9 PM")
    |> mes("to 12 AM. That's Pacific")
    |> mes("Standard Time. Don't forget!")
    |> close()
  end

  defp return_at_midday(ctx) do
    ctx
    |> next()
    |> mes("[Bafhail]")
    |> mes("Would you mind coming ")
    |> mes("back to me later? Now")
    |> mes("isn't the right time to talk")
    |> mes("to me. I'm available for 3")
    |> mes("hours at the start of the day,")
    |> mes("and 3 hours in midday.")
    |> close()
  end

  defp collection_hours_warning(ctx) do
    ctx
    |> mes("[Bafhail]")
    |> mes("Remember that I won't")
    |> mes("accept your items, even")
    |> mes("if you have everything,")
    |> mes("if you don't come during")
    |> mes("the hours when I accept")
    |> mes("items for missions, okay?")
    |> close()
  end

  defp collection_introduction(ctx) do
    ctx
    |> next()
    |> mes("[Bafhail]")
    |> mes("Alright, let's get down")
    |> mes("to what you came for.")
    |> mes("My mission is for you to")
    |> mes("collect some items, and")
    |> mes("for you to bring them at")
    |> mes("the right time. Bring me...")
    |> next()
    |> mes("[Bafhail]")
  end

  defp job?(ctx, job), do: Rathena.job_id(base_class(ctx)) == Rathena.job_id(job)

  defp between?(hour, from, to), do: hour >= from and hour < to
end
