defmodule Aesir.ZoneServer.Content.Npc.Quests.Partyrelay.Ledrion do
  @moduledoc """
  Ledrion organizes a party relay that rewards cooperation between guild members.

  ## Behavior

  - Invites a level 40 party leader with a guild and at least six party members to begin.
  - Hands out the first ticket for a Swordman to deliver to Gatan.
  - Exchanges the fourth and eighth tickets for rewards and the next relay tickets.
  - Awards the final reward and resets the relay when the leader brings the last ticket.

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
        x: 103,
        y: 113,
        dir: 3,
        sprite: 109,
        name: "Ledrion",
        scope: :shared,
        unique_name: "RelayLedrion"
      },
      %{
        map: "comodo",
        x: 71,
        y: 137,
        dir: 3,
        sprite: 109,
        name: "Ledrion",
        scope: :shared,
        unique_name: "Ledrion#comodo"
      },
      %{
        map: "einbroch",
        x: 107,
        y: 93,
        dir: 3,
        sprite: 109,
        name: "Ledrion",
        scope: :shared,
        unique_name: "Ledrion#einbroch"
      },
      %{
        map: "hugel",
        x: 102,
        y: 130,
        dir: 3,
        sprite: 109,
        name: "Ledrion",
        scope: :shared,
        unique_name: "Ledrion#hugel"
      },
      %{
        map: "rachel",
        x: 215,
        y: 71,
        dir: 3,
        sprite: 109,
        name: "Ledrion",
        scope: :shared,
        unique_name: "Ledrion#rachel"
      },
      %{
        map: "veins",
        x: 274,
        y: 188,
        dir: 5,
        sprite: 109,
        name: "Ledrion",
        scope: :shared,
        unique_name: "Ledrion#veins"
      }
    ]

  import Aesir.ZoneServer.Script.Dsl, warn: false

  alias Aesir.ZoneServer.Content.Npc.Functions.FPartyrelayExp
  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, _} = getpartymember(ctx, getcharid(ctx, 1))
    party_member_count = get_server_temp_var(ctx, "partymembercount", 0)
    party_leader = party_leader?(ctx)

    cond do
      checkweight(ctx, [{907, 300}]) == 0 ->
        overweight(ctx)

      count_item(ctx, 7731) > 0 or count_item(ctx, 7732) > 0 or count_item(ctx, 7735) > 0 or
        count_item(ctx, 7736) > 0 or count_item(ctx, 7739) > 0 or count_item(ctx, 7740) > 0 ->
        wrong_ticket(ctx)

      true ->
        relay_progress(ctx, party_leader, party_member_count)
    end
  end

  defp relay_progress(ctx, party_leader, party_member_count) do
    cond do
      count_item(ctx, 7741) > 0 and party_ready?(ctx, party_leader, party_member_count) ->
        finish_relay(ctx)

      count_item(ctx, 7741) > 0 ->
        bring_party(ctx)

      get_char_var(ctx, :party_relay, 0) == 23 ->
        remind_swordman_or_mage(ctx)

      count_item(ctx, 7737) > 0 and party_ready?(ctx, party_leader, party_member_count) ->
        reward_eighth_ticket(ctx)

      count_item(ctx, 7737) > 0 ->
        bring_party(ctx)

      get_char_var(ctx, :party_relay, 0) == 12 ->
        remind_mage(ctx)

      count_item(ctx, 7733) > 0 and party_ready?(ctx, party_leader, party_member_count) ->
        reward_fourth_ticket(ctx)

      count_item(ctx, 7733) > 0 ->
        bring_party(ctx)

      true ->
        relay_start(ctx, party_leader, party_member_count)
    end
  end

  defp relay_start(ctx, party_leader, party_member_count) do
    cond do
      get_char_var(ctx, :party_relay, 0) == 2 ->
        await_relay(ctx)

      base_level(ctx) > 39 and party_ready?(ctx, party_leader, party_member_count) and
          get_char_var(ctx, :party_relay, 0) == 1 ->
        start_relay(ctx)

      party_ready?(ctx, party_leader, party_member_count) and
          get_char_var(ctx, :party_relay, 0) > 0 ->
        advise_leader(ctx)

      party_leader == 0 and getcharid(ctx, 2) > 0 ->
        require_leader(ctx)

      true ->
        invite(ctx, party_leader, party_member_count)
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
    |> mes("[Ledrion]")
    |> mes("Hm? I'm afraid that you've")
    |> mes("misunderstood me earlier...")
    |> mes("You're not ready to see")
    |> mes("me until you bring enough")
    |> mes("of your group members with you.")
    |> close()
  end

  defp bring_party(ctx) do
    ctx
    |> mes("[Ledrion]")
    |> mes("Hm? Why aren't your")
    |> mes("comrades with you?")
    |> mes("You must bring your")
    |> mes("group members here to")
    |> mes("proceed with these trials.")
    |> close()
  end

  defp remind_swordman_or_mage(ctx) do
    ctx
    |> mes("[Ledrion]")
    |> mes("Aren't you supposed to")
    |> mes("ask one a Swordman or")
    |> mes("Mage Class member of ")
    |> mes("your group to bring a ticket")
    |> mes("over to Gatan right now?")
    |> close()
  end

  defp remind_mage(ctx) do
    ctx
    |> mes("[Ledrion]")
    |> mes("Hm? Aren't you supposed to")
    |> mes("ask a Mage Class character")
    |> mes("in your group to deliver")
    |> mes("a ticket to Gatan?")
    |> close()
  end

  defp await_relay(ctx) do
    ctx
    |> mes("[Ledrion]")
    |> mes("You didn't finish what")
    |> mes("I asked you to do, did you?")
    |> mes("It's not time for you to")
    |> mes("come to me, not yet.")
    |> close()
  end

  defp start_relay(ctx) do
    ctx
    |> mes("[Ledrion]")
    |> mes("As I mentioned earlier,")
    |> mes("I'm challenging guild")
    |> mes("parties with missions")
    |> mes("that will require ")
    |> mes("cooperation between")
    |> mes("the group members.")
    |> next()
    |> mes("[Ledrion]")
    |> mes("These challenges are")
    |> mes("something of a relay")
    |> mes("race, where we'll ask")
    |> mes("for an item to be passed")
    |> mes("to a member of a specific")
    |> mes("Class to deliver for us.")
    |> next()
    |> mes("[Ledrion]")
    |> mes("Of course, we, the")
    |> mes("administrators of this")
    |> mes("test, might add our own")
    |> mes("little challenges here and")
    |> mes("there to see just how")
    |> mes("capable your group is.")
    |> next()
    |> mes("[Ledrion]")
    |> mes("Why don't you give it")
    |> mes("a shot? You won't lose")
    |> mes("anything by trying our")
    |> mes("test. I guarantee that")
    |> mes("you'll benefit from")
    |> mes("our little exercise.")
    |> next()
    |> mes("[Ledrion]")
    |> mes("Heh! Let's start with you!")
    |> mes("Here, take this ticket, and")
    |> mes("give it to a Swordman Class")
    |> mes("member of your guild, and")
    |> mes("ask him to bring it to Gatan.")
    |> mes("The relay has started~")
    |> next()
    |> set_char_var(:party_relay, 2)
    |> give_item(7730, 1)
    |> mes("[Ledrion]")
    |> mes("Now, since you're the")
    |> mes("one that started the relay,")
    |> mes("you'll have to come back")
    |> mes("to me later on. Don't")
    |> mes("worry, we'll let you know")
    |> mes("once the time is right.")
    |> close()
  end

  defp advise_leader(ctx) do
    ctx
    |> mes("[Ledrion]")
    |> mes("As leader of your")
    |> mes("Party, you should")
    |> mes("always think of what")
    |> mes("would be best for all")
    |> mes("of your partners.")
    |> close()
  end

  defp require_leader(ctx) do
    ctx
    |> mes("[Ledrion]")
    |> mes("I'm sorry, but there's")
    |> mes("nothing I can really offer")
    |> mes("you... Unless you formed")
    |> mes("a Party and became its")
    |> mes("leader, there's absolutely")
    |> mes("nothing I can do for you...")
    |> close()
  end

  defp finish_relay(ctx) do
    ctx =
      ctx
      |> mes("[Ledrion]")
      |> mes("Ah, you've brought the")
      |> mes("last ticket from Rospii.")
      |> mes("Now I'm convinced that")
      |> mes("you and your group really")
      |> mes("work well together. Good")
      |> mes("job on passing the trials!")
      |> next()
      |> mes("[Ledrion]")
      |> mes("Your group must truly")
      |> mes("understand the value of")
      |> mes("teamwork. And thanks to")
      |> mes("you, I've won the bet! Er, but")
      |> mes("what's more important is you")
      |> mes("proving my faith in you guys.")
      |> next()
      |> mes("[Ledrion]")
      |> mes("I'm really proud of")
      |> mes("you guys for your great")
      |> mes("accomplishment. Here...")
      |> mes("You deserve a real reward!")
      |> next()

    present = Enum.random(1..7)

    ctx
    |> delitem(7741, 1)
    |> set_char_var(:party_relay, 0)
    |> give_item(644, 6)
    |> give_item(603, 3)
    |> final_prize(present)
    |> relay_exp()
    |> mes("[Ledrion]")
    |> mes("Well, I hope you like it!")
    |> mes("If you can't use it, then")
    |> mes("why don't you share it with")
    |> mes("someone in your guild? Feel")
    |> mes("free to come back if you want")
    |> mes("to try my trials again, okay?")
    |> next()
    |> mes("[Ledrion]")
    |> mes("Once again, I'd like to")
    |> mes("thank you. I'm not sure")
    |> mes("if we'll ever meet again,")
    |> mes("but I'll be praying for you as")
    |> mes("you go on your adventures.")
    |> close()
  end

  defp reward_eighth_ticket(ctx) do
    ctx =
      ctx
      |> mes("[Ledrion]")
      |> mes("Great, you've brought")
      |> mes("me the eighth ticket from")
      |> mes("Lospii. Your group must")
      |> mes("work pretty well together,")
      |> mes("eh? It usually isn't easy to")
      |> mes("gather people like that...")
      |> next()
      |> mes("[Ledrion]")
      |> mes("Please keep up the good")
      |> mes("work until you finish all")
      |> mes("of the trials, okay? Here's")
      |> mes("a little reward for your")
      |> mes("effort thus far, and the")
      |> mes("nineth ticket for your guild.")
      |> delitem(7737, 1)
      |> set_char_var(:party_relay, 23)
      |> give_item(603, 3)
      |> give_item(617, 1)
      |> give_item(7738, 1)
      |> relay_exp()

    ctx
    |> next()
    |> mes("[Ledrion]")
    |> mes("Please give that ticket")
    |> mes("to someone in your guild")
    |> mes("that's a Swordman or Mage")
    |> mes("Class character, and tell")
    |> mes("him to deliver it to Gatan.")
    |> mes("Okay? I'll be seeing you.")
    |> close()
  end

  defp reward_fourth_ticket(ctx) do
    ctx
    |> mes("[Ledrion]")
    |> mes("I see that you've brought")
    |> mes("me the fourth ticket from")
    |> mes("Lospii. Good work, good work.")
    |> mes("Please hang in there, and")
    |> mes("finish all the trials we've")
    |> mes("set before you guys, alright?")
    |> next()
    |> mes("[Ledrion]")
    |> mes("Here's a little something")
    |> mes("to reward you for your")
    |> mes("efforts for now. Now, please")
    |> mes("give this ticket to a Mage")
    |> mes("Class character, and tell")
    |> mes("him to bring it to Gatan.")
    |> delitem(7733, 1)
    |> set_char_var(:party_relay, 12)
    |> give_item(644, 3)
    |> give_item(603, 1)
    |> give_item(7734, 1)
    |> relay_exp()
    |> close()
  end

  defp relay_exp(ctx) do
    {ctx, _} = FPartyrelayExp.call(ctx, [])
    ctx
  end

  defp final_prize(ctx, 2), do: give_item(ctx, 1365, 1)
  defp final_prize(ctx, 4), do: give_item(ctx, 1367, 1)
  defp final_prize(ctx, 6), do: give_item(ctx, 1527, 1)
  defp final_prize(ctx, _present), do: give_item(ctx, 617, 3)

  defp invite(ctx, party_leader, party_member_count) do
    {ctx, choice} =
      ctx
      |> mes("[Ledrion]")
      |> mes("Ah, pleased to make your")
      |> mes("acquaintance, adventurer.")
      |> mes("I am Ledrion, a man of great")
      |> mes("intelligence, mystery, and")
      |> mes("most importantly, wealth.")
      |> mes("Yes, I'm a philanthropist.")
      |> next()
      |> mes("[Ledrion]")
      |> mes("I'm always working to make")
      |> mes("a meaningful contribution")
      |> mes("to all of Rune-Midgarts, which")
      |> mes("brings me to why I am here.")
      |> mes("There are many adventurers like you, but we have a problem.")
      |> next()
      |> mes("[Ledrion]")
      |> mes("So many adventurers have")
      |> mes("chosen the ways of greed,")
      |> mes("and have forgotten how to")
      |> mes("work well together with their")
      |> mes("colleagues. Such selfishness")
      |> mes("sickens me to no end! Ugh!")
      |> next()
      |> mes("[Ledrion]")
      |> mes("I may not be an adventurer,")
      |> mes("but I have the money to do")
      |> mes("something. I am hosting")
      |> mes("my own little challenge")
      |> mes("to adventurers to encourage")
      |> mes("camaraderie and teamwork.")
      |> next()
      |> mes("[Ledrion]")
      |> mes("Please, I invite you to")
      |> mes("give it a try! Allow me to")
      |> mes("state some of my conditions.")
      |> mes("Firstly, you must be part of")
      |> mes("a group of 6 or more members,")
      |> mes("such as a Party or a Guild.")
      |> next()
      |> mes("[Ledrion]")
      |> mes("Secondly, only the leader")
      |> mes("of the group can begin the")
      |> mes("first part of my challenge.")
      |> mes("If you are not the leader,")
      |> mes("let him know that he should")
      |> mes("speak to me for the challenge.")
      |> next()
      |> mes("[Ledrion]")
      |> mes("Thirdly, you must have a")
      |> mes("Swordman Class, Mage Class,")
      |> mes("Acolyte Class, Archer Class,")
      |> mes("Thief Class, and Merchant")
      |> mes("Class character to complete")
      |> mes("the challenges you'll receive.")
      |> next()
      |> mes("[Ledrion]")
      |> mes("Transcended characters")
      |> mes("are good too. Fourthly, all")
      |> mes("group members must be")
      |> mes("at least Base Level 40.")
      |> mes("Everything else, well,")
      |> mes("you'll learn along the way.")
      |> next()
      |> mes("[Ledrion]")
      |> mes("Don't fret, I won't have you")
      |> mes("jumping through hoops for")
      |> mes("no reason at all. I'll provide")
      |> mes("plenty of rewards as an")
      |> mes("incentive for your group.")
      |> mes("Would you like to participate?")
      |> next()
      |> select(["Sure!", "No."])

    case choice do
      1 -> accept_challenge(ctx, party_leader, party_member_count)
      2 -> decline_challenge(ctx)
      _ -> ctx
    end
  end

  defp accept_challenge(ctx, party_leader, party_member_count) do
    if base_level(ctx) > 39 and party_ready?(ctx, party_leader, party_member_count) do
      ctx
      |> mes("[Ledrion]")
      |> mes("Great! Let's see...")
      |> mes("Well, you meet all the")
      |> mes("requirements. It looks")
      |> mes("like I'll win the bet! Er, let")
      |> mes("me give you your first")
      |> mes("set of instructions.")
      |> next()
      |> set_char_var(:party_relay, 1)
      |> mes("[Ledrion]")
      |> mes("Just--^666666*Cough!*^000000")
      |> mes("Lemme clear my")
      |> mes("throat for a second...")
      |> close()
    else
      ctx
      |> mes("[Ledrion]")
      |> mes("That's great! Still,")
      |> mes("you're not ready to tackle")
      |> mes("my little challenge until")
      |> mes("you fulfill all of my")
      |> mes("conditions. Come back")
      |> mes("once you do that, alright?")
      |> close()
    end
  end

  defp decline_challenge(ctx) do
    ctx
    |> mes("[Ledrion]")
    |> mes("Really? Trust me, this")
    |> mes("little challenge will be")
    |> mes("worthwhile for you, and it")
    |> mes("would bring a greater sense")
    |> mes("of solidarity and teamwork")
    |> mes("to Rune-Midgarts. It's win-win!")
    |> close()
  end

  defp party_ready?(ctx, party_leader, party_member_count) do
    party_leader == 1 and getcharid(ctx, 2) > 0 and party_member_count > 5
  end
end
