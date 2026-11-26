defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsNameless.DorianIzlude do
  @moduledoc """
  Dorian helps adventurers repair his Mystic Dryer.

  ## Behavior

  - Guides the player through gathering materials and repairing the dryer.

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
      %{name: "", scope: :shared, unique_name: "Dorian_izlude"},
      %{
        map: "izlude_in",
        x: 57,
        y: 92,
        dir: 3,
        sprite: 878,
        name: "Dorian",
        scope: :renewal,
        unique_name: "Dorian",
        trigger: {2, 2}
      },
      %{
        map: "izlude_in",
        x: 110,
        y: 64,
        dir: 3,
        sprite: 878,
        name: "Dorian",
        scope: :pre_renewal,
        unique_name: "Dorian",
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTouch", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{907, 200}]) == 0 ->
        ctx
        |> mes("[Dorian]")
        |> mes("Ugh, just like a member")
        |> mes("of the working class:")
        |> mes("hoarding all your items")
        |> mes("like a packrat? Have the")
        |> mes("decency to relocate your")
        |> mes("goods to Kafra Storage, please.")
        |> close()

      get_char_var(ctx, :diamond_edq, 0) < 6 ->
        ctx
        |> mes("[Dorian]")
        |> mes("You must be in awe")
        |> mes("of my elegant, artistic")
        |> mes("touch. In my hands, almost")
        |> mes("anything can become a")
        |> mes("work of art... Even you~")
        |> close()

      get_char_var(ctx, :diamond_edq, 0) == 6 ->
        discuss_dryer(ctx)

      get_char_var(ctx, :diamond_edq, 0) == 7 ->
        ctx
        |> mes("[Dorian]")
        |> mes("Ugh, your behavior")
        |> mes("from before disgusts me...")
        |> mes("But those pitiful eyes...")
        |> mes("Seeking sympathy. Ah,")
        |> mes("you're only human.")
        |> mes("I shall forgive you.")
        |> next()
        |> mes("[Dorian]")
        |> mes("Alright then. Please")
        |> mes("listen carefully this time,")
        |> mes("and don't insult my pride")
        |> mes("again. When you are ready,")
        |> mes("please come talk to me.")
        |> set_char_var(:diamond_edq, 6)
        |> close()

      get_char_var(ctx, :diamond_edq, 0) == 9 ->
        ctx =
          ctx
          |> mes("[Dorian]")
          |> mes("Ah, did you bring all")
          |> mes("the materials I need to")
          |> mes("repair the Mystic Dryer")
          |> mes("de Elegance? Let me take")
          |> mes("a glance at what you brought...")
          |> next()

        if count_item(ctx, 7317) > 19 and count_item(ctx, 1002) > 9 and count_item(ctx, 999) > 4 and
             count_item(ctx, 723) > 1 and count_item(ctx, 716) > 4 do
          ctx
          |> mes("[Dorian]")
          |> mes("Ah, well done. Now")
          |> mes("that the materials are")
          |> mes("ready, I can instruct you on")
          |> mes("how to repair the machine.")
          |> next()
          |> delitem(7317, 20)
          |> delitem(1002, 10)
          |> delitem(999, 5)
          |> delitem(723, 2)
          |> delitem(716, 5)
          |> changequest(3104, 3105)
          |> set_char_var(:diamond_edq, 10)
          |> mes("[Dorian]")
          |> mes("I expect you to fail")
          |> mes("a few times, but the")
          |> mes("Mystic Dryer de Elegance")
          |> mes("is designed for durability:")
          |> mes("even if you tried, you'd")
          |> mes("have trouble scratching it.")
          |> next()
          |> mes("[Dorian]")
          |> mes("First, insert a new rough")
          |> mes("ruby into the ruby engine,")
          |> mes("and tighten the screw on")
          |> mes("the joint until you hear")
          |> mes("a ^0000FFclick^000000. You'll break it")
          |> mes("if you tighten it further.")
          |> next()
          |> mes("[Dorian]")
          |> mes("Next you'll need to")
          |> mes("operate the four switches")
          |> mes("coded by the colors red,")
          |> mes("blue, yellow, and green.")
          |> next()
          |> mes("[Dorian]")
          |> mes("Press the ^0000FFRed^000000 switch")
          |> mes("if the engine is in 1st")
          |> mes("Gear. Press the ^0000FFBlue^000000")
          |> mes("switch in 2nd Gear,")
          |> mes("^0000FFYellow^000000 for 3rd, and")
          |> mes("^0000FFGreen^000000 for 4th.")
          |> next()
          |> mes("[Dorian]")
          |> mes("The engine's sound is the")
          |> mes("only indicator of which")
          |> mes("gear is running. You'll")
          |> mes("have to figure that out")
          |> mes("on your own. I'm sorry")
          |> mes("I designed it that way...")
          |> next()
          |> mes("[Dorian]")
          |> mes("Ah, one last tip!")
          |> mes("If you enter the correct")
          |> mes("engine gear, the machine")
          |> mes("will start without a problem,")
          |> mes("even if you press the same")
          |> mes("switch more than once.")
          |> next()
          |> mes("[Dorian]")
          |> mes("Please let me know")
          |> mes("if you get it started so")
          |> mes("I can verify if the Mystic")
          |> mes("Dryer de Elegance is fully")
          |> mes("operational. Good luck now~")
          |> close()
        else
          ctx
          |> mes("[Dorian]")
          |> mes("Oh? You're still missing")
          |> mes("some materials. Well, we're")
          |> mes("in no rush. If you already")
          |> mes("forgot, then let me remind")
          |> mes("you what you need to bring...")
          |> next()
          |> mes("[Dorian]")
          |> mes("Please procure")
          |> mes("^FF000020 Rusty Screws^000000,")
          |> mes("^FF000010 Iron Ores^000000,")
          |> mes("^FF00005 Steel^000000,")
          |> mes("^FF00002 Rubies^000000, and")
          |> mes("^FF000010 Red Gemstones^000000.")
          |> close()
        end

      get_char_var(ctx, :diamond_edq, 0) == 10 ->
        {ctx, instruction_choice} =
          ctx
          |> mes("[Dorian]")
          |> mes("Did you already forget")
          |> mes("my instructions for fixing my")
          |> mes("Mystic Dryer de Elegance?")
          |> mes("I can't blame you since")
          |> mes("they're a bit complicated.")
          |> next()
          |> select(["Instructions", "Cancel"])

        case instruction_choice do
          1 ->
            ctx
            |> mes("[Dorian]")
            |> mes("First, insert a new rough")
            |> mes("ruby into the ruby engine,")
            |> mes("and tighten the screw on")
            |> mes("the joint until you hear")
            |> mes("a ^0000FFclick^000000. You'll break it")
            |> mes("if you tighten it further.")
            |> next()
            |> mes("[Dorian]")
            |> mes("Next you'll need to")
            |> mes("operate the four switches")
            |> mes("coded by the colors red,")
            |> mes("blue, yellow, and green.")
            |> next()
            |> mes("[Dorian]")
            |> mes("Press the ^0000FFRed^000000 switch")
            |> mes("if the engine is in 1st")
            |> mes("Gear. Press the ^0000FFBlue^000000")
            |> mes("switch in 2nd Gear,")
            |> mes("^0000FFYellow^000000 for 3rd, and")
            |> mes("^0000FFGreen^000000 for 4th.")
            |> next()
            |> mes("[Dorian]")
            |> mes("The engine's sound is the")
            |> mes("only indicator of which")
            |> mes("gear is running. You'll")
            |> mes("have to figure that out")
            |> mes("on your own. I'm sorry")
            |> mes("I designed it that way...")
            |> next()
            |> mes("[Dorian]")
            |> mes("Ah, one last tip!")
            |> mes("If you enter the correct")
            |> mes("engine gear, the machine")
            |> mes("will start without a problem,")
            |> mes("even if you press the same")
            |> mes("switch more than once.")
            |> next()
            |> mes("[Dorian]")
            |> mes("Please let me know")
            |> mes("if you get it started so")
            |> mes("I can verify if the Mystic")
            |> mes("Dryer de Elegance is fully")
            |> mes("operational. Good luck now~")
            |> close()

          2 ->
            ctx
            |> mes("[Dorian]")
            |> mes("Really? It's no problem")
            |> mes("for me to explain it again")
            |> mes("to you. Don't be shy now:")
            |> mes("not all of us can be geniuses~")
            |> close()

          _ ->
            ctx
        end

      get_char_var(ctx, :diamond_edq, 0) == 11 ->
        ctx
        |> mes("[Dorian]")
        |> mes("Ah, so you failed to")
        |> mes("fix the Mystic Dryer de")
        |> mes("Elegance? That's expected:")
        |> mes("I didn't really design it for the common user in mind. Well,")
        |> mes("why don't you try it again?")
        |> changequest(3106, 3105)
        |> set_char_var(:diamond_edq, 10)
        |> close()

      get_char_var(ctx, :diamond_edq, 0) == 12 ->
        ctx
        |> mes("[Dorian]")
        |> mes("Ah, I underestimated you.")
        |> mes("You really repaired the")
        |> mes("Mystic Dryer de Elegance~")
        |> mes("This is a testament to my")
        |> mes("incredible teaching prowess.")
        |> mes("Congratulations are in order!")
        |> next()
        |> mes("[Dorian]")
        |> mes("Now all you have to do")
        |> mes("is insert the damaged")
        |> mes("document and press the")
        |> mes("switch. Simple, yes?")
        |> changequest(3107, 3108)
        |> set_char_var(:diamond_edq, 13)
        |> next()
        |> mes("[Dorian]")
        |> mes("Well, I'm afraid my")
        |> mes("usefulness to you has")
        |> mes("been all used up. Ah,")
        |> mes("but I'll make sure to")
        |> mes("contact you if I need")
        |> mes("your kind of help. Farewell~")
        |> close()

      get_char_var(ctx, :diamond_edq, 0) > 12 ->
        ctx
        |> mes("[Dorian]")
        |> mes("Ah, hello! How have")
        |> mes("you been? Are you in need")
        |> mes("of my artistic inventions?")
        |> mes("Or did you just miss me?")
        |> close()

      true ->
        ev_ontouch(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp discuss_dryer(ctx) do
    {ctx, request} =
      ctx
      |> mes("[Dorian]")
      |> mes("I am Inventor Dorian,")
      |> mes("and I welcome you to my")
      |> mes("workship. All I create is")
      |> mes("infused with art's essence~")
      |> mes("So... How may I assist you?")
      |> next()
      |> select([
        "I want to use your Magic Dryer.",
        "I want to be your student.",
        "No, thanks."
      ])

    case request do
      1 ->
        ask_dryer_purpose(ctx)

      2 ->
        if sex(ctx) == 1 do
          ctx
          |> mes("[Dorian]")
          |> mes("Ah, my apologies.")
          |> mes("Too many have asked, so")
          |> mes("I now only accept beautiful")
          |> mes("female students. Don't be")
          |> mes("too disappointed: I know")
          |> mes("you can find someone else.")
          |> close()
        else
          ctx
          |> mes("[Dorian]")
          |> mes("Mademoiselle, it is my")
          |> mes("honor to meet you: even")
          |> mes("the moon covers its face,")
          |> mes("and roses raise their thorns,")
          |> mes("shameful of themselves")
          |> mes("and jealous of your beauty.")
          |> next()
          |> mes("[Dorian]")
          |> mes("Ah! But why go under the")
          |> mes("pretense of being my student")
          |> mes("when we can leisurely spend")
          |> mes("time together as lovers?")
          |> mes("Won't you--Mademoiselle?")
          |> mes("Wait, where are you going?")
          |> close()
        end

      3 ->
        ctx
        |> mes("[Dorian]")
        |> mes("I don't have enough")
        |> mes("time for trivel, so")
        |> mes("please leave me to my")
        |> mes("artistic endeavors and")
        |> mes("bother me no longer.")
        |> close()

      _ ->
        ctx
    end
  end

  defp ask_dryer_purpose(ctx) do
    {ctx, dryer_request} =
      ctx
      |> mes("[Dorian]")
      |> mes("Magic Dryer? No, no, no.")
      |> mes("That, my friend, is my")
      |> mes("Mystic Heater de Elegance.")
      |> mes("Don't disgrace my creation")
      |> mes("like that. What, pray tell,")
      |> mes("do you need to dry?")
      |> next()
      |> select(["This Bond of Debt", "My Hair", "I'm just curious."])

    case dryer_request do
      1 ->
        discuss_bond(ctx)

      2 ->
        ctx
        |> mes("[Dorian]")
        |> mes("How can you compare my")
        |> mes("Mystic Dryer de Elegance")
        |> mes("to a simple hair dryer?")
        |> mes("Your comment offends me!")
        |> mes("I'm no mere engineer...")
        |> mes("I'm a true virtuoso!")
        |> set_char_var(:diamond_edq, 7)
        |> close()

      3 ->
        ctx =
          ctx
          |> mes("[Dorian]")
          |> mes("Allow me to explain how")
          |> mes("the Mystic Dryer de Elegance")
          |> mes("works. A glamourous ruby")
          |> mes("engine whose design was born")
          |> mes("of my genius, generates a")
          |> mes("powerful magnetic field.")
          |> next()
          |> mes("[Dorian]")
          |> mes("The ruby engine's")
          |> mes("magnetic field operates")
          |> mes("according to the ^FF00003 Centrifuge")
          |> mes("Wavelength Theory^000000. Now,")
          |> mes("pearl inset sensors detect")
          |> mes("the amount of calibration...")
          |> next()
          |> mes("[Dorian]")
          |> mes("...............................")
          |> mes("...............................")
          |> mes("...............................")
          |> mes("...............................")
          |> mes("...............................")
          |> mes("...............................")
          |> next()
          |> mes("[Dorian]")
          |> mes("...............................")
          |> mes("...............................")
          |> mes("...............................")
          |> mes("...............................")
          |> mes("Blah-blah--that's just")
          |> mes("about it in a nutshell.")
          |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("......")
        |> next()
        |> mes("[Dorian]")
        |> mes("I know, I know.")
        |> mes("Astounding, isn't it?")
        |> close()

      _ ->
        ctx
    end
  end

  defp discuss_bond(ctx) do
    {ctx, reaction} =
      ctx
      |> mes("[Dorian]")
      |> mes("Mm? My masterpiece is far")
      |> mes("too sophisticated for such")
      |> mes("petty purposes, but... You")
      |> mes("intrigue me. Show me this")
      |> mes("''bond of debt'' you wish")
      |> mes("to restore. ")
      |> next()
      |> mes("[Dorian]")
      |> mes("Ah, now I understand.")
      |> mes("This print is beyond")
      |> mes("recognition. Only my creation")
      |> mes("can restore the life that")
      |> mes("nature has taken away! Yes...")
      |> mes("You were right to come here.")
      |> next()
      |> mes("[Dorian]")
      |> mes("Allow me to explain how")
      |> mes("the Mystic Dryer de Elegance")
      |> mes("works. A glamourous ruby")
      |> mes("engine whose design was born")
      |> mes("of my genius, generates a")
      |> mes("powerful magnetic field.")
      |> next()
      |> mes("[Dorian]")
      |> mes("The ruby engine's")
      |> mes("magnetic field operates")
      |> mes("according to the ^FF00003 Centrifuge")
      |> mes("Wavelength Theory^000000. Now,")
      |> mes("pearl inset sensors detect")
      |> mes("the amount of calibration...")
      |> next()
      |> mes("[Dorian]")
      |> mes("...............................")
      |> mes("...............................")
      |> mes("...............................")
      |> mes("...............................")
      |> mes("...............................")
      |> mes("...............................")
      |> next()
      |> mes("[Dorian]")
      |> mes("...............................")
      |> mes("...............................")
      |> mes("...............................")
      |> mes("...............................")
      |> mes("Blah-blah--that's just")
      |> mes("about it in a nutshell.")
      |> next()
      |> select(["Zzz...", "Oh, please!"])

    case reaction do
      1 ->
        {ctx, answer} =
          ctx
          |> mes("[Dorian]")
          |> mes("You... You fell asleep?")
          |> mes("But I was dutifully explaining")
          |> mes("the machine's operation!")
          |> mes("No, no, I won't hear your")
          |> mes("excuses. What's that?")
          |> mes("You were listening?")
          |> next()
          |> mes("[Dorian]")
          |> mes("Hm. Well then, let me")
          |> mes("ask you this: what is the")
          |> mes("main theory by which the")
          |> mes("Mystic Heater de Elegance")
          |> mes("operates? Hmm? Well?")
          |> next()
          |> input(:string)

        ctx = set_local(ctx, :"input$", answer)

        if get_local(ctx, :"input$", "") == "3 Centrifuge Wavelength Theory" do
          ctx
          |> mes("[Dorian]")
          |> mes("That's right. My apologies.")
          |> mes("I suppose I misjudged you.")
          |> mes("Yes, the magnetic field can")
          |> mes("restore the shape and integrity")
          |> mes("of damaged, inanimate objects.")
          |> mes("However, there is a problem.")
          |> next()
          |> mes("[Dorian]")
          |> mes("The ruby engine is broken,")
          |> mes("and I've been too busy with")
          |> mes("other projects as ordered by")
          |> mes("the Rune-Midgarts Kingdom.")
          |> mes("I'll need your assistance")
          |> mes("to fix the engine. Alright?")
          |> next()
          |> mes("[Dorian]")
          |> mes("If you help me fix the")
          |> mes("Mystic Dryer de Elegance,")
          |> mes("I'll allow you to use it")
          |> mes("as much as you like. First,")
          |> mes("I'd like you to gather all")
          |> mes("of the repair materials.")
          |> next()
          |> mes("[Dorian]")
          |> mes("Please procure")
          |> mes("^FF000020 Rusty Screws^000000,")
          |> mes("^FF000010 Iron Ores^000000,")
          |> mes("^FF00005 Steel^000000,")
          |> mes("^FF00002 Rubies^000000, and")
          |> mes("^FF000010 Red Gemstones^000000.")
          |> next()
          |> mes("[Dorian]")
          |> mes("Once you bring all the")
          |> mes("repair materials, I'll")
          |> mes("explain how you can")
          |> mes("repair the Mystic")
          |> mes("Dryer de Elegance.")
          |> changequest(3103, 3104)
          |> set_char_var(:diamond_edq, 9)
          |> close()
        else
          ctx
          |> mes("[Dorian]")
          |> mes("Oh? You sound dissatisfied")
          |> mes("with my explanation. Well...")
          |> mes("I surely can't let you use the")
          |> mes("machine unless you fathom")
          |> mes("how it works. Otherwise,")
          |> mes("you just might break it.")
          |> close()
        end

      2 ->
        ctx
        |> mes("[Dorian]")
        |> mes("Were you too bored while")
        |> mes("listening to me speak?")
        |> mes("Ah! This wound! It's so...")
        |> mes("Alas! It's too emotional!")
        |> mes("I am seriously hurt!")
        |> set_char_var(:diamond_edq, 7)
        |> close()

      _ ->
        ctx
    end
  end

  def ev_ontouch(ctx) do
    cond do
      get_char_var(ctx, :diamond_edq, 0) < 9 ->
        ctx
        |> mes("[Dorian]")
        |> mes("Wh-what are you doing?")
        |> mes("D-don't sully my wonderful")
        |> mes("masterpieces with your")
        |> mes("uncultured hands!")
        |> close()

      get_char_var(ctx, :diamond_edq, 0) == 9 ->
        ctx
        |> mes("[Dorian]")
        |> mes("Can't you see that the")
        |> mes("machine won't work without")
        |> mes("the materials? Even a simple")
        |> mes("child should understand that!")
        |> close()

      true ->
        ctx
    end
  end
end
