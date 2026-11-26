defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Man102298 do
  @moduledoc """
  A treasure hunter bargains for help recovering a buried chest.

  ## Behavior

  - Trades information for items and discusses the chest's magical protection.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "morocc",
        x: 102,
        y: 298,
        dir: 3,
        sprite: 98,
        name: "Man",
        scope: :shared,
        unique_name: "Man#zgang"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :treasure_nd, 0) < 2 ->
        ctx |> mes("[Man]") |> mes("What do you want?") |> mes("Just leave me alone.") |> close()

      get_char_var(ctx, :treasure_nd, 0) == 2 ->
        {ctx, treasure_choice} =
          ctx
          |> mes("[Man]")
          |> mes("What do you want?")
          |> mes("Just leave me alone.")
          |> next()
          |> select(["Tell me about the treasure."])

        case treasure_choice do
          1 ->
            ctx =
              ctx
              |> emotion(:surprise)
              |> mes("[Man]")
              |> mes("What? So you're the one")
              |> mes("I was warned about! I've")
              |> mes("been wondering when you'd")
              |> mes("show up. Prepare to die!")
              |> next()

            ctx =
              ctx
              |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
              |> mes("Umm... Excuse me?")
              |> mes("I've just heard that you")
              |> mes("confirmed the location of")
              |> mes("some amazing treasure,")
              |> mes("and I just wanted to ask")
              |> mes("you more about it. That's all!")
              |> next()
              |> mes("[Man]")
              |> mes("What? If you're just here")
              |> mes("for that, then how'd you")
              |> mes("find out about me and")
              |> mes("the treasure? Not just")
              |> mes("everyone knows about it.")
              |> next()

            {ctx, deal_choice} =
              ctx
              |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
              |> mes("Well, I was talking to")
              |> mes("this other treasure hunter")
              |> mes("who's... Well, he's kind")
              |> mes("of a beggar now...")
              |> next()
              |> mes("[Man]")
              |> mes("Oh. That old man?")
              |> mes("Well, I don't know if the")
              |> mes("treasure he was looking")
              |> mes("for and the one I've found")
              |> mes("are the same one. But")
              |> mes("yeah, I know that guy.")
              |> next()
              |> mes("[Man]")
              |> mes("Alright. So I found this")
              |> mes("treasure, but I have no way")
              |> mes("of digging it up. Maybe we")
              |> mes("can help each other. I need")
              |> mes("money, and you want to know")
              |> mes("more, right? Let's cut a deal.")
              |> next()
              |> select(["No, thanks.", "What'd you have in mind?"])

            case deal_choice do
              1 ->
                ctx
                |> mes("[Man]")
                |> mes("No? Well...")
                |> mes("There's no reason for")
                |> mes("you to trust me now,")
                |> mes("I suppose. But what can")
                |> mes("you gain by walking away?")
                |> set_char_var(:treasure_nd, 3)
                |> close()

              2 ->
                explain_deal(ctx)

              _ ->
                ctx
            end

          _ ->
            ctx
        end

      get_char_var(ctx, :treasure_nd, 0) == 3 ->
        {ctx, reconsider_choice} =
          ctx
          |> mes("[Man]")
          |> mes("You again? Lemme guess...")
          |> mes("You're reconsidering that")
          |> mes("deal I had in mind, aren't you?")
          |> next()
          |> select(["No, not really.", "I guess so."])

        case reconsider_choice do
          1 ->
            ctx
            |> mes("[Man]")
            |> mes("You sure? No one would")
            |> mes("be losing in this deal, you")
            |> mes("know. Well, except the guys")
            |> mes("that hired me to find that")
            |> mes("treasure. It's pretty much")
            |> mes("a win-win situation.")
            |> next()
            |> mes("[Man]")
            |> mes("Way I figure it,")
            |> mes("someone ought to get")
            |> mes("that treasure. I can't")
            |> mes("dig it up, but maybe")
            |> mes("someone like you can...")
            |> close()

          2 ->
            explain_deal(ctx)

          _ ->
            ctx
        end

      get_char_var(ctx, :treasure_nd, 0) == 4 ->
        ctx =
          ctx
          |> mes("[Man]")
          |> mes("Back again, huh?")
          |> mes("So did you bring")
          |> mes("the stuff I asked?")
          |> next()

        if count_item(ctx, 722) > 1 and count_item(ctx, 912) > 1 and count_item(ctx, 934) > 19 do
          ctx
          |> mes("[Man]")
          |> mes("Nice. You did your part.")
          |> mes("And now it's time that")
          |> mes("I fulfilled my part of")
          |> mes("this bargain. Listen up.")
          |> delitem(722, 2)
          |> delitem(912, 2)
          |> delitem(934, 20)
          |> set_char_var(:treasure_nd, 5)
          |> next()
          |> mes("[Man]")
          |> mes("The treasure is buried")
          |> mes("south of Morocc. Use the")
          |> mes("south gate to leave town,")
          |> mes("and then head to the next")
          |> mes("field to the south. From")
          |> mes("there, you're on your own.")
          |> next()
          |> mes("[Man]")
          |> mes("I don't know exactly")
          |> mes("where the treasure is")
          |> mes("buried, but you should")
          |> mes("be able to find it within")
          |> mes("that general area. Good luck.")
          |> close()
        else
          ctx
          |> mes("[Man]")
          |> mes("Huh, you must have")
          |> mes("forgotten what I wanted.")
          |> mes("I'm not really asking you")
          |> mes("for extremely valuable stuff")
          |> mes("here. Anyway, listen up.")
          |> next()
          |> mes("[Man]")
          |> mes("Just bring me,")
          |> mes("^FF000020 Mementos^000000,")
          |> mes("^FF00002 Pearls^000000, and")
          |> mes("^FF00002 Zargons^000000 so we can talk")
          |> mes("business further. Got it?")
          |> close()
        end

      get_char_var(ctx, :treasure_nd, 0) == 5 ->
        ctx
        |> mes("[Man]")
        |> mes("What are you still doing")
        |> mes("here? Shouldn't you be")
        |> mes("looking for the treasure?")
        |> close()

      get_char_var(ctx, :treasure_nd, 0) == 6 ->
        {ctx, _} =
          ctx
          |> mes("[Man]")
          |> mes("What are you still doing")
          |> mes("here? Shouldn't you be")
          |> mes("looking for the treasure?")
          |> next()
          |> select(["I already found it, but..."])

        {result, ctx} =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("I already found it, but...")
          |> mes("It won't budge at all!")
          |> mes("I think it's protected by")
          |> mes("magic. Do you know")
          |> mes("anything about that?")
          |> next()
          |> mes("[Man]")
          |> mes("Wow, you actually found")
          |> mes("it? Heh, you're better than")
          |> mes("I thought. Sorry about that.")
          |> mes("I didn't explain the magic")
          |> mes("part since... Well, I didn't")
          |> mes("think you'd get that far.")
          |> next()
          |> mes("[Man]")
          |> mes("Anyway, I had problems")
          |> mes("with that magic too. Some")
          |> mes("guy was supposed to help me")
          |> mes("with that, but he didn't come.")
          |> mes("I've been so frustrated!")
          |> next()
          |> mes("[Man]")
          |> mes("I mean, I have no clue")
          |> mes("when it comes to magic, and")
          |> mes("I don't understand how I'm")
          |> mes("supposed to use this thing")
          |> mes("my clients gave to me.")
          |> next()
          |> discuss_document()

        if result == :cancelled do
          ctx
        else
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Wait, how could you not")
          |> mes("know how to use this?")
          |> mes("Didn't you get a chance")
          |> mes("to talk to your clients?")
          |> next()
          |> mes("[Man]")
          |> mes("I haven't even met them.")
          |> mes("I just get their instructions")
          |> mes("through the mail. Everything")
          |> mes("is through a medium with these")
          |> mes("guys. I guess they've got their")
          |> mes("eyes on me too, but whatever.")
          |> next()
          |> mes("[Man]")
          |> mes("I guess they hired me because")
          |> mes("they really want the treasure,")
          |> mes("but don't want to tip anyone")
          |> mes("off that they're looking for ")
          |> mes("it, or that they have it.")
          |> next()
          |> mes("[Man]")
          |> mes("Anyway, all I know is that")
          |> mes("this piece of paper is supposed")
          |> mes("to do something. But I guess")
          |> mes("I'm not smart enough to figure")
          |> mes("it out. Maybe you'll have")
          |> mes("better luck with them.")
          |> next()
          |> mes("[Man]")
          |> mes("You know, if you can actually")
          |> mes("find that guy who was supposed")
          |> mes("to help me but never showed up,")
          |> mes("maybe he'll understand how to")
          |> mes("use that document. Go ahead")
          |> mes("and take 'em. Good luck, now.")
          |> close()
        end

      get_char_var(ctx, :treasure_nd, 0) == 7 or get_char_var(ctx, :treasure_nd, 0) == 8 ->
        ctx
        |> mes("[Man]")
        |> mes("I already told you everything")
        |> mes("I know. You'd be better off")
        |> mes("finding that guy over in")
        |> mes("Comodo, or the rest of")
        |> mes("that torn document.")
        |> close()

      get_char_var(ctx, :treasure_nd, 0) == 9 or get_char_var(ctx, :treasure_nd, 0) == 10 ->
        ctx
        |> mes("[Man]")
        |> mes("Now that I think about it,")
        |> mes("maybe the treasure can be")
        |> mes("obtained by two people?")
        |> mes("I mean, they planned for")
        |> mes("me to go with that guy. Eh,")
        |> mes("best not to think about it.")
        |> close()

      true ->
        ctx
        |> mes("[Man]")
        |> mes("Heh! Looks like I'll be")
        |> mes("headed home soon~")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp explain_deal(ctx) do
    ctx
    |> mes("[Man]")
    |> mes("Let me lay it out for you.")
    |> mes("I've been hired to find this")
    |> mes("treasure by some people:")
    |> mes("they said I can take whatever")
    |> mes("I find, but they specifically")
    |> mes("want one item for themselves.")
    |> next()
    |> mes("[Man]")
    |> mes("They pay me on delivery")
    |> mes("so I haven't seen a dime yet.")
    |> mes("Now, my agreement with them")
    |> mes("is conditional. I can't dig")
    |> mes("up the treasure so they'll")
    |> mes("understand if I say I failed.")
    |> next()
    |> mes("[Man]")
    |> mes("But if you dig it up, you can")
    |> mes("keep everything. Sound good?")
    |> mes("All I want is some stuff from")
    |> mes("you to make all my efforts up")
    |> mes("till now worth my while.")
    |> next()
    |> mes("[Man]")
    |> mes("In other words,")
    |> mes("if you bring me,")
    |> mes("^FF000020 Mementos^000000,")
    |> mes("^FF00002 Pearls^000000, and")
    |> mes("^FF00002 Zargons^000000, we can talk")
    |> mes("business further. Got it?")
    |> set_char_var(:treasure_nd, 4)
    |> next()
    |> mes("[Man]")
    |> mes("Hey, I might be losing out")
    |> mes("by giving up my share of that")
    |> mes("treasure, but hey, a bird in")
    |> mes("the hand's always worth more.")
    |> close()
  end

  defp discuss_document(ctx) do
    {ctx, topic} = select(ctx, ["Who was going to help you?", "Your clients gave you something?"])

    case topic do
      1 ->
        ctx
        |> mes("[Man]")
        |> mes("Oh, yeah. The guys that")
        |> mes("hired me said that if I waited")
        |> mes("at the treasure site, someone")
        |> mes("would eventually come to help")
        |> mes("me out on the magic end.")
        |> mes("I don't know who he is, though.")
        |> next()
        |> mes("[Man]")
        |> mes("Oh, yeah. They mentioned")
        |> mes("something about him coming")
        |> mes("a bit from the west. Maybe")
        |> mes("he's over in Comodo?")
        |> next()
        |> set_local(:joho1, 1)
        |> continue_discussion()

      2 ->
        ctx |> describe_document() |> continue_discussion()

      _ ->
        {:cancelled, ctx}
    end
  end

  defp continue_discussion(ctx) do
    if get_local(ctx, :joho1, 0) == 1 and get_local(ctx, :joho2, 0) == 1 do
      {:complete, ctx}
    else
      discuss_document(ctx)
    end
  end

  defp describe_document(ctx) do
    cond do
      get_char_var(ctx, :treasure_nd, 0) == 7 ->
        ctx
        |> mes("[Man]")
        |> mes("Oh, yeah. They gave me")
        |> mes("this weird document labeled")
        |> mes("''^FF0000[Open^000000.'' I don't know how")
        |> mes("to use it at all, though.")
        |> next()

      get_char_var(ctx, :treasure_nd, 0) == 8 ->
        ctx
        |> mes("[Man]")
        |> mes("Oh, yeah. They gave me")
        |> mes("this weird document labeled")
        |> mes("''^FF0000[Unlock^000000.'' I don't know how")
        |> mes("to use it at all, though.")
        |> next()

      true ->
        ctx =
          ctx
          |> mes("[Man]")
          |> mes("Oh, yeah. Let's see here.")
          |> mes("Ah, here's the document")
          |> mes("that they gave me. It's kind")
          |> mes("of a bit torn, though.")
          |> next()

        if Enum.random(1..2) == 1 do
          ctx
          |> mes("^3355FFThe torn document")
          |> mes("is labeled ''^FF0000[Open^3355FF.''^000000")
          |> next()
          |> set_char_var(:treasure_nd, 7)
          |> set_local(:joho2, 1)
        else
          ctx
          |> mes("^3355FFThe torn document")
          |> mes("is labeled ''^FF0000[Unlock^3355FF.''^000000")
          |> next()
          |> set_char_var(:treasure_nd, 8)
          |> set_local(:joho2, 1)
        end
    end
  end
end
