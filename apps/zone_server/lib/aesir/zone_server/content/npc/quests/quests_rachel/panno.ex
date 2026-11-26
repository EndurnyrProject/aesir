defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Panno do
  @moduledoc """
  Panno exchanges lottery tickets and explains the temple’s history.

  ## Behavior

  - Exchanges one ticket for a random reward, subject to carrying capacity.
  - Shares information about the temple and its gate as the quest progresses.

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
        map: "ra_temin",
        x: 170,
        y: 46,
        dir: 3,
        sprite: 920,
        name: "Panno",
        scope: :shared,
        unique_name: "Panno#rachel"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    ctx = cutin(ctx, "ra_fano03", 2)

    cond do
      get_char_var(ctx, :ra_tem_q, 0) >= 12 or
          Rathena.truthy?(:erlang.band(get_char_var(ctx, :MISC_QUEST, 0), 8192)) ->
        later_visit(ctx)

      get_char_var(ctx, :ra_tem_q, 0) < 2 ->
        early_visit(ctx)

      get_char_var(ctx, :ra_tem_q, 0) == 10 ->
        gate_visit(ctx)

      get_char_var(ctx, :ra_tem_q, 0) == 11 ->
        explain_gate(ctx)

      true ->
        admonish(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp later_visit(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("ra_fano03", 2)
      |> mes("[Priestess Panno]")
      |> mes("Good day.")
      |> mes("Have you come to")
      |> mes("redeem Lottery Tickets?")
      |> next()
      |> select(["Yes", "No"])

    cond do
      choice == 1 -> lottery(ctx)
      get_char_var(ctx, :ra_tem_q, 0) == 12 -> keep_quiet(ctx)
      true -> admonish(ctx)
    end
  end

  defp keep_quiet(ctx) do
    ctx
    |> cutin("ra_fano01", 2)
    |> mes("[Priestess Panno]")
    |> mes("I already told you")
    |> mes("everything I know.")
    |> mes("Remember to keep")
    |> mes("quiet about what I said.")
    |> close()
    |> cutin("", 255)
  end

  defp early_visit(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Priestess Panno]")
      |> mes("Greetings.")
      |> mes("May Freya fill")
      |> mes("your days with joy.")
      |> mes("Laughter. And prosperity.")
      |> next()
      |> select([
        "Redeem Lottery Tickets",
        "Temple Information",
        "Hey, what's happening?"
      ])

    case choice do
      1 -> early_lottery(ctx)
      2 -> early_information(ctx)
      3 -> no_chat(ctx)
      _ -> ctx
    end
  end

  defp early_lottery(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("ra_fano03", 2)
      |> mes("[Priestess Panno]")
      |> mes("Fine. You really")
      |> mes("want to exchange your")
      |> mes("Lottery Tickets? It's my job")
      |> mes("to ask and make sure, you")
      |> mes("know, in case you were saving")
      |> mes("them for some weird reason.")
      |> next()
      |> select(["Yes", "No"])

    if choice == 1 do
      lottery(ctx)
    else
      ctx
      |> cutin("ra_fano03", 2)
      |> mes("[Priestess Panno]")
      |> mes("You can redeem your")
      |> mes("Lottery Tickets at any")
      |> mes("time, so please visit")
      |> mes("me at your leisure.")
      |> mes("Go with Freya.")
      |> close()
      |> cutin("", 255)
    end
  end

  defp early_information(ctx) do
    ctx =
      ctx
      |> cutin("ra_fano01", 2)
      |> mes("[Priestess Panno]")
      |> mes("The Chapel is located")
      |> mes("over the wall behind me.")
      |> mes("Our pope's office and chambers")
      |> mes("are upstairs. You can only go")
      |> mes("there if you have special")
      |> mes("authorization.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("......")
      |> mes(".........")
      |> next()
      |> mes("[Priestess Panno]")
      |> mes("............")
      |> mes(".........")
      |> mes("......")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("...?")
    |> next()
    |> cutin("ra_fano02", 2)
    |> mes("[Priestess Panno]")
    |> mes("You come to a temple")
    |> mes("to pray, not to look")
    |> mes("around. Or chit-chat")
    |> mes("with the priestesses")
    |> mes("like me. Don't forget it.")
    |> next()
    |> cutin("ra_fano03", 2)
    |> mes("[Priestess Panno]")
    |> mes("The offices for the High")
    |> mes("Priests are located on each")
    |> mes("side of the hallway. However,")
    |> mes("you can only enter if you've")
    |> mes("been permitted beforehand.")
    |> close()
    |> cutin("", 255)
  end

  defp no_chat(ctx) do
    ctx
    |> mes("[Priestess Panno]")
    |> mes("......................")
    |> mes("No chit-chat")
    |> mes("inside the temple.")
    |> close()
    |> cutin("", 255)
  end

  defp gate_visit(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Priestess Panno]")
      |> mes("Good day.")
      |> next()
      |> select([
        "Redeem Lottery Tickets",
        "Temple Information",
        "Hey, did you open the gate?"
      ])

    case choice do
      1 -> late_lottery(ctx)
      2 -> late_information(ctx)
      3 -> ask_about_gate(ctx)
      _ -> ctx
    end
  end

  defp late_lottery(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("ra_fano01", 2)
      |> mes("[Priestess Panno]")
      |> mes("You... still have")
      |> mes("Lottery Tickets from")
      |> mes("making donations for")
      |> mes("the festival? Look up the")
      |> mes("word ''punctuality'' in the")
      |> mes("dictionary. It might help you.")
      |> next()
      |> mes("[Priestess Panno]")
      |> mes("Fine. You really")
      |> mes("want to exchange your")
      |> mes("Lottery Tickets? It's my job")
      |> mes("to ask and make sure, you")
      |> mes("know, in case you were saving")
      |> mes("them for some weird reason.")
      |> next()
      |> select(["Yes", "No"])

    if choice == 1 do
      lottery(ctx)
    else
      ctx
      |> mes("[Priestess Panno]")
      |> mes("You can redeem your")
      |> mes("Lottery Tickets at any")
      |> mes("time, so please visit")
      |> mes("me at your leisure.")
      |> mes("Go with Freya.")
      |> close()
      |> cutin("", 255)
    end
  end

  defp late_information(ctx) do
    ctx =
      ctx
      |> cutin("ra_fano01", 2)
      |> mes("[Priestess Panno]")
      |> mes("The Chapel is located")
      |> mes("over the wall behind me")
      |> mes("Our pope's office and chambers")
      |> mes("are upstairs. You can only go")
      |> mes("there if you have special")
      |> mes("authorization.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("......")
      |> mes(".........")
      |> next()
      |> mes("[Priestess Panno]")
      |> mes("............")
      |> mes(".........")
      |> mes("......")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("...?")
    |> next()
    |> cutin("ra_fano02", 2)
    |> mes("[Priestess Panno]")
    |> mes("You come to a temple")
    |> mes("to pray, not to look")
    |> mes("around. Or chit-chat")
    |> mes("with the priestesses")
    |> mes("like me. Don't forget it.")
    |> next()
    |> cutin("ra_fano02", 2)
    |> mes("[Priestess Panno]")
    |> mes("The offices for the High")
    |> mes("Priests are located on each")
    |> mes("side of the hallway. However,")
    |> mes("you can only enter if you've")
    |> mes("been permitted beforehand.")
    |> close()
    |> cutin("", 255)
  end

  defp ask_about_gate(ctx) do
    {ctx, _} =
      ctx
      |> cutin("ra_fano02", 2)
      |> mes("[Priestess Panno]")
      |> mes("Gate...?")
      |> next()
      |> select(["The locked gate to the temple!"])

    {ctx, _} =
      ctx
      |> mes("[Priestess Panno]")
      |> mes("I don't know")
      |> mes("what you mean.")
      |> next()
      |> select(["Explain"])

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("I think that Priestess Nemma")
      |> mes("has been worried about the")
      |> mes("gate being broken, though")
      |> mes("it hasn't been like that since")
      |> mes("you've started your position")
      |> mes("here at the temple.")
      |> next()
      |> mes("[Priestess Panno]")
      |> mes("Worried...?")
      |> mes("Yes, my twin sister")
      |> mes("has been known to")
      |> mes("do a lot of that, and cry")
      |> mes("for my help. Am I right?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("It's weird")
      |> mes("...She said that the gate")
      |> mes("should automatically fix")
      |> mes("itself, but it hasn't been")
      |> mes("doing it lately. She was")
      |> mes("acting really funny..")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("She was talking about")
    |> mes("the temple's history and")
    |> mes("how the security system was")
    |> mes("built. Then she mentioned you,")
    |> mes("so I get the feeling you might")
    |> mes("know something about this.")
    |> next()
    |> mes("[Priestess Panno]")
    |> mes(".........")
    |> set_char_var(:ra_tem_q, 11)
    |> close()
    |> cutin("", 255)
  end

  defp explain_gate(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("I remember now...!")
    |> mes("I was there when the gate")
    |> mes("closed, and I heard someone")
    |> mes("with your exact voice whisper")
    |> mes("something to magically open")
    |> mes("the gate! What's that all about?")
    |> next()
    |> mes("[Priestess Panno]")
    |> mes("......")
    |> mes(".........")
    |> mes("............")
    |> next()
    |> mes("[Priestess Panno]")
    |> mes("......")
    |> mes(".........")
    |> mes("............")
    |> mes("We... I mean....")
    |> next()
    |> cutin("ra_fano01", 2)
    |> mes("[Priestess Panno]")
    |> mes("Nemma and I are descended")
    |> mes("from a family of great alchemists.")
    |> mes("They went on a long, religious")
    |> mes("pilgrimage and ended up here.")
    |> mes("They are the ones that built")
    |> mes("this temple and security system.")
    |> next()
    |> mes("[Priestess Panno]")
    |> mes("In a sense, this temple")
    |> mes("is the tomb of our ancestors,")
    |> mes("who left Rune-Midgarts and")
    |> mes("built this city of Rachel about")
    |> mes("a thousand years ago.")
    |> next()
    |> mes("[Priestess Panno]")
    |> mes("Over the generations, many")
    |> mes("Alchemists left Rune-Midgarts")
    |> mes("and settled here, converting")
    |> mes("the desert into green fields.")
    |> mes("This temple was supposed")
    |> mes("be a shelter from intruders.")
    |> next()
    |> mes("[Priestess Panno]")
    |> mes("My ancestor designed the")
    |> mes("temple security system to")
    |> mes("require a special permit in")
    |> mes("order to access the temple")
    |> mes("But the invaders never came,")
    |> mes("and we didn't need the permits.")
    |> next()
    |> mes("[Priestess Panno]")
    |> mes("The special permits were")
    |> mes("disposed, but the automatic")
    |> mes("security system was left on")
    |> mes("the gate, just in case. Now,")
    |> mes("I've heard that the security")
    |> mes("system has been malfunctioning.")
    |> next()
    |> cutin("ra_fano03", 2)
    |> mes("[Priestess Panno]")
    |> mes("However, that's not possible.")
    |> mes("Even by today's standards, the")
    |> mes("system is perfectly designed.")
    |> mes("While I was praying in the")
    |> mes("Chapel some time ago, I found")
    |> mes("what is causing the gate problems.")
    |> next()
    |> mes("[Priestess Panno]")
    |> mes("Suddenly, the lights went")
    |> mes("out, and I could only barely")
    |> mes("see distinguish my surroundings.")
    |> mes("I was about to go outside when")
    |> mes("I heard a noise from the stairs.")
    |> next()
    |> cutin("ra_fano02", 2)
    |> mes("[Priestess Panno]")
    |> mes("From what I can tell,")
    |> mes("someone is transporting")
    |> mes("something out of the Holy")
    |> mes("Grounds. I don't know what")
    |> mes("they keep there, though.")
    |> mes("I'm not a high rank Priestess.")
    |> next()
    |> mes("[Priestess Panno]")
    |> mes("I'm not sure if I want")
    |> mes("to find out what's there")
    |> mes("I heard something that")
    |> mes("sounded like a horrible")
    |> mes("monster's howl. It was")
    |> mes("incredibly frightening.")
    |> next()
    |> mes("[Priestess Panno]")
    |> mes("I panicked, ran to")
    |> mes("my desk at the front,")
    |> mes("and just recited the secret")
    |> mes("password passed down from my")
    |> mes("ancestors to open the gate.")
    |> next()
    |> cutin("ra_fano01", 2)
    |> mes("[Priestess Panno]")
    |> mes("You see, my ancestors")
    |> mes("included the secret password")
    |> mes("and voice recognition feature")
    |> mes("into the gate in case something")
    |> mes("after they disposed of the")
    |> mes("temple permits--just in case.")
    |> next()
    |> mes("[Priestess Panno]")
    |> mes("The real reason why the gate")
    |> mes("is acting strangely is not")
    |> mes("because the gate is broken,")
    |> mes("but because someone is sneaking")
    |> mes("in and out of the Holy Ground.")
    |> next()
    |> mes("[Priestess Panno]")
    |> mes("Whoever they are, they")
    |> mes("must be using one of the")
    |> mes("old temple permits in order")
    |> mes("to cover their tracks. Now,")
    |> mes("you know everything.")
    |> next()
    |> cutin("ra_fano01", 2)
    |> mes("[Priestess Panno]")
    |> mes("You'd better not")
    |> mes("reveal what you learned")
    |> mes("from me. Otherwise, I'm")
    |> mes("sure we'll end up dead.")
    |> mes("Excuse me now, I need")
    |> mes("to get back to work.")
    |> set_char_var(:ra_tem_q, 12)
    |> close()
    |> cutin("", 255)
  end

  defp admonish(ctx) do
    ctx
    |> cutin("ra_fano02", 2)
    |> mes("[Priestess Panno]")
    |> mes("This is a holy place")
    |> mes("Behave yourself, and")
    |> mes("respect those who have")
    |> mes("come here just to worship.")
    |> close()
    |> cutin("", 255)
  end

  defp lottery(ctx) do
    if checkweight(ctx, [{607, 1}]) == 0 do
      ctx
      |> cutin("ra_fano02", 2)
      |> mes("[Priestess Panno]")
      |> mes("You're carrying too much")
      |> mes("right now. What are you")
      |> mes("going to do if I give you")
      |> mes("something large, unwieldy")
      |> mes("and heavy? Put your junk")
      |> mes("away in Storage first.")
      |> close()
      |> cutin("", 255)
    else
      redeem_ticket(ctx)
    end
  end

  defp redeem_ticket(ctx) do
    ctx =
      ctx
      |> mes("[Priestess Panno]")
      |> mes("Here we go")
      |> mes("Excited? Mm")
      |> mes("I can redeem only")
      |> mes("1 Lottery Ticket at")
      |> mes("a time. Your reward")
      |> mes("for this ticket is...")
      |> next()
      |> cutin("ra_fano02", 2)

    if count_item(ctx, 7570) > 0 do
      reward_ticket(ctx)
    else
      no_ticket(ctx)
    end
  end

  defp reward_ticket(ctx) do
    ctx =
      ctx
      |> mes("[Priestess Panno]")
      |> mes("^FF0000This^000000. It's been in our")
      |> mes("storage for a while, but")
      |> mes("I hope this is acceptable")
      |> mes("as a token of the temple's")
      |> mes("gratitude. May Freya smile")
      |> mes("upon you for your generosity...")
      |> delitem(7570, 1)
      |> set_local(:bonus_donate, :rand.uniform(100) - 1)

    ctx =
      if get_local(ctx, :bonus_donate, 0) == 99 do
        ctx = set_local(ctx, :bonus_donate2, :rand.uniform(100) - 1)
        roll = get_local(ctx, :bonus_donate2, 0)

        item =
          cond do
            roll > 0 and roll < 11 -> 616
            roll > 10 and roll < 31 -> 617
            roll > 30 and roll < 61 -> 603
            true -> 607
          end

        give_item(ctx, item, 1)
      else
        roll = get_local(ctx, :bonus_donate, 0)

        item =
          cond do
            roll > 88 and roll < 96 -> 644
            roll > 76 and roll < 89 -> 607
            roll > 65 and roll < 77 -> 505
            roll > 57 and roll < 66 -> 604
            roll > 45 and roll < 58 -> 608
            roll > 5 and roll < 11 -> 518
            roll > 0 and roll < 6 -> 526
            true -> 547
          end

        give_item(ctx, item, 1)
      end

    ctx |> close() |> cutin("", 255)
  end

  defp no_ticket(ctx) do
    ctx =
      ctx
      |> mes("[Priestess Panno]")
      |> mes("You...")
      |> mes("Don't have any Lottery")
      |> mes("Tickets to redeem.")

    ctx =
      if get_server_var(ctx, "rachel_donate", 0) > 9999 do
        ctx
        |> mes("We're not distributing")
        |> mes("them now, but maybe you")
        |> mes("can ask your friends for one.")
      else
        ctx
        |> mes("You can obtain them from")
        |> mes("Priestess Nemma at the temple")
        |> mes("entrance after you donate zeny.")
      end

    ctx
    |> next()
    |> cutin("ra_fano03", 2)
    |> mes("[Priestess Panno]")
    |> mes("May Freya be with you.")
    |> close()
    |> cutin("", 255)
  end
end
