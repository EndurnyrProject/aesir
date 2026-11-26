defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.LittleCurdie do
  @moduledoc """
  Curdie awaits rescue from her shackles in the volcano.

  ## Behavior

  - Guides the player through the rescue and updates the quest as it progresses.

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
      %{map: "que_thor", x: 36, y: 66, dir: 5, sprite: 941, name: "Little Curdie", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :rachel_camel, 0)

    cond do
      stage == 1 ->
        ctx
        |> mes("^3355FFYou come across")
        |> mes("a little girl lying on the")
        |> mes("ground unconscious.^000000")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Hey, kid! Wake up!")
        |> mes("Can you hear me?")
        |> next()
        |> mes("^3355FFShe has a pulse, but")
        |> mes("despite your verbal")
        |> mes("entreaties, she won't")
        |> mes("open her eyes. You")
        |> mes("lightly slap her cheek")
        |> mes("to wake her up.^000000")
        |> next()
        |> mes("[Little Curdie]")
        |> mes("Huh?!")
        |> mes("...Ah, owwww~")
        |> mes("W-waaaaaaaah!")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Sorry! I didn't mean")
        |> mes("to make you cry! Are...")
        |> mes("Are you alright?")
        |> next()
        |> mes("[Little Curdie]")
        |> mes("Huh? Wh-who are you?")
        |> mes("Oh no, you have to get")
        |> mes("out of here! You'll be in")
        |> mes("trouble if they catch you!")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Are you Curdie?")
        |> mes("Your brother Karyn")
        |> mes("asked me to rescue you.")
        |> mes("Come on, we've got to")
        |> mes("get you out of here.")
        |> next()
        |> mes("[Little Curdie]")
        |> mes("Karyn...?")
        |> mes("Oh, oh no! I... They")
        |> mes("locked me in these")
        |> mes("shackles and I can't move!")
        |> mes("You have to leave before")
        |> mes("those scary men come back!")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("What...?!")
        |> mes("Those bastards!")
        |> mes("Tying up a little")
        |> mes("girl like this...")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Argh! And I can't just")
        |> mes("use brute force to shatter")
        |> mes("these shackles! I might")
        |> mes("end up hurting you...!")
        |> next()
        |> mes("[Little Curdie]")
        |> mes("Don't worry about me...")
        |> mes("Just hurry and leave!")
        |> mes("I... I'll be alright! Now")
        |> mes("hurry! Someone's coming!")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Okay, I'll go...")
        |> mes("But sit tight, and")
        |> mes("wait for me to come")
        |> mes("back. I'll figure out")
        |> mes("some way to free you.")
        |> next()
        |> mes("[Little Curdie]")
        |> mes("^333333*Sob*^000000 R-really...?")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("I promise.")
        |> mes("I'm sure that someone")
        |> mes("in town will know of a way")
        |> mes("to unlock your shackles.")
        |> mes("I'll be back as soon as I can!")
        |> changequest(3060, 3061)
        |> set_char_var(:rachel_camel, 2)
        |> close()

      stage == 2 ->
        ctx
        |> mes("^3355FFSomeone in town")
        |> mes("must have the")
        |> mes("expertise to unlock")
        |> mes("these shackles. It's your")
        |> mes("only hope to free Curdie")
        |> mes("from these chains.^000000")
        |> close()

      stage in [3, 6, 8, 22] ->
        ctx |> mes("^3355FFCurdie is lying") |> mes("feebly on the ground.^000000") |> close()

      stage == 4 ->
        ctx
        |> mes("[Little Curdie]")
        |> mes("I hate the metal")
        |> mes("clanging sounds...")
        |> mes("Th-the sparks,")
        |> mes("they're... They're...")
        |> next()
        |> mes("^3355FFCurdie is curled up on")
        |> mes("the ground, eyes tightly")
        |> mes("shut, her entire body")
        |> mes("trembling with fear.^000000")
        |> close()

      stage == 5 ->
        ctx
        |> mes("^3355FFOn the ground, you see")
        |> mes("some equipment that looks")
        |> mes("similarly to that used by")
        |> mes("the Rachel soldiers.^000000")
        |> close()

      stage == 7 ->
        ctx
        |> mes("^3355FFIt seems that someone")
        |> mes("has come by to give")
        |> mes("Curdie food and water.^000000")
        |> close()

      stage == 9 ->
        ctx
        |> mes("^3355FFCurdie squints at you")
        |> mes("as you walk by. It seems")
        |> mes("that her vision gets worse")
        |> mes("the longer she's locked")
        |> mes("up in this cave.")
        |> close()

      stage == 10 ->
        ctx
        |> mes("^3355FFYou'd better find the")
        |> mes("Silk Sand Camel and get")
        |> mes("the soap ingredients if")
        |> mes("you really want to free")
        |> mes("Curdie from her shackles.^000000")
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

      stage > 11 and stage < 17 ->
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
        |> mes("^3355FFYou should be leaving")
        |> mes("to see Ms. Ivory now if")
        |> mes("you really want to free")
        |> mes("Curdie from her shackles.^000000")
        |> close()

      stage == 19 ->
        ctx
        |> mes("^3355FFNow that you have the")
        |> mes("Silk Sand Camel Soap,")
        |> mes("you should bring it")
        |> mes("over to Mr. Lockenlock.^000000")
        |> close()

      stage == 20 ->
        ctx
        |> mes("^3355FFCurdie is exactly")
        |> mes("where you left her.")
        |> mes("There's a bowl of cold")
        |> mes("soup next to her, so it's")
        |> mes("clear that someone has")
        |> mes("been feeding her.^000000")
        |> next()
        |> mes("^3355FFYou pour the soap into")
        |> mes("the shackle's lock to create")
        |> mes("a mold that Mr. Lockenlock")
        |> mes("can use to make a key.^000000")
        |> next()
        |> mes("[Little Curdie]")
        |> mes("Will...")
        |> mes("Will I always")
        |> mes("be stuck here?")
        |> mes("I... I want my mommy...")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Oh... You're awake?")
        |> mes("Don't worry, Curdie,")
        |> mes("I'm sure that I'll be")
        |> mes("able to get you free soon.")
        |> mes("Try to hold on a bit longer.")
        |> next()
        |> mes("[Little Curdie]")
        |> mes("When the door is open,")
        |> mes("I see blazing flames...")
        |> mes("And I hear... the sound")
        |> mes("of machines? These men")
        |> mes("wearing the same clothes")
        |> mes("keep marching past me...")
        |> next()
        |> mes("[Little Curdie]")
        |> mes("I... They scare me so much!")
        |> mes("Th-the man that brings me")
        |> mes("food says that they won't")
        |> mes("let me go because of what")
        |> mes("I saw inside there. They...")
        |> mes("They won't let be go home...")
        |> next()
        |> mes("^3355FFCurdie's eyes are")
        |> mes("disfocused and are")
        |> mes("pointed above your head.")
        |> mes("She might not survive if")
        |> mes("she's forced to remain")
        |> mes("here for much longer.^000000")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Don't worry.")
        |> mes("I'll come rescue")
        |> mes("you as soon as I make")
        |> mes("the key to unlock these")
        |> mes("awful shackles. Don't worry...")
        |> next()
        |> mes("[Little Curdie]")
        |> mes("If I'm not here the")
        |> mes("next time you come,")
        |> mes("then just run away.")
        |> mes("Don't even tell my brother.")
        |> mes("Get far away before they")
        |> mes("can catch you. I-I'm serious...")
        |> next()
        |> mes("[Little Curdie]")
        |> mes("Even if I don't see you")
        |> mes("again... I just... I just")
        |> mes("want to thank you for doing")
        |> mes("your best to help me.")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Everything will be")
        |> mes("alright. I just have")
        |> mes("to hurry a little bit.")
        |> mes("Alright, it's time to go.")
        |> next()
        |> mes("^3355FFYou extract the soap")
        |> mes("from the lock, and")
        |> mes("carefully wrap it.")
        |> mes("Now you need to take")
        |> mes("the mold back to town")
        |> mes("to Mr. Lockenlock.^000000")
        |> changequest(3079, 3080)
        |> set_char_var(:rachel_camel, 21)
        |> close()

      stage == 21 ->
        ctx
        |> mes("^3355FFYou have to hurry back")
        |> mes("to town and bring the")
        |> mes("key mold to Mr. Lockenlock")
        |> mes("so that he can make a key")
        |> mes("to unlock Curdie's shackles.^000000")
        |> close()

      stage == 23 ->
        ctx
        |> mes("[Little Curdie]")
        |> mes("Y-you...")
        |> mes("Is it really you?")
        |> next()
        |> mes(
          Rathena.concat(
            Rathena.concat("[", char_name(ctx, 0)),
            "]"
          )
        )
        |> mes("Hang on, Curdie!")
        |> mes("I hope this key works...")
        |> next()
        |> mes("^3355FFYou unlock the")
        |> mes("shackles with")
        |> mes("Mr. Lockenlock's key.^000000")
        |> next()
        |> mes("^333333*Crack*^000000")
        |> next()
        |> mes("[Little Curdie]")
        |> mes("Aaaah!")
        |> mes("M-my... My...!")
        |> next()
        |> mes("^3355FFCurdie's legs are")
        |> mes("swollen from the")
        |> mes("weight and pressure")
        |> mes("of wearing the shackles")
        |> mes("for such a long time.^000000")
        |> next()
        |> mes("[Little Curdie]")
        |> mes("I can't move my legs!")
        |> next()
        |> mes(
          Rathena.concat(
            Rathena.concat("[", char_name(ctx, 0)),
            "]"
          )
        )
        |> mes("Well, there's no other")
        |> mes("choice. Curdie, I'm")
        |> mes("going to send you back to")
        |> mes("town with a Butterfly Wing.")
        |> mes("Try not to move, alright?")
        |> next()
        |> mes("[Little Curdie]")
        |> mes("Oh! Thank you...")
        |> mes("I... I can go home...")
        |> mes("Thank you s-so much...")
        |> next()
        |> mes("^3355FFYou use the power")
        |> mes("of a Butterfly Wing to")
        |> mes("send Curdie back to")
        |> mes("town. Hopefully, she'll")
        |> mes("arrive safely and see")
        |> mes("her brother Karyn again.^000000")
        |> next()
        |> mes(
          Rathena.concat(
            Rathena.concat("[", char_name(ctx, 0)),
            "]"
          )
        )
        |> mes("What did she see behind")
        |> mes("the steel door in this old")
        |> mes("volcano? It must have been")
        |> mes("dangerous... Something")
        |> mes("related to the Rachel Army...")
        |> changequest(3082, 3083)
        |> set_char_var(:rachel_camel, 24)
        |> close()

      true ->
        ctx
        |> mes("[Little Curdie]")
        |> mes(" ...Wah....")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
