defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.Cavitar do
  @moduledoc """
  Cavitar is an Einbech miner raising zeny to treat his wife, injured in a tunnel collapse.

  ## Behavior

  - Tells adventurers below base level 40 about the tunnel cave-ins.
  - Accepts a 1,000 zeny donation, then offers to trade an Oridecon for 40 Large Jellopy,
    10 Emveretarcon, 3 Coal and 10 Zargon, or gives a Phracon if the trade is declined.
  - Once enough adventurers have helped, a donation has a one in three chance of being
    rewarded with a random rare ore instead.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - MasterOfMuppets
    - Lupus
    - KarLaeda
    - SinSloth
    - L0ne_W0lf
    - Yommy
    - Paradox924X
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "einbech", x: 97, y: 167, dir: 5, sprite: 847, name: "Cavitar", scope: :shared}
    ]

  @coal 1003
  @emveretarcon 1011
  @zargon 912
  @large_jellopy 7126
  @ores [7290, 7291, 7293, 7294, 7295, 7296, 7289]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :ein_gear1, 0) do
      2 -> wife_recovered(ctx)
      1 -> check_trade(ctx)
      _ -> greet(ctx)
    end
  end

  defp wife_recovered(ctx) do
    ctx
    |> mes("[Cavitar]")
    |> mes("It's been a long")
    |> mes("time, my friend. With")
    |> mes("your help, my wife has")
    |> mes("gotten much better.")
    |> next()
    |> mes("[Cavitar]")
    |> mes("Once again, I want to")
    |> mes("thank you for what you've")
    |> mes("done for me. Please drop")
    |> mes("by anytime whenever you")
    |> mes("come visit my town.")
    |> close()
  end

  defp check_trade(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Cavitar]")
      |> mes("Oh, welcome.")
      |> mes("So did you bring")
      |> mes("everything that")
      |> mes("I've asked you?")
      |> next()
      |> select(["Yes.", "No, not yet."])

    case choice do
      1 ->
        if trade_items?(ctx), do: trade_oridecon(ctx), else: missing_items(ctx)

      2 ->
        ctx
        |> mes("[Cavitar]")
        |> mes("Oh, alright.")
        |> mes("Let me remind")
        |> mes("you of what you")
        |> mes("need to trade for")
        |> mes("1 Oridecon in")
        |> mes("case you've forgotten.")
        |> next()
        |> mes("[Cavitar]")
        |> mes("40 Large Jellopy,")
        |> mes("10 Emveretarcon,")
        |> mes("3 Coal and")
        |> mes("10 Zargon.")
        |> mes("Come back")
        |> mes("whenever you're ready.")
        |> close()

      _ ->
        ctx
    end
  end

  defp trade_items?(ctx) do
    count_item(ctx, @emveretarcon) > 9 and count_item(ctx, @coal) > 2 and
      count_item(ctx, @zargon) > 9 and count_item(ctx, @large_jellopy) > 39
  end

  defp trade_oridecon(ctx) do
    ctx =
      ctx
      |> mes("[Cavitar]")
      |> mes("Let me check the items")
      |> mes("that you brought before")
      |> mes("I give you an Oridecon.")
      |> next()

    if max_weight(ctx) - weight(ctx) > 2399 do
      ctx
      |> mes("[Cavitar]")
      |> mes("Good, you brought")
      |> mes("everything! Now let me")
      |> mes("give you this Oridecon.")
      |> mes("I'm sorry that I can't offer")
      |> mes("you much more than this.")
      |> next()
      |> mes("[Cavitar]")
      |> mes("Alright then,")
      |> mes("adventurer. I hope")
      |> mes("you travel in safety.")
      |> delitem(@coal, 3)
      |> delitem(@large_jellopy, 40)
      |> delitem(@emveretarcon, 10)
      |> delitem(@zargon, 10)
      |> set_char_var(:ein_gear1, 0)
      |> give_item(615, 1)
      |> close()
    else
      overweight(ctx)
    end
  end

  defp missing_items(ctx) do
    ctx
    |> mes("[Cavitar]")
    |> mes("Hm...?")
    |> mes("You're missing some")
    |> mes("things. Let me tell you")
    |> mes("what you need to bring")
    |> mes("once again so that I can")
    |> mes("give you 1 Oridecon.")
    |> next()
    |> mes("[Cavitar]")
    |> mes("40 Large Jellopy,")
    |> mes("10 Emveretarcon,")
    |> mes("3 Coal and")
    |> mes("10 Zargon.")
    |> mes("Please don't")
    |> mes("forget this.")
    |> close()
  end

  defp greet(ctx) do
    cond do
      base_level(ctx) < 40 ->
        ctx |> accident_story() |> close()

      zeny(ctx) < 1000 ->
        ctx
        |> mes("[Cavitar]")
        |> mes("You're...")
        |> mes("You're just as")
        |> mes("bad off as I am!")
        |> mes("I feel so sorry for you")
        |> mes("that I'd give you some")
        |> mes("zeny if I could spare it...")
        |> close()

      true ->
        plead(ctx)
    end
  end

  defp plead(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Cavitar]")
      |> mes("Hmm...?")
      |> mes("I'm sorry, but")
      |> mes("I don't think I have")
      |> mes("the luxury of chatting")
      |> mes("at the moment.")
      |> next()
      |> mes("[Cavitar]")
      |> mes("My wife was seriously")
      |> mes("injured when she was")
      |> mes("working with me in the")
      |> mes("mine when it collapsed.")
      |> mes("It's agonizing, wondering")
      |> mes("if she'll be okay or not.")
      |> next()
      |> mes("[Cavitar]")
      |> mes("Luckily no one")
      |> mes("was killed, but my")
      |> mes("wife is... ^333333*S-Sob*^000000")
      |> mes("I'm sorry, but I need")
      |> mes("to be alone right now...")
      |> next()
      |> select(["I can help you.", "Okay...", "An accident?"])

    case choice do
      1 ->
        ask_for_help(ctx)

      2 ->
        ctx
        |> mes("[Cavitar]")
        |> mes("You're...")
        |> mes("You're heartless!")
        |> mes("^666666*Sob...*^000000")
        |> mes("Can't you see that I'm")
        |> mes("poor and need help?!")
        |> close()

      3 ->
        ctx |> accident_story() |> close()

      _ ->
        ctx
    end
  end

  defp ask_for_help(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Cavitar]")
      |> mes("Are you serious?!")
      |> mes("Thank you, thank you so much!")
      |> mes("A-as you can see, I'm not doing")
      |> mes("so well financially. But I've got to get my wife to a hospital.")
      |> next()
      |> mes("[Cavitar]")
      |> mes("And since I've got to")
      |> mes("take of her myself,")
      |> mes("I haven't been able to work.")
      |> mes("I don't know what I should do.")
      |> next()
      |> select(["Then how can I help?"])

    {ctx, choice} =
      ctx
      |> mes("[Cavitar]")
      |> mes("Well, to be frank,")
      |> mes("I'm in dire need of zeny.")
      |> mes("It costs 1,000 zeny to cover")
      |> mes("her medical expenses and")
      |> mes("food for just one day.")
      |> next()
      |> select(["Help Him.", "Quit."])

    case choice do
      1 ->
        donate(ctx)

      2 ->
        ctx
        |> mes("[Cavitar]")
        |> mes("I understand.")
        |> mes("I'm sorry that I've")
        |> mes("asked so much of you.")
        |> mes("But please understand")
        |> mes("that I'm desperate...")
        |> close()

      _ ->
        ctx
    end
  end

  defp donate(ctx) do
    if checkweight(ctx, [{908, 10}]) == 0 do
      overweight(ctx)
    else
      ctx =
        ctx
        |> mes("[Cavitar]")
        |> mes("Oh...!")
        |> mes("Thank you, you")
        |> mes("can't imagine how")
        |> mes("grateful I am! I never")
        |> mes("believed that I'd meet")
        |> mes("someone as kind as you.")
        |> next()

      cond do
        get_server_var(ctx, "ein_amano", 0) != 60 -> propose_trade(ctx, true)
        Enum.random(1..3) == 1 -> reward_ore(ctx)
        true -> propose_trade(ctx, false)
      end
    end
  end

  defp reward_ore(ctx) do
    ctx
    |> mes("[Cavitar]")
    |> mes("Other adventurers have")
    |> mes("also been helping me, so")
    |> mes("with all of your help, my wife")
    |> mes("has been getting better.")
    |> next()
    |> mes("[Cavitar]")
    |> mes("I would like to give")
    |> mes("you a small present")
    |> mes("as a token of my gratitute.")
    |> mes("If you would, please take this.")
    |> pay_zeny(1000)
    |> set_char_var(:ein_gear1, 2)
    |> give_item(Enum.random(@ores), 1)
    |> next()
    |> mes("[Cavitar]")
    |> mes("I've been keeping these")
    |> mes("kinds of metals since I was")
    |> mes("sure they'd be more useful")
    |> mes("to someone other than me.")
    |> mes("Hopefully, you'll find this ore")
    |> mes("useful in one way or another.")
    |> close()
  end

  defp propose_trade(ctx, count_helper?) do
    {ctx, choice} =
      ctx
      |> mes("[Cavitar]")
      |> mes("If I were still")
      |> mes("working, I'd try my")
      |> mes("best to pay you back.")
      |> mes("But my current situation")
      |> mes("doesn't really allow it...")
      |> next()
      |> mes("[Cavitar]")
      |> mes("Still, I'd be happy")
      |> mes("to trade you 1 Oridecon")
      |> mes("if you can bring me some")
      |> mes("items. How does that sound?")
      |> next()
      |> mes("[Cavitar]")
      |> mes("Would you bring me")
      |> mes("40 Large Jellopy,")
      |> mes("10 Emveretarcon,")
      |> mes("3 Coal and")
      |> mes("10 Zargon?")
      |> next()
      |> select(["Sure~!", "No, thanks."])

    case choice do
      1 ->
        ctx
        |> pay_zeny(1000)
        |> count_helper(count_helper?)
        |> set_char_var(:ein_gear1, 1)
        |> mes("[Cavitar]")
        |> mes("Great...!")
        |> mes("Now I need to go")
        |> mes("take care of my wife.")
        |> mes("Come back when you")
        |> mes("gather everything I've")
        |> mes("asked you to bring.")
        |> close()

      2 ->
        ctx
        |> mes("[Cavitar]")
        |> mes("I see.")
        |> mes("Well, I understand")
        |> mes("that adventurers don't")
        |> mes("stay in one place for")
        |> mes("very long. Once again,")
        |> mes("thank you for your help.")
        |> next()
        |> mes("[Cavitar]")
        |> mes("But please take")
        |> mes("this small gift")
        |> mes("as a token of")
        |> mes("my gratitude.")
        |> pay_zeny(1000)
        |> give_item(1010, 1)
        |> close()

      _ ->
        ctx
    end
  end

  defp count_helper(ctx, true),
    do: set_server_var(ctx, "ein_amano", get_server_var(ctx, "ein_amano", 0) + 1)

  defp count_helper(ctx, false), do: ctx

  defp overweight(ctx) do
    ctx
    |> mes("[Cavitar]")
    |> mes("Hmmm, it seems you're")
    |> mes("carrying too many things")
    |> mes("with you. Shouldn't you")
    |> mes("store some of your items")
    |> mes("in Kafra Storage first?")
    |> close()
  end

  defp accident_story(ctx) do
    ctx
    |> mes("[Cavitar]")
    |> mes("Recently, we've had some")
    |> mes("tunnel cave-ins which resulted")
    |> mes("in miner casualties. We're having")
    |> mes("a harder time working in the")
    |> mes("mines now that we're even")
    |> mes("lower on manpower.")
    |> next()
    |> mes("[Cavitar]")
    |> mes("What's really suspicious")
    |> mes("is that it seems something")
    |> mes("has been making the tunnels")
    |> mes("collapse on purpose. Some of")
    |> mes("us believe it's because we've")
    |> mes("angered the master of the cave.")
    |> next()
    |> mes("[Cavitar]")
    |> mes("The tunnel accident")
    |> mes("is still fresh in my mind.")
    |> mes("It seems that there are")
    |> mes("more ^FF0000Cave Master^000000 sightings")
    |> mes("when the tunnels started")
    |> mes("to inexplicably collapse.")
    |> next()
    |> mes("[Cavitar]")
    |> mes("I was off duty when")
    |> mes("the accident happened.")
    |> mes("Still, I hear the only survivor")
    |> mes("went crazy and disappeared")
    |> mes("somewhere. The poor bastard...")
  end
end
