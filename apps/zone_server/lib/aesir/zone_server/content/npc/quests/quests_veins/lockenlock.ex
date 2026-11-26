defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.Lockenlock do
  @moduledoc """
  The locksmith helps rescue Curdie by providing a key.

  ## Behavior

  - Guides the player through the soap mold and key stages of the rescue.

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
    spawn: [
      %{map: "veins", x: 181, y: 166, dir: 3, sprite: 900, name: "Lockenlock", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      Rathena.truthy?(get_char_var(ctx, :rachel_camel, 0)) and
          get_char_var(ctx, :rachel_camel, 0) < 4 ->
        ctx
        |> mes("^3355FFIt's a drunkard...")
        |> mes("The scent of pure")
        |> mes("alcohol wafts around him.")
        |> mes("There's a certain beauty")
        |> mes("to his disheveled misery.^000000")
        |> close()

      get_char_var(ctx, :rachel_camel, 0) == 4 ->
        cond do
          count_item(ctx, 503) > 0 ->
            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("Excuse me...?")
            |> next()
            |> mes("[Locksmith Lockenlock]")
            |> mes("Huh? Arrrgh...")
            |> mes("My head... What")
            |> mes("do you want?")
            |> next()
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("Oh, I'd like")
            |> mes("to make a key.")
            |> next()
            |> mes("[Locksmith Lockenlock]")
            |> mes("Keys? Yeah, yeah...")
            |> mes("That's what I do.")
            |> mes("If you've got the lock,")
            |> mes("it'll be a piece of cake.")
            |> next()
            |> mes("[Locksmith Lockenlock]")
            |> mes("Ugh, but I'm so thirsty")
            |> mes("and this headache is")
            |> mes("killing me. You mind")
            |> mes("bringing me a Yellow")
            |> mes("Potion first?")
            |> next()
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("Sure, I guess.")
            |> mes("I can part with just")
            |> mes("1 Yellow Potion.")
            |> mes("Here you go.")
            |> next()
            |> mes("[Locksmith Lockenlock]")
            |> mes("Ah, that hit the spot!")
            |> mes("Wait, wait... Now I feel")
            |> mes("dizzy... What's going...")
            |> mes("What's going on...?")
            |> next()
            |> mes("[Locksmith Lockenlock]")
            |> mes("Okay, okay...")
            |> mes("I'm alright now.")
            |> mes("So what'd you say you")
            |> mes("needed? A key? Did you")
            |> mes("bring the lock with you?")
            |> next()
            |> mes("[Locksmith Lockenlock]")
            |> mes("I'm an expert in crafting")
            |> mes("keys and locks. Hell, my locks")
            |> mes("are strong enough to hold down")
            |> mes("a dragon, you know that? I'll")
            |> mes("have you know that the Rachel")
            |> mes("Army's a regular customer~")
            |> next()
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("(^333333This guy made locks for")
            |> mes("the Rachel army?! It might")
            |> mes("not be a good idea to let him")
            |> mes("know that I'm trying to free")
            |> mes("one of their prisoners. Who")
            |> mes("knows if he's loyal to them?^000000)")
            |> next()
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("So what happened was...")
            |> mes("I lost my key, but I can't")
            |> mes("bring the lock here with me.")
            |> mes("I think I'd end up breaking")
            |> mes("it if I brought it with me.")
            |> next()
            |> mes("[Locksmith Lockenlock]")
            |> mes("Oh, yeah? No problem.")
            |> mes("Just take me to the lock.")
            |> mes("I'll charge you extra, though,")
            |> mes("especially since my knees")
            |> mes("are going bad. So where")
            |> mes("are we going exactly?")
            |> next()
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("Wait!")
            |> mes("We can't do that!")
            |> next()
            |> mes("[Locksmith Lockenlock]")
            |> mes("What do you mean?")
            |> mes("You're not trying to")
            |> mes("open up a bank safe")
            |> mes("or something, are you?")
            |> next()
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("No, it's nothing like")
            |> mes("that! It's just that the lock")
            |> mes("is in a dangerous place.")
            |> mes("This is really important...")
            |> mes("Please, you have to help me!")
            |> next()
            |> mes("[Locksmith Lockenlock]")
            |> mes("Huh. Well, bottom line,")
            |> mes("I can't make a key without")
            |> mes("looking at the lock. Let me")
            |> mes("think of a way I can help you.")
            |> mes("Give me a second, will you?")
            |> next()
            |> mes("[Locksmith Lockenlock]")
            |> mes("...............................")
            |> mes("Well, I guess you can try")
            |> mes("to make a mold of the lock.")
            |> mes("It'll have to be perfect, so")
            |> mes("this'll get pretty expensive.")
            |> next()
            |> mes("[Locksmith Lockenlock]")
            |> mes("Go to the market and")
            |> mes("find a lady selling organic")
            |> mes("soap. You need to get a bottle")
            |> mes("of Chamelepu Soap. You will")
            |> mes("need that exact type of soap:")
            |> mes("nothing else will do.")
            |> next()
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("Chamelpu Soap?")
            |> mes("What is th--")
            |> next()
            |> mes("[Locksmith Lockenlock]")
            |> mes("No time to explain.")
            |> mes("You'd better hurry and")
            |> mes("find her before she closes")
            |> mes("shop for the day. The shop")
            |> mes("owner's a beauty, so it'll")
            |> mes("be tough for you to miss her.")
            |> next()
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("...........")
            |> delitem(503, 1)
            |> changequest(3063, 3064)
            |> set_char_var(:rachel_camel, 5)
            |> close()

          true ->
            ctx
            |> mes("^3355FFIt's a drunkard...")
            |> mes("This man must be the")
            |> mes("Mr. Lockenlock that you seek.")
            |> mes("You'd better follow Toby's")
            |> mes("advice and bring this man")
            |> mes("a Yellow Potion first.^000000")
            |> close()
        end

      get_char_var(ctx, :rachel_camel, 0) == 5 ->
        ctx
        |> mes("[Locksmith Lockenlock]")
        |> mes("Go to the market and")
        |> mes("find a lady selling organic")
        |> mes("soap, and get a bottle of")
        |> mes("Chamelepu Soap. You will")
        |> mes("need that exact type of soap:")
        |> mes("nothing else will do.")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Chamelpu Soap?")
        |> mes("What is th--")
        |> next()
        |> mes("[Locksmith Lockenlock]")
        |> mes("No time to explain.")
        |> mes("You'd better hurry and")
        |> mes("find her before she closes")
        |> mes("shop for the day. The shop")
        |> mes("owner's a beauty, so it'll")
        |> mes("be tough for you to miss her.")
        |> close()

      get_char_var(ctx, :rachel_camel, 0) == 6 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Wait... I should be")
        |> mes("bringing Ms. Ivory all")
        |> mes("of the soap ingredients.")
        |> mes("What were they again...?")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("^4D4DFF10 Milk^000000,")
        |> mes("^4D4DFF100 Green Herbs^000000,")
        |> mes("^4D4DFF50 Jellopies^000000, and")
        |> mes("^4D4DFF5 Empty Bottles^000000.")
        |> mes("I better get those...")
        |> close()

      get_char_var(ctx, :rachel_camel, 0) == 7 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("I need to talk to")
        |> mes("someone named Saraman")
        |> mes("to get the soap ingredients...")
        |> close()

      get_char_var(ctx, :rachel_camel, 0) == 8 ->
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

      get_char_var(ctx, :rachel_camel, 0) == 9 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("I have everything I need")
        |> mes("to stimulate a camel's")
        |> mes("appetite. Now I need to")
        |> mes("feed the camel so that I can")
        |> mes("get the soap ingredients and")
        |> mes("5 lumps of camel dung.")
        |> close()

      get_char_var(ctx, :rachel_camel, 0) == 10 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Right now, my time")
        |> mes("would be better spent")
        |> mes("looking for the Silk Sand")
        |> mes("Camel for the ingredients.")
        |> close()

      get_char_var(ctx, :rachel_camel, 0) == 11 ->
        ctx
        |> mes(
          Rathena.concat(
            Rathena.concat("[", char_name(ctx, 0)),
            "]"
          )
        )
        |> mes("I'd better find Mr. Saraman's")
        |> mes("lost camel, feed it camel")
        |> mes("appetite stimulants, and")
        |> mes("then get the soap ingredient")
        |> mes("and 5 lumps of camel dung")
        |> mes("if I want to free Curdie.")
        |> close()

      get_char_var(ctx, :rachel_camel, 0) == 12 ->
        ctx
        |> mes(
          Rathena.concat(
            Rathena.concat("[", char_name(ctx, 0)),
            "]"
          )
        )
        |> mes("Well... I found the")
        |> mes("camel. Now I need to get")
        |> mes("all the soap ingredients.")
        |> mes("The sooner I do that, the")
        |> mes("sooner I can help Curdie.")
        |> close()

      get_char_var(ctx, :rachel_camel, 0) > 12 and
          get_char_var(ctx, :rachel_camel, 0) < 17 ->
        ctx
        |> mes("^3355FFYou already found the")
        |> mes("camel, so you need to collect")
        |> mes("the soap ingredients if you")
        |> mes("want to free Curdie.^000000")
        |> close()

      get_char_var(ctx, :rachel_camel, 0) == 17 ->
        ctx
        |> mes(
          Rathena.concat(
            Rathena.concat("[", char_name(ctx, 0)),
            "]"
          )
        )
        |> mes("I managed to get the soap")
        |> mes("ingredients: 5 of those")
        |> mes("camel dung lumps. I should")
        |> mes("head back to Mr. Saraman to")
        |> mes("tell him where his camel is,")
        |> mes("and then go to Ms. Ivory.")
        |> close()

      get_char_var(ctx, :rachel_camel, 0) == 18 ->
        ctx
        |> mes(
          Rathena.concat(
            Rathena.concat(
              "[",
              char_name(ctx, 0)
            ),
            "]"
          )
        )
        |> mes("Let's see...")
        |> mes("Shouldn't I be going")
        |> mes("to see Ms. Ivory now?")
        |> close()

      get_char_var(ctx, :rachel_camel, 0) ==
          19 ->
        ctx
        |> mes("[Locksmith Lockenlock]")
        |> mes("Oh, so you're finally")
        |> mes("back with the Chamelpu")
        |> mes("Soap. What took so long?")
        |> mes("All you had to do was go")
        |> mes("to the market and buy it.")
        |> next()
        |> mes(
          Rathena.concat(
            Rathena.concat(
              "[",
              char_name(ctx, 0)
            ),
            "]"
          )
        )
        |> mes("...............................")
        |> mes("...............................")
        |> mes("...............................")
        |> mes("...............................")
        |> mes("...............................")
        |> mes("...............................")
        |> next()
        |> mes("[Locksmith Lockenlock]")
        |> mes("Uh, anyway, did Ms. Ivory")
        |> mes("tell you how to use the soap?")
        |> mes("You just pour it into the")
        |> mes("keyhole, and then pour the")
        |> mes("soap back into the bottle.")
        |> mes("Do it carefully and quickly.")
        |> next()
        |> mes("[Locksmith Lockenlock]")
        |> mes("Make sure you close the")
        |> mes("bottle tightly when you're")
        |> mes("done so no air gets into it.")
        |> mes("If you take more than thirty")
        |> mes("seconds, the soap won't retain")
        |> mes("the lock's shape very well.")
        |> next()
        |> mes("[Locksmith Lockenlock]")
        |> mes("Pour the liquid soap to the key hole in the lock,")
        |> mes("pour the soap back to the bottle.")
        |> mes("and close the lid so tightly that the air wouldn't go inside the bottle.")
        |> mes("Remember, you can't take longer than 30 seconds to finish the procedures.")
        |> next()
        |> mes("[Locksmith Lockenlock]")
        |> mes("Finally, bring the bottle")
        |> mes("back here for me so that")
        |> mes("I can make the key. But when")
        |> mes("you come back, I need to make")
        |> mes("sure that the key you're making")
        |> mes("isn't for anything illegal...")
        |> next()
        |> mes(
          Rathena.concat(
            Rathena.concat(
              "[",
              char_name(ctx, 0)
            ),
            "]"
          )
        )
        |> mes("Alright.")
        |> changequest(3078, 3079)
        |> set_char_var(:rachel_camel, 20)
        |> close()

      get_char_var(ctx, :rachel_camel, 0) ==
          20 ->
        ctx
        |> mes(
          Rathena.concat(
            Rathena.concat(
              "[",
              char_name(ctx, 0)
            ),
            "]"
          )
        )
        |> mes("I'd better use the soap to")
        |> mes("make a key mold that I can")
        |> mes("bring over to Mr. Lockenlock.")
        |> close()

      get_char_var(ctx, :rachel_camel, 0) == 21 ->
        ctx
        |> mes("[Locksmith Lockenlock]")
        |> mes("Oh, you're back...")
        |> mes("So did you manage")
        |> mes("to make the key mold?")
        |> next()
        |> mes(
          Rathena.concat(
            Rathena.concat(
              "[",
              char_name(ctx, 0)
            ),
            "]"
          )
        )
        |> mes("Yes, I did. Would you")
        |> mes("please hurry? This is an")
        |> mes("emergency, and it could")
        |> mes("get really bad if I don't")
        |> mes("get this key made soon...")
        |> next()
        |> mes("[Locksmith Lockenlock]")
        |> mes("Let me see... Well,")
        |> mes("it's not really perfect, but")
        |> mes("I should be able to fashion")
        |> mes("a key for this lock. Ooh...")
        |> mes("But you know what? I don't")
        |> mes("have any materials on me.")
        |> next()
        |> mes("[Locksmith Lockenlock]")
        |> mes("I've already made all")
        |> mes("the keys and locks for this")
        |> mes("town, so no one's really had")
        |> mes("to send in any orders lately.")
        |> mes("That's why I didn't have any")
        |> mes("materials onhand. Sorry.")
        |> next()
        |> mes("[Locksmith Lockenlock]")
        |> mes("All I need is ^4D4DFF1 Steel^000000.")
        |> mes("It won't take me more")
        |> mes("than five minutes to make")
        |> mes("the key, so I can get it done")
        |> mes("as soon as you can bring")
        |> mes("me the Steel. I'll be waiting.")
        |> changequest(3080, 3081)
        |> set_char_var(
          :rachel_camel,
          22
        )
        |> close()

      get_char_var(ctx, :rachel_camel, 0) == 22 ->
        cond do
          count_item(ctx, 999) > 0 ->
            ctx
            |> mes(
              Rathena.concat(
                Rathena.concat(
                  "[",
                  char_name(
                    ctx,
                    0
                  )
                ),
                "]"
              )
            )
            |> mes("Here's the Steel that")
            |> mes("you need. Would you")
            |> mes("please make the key now?")
            |> next()
            |> mes("[Locksmith Lockenlock]")
            |> mes("...............................")
            |> mes("I've been studying")
            |> mes("this key mold, and")
            |> mes("I just realized something...")
            |> mes("Tell me right now: what")
            |> mes("are you using this key for?")
            |> next()
            |> mes(
              Rathena.concat(
                Rathena.concat(
                  "[",
                  char_name(
                    ctx,
                    0
                  )
                ),
                "]"
              )
            )
            |> mes("Huh...?")
            |> mes("What are you...?")
            |> next()
            |> mes("[Locksmith Lockenlock]")
            |> mes("I asked you first.")
            |> mes("Tell me what you intend")
            |> mes("to do with this key! If you")
            |> mes("don't, I can't help you.")
            |> next()
            |> mes("[Locksmith Lockenlock]")
            |> mes("Don't lie to me.")
            |> mes("This mold... This is")
            |> mes("the lock for the shackles")
            |> mes("that I've made under the")
            |> mes("orders of the Rachel Army.")
            |> mes("I have the master key for that.")
            |> next()
            |> mes("[Locksmith Lockenlock]")
            |> mes("These shackles are only")
            |> mes("supposed to be used for")
            |> mes("prisoners! If I release one")
            |> mes("of them, they will hunt you")
            |> mes("down and hold me accountable.")
            |> next()
            |> mes(
              Rathena.concat(
                Rathena.concat(
                  "[",
                  char_name(
                    ctx,
                    0
                  )
                ),
                "]"
              )
            )
            |> mes("The truth is... I really")
            |> mes("am trying to free somebody")
            |> mes("the Rachel Army imprisoned...")
            |> mes("She's Curdie, a young girl")
            |> mes("that they locked up in")
            |> mes("Thor Volcano...")
            |> next()
            |> mes("[Locksmith Lockenlock]")
            |> mes("What...?!")
            |> mes("Are you serious?")
            |> mes("Y-you're... No way.")
            |> mes("You're not lying. This...")
            |> mes("I'm sorry. You shouldn't")
            |> mes("have gotten involved, but...")
            |> next()
            |> mes("[Locksmith Lockenlock]")
            |> mes("Oh God!")
            |> mes("They... They")
            |> mes("really imprisoned")
            |> mes("an innocent child?!")
            |> next()
            |> mes("[Locksmith Lockenlock]")
            |> mes("Here. Take it.")
            |> mes("Take the master key.")
            |> mes("Bring it to Thor Volcano")
            |> mes("and rescue that poor kid.")
            |> mes("We could get in a lot of")
            |> mes("trouble for doing this, but...")
            |> next()
            |> mes("[Locksmith Lockenlock]")
            |> mes("My conscience won't allow")
            |> mes("them to do something like")
            |> mes("this. Rescue that kid, and")
            |> mes("then throw the key away")
            |> mes("somewhere when you're done.")
            |> next()
            |> mes("[Locksmith Lockenlock]")
            |> mes("That way, if the army")
            |> mes("comes to interrogate me,")
            |> mes("I'll just say that it was")
            |> mes("stolen from my shop by")
            |> mes("some thief. I should get")
            |> mes("rid of all my keys too...")
            |> next()
            |> mes("[Locksmith Lockenlock]")
            |> mes("Hurry up and go!")
            |> mes("Make sure that you")
            |> mes("bring that child back")
            |> mes("safe to her family!")
            |> changequest(
              3081,
              3082
            )
            |> set_char_var(
              :rachel_camel,
              23
            )
            |> close()

          true ->
            ctx
            |> mes("[Locksmith Lockenlock]")
            |> mes("All I need is ^4D4DFF1 Steel^000000.")
            |> mes("It won't take me more")
            |> mes("than five minutes to make")
            |> mes("the key, so I can get it done")
            |> mes("as soon as you can bring")
            |> mes("me the Steel. I'll be waiting.")
            |> close()
        end

      get_char_var(ctx, :rachel_camel, 0) == 23 ->
        ctx
        |> mes("[Locksmith Lockenlock]")
        |> mes("Here. Take it.")
        |> mes("Take the master key.")
        |> mes("Bring it to Thor Volcano")
        |> mes("and rescue that poor kid.")
        |> mes("We could get in a lot of")
        |> mes("trouble for doing this, but...")
        |> next()
        |> mes("[Locksmith Lockenlock]")
        |> mes("Hurry up and go!")
        |> mes("Make sure that you")
        |> mes("bring that child back")
        |> mes("safe to her family!")
        |> close()

      get_char_var(ctx, :rachel_camel, 0) in [24, 25] ->
        ctx
        |> mes("[Locksmith Lockenlock]")
        |> mes("Hey, that kid you saved...")
        |> mes("Curdie. She's safely back")
        |> mes("in town. I feel so responsible")
        |> mes("about what happened. I mean,")
        |> mes("she was locked up in shackles")
        |> mes("that I designed for the army.")
        |> next()
        |> mes("[Locksmith Lockenlock]")
        |> mes("Anyway, I'm packing my")
        |> mes("things. I'm thinking of")
        |> mes("leaving this town for good.")
        |> mes("The army's rotten to the core")
        |> mes("for doing something like this.")
        |> next()
        |> mes("[Locksmith Lockenlock]")
        |> mes("You're a real good person,")
        |> mes("and I'm glad I got to know")
        |> mes("you. I don't know if we'll")
        |> mes("ever meet again, but it's")
        |> mes("good that there are people")
        |> mes("like you in this world.")
        |> close()

      true ->
        ctx
        |> mes("[Lockenlock]")
        |> mes("Zzzz...")
        |> mes("Zzzz... Argh!")
        |> mes("...Zzz...")
        |> next()
        |> mes("^3355FFHe's drunk and")
        |> mes("fast asleep.^000000")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
