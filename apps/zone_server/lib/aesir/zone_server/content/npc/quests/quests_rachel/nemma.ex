defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Nemma do
  @moduledoc """
  A priestess collecting donations and guiding the sanctuary quest.

  ## Behavior

  - Accepts festival donations and awards lottery tickets.
  - Guides adventurers through the temple and requests firecrackers.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ra_temple",
        x: 116,
        y: 174,
        dir: 3,
        sprite: 920,
        name: "Nemma",
        scope: :shared,
        unique_name: "Nemma#ra_temple"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    ctx = cutin(ctx, "ra_nemma02", 2)

    cond do
      get_server_var(ctx, "rachel_donate", 0) >= 10_000 -> sanctuary(ctx)
      get_char_var(ctx, :ra_have_donated, 0) == 0 -> first_visit(ctx)
      true -> returning_donor(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp first_visit(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("ra_nemma03", 2)
      |> mes("[Priestess Nemma]")
      |> mes("Good day, adventurer.")
      |> mes("May I ask what brings")
      |> mes("you to the temple today?")
      |> next()
      |> select(["Just sight-seeing.", "I came to pray."])

    if choice == 1 do
      ctx
      |> cutin("ra_nemma01", 2)
      |> mes("[Priestess Nemma]")
      |> mes("I guess most foreigners")
      |> mes("aren't familiar with our")
      |> mes("faith, so I suppose they")
      |> mes("wouldn't come here to pray...")
      |> mes("Well, I hope you enjoy your")
      |> mes("time here, adventurer.")
      |> close()
      |> cutin("", 255)
    else
      explain_donations(ctx)
    end
  end

  defp explain_donations(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Priestess Nemma]")
      |> mes("Oh! I'm glad to see that")
      |> mes("our kind of spirituality is")
      |> mes("practiced in other countries~")
      |> mes("You know, we at the Temple of")
      |> mes("Cheshrumnir will be hosting a")
      |> mes("festival here at the temple.")
      |> next()
      |> cutin("ra_nemma01", 2)
      |> mes("[Priestess Nemma]")
      |> mes("We're accepting donations")
      |> mes("for the festival, so we'd be")
      |> mes("grateful if you could make")
      |> mes("a contribution. Regardless,")
      |> mes("we invite you to celebrate the")
      |> mes("grace of the goddess with us.")
      |> emotion(:delight)
      |> next()
      |> mes("[Priestess Nemma]")
      |> mes("There's one High Priest that")
      |> mes("disagrees with collecting money")
      |> mes("from the temple's patrons, but")
      |> mes("it's up to you if you want to")
      |> mes("give or not. If you donate, you")
      |> mes("might be able to win a prize!")
      |> next()
      |> mes("[Priestess Nemma]")
      |> mes("You can use our Lottery Tickets")
      |> mes("to win something nice from our")
      |> mes("Temple Storage. However, you")
      |> mes("donate the 50,000 zeny for each")
      |> mes("Lottery Ticket, which also happens to be the minimum donation amount.")
      |> next()
      |> cutin("ra_nemma03", 2)
      |> mes("[Priestess Nemma]")
      |> mes("The prizes that are given to")
      |> mes("donators are also randomly")
      |> mes("chosen, so I have no way of")
      |> mes("telling you what you'd get.")
      |> mes("Would you be interested")
      |> mes("in making a donation?")
      |> next()
      |> select(["No, thanks.", "Sure."])

    if choice == 1 do
      ctx
      |> cutin("ra_nemma01", 2)
      |> mes("[Priestess Nemma]")
      |> mes("I understand. Well,")
      |> mes("maybe some other time.")
      |> mes("May Freya bless you on")
      |> mes("all your journeys. May the")
      |> mes("grace of the goddess always")
      |> mes("support us in all that we do~")
      |> close()
      |> cutin("", 255)
    else
      first_donation(ctx)
    end
  end

  defp first_donation(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Priestess Nemma]")
      |> mes("Great! How much would you")
      |> mes("like to donate? We can only")
      |> mes("accept donations in increments")
      |> mes("of 50,000 zeny, and we can only")
      |> mes("accept up to 150,000 zeny at once. It's a bit complicated, I know...")
      |> next()
      |> select([
        "50,000z - 1 Lottery Ticket",
        "100,000z - 2 Lottery Ticket",
        "150,000z - 3 Lottery Ticket",
        "Cancel"
      ])

    donation_choice(ctx, choice)
  end

  defp returning_donor(ctx) do
    ctx = ctx |> cutin("ra_nemma03", 2) |> mes("[Priestess Nemma]")

    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("Oh, you're ", char_name(ctx, 0)), "!"))
      |> mes("Welcome back! I remember")
      |> mes("that you donated just a little")
      |> mes("while ago. So what brings you")
      |> mes("to the temple today, hmm?")
      |> next()
      |> select([
        "I've come to donate again.",
        "Just sight-seeing.",
        "I came to attend the service.",
        "I just wanted to see you again."
      ])

    case choice do
      1 ->
        donate_again(ctx)

      2 ->
        ctx
        |> mes("[Priestess Nemma]")
        |> mes("Oh! If you'd like some")
        |> mes("information about our temple,")
        |> mes("why don't you ask Priestess")
        |> mes("Pano at the Help Desk inside?")
        |> next()
        |> mes("[Priestess Nemma]")
        |> mes("Penno will also redeem")
        |> mes("your Lottery Tickets for")
        |> mes("prizes, although she doesn't")
        |> mes("really seem to enjoy that job.")
        |> mes("Well, anyway, she'll help")
        |> mes("you out. See you later!")
        |> finish_dialog()

      3 ->
        ctx
        |> mes("[Priestess Nemma]")
        |> mes("You're here for the")
        |> mes("service? That's great~")
        |> mes("I hope you find the sense")
        |> mes("of calm that you can only")
        |> mes("get from goddess Freya~")
        |> finish_dialog()

      4 ->
        ctx |> mes("[Priestess Nemma]") |> mes("Oh, how sweet of you~") |> finish_dialog()

      _ ->
        ctx
    end
  end

  defp donate_again(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Priestess Nemma]")
      |> mes("You've come to make another")
      |> mes("donation? Splendid! How much")
      |> mes("would you like to donate this")
      |> mes("time? Remember that we can only")
      |> mes("accept donations in increments of")
      |> mes("50,000 zeny up to 150,000 zeny.")
      |> next()
      |> select([
        "50,000z - 1 Lottery Ticket",
        "100,000z - 2 Lottery Ticket",
        "150,000z - 3 Lottery Ticket",
        "Cancel"
      ])

    donation_choice(ctx, choice)
  end

  defp donation_choice(ctx, choice) do
    case choice do
      1 ->
        donate(ctx, 1, "50,000")

      2 ->
        donate(ctx, 2, "100,000")

      3 ->
        donate(ctx, 3, "150,000")

      4 ->
        ctx
        |> cutin("ra_nemma02", 2)
        |> mes("[Priestess Nemma]")
        |> mes("I understand that it takes")
        |> mes("some thought to part with an")
        |> mes("amount of money like 50,000")
        |> mes("zeny. Even so, Freya is always")
        |> mes("protecting you, wherever you go~")
        |> finish_dialog()

      _ ->
        ctx
    end
  end

  defp donate(ctx, tickets, amount) do
    {ctx, _} = scoped_call(ctx, [tickets, amount], &donation_subroutine/2)
    finish_dialog(ctx)
  end

  defp finish_dialog(ctx) do
    ctx |> close() |> cutin("", 255)
  end

  defp sanctuary(ctx) do
    cond do
      Rathena.truthy?(:erlang.band(get_char_var(ctx, :MISC_QUEST, 0), 8192)) -> welcome(ctx)
      get_char_var(ctx, :ra_tem_q, 0) < 1 -> locked_gate(ctx)
      get_char_var(ctx, :ra_tem_q, 0) < 10 -> secret_entrance(ctx)
      get_char_var(ctx, :ra_tem_q, 0) == 10 -> gate_opened(ctx)
      get_char_var(ctx, :ra_tem_q, 0) == 11 -> target_reached(ctx)
      get_char_var(ctx, :ra_tem_q, 0) == 12 -> request_firecrackers(ctx)
      get_char_var(ctx, :ra_tem_q, 0) == 13 -> ask_firecrackers(ctx)
      true -> welcome(ctx)
    end
  end

  defp welcome(ctx) do
    ctx
    |> cutin("ra_nemma01", 2)
    |> mes("[Priestess Nemma]")
    |> mes("Welcome to our temple!")
    |> close()
    |> cutin("", 255)
  end

  defp locked_gate(ctx) do
    ctx
    |> mes("[Priestess Nemma]")
    |> mes("Hello, there!")
    |> mes("...............................")
    |> mes("Um, for some reason, the")
    |> mes("temple gate hasn't opened yet")
    |> mes("But it should be open now. Well")
    |> mes("this happens sometimes so...")
    |> next()
    |> mes("[Priestess Nemma]")
    |> mes("See, there's this auto locking")
    |> mes("system that was added to the")
    |> mes("gate when this temple was")
    |> mes("built, but now it's more of")
    |> mes("an annoyance than security.")
    |> next()
    |> mes("[Priestess Nemma]")
    |> mes("Every time someone messes")
    |> mes("with the lock, or if it breaks,")
    |> mes("we have to wait until it auto")
    |> mes("resets itself before it works")
    |> mes("again. No one can fix it")
    |> mes("really quickly, you know...")
    |> next()
    |> mes("[Priestess Nemma]")
    |> mes("^333333*Sniff*^000000 What should I do?")
    |> mes("The auto reset never takes")
    |> mes("this long, and I really need")
    |> mes("to go inside. ^333333*Sob*^000000 P-Panno!")
    |> mes("Panno, I neeeed heeeeelp~!")
    |> set_char_var(:ra_tem_q, 1)
    |> close()
    |> cutin("", 255)
  end

  defp secret_entrance(ctx) do
    ctx
    |> mes("[Priestess Nemma]")
    |> mes("If the gate's locked, then")
    |> mes("I've just got to find that")
    |> mes("secret entrance. Some kids")
    |> mes("supposedly use it to enter")
    |> mes("and play pranks in the temple,")
    |> mes("but I don't know who they are...")
    |> next()
    |> mes("[Priestess Nemma]")
    |> mes("Panno would know")
    |> mes("what to do... I think.")
    |> mes("Ooh, Panno, help me!")
    |> close()
    |> cutin("", 255)
  end

  defp gate_opened(ctx) do
    ctx = ctx |> cutin("ra_nemma04", 2) |> mes("[Priestess Nemma]")

    ctx
    |> mes(Rathena.concat(Rathena.concat("Oh, ", char_name(ctx, 0)), "!"))
    |> mes("The gate just opened and")
    |> mes("I was able to get inside")
    |> mes("the temple! ^333333*Whew*^000000 I was")
    |> mes("getting really worried")
    |> mes("about it for awhile.")
    |> next()
    |> mes("[Priestess Nemma]")
    |> mes("This is the first time that the")
    |> mes("gate locked up since Panno")
    |> mes("was assigned to her post in")
    |> mes("the temple. I thought maybe")
    |> mes("something happened and")
    |> mes("she got in trouble, you know?")
    |> next()
    |> cutin("ra_nemma02", 2)
    |> mes("[Priestess Nemma]")
    |> mes("Wait, wait...")
    |> mes("I'm outside. What if")
    |> mes("the gate locks up again?")
    |> mes("Oooh, what should I do?!")
    |> close()
    |> cutin("", 255)
  end

  defp target_reached(ctx) do
    ctx =
      ctx
      |> emotion(:delight)
      |> cutin("ra_nemma03", 2)
      |> mes("[Priestess Nemma]")

    ctx
    |> mes(Rathena.concat(Rathena.concat("Hey, ", char_name(ctx, 0)), "~!"))
    |> mes("We reached our target!")
    |> mes("Isn't that great? We're no")
    |> mes("longer asking for donations,")
    |> mes("but you can still redeem your")
    |> mes("Lottery Tickets inside, okay?")
    |> close()
    |> cutin("", 255)
  end

  defp request_firecrackers(ctx) do
    ctx
    |> mes("[Priestess Nemma]")
    |> mes("Mmm... I know what")
    |> mes("I can do! I can ask for")
    |> mes("Firecrackers! Yes, that'll")
    |> mes("be fun for the festival.")
    |> mes("Hey, do you know where")
    |> mes("those things are sold?")
    |> next()
    |> cutin("ra_nemma01", 2)
    |> mes("[Priestess Nemma]")
    |> mes("I, uh, can't give you")
    |> mes("much... But if you would")
    |> mes("bring me some Firecrackers,")
    |> mes("then I'll pray for your good")
    |> mes("fortune. Sorry, but that's")
    |> mes("all I can really offer.")
    |> next()
    |> cutin("ra_nemma04", 2)
    |> mes("[Priestess Nemma]")
    |> mes("Hey, bring me")
    |> mes("a lot of Firecrackers,")
    |> mes("like, ^FF000020 of them^000000! Thank")
    |> mes("you thank you thank you!")
    |> set_char_var(:ra_tem_q, 13)
    |> close()
    |> cutin("", 255)
  end

  defp ask_firecrackers(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Priestess Nemma]")
      |> mes("Hey, did you bring me")
      |> mes("^FF000020 Firecrackers^000000? Mmm?")
      |> next()
      |> select(["Yes.", "No, not yet."])

    if choice == 1 do
      check_firecrackers(ctx)
    else
      ctx
      |> cutin("ra_nemma01", 2)
      |> mes("[Priestess Nemma]")
      |> mes("Awww...")
      |> mes("Well, I don't really")
      |> mes("have much to pay you")
      |> mes("back with, anyway~")
      |> finish_dialog()
    end
  end

  defp check_firecrackers(ctx) do
    ctx =
      ctx
      |> cutin("ra_nemma01", 2)
      |> mes("[Priestess Nemma]")
      |> mes("Let's see...")
      |> next()

    if count_item(ctx, 12_018) >= 20 do
      reward_firecrackers(ctx)
    else
      ctx
      |> cutin("ra_nemma02", 2)
      |> mes("[Priestess Nemma]")
      |> mes("Awww...")
      |> mes("This isn't enough")
      |> mes("Firecrackers. I mean,")
      |> mes("I know it's like a donation,")
      |> mes("but still. How much fun are")
      |> mes("fireworks if there isn't a lot?")
      |> finish_dialog()
    end
  end

  defp reward_firecrackers(ctx) do
    ctx = ctx |> cutin("ra_nemma04", 2) |> delitem(12_018, 20)

    ctx
    |> getexp(
      if(Rathena.truthy?(checkre(ctx, 3)),
        do: 50_000,
        else: 200_000
      ),
      0
    )
    |> set_char_var(:ra_tem_q, 14)
    |> mes("[Priestess Nemma]")
    |> mes("Yay!")
    |> mes("Firecrackers!")
    |> mes("Oh, let me pray")
    |> mes("for your good fortune!")
    |> next()
    |> mes("^3355FFPriestess Nemma prayed")
    |> mes("fervently for your good")
    |> mes("fortune. It feels like")
    |> mes("it's actually working...^000000")
    |> next()
    |> cutin("ra_nemma04", 2)
    |> mes("[Priestess Nemma]")
    |> mes("I'm done!")
    |> mes("Now it's time")
    |> mes("to play! Hm, maybe")
    |> mes("our pope would like")
    |> mes("to see these too?")
    |> close()
    |> cutin("", 255)
  end

  defp donation_subroutine(ctx, args) do
    ctx =
      ctx
      |> set_local(:num, Enum.at(args, 0, 0))
      |> cutin("ra_nemma01", 2)
      |> mes("[Priestess Nemma]")

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("So, ", char_name(ctx, 0)), "..."))
      |> mes("I just want to make sure:")
      |> mes(Rathena.concat("You want to donate ", Enum.at(args, 1, 0)))

    ctx =
      mes(
        ctx,
        Rathena.concat(
          Rathena.concat("zeny, and receive ", get_local(ctx, :num, 0)),
          " Lottery"
        )
      )

    ctx =
      if get_local(ctx, :num, 0) == 1 do
        mes(ctx, "Ticket. Is that correct?")
      else
        mes(ctx, "Tickets. Is that correct?")
      end

    {ctx, choice} = ctx |> next() |> select(["No", "Yes"])

    ctx =
      cond do
        choice == 1 ->
          decline_confirmation(ctx)

        zeny(ctx) < get_local(ctx, :num, 0) * 50_000 ->
          insufficient_zeny(ctx)

        not Rathena.truthy?(checkweight(ctx, [{7570, get_local(ctx, :num, 0)}])) ->
          overweight(ctx)

        true ->
          complete_donation(ctx)
      end

    {ctx, nil}
  end

  defp decline_confirmation(ctx) do
    ctx
    |> mes("[Priestess Nemma]")
    |> mes("Oh, I see. Well, if you")
    |> mes("don't have enough zeny with")
    |> mes("you, then you can just come")
    |> mes("back and donate later. Our")
    |> mes("goddess Freya smiles on the")
    |> mes("generous and rewards the patient!")
  end

  defp overweight(ctx) do
    ctx
    |> cutin("ra_nemma02", 2)
    |> mes("[Priestess Nemma]")
    |> mes("I can scarcely believe it...")
    |> mes("You're carrying so much stuff,")
    |> mes("you don't even have enough")
    |> mes("room for a Lottery Ticket.")
    |> mes("You'd better put some of")
    |> mes("your things in Storage, yes?")
    |> next()
    |> cutin("ra_nemma01", 2)
    |> mes("[Priestess Nemma]")
    |> mes("Don't worry, I'll still be")
    |> mes("here after you make more")
    |> mes("space available in your")
    |> mes("Inventory. Hurry back, and")
    |> mes("donate if you can, okay?")
  end

  defp insufficient_zeny(ctx) do
    ctx = ctx |> mes("[Priestess Nemma]") |> mes("I'm sorry, but you have")

    ctx
    |> mes(
      Rathena.concat(
        Rathena.concat("less than ", get_local(ctx, :num, 0) * 50_000),
        " zeny..."
      )
    )
    |> mes("I know it's asking a lot,")
    |> mes("but those are the rules that")
    |> mes("I've been told to follow, so...")
    |> mes("Well, maybe another time, yes?")
  end

  defp complete_donation(ctx) do
    ctx =
      set_server_var(
        ctx,
        "rachel_donate",
        get_server_var(ctx, "rachel_donate", 0) + get_local(ctx, :num, 0)
      )

    ctx = give_item(ctx, 7570, get_local(ctx, :num, 0))

    ctx =
      ctx |> pay_zeny(get_local(ctx, :num, 0) * 50_000) |> set_char_var(:ra_have_donated, 1)

    if get_server_var(ctx, "rachel_donate", 0) > 9999 do
      ctx
      |> cutin("ra_nemma03", 2)
      |> mes("[Priestess Nemma]")
      |> mes("There you are~")
      |> mes("Thanks so much for")
      |> mes("your donation! I'm sure")
      |> mes("that Freya is smiling down")
      |> mes("upon you, and will reward")
      |> mes("you for your generosity~")
    else
      ctx =
        ctx
        |> set_local(:Remaining, 10_000 - get_server_var(ctx, "rachel_donate", 0))
        |> cutin("ra_nemma03", 2)
        |> mes("[Priestess Nemma]")
        |> mes("Thank you so much! We'll be")
        |> mes("continuing to accept donations")
        |> mes("until we reach our target. Once")

      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat("we receive ", get_local(ctx, :Remaining, 0)),
          " more donations"
        )
      )
      |> mes("in increments of 50,000 zeny,")
      |> mes("our fundraiser will finish.")
      |> next()
      |> mes("[Priestess Nemma]")
      |> mes("If you're feeling so")
      |> mes("inclined, come back later")
      |> mes("and make another contribution.")
      |> mes("Thanks again, and may Freya")
      |> mes("always watch over you.")
    end
  end
end
