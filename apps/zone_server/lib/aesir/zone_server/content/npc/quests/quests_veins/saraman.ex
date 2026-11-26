defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.Saraman do
  @moduledoc """
  Saraman helps the player obtain soap ingredients and recover his camel.

  ## Behavior

  - Requests ingredients for a camel appetite stimulant and advances the siblings quest.
  - Sends the player to find Soony and rewards her recovery.

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
    spawn: [%{map: "veins", x: 115, y: 59, dir: 5, sprite: 847, name: "Saraman", scope: :shared}]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :rachel_camel, 0)

    cond do
      Rathena.truthy?(stage) and stage < 7 ->
        ctx
        |> mes("[Saraman]")
        |> mes("Zzzzz...")
        |> mes("Zzz... Zzzzzz...")
        |> close()

      stage == 7 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Excuse me. Hello~")
        |> mes("Ms. Ivory sent me")
        |> mes("here with these soap")
        |> mes("ingredients? She said")
        |> mes("I had to come to you if")
        |> mes("I wanted her to make it.")
        |> next()
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("Soap, eh? Oh, I see.")
        |> mes("You must be here to get")
        |> mes("some fresh camel dung.")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Wh-what?")
        |> mes("My God!")
        |> mes("A-are you sure?")
        |> mes("Tell me you're joking!")
        |> next()
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("Sure as sin, and")
        |> mes("honest to God.")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("...............................")
        |> mes("...............................")
        |> mes("...............................")
        |> next()
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("Yeah, those ingredients")
        |> mes("you brought me? They're for")
        |> mes("making soap alright. ^FF0000That's")
        |> mes("what we feed the camels^000000 so")
        |> mes("that they make a whole lotta")
        |> mes("dung. Dung to make soap.")
        |> next()
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("Oh, don't worry. Camel")
        |> mes("dung is sterile, completely")
        |> mes("safe. In fact, it smells nice,")
        |> mes("has medicinal properties, and")
        |> mes("it's considered a delicacy")
        |> mes("in certain countries.")
        |> next()
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("Sadly, Silk Sand Camels")
        |> mes("are almost extinct, so I only")
        |> mes("have one on this farm. That's")
        |> mes("why we have a special contract with Ms. Ivory to make her soap.")
        |> next()
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("Say... I wasn't expecting")
        |> mes("her to send a deliveryman")
        |> mes("until tomorrow. Why are")
        |> mes("you here so early anyway?")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Actually, this is kind")
        |> mes("of an emergency. You see,")
        |> mes("I need the soap to make a")
        |> mes("key mold because I lost--")
        |> next()
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("Never mind, never mind.")
        |> mes("I'm sorry I asked! So this")
        |> mes("is a personal favor for you,")
        |> mes("huh? Well, there's a bit of")
        |> mes("a problem that we need to")
        |> mes("solve first. Listen up...")
        |> next()
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("We can only get camel")
        |> mes("dung after a camel eats,")
        |> mes("right? Well, my camel isn't")
        |> mes("used to eating so late in the")
        |> mes("day. Even if we put food in")
        |> mes("front of her, she won't eat it.")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("What? Isn't there")
        |> mes("something we can do?")
        |> mes("I mean, I'm talking about")
        |> mes("a life or death matter!")
        |> next()
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("*Sigh* ...This isn't good... Okay then, let's do this.")
        |> mes("Sometimes I make an appetite stimulant for the camel")
        |> mes("when she's sick and wouldn't eat anything.")
        |> mes("We can try feeding her the stimulant, and make it poop.")
        |> next()
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("Well, we can't forcefeed")
        |> mes("her, but we can get her to")
        |> mes("munch a bit on some appetite")
        |> mes("stimulant. I usually use that")
        |> mes("if she's sick, but if you say")
        |> mes("that this is an emergency...")
        |> next()
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("Alright, I guess we")
        |> mes("can try it. But I want you")
        |> mes("to bring me the ingredients.")
        |> mes("Get me... Let's see now...")
        |> next()
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("^4D4DFF1 Unripe Apple^000000,")
        |> mes("^4D4DFF5 Monster's Feed^000000,")
        |> mes("^4D4DFF1 Empty Bottle^000000, and")
        |> mes("^4D4DFF1 Yellow Potion^000000.")
        |> changequest(3066, 3067)
        |> set_char_var(:rachel_camel, 8)
        |> close()

      stage == 8 and ingredients?(ctx) ->
        ctx
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("Oh good, you're back.")
        |> mes("Did you bring everything?")
        |> mes("Here, I need to mix it all")
        |> mes("together first before you")
        |> mes("can feed it to my camel.")
        |> mes("Just a minute now...")
        |> next()
        |> mes("^3355FFSaraman mixed all")
        |> mes("of the ingredients,")
        |> mes("and gingerly poured")
        |> mes("them into a bottle.^000000")
        |> next()
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("Alright, now bring")
        |> mes("this to the camels over")
        |> mes("there. Only my Silk Sand")
        |> mes("Camel will know to eat it,")
        |> mes("so she'll come after you.")
        |> next()
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("Once she nibbles this")
        |> mes("appetite stimulant, she'll")
        |> mes("eat her feed like crazy.")
        |> mes("Then the dung will flow")
        |> mes("like a faucet. Come on,")
        |> mes("why don't you give it a try?")
        |> next()
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("Oh, right. You should")
        |> mes("be able to get 5 lumps")
        |> mes("of camel dung with those")
        |> mes("ingredients. That's a good")
        |> mes("amount to collect since that's")
        |> mes("what Ms. Ivory usually orders.")
        |> delitem(528, 5)
        |> delitem(503, 1)
        |> delitem(619, 1)
        |> delitem(713, 1)
        |> changequest(3067, 3068)
        |> set_char_var(:rachel_camel, 9)
        |> close()

      stage == 8 ->
        ctx
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("Well, we can't forcefeed")
        |> mes("her, but we can get her to")
        |> mes("munch a bit on some appetite")
        |> mes("stimulant. I usually use that")
        |> mes("if she's sick, but if you say")
        |> mes("that this is an emergency...")
        |> next()
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("Alright, I guess we")
        |> mes("can try it. But I want you")
        |> mes("to bring me the ingredients.")
        |> mes("Get me... Let's see now...")
        |> next()
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("^4D4DFF1 Unripe Apple^000000,")
        |> mes("^4D4DFF5 Monster's Feed^000000,")
        |> mes("^4D4DFF1 Empty Bottle^000000, and")
        |> mes("^4D4DFF1 Yellow Potion^000000.")
        |> close()

      stage == 9 ->
        ctx
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("Once she nibbles this")
        |> mes("appetite stimulant, she'll")
        |> mes("eat her feed like crazy.")
        |> mes("Then the dung will flow")
        |> mes("like a faucet. Come on,")
        |> mes("why don't you give it a try?")
        |> next()
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("Oh, right. You should")
        |> mes("be able to get 5 lumps")
        |> mes("of camel dung with those")
        |> mes("ingredients. That's a good")
        |> mes("amount to collect since that's")
        |> mes("what Ms. Ivory usually orders.")
        |> close()

      stage == 10 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Mr. Saraman, none")
        |> mes("of the camels will eat")
        |> mes("this appetite stimulant...")
        |> mes("Am I doing something wrong?")
        |> next()
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("Oh, yes, well...")
        |> mes("One of my workers")
        |> mes("just came by, and told me")
        |> mes("that my Silk Sand Camel")
        |> mes("disappeared somewhere...")
        |> mes("This is terrible news!")
        |> next()
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("My precious Silk Sand")
        |> mes("Camel... It's my biggest")
        |> mes("business investment! I'm")
        |> mes("ruined without it! Please...")
        |> mes("I'll reward you if you can")
        |> mes("find my camel for me!")
        |> next()
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("Damn it! My stupid worker")
        |> mes("forgot to tie her up, so")
        |> mes("she ended up running away!")
        |> mes("Ugh! Please help me find her!")
        |> mes("Without her, you won't be able")
        |> mes("to get your special camel dung.")
        |> next()
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("Wait, don't panic...")
        |> mes("It'll all be alright.")
        |> mes("This camel moves very slowly")
        |> mes("so she shouldn't be far from")
        |> mes("here. Please find my camel")
        |> mes("Soony as soon as you can!")
        |> changequest(3069, 3070)
        |> set_char_var(:rachel_camel, 11)
        |> close()

      stage == 11 ->
        ctx
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("Soony! Soony...!")
        |> mes("Wh-where are you?!")
        |> next()
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("Please, help me find")
        |> mes("my Soony, my Silk Sand")
        |> mes("Camel. You won't be able to")
        |> mes("make your soap without her!")
        |> mes("And my business is really")
        |> mes("dependent on my Soony!")
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
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("Oh, it's you!")
        |> mes("Did you find my")
        |> mes("Soony? Where is she?")
        |> mes("What happened to her?")
        |> mes("Oh God, I don't know what")
        |> mes("I'll do without that camel!")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Don't worry, Mr. Saraman,")
        |> mes("I found Soony at the outskirts")
        |> mes("of town. She hurt her leg so")
        |> mes("I think it'd be a good idea if")
        |> mes("you sent some people to")
        |> mes("help bring her back.")
        |> next()
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("Thank god! Thank you, thank you so much!")
        |> mes("I'll send my workers over there immediately.")
        |> next()
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("Thank goodness, you have")
        |> mes("no idea how valuable that")
        |> mes("camel is! I'll send some of")
        |> mes("my men to bring her home")
        |> mes("immediately! Thank you,")
        |> mes("you just saved my business!")
        |> next()
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("Here, I want you to")
        |> mes("have this. Consider it")
        |> mes("a little thank you gift for")
        |> mes("what you've done for me.")
        |> mes("Good luck with getting")
        |> mes("that soap you want made.")
        |> changequest(3076, 3077)
        |> give_item(617, 1)
        |> set_char_var(:rachel_camel, 18)
        |> close()

      stage == 18 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Let's see...")
        |> mes("Shouldn't I be going")
        |> mes("to see Ms. Ivory now?")
        |> close()

      stage > 18 and stage < 24 ->
        ctx
        |> mes("[Camel Farm Owner Saraman]")
        |> mes("Thank you for finding my")
        |> mes("precious Silk Sand Camel")
        |> mes("Soony. Come again sometime,")
        |> mes("and maybe we can special my")
        |> mes("special camel yogurt together.")
        |> close()

      true ->
        ctx
        |> mes("[Saraman]")
        |> mes("Zzz... Zzz~")
        |> mes("Zzz...")
        |> next()
        |> mes("^3355FFWatching this man")
        |> mes("snore also makes you")
        |> mes("want to take a snooze.^000000")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp ingredients?(ctx) do
    count_item(ctx, 528) > 4 and count_item(ctx, 503) > 0 and count_item(ctx, 619) > 0 and
      count_item(ctx, 713) > 0
  end
end
