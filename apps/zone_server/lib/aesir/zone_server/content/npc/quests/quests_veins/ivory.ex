defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.Ivory do
  @moduledoc """
  Ivory makes the soap needed to rescue Curdie.

  ## Behavior

  - She requests ingredients, directs the player to the camel farm, and makes soap
    as the quest advances.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "veins", x: 227, y: 127, dir: 5, sprite: 940, name: "Ivory", scope: :shared}]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :rachel_camel, 0)

    cond do
      Rathena.truthy?(stage) and stage < 5 ->
        ctx
        |> mes("[Organic Soap Maker Ivory]")
        |> mes("I need to make more of")
        |> mes("my soap, but I've run out")
        |> mes("of ingredients. Well, there's")
        |> mes("not much I can do without them,")
        |> mes("so maybe it'd be better if")
        |> mes("I just close up shop today...")
        |> close()

      stage == 5 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Excuse me...?")
        |> next()
        |> mes("[Organic Soap Maker Ivory]")
        |> mes("Oh, I'm sorry, but I'm")
        |> mes("closing shop right now")
        |> mes("because I just ran out of")
        |> mes("soap ingredients. If you")
        |> mes("ordered something, then you")
        |> mes("could just come back tomorrow.")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Um, this is an emergency!")
        |> mes("Mr. Lockenlock told me to")
        |> mes("come here to get some kind")
        |> mes("of special soap. I need it")
        |> mes("to make a mold for him")
        |> mes("to make a key for me...")
        |> next()
        |> mes("[Organic Soap Maker Ivory]")
        |> mes("Oh? You locked yourself")
        |> mes("out? Ah, Mr. Lockenlock")
        |> mes("must have been talking")
        |> mes("about my organic Chamelepu")
        |> mes("soap. It's an artistic soap")
        |> mes("that you can shape easily~")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Yes, that's right!")
        |> mes("Chamelepu Soap!")
        |> next()
        |> mes("[Organic Soap Maker Ivory]")
        |> mes("My Chamelepu Soap")
        |> mes("is pretty popular. It's")
        |> mes("a liquid soap that you can")
        |> mes("pour into anything, and it'll")
        |> mes("harden into any shape that")
        |> mes("you want. Neat, huh?")
        |> next()
        |> mes("[Organic Soap Maker Ivory]")
        |> mes("Well, as I told you earlier,")
        |> mes("I ran out of every soap ingredient,")
        |> mes("so I cannot make any more soap today.")
        |> mes("You should come back tomorrow evening")
        |> mes("if you want to buy the soap.")
        |> next()
        |> mes("[Organic Soap Maker Ivory]")
        |> mes("If you really need it")
        |> mes("right away, I can still")
        |> mes("make it for you if can")
        |> mes("bring all the ingredients.")
        |> mes("They might be a bit hard")
        |> mes("to obtain, though...")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("That's fine. The")
        |> mes("important thing for me")
        |> mes("is to get this soap as")
        |> mes("soon as I possibly can!")
        |> next()
        |> mes("[Organic Soap Maker Ivory]")
        |> mes("Alright, first I want")
        |> mes("you to bring me the basic")
        |> mes("stuff. Bring these items")
        |> mes("in the exact amounts I ask")
        |> mes("for, alright? Ratios are pretty")
        |> mes("important in making soap.")
        |> next()
        |> mes("[Organic Soap Maker Ivory]")
        |> mes("^4D4DFF10 Milk^000000,")
        |> mes("^4D4DFF100 Green Herbs^000000,")
        |> mes("^4D4DFF50 Jellopies^000000, and")
        |> mes("^4D4DFF5 Empty Bottles^000000.")
        |> mes("Then we can move")
        |> mes("on to the hard part.")
        |> changequest(3064, 3065)
        |> set_char_var(:rachel_camel, 6)
        |> close()

      stage == 6 and count_item(ctx, 511) > 99 and count_item(ctx, 909) > 49 and
        count_item(ctx, 519) > 9 and count_item(ctx, 713) > 4 ->
        ctx
        |> mes("[Organic Soap Maker Ivory]")
        |> mes("Oh, great! You brought")
        |> mes("everything! Now... It's")
        |> mes("time for you to do the,")
        |> mes("um, hard part.")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("...............................")
        |> mes("...............................")
        |> mes("...............................")
        |> next()
        |> mes("[Organic Soap Maker Ivory]")
        |> mes("Please tell the")
        |> mes("Silk Sand Camel farm")
        |> mes("owner in town that I sent")
        |> mes("you, and show him the")
        |> mes("ingredients that you've")
        |> mes("gathered for me so far.")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Wait...")
        |> mes("Why would I want")
        |> mes("to see the guy that")
        |> mes("takes care of Silk Sand")
        |> mes("Camels? What does he")
        |> mes("have to do with soap?")
        |> next()
        |> mes("[Organic Soap Maker Ivory]")
        |> mes("Don't sweat it for now...")
        |> mes("Just go visit Mr. Saraman,")
        |> mes("the Camel Farm owner.")
        |> mes("I can't wait for you that long,")
        |> mes("so please come back here")
        |> mes("as soon as possible.")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Mr. Saraman...?")
        |> mes("Okay, so I need to visit")
        |> mes("him if I really need you")
        |> mes("to make the soap...")
        |> changequest(3065, 3066)
        |> set_char_var(:rachel_camel, 7)
        |> close()

      stage == 6 ->
        ctx
        |> mes("[Organic Soap Maker Ivory]")
        |> mes("Alright, first I want")
        |> mes("you to bring me the basic")
        |> mes("stuff. Bring these items")
        |> mes("in the exact amounts I ask")
        |> mes("for, alright? Ratios are pretty")
        |> mes("important in making soap.")
        |> next()
        |> mes("[Organic Soap Maker Ivory]")
        |> mes("^4D4DFF10 Milk^000000,")
        |> mes("^4D4DFF100 Green Herbs^000000,")
        |> mes("^4D4DFF50 Jellopies^000000, and")
        |> mes("^4D4DFF5 Empty Bottles^000000.")
        |> mes("Then we can move")
        |> mes("on to the hard part.")
        |> close()

      stage == 7 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("I need to talk to")
        |> mes("someone named Saraman")
        |> mes("to get the soap ingredients...")
        |> close()

      stage == 8 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Let's see...")
        |> mes("I need to bring")
        |> mes("Mr. Saruman all the")
        |> mes("things he needs to")
        |> mes("stimulate a camel's ")
        |> mes("appetite. I need to get...")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("^4D4DFF1 Unripe Apple^000000,")
        |> mes("^4D4DFF5 Monster's Feed^000000,")
        |> mes("^4D4DFF1 Empty Bottle^000000, and")
        |> mes("^4D4DFF1 Yellow Potion^000000.")
        |> close()

      stage == 9 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("I have everything I need")
        |> mes("to stimulate a camel's")
        |> mes("appetite. Now I need to")
        |> mes("feed the camel so that I can")
        |> mes("get the soap ingredients and")
        |> mes("5 lumps of camel dung.")
        |> close()

      stage == 10 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Right now, my time")
        |> mes("would be better spent")
        |> mes("looking for the Silk Sand")
        |> mes("Camel for the ingredients.")
        |> close()

      stage == 11 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("I'd better find Mr. Saraman's")
        |> mes("lost camel, feed it camel")
        |> mes("appetite stimulants, and")
        |> mes("then get the soap ingredient")
        |> mes("and 5 lumps of camel dung")
        |> mes("if I want to free Curdie.")
        |> close()

      stage == 12 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Well... I found the")
        |> mes("camel. Now I need to get")
        |> mes("all the soap ingredients.")
        |> mes("The sooner I do that, the")
        |> mes("sooner I can help Curdie.")
        |> close()

      stage > 12 and stage < 17 ->
        ctx
        |> mes("^3355FFYou already found the")
        |> mes("camel, so you need to collect")
        |> mes("the soap ingredients if you")
        |> mes("want to free Curdie.^000000")
        |> close()

      stage == 17 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("I managed to get the soap")
        |> mes("ingredients: 5 of those")
        |> mes("camel dung lumps. I should")
        |> mes("head back to Mr. Saraman to")
        |> mes("tell him where his camel is,")
        |> mes("and then go to Ms. Ivory.")
        |> close()

      stage == 18 ->
        ctx
        |> mes("[Organic Soap Maker Ivory]")
        |> mes("Hm, did Soony give you")
        |> mes("any trouble? I'm guessing")
        |> mes("that's why it's been taking")
        |> mes("you so long to get all that")
        |> mes("camel dung over here.")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("It was a pretty big")
        |> mes("hassle... But hopefully,")
        |> mes("this will all be worth it.")
        |> mes("Anyway, take this camel")
        |> mes("dung. I don't want to")
        |> mes("handle it for much longer.")
        |> next()
        |> mes("[Organic Soap Maker Ivory]")
        |> mes("Yes, I can understand that.")
        |> mes("Even though it's in bottles,")
        |> mes("it's pretty gross that these")
        |> mes("bottles are still warm...")
        |> mes("Anyway, we're good to go.")
        |> mes("Let me make you some soap~")
        |> next()
        |> mes("[Organic Soap Maker Ivory]")
        |> mes("You spent a lot of")
        |> mes("time and energy to get")
        |> mes("these, so I won't charge")
        |> mes("you for my service. Besides,")
        |> mes("you brought enough materials")
        |> mes("that I'll have some left over.")
        |> next()
        |> mes("^3355FFMs. Ivory put on a pair")
        |> mes("of long gloves, and mixed")
        |> mes("the ingredients. She then")
        |> mes("placed them in a clean bottle.^000000")
        |> next()
        |> mes("[Organic Soap Maker Ivory]")
        |> mes("Here's your soap! After")
        |> mes("you pour the soap into")
        |> mes("something, don't forget")
        |> mes("to put it into a larger bottle")
        |> mes("after about twenty seconds.")
        |> next()
        |> mes("[Organic Soap Maker Ivory]")
        |> mes("And um... Don't let")
        |> mes("anyone else know what")
        |> mes("I use to make this soap.")
        |> mes("People won't buy it if they")
        |> mes("knew they were washing their")
        |> mes("faces with... You know...")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Don't worry, I won't")
        |> mes("tell anyone. Thanks")
        |> mes("for making the soap! ")
        |> next()
        |> mes("^3355FFNow that you have the")
        |> mes("Silk Sand Camel Soap.")
        |> mes("you should bring it")
        |> mes("to Mr. Lockenlock.^000000")
        |> changequest(3077, 3078)
        |> set_char_var(:rachel_camel, 19)
        |> close()

      stage == 19 ->
        ctx
        |> mes("^3355FFNow that you have the")
        |> mes("Silk Sand Camel Soap.")
        |> mes("you should bring it")
        |> mes("to Mr. Lockenlock.^000000")
        |> close()

      stage > 19 and stage < 26 ->
        ctx
        |> mes("[Organic Soap Maker Ivory]")
        |> mes("^333333*Phew!*^000000 It's been")
        |> mes("a long day. I think")
        |> mes("I'll close up shop now~")
        |> close()

      true ->
        ctx
        |> mes("[Beautiful Lady]")
        |> mes("Hm? Did you need")
        |> mes("something? I'm still")
        |> mes("setting up shop now")
        |> mes("so I'm not really ready")
        |> mes("to sell anything yet.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
