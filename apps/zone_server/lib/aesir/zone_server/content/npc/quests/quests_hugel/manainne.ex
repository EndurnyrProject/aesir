defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Manainne do
  @moduledoc """
  Manainne helps uncover the memories surrounding Hugel’s tree.

  ## Behavior

  - Advances the Memory Quest and hosts Kanainne’s spirit.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "hugel", x: 191, y: 172, dir: 3, sprite: 892, name: "Manainne", scope: :shared}
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :hg_memory, 0) do
      1 ->
        ctx
        |> mes("[Manainne]")
        |> mes("This tree means so much")
        |> mes("to everyone in this town,")
        |> mes("and we all have special")
        |> mes("memories of this place. But")
        |> mes("that El Schatt fellow plans to")
        |> mes("chop it down for his shop...")
        |> next()
        |> mes("[Manainne]")
        |> mes("You see him? That's")
        |> mes("El Schatt right there.")
        |> mes("I've never met anyone")
        |> mes("so cruel and selfish!")
        |> mes("Right now he's surveying")
        |> mes("the land for construction...")
        |> set_char_var(:hg_memory, 2)
        |> changequest(8057, 8058)
        |> close()

      2 ->
        ctx
        |> mes("[Manainne]")
        |> mes("This tree means so much")
        |> mes("to everyone in this town,")
        |> mes("and we all have special")
        |> mes("memories of this place. But")
        |> mes("that El Schatt fellow plans to")
        |> mes("chop it down for his shop...")
        |> next()
        |> mes("[Manainne]")
        |> mes("You see him? That's")
        |> mes("El Schatt right there.")
        |> mes("I've never met anyone")
        |> mes("so cruel and selfish!")
        |> mes("Right now he's surveying")
        |> mes("the land for construction...")
        |> close()

      5 ->
        ctx
        |> mes("[Manainne]")
        |> mes("You know, El Schatt and")
        |> mes("I used to get along when")
        |> mes("he dated my older sister,")
        |> mes("Kanainne. In fact, they'd")
        |> mes("always spend time together right under that tree. Weird, huh?")
        |> next()
        |> mes("[Manainne]")
        |> mes("Then, well, Kanainne")
        |> mes("got really sick, and we...")
        |> mes("We couldn't help her. She")
        |> mes("passed away, and then El Schatt")
        |> mes("just disappeared. It was only")
        |> mes("recently that he's come back.")
        |> next()
        |> mes("[Manainne]")
        |> mes("Now El Schatt is just a")
        |> mes("heartless, money grubbing...!")
        |> mes("He's completely changed.")
        |> mes("My sister would be rolling")
        |> mes("in her grave, seeing him now...")
        |> set_char_var(:hg_memory, 6)
        |> changequest(8061, 8062)
        |> close()

      6 ->
        ctx
        |> mes("[Manainne]")
        |> mes("Now El Schatt is just a")
        |> mes("heartless, money grubbing...!")
        |> mes("He's completely changed.")
        |> mes("My sister would be rolling")
        |> mes("in her grave, seeing him now...")
        |> close()

      7 ->
        ctx
        |> mes("[Manainne]")
        |> mes("What? That's...")
        |> mes("That's an incredible")
        |> mes("story. You met my dead")
        |> mes("sister in Niflheim?! You")
        |> mes("must be lying to me!")
        |> next()
        |> mes("[Manainne]")
        |> mes("Let's... Let's just")
        |> mes("stop talking about this,")
        |> mes("okay? I appreciate that you")
        |> mes("want to stop El Schatt from")
        |> mes("cutting down our tree, but")
        |> mes("this is almost too much.")
        |> next()
        |> set_char_var(:hg_memory, 8)
        |> mes("[Manainne]")
        |> mes("Gosh, all that talk")
        |> mes("about Niflheim is...")
        |> mes("It's giving me the chills!")
        |> mes("A-aren't you cold?")
        |> close()

      8 ->
        ctx
        |> mes("[Manainne]")
        |> mes("......")
        |> mes(".........")
        |> mes("Huh? You're...")
        |> mes("Still here...?")
        |> next()
        |> mes("[Manainne]")
        |> mes("Y-you know what's")
        |> mes("weird? The weather's")
        |> mes("perfectly fine, but I...")
        |> mes("I feel so cold all of a")
        |> mes("sudden. You don't feel")
        |> mes("it at all, don't you?")
        |> next()
        |> mes("[Manainne]")
        |> mes("I think I'm coming down")
        |> mes("with something. My head")
        |> mes("feels so numb, and I c-can't")
        |> mes("focus any of my thoughts.")
        |> mes("This is freakin' me out...")
        |> next()
        |> mes("[Manainne]")
        |> mes("...!")
        |> next()
        |> set_char_var(:hg_memory, 9)
        |> mes("[Manainne]")
        |> mes("......")
        |> mes("..........")
        |> close()

      9 ->
        ctx
        |> mes("[Manainne]")
        |> mes("...I'm here. I'm really")
        |> mes("back! Oh, it's been so")
        |> mes("long! Hello, adventurer,")
        |> mes("remember me? I'm Kanainne,")
        |> mes("the spirit you saw down in")
        |> mes("Niflheim. Let me explain...")
        |> next()
        |> mes("[Manainne]")
        |> mes("My spirit was able to follow")
        |> mes("you here, and now that I'm")
        |> mes("here, I only have so much time")
        |> mes("to possess my sister's body,")
        |> mes("and then talk to El Schatt.")
        |> mes("El Schatt? El Schatt...?")
        |> next()
        |> mes("[El Schatt]")
        |> mes("Manainne...?")
        |> mes("What do you want?")
        |> mes("Quit bugging me,")
        |> mes("I'm busy right now...")
        |> next()
        |> mes("[Manainne]")
        |> mes("It's... It's me,")
        |> mes("El Schatt, it's Kanainne.")
        |> mes("Of course you remember")
        |> mes("me, right? Listen, I need to--")
        |> next()
        |> mes("[El Schatt]")
        |> mes("Manainne...?!")
        |> mes("I'm shocked...")
        |> mes("Don't you respect")
        |> mes("your own sister?!")
        |> mes("I can't believe you'd...")
        |> mes("Knock it off right now!")
        |> next()
        |> set_char_var(:hg_memory, 10)
        |> mes("[El Schatt]")
        |> mes("Look, out of my respect")
        |> mes("for you and the relationship")
        |> mes("that me and your sister had,")
        |> mes("I'm going to forget you said")
        |> mes("that. But don't you dare use")
        |> mes("her name that way again!")
        |> next()
        |> mes("[Manainne]")
        |> mes("......")
        |> mes(".........")
        |> mes("............")
        |> close()

      10 ->
        ctx
        |> mes("[Manainne]")
        |> mes("Wait, El Schatt!")
        |> mes("It's really me, but")
        |> mes("I can only speak to you")
        |> mes("through my sister for")
        |> mes("a short time. L-listen...")
        |> next()
        |> mes("[El Schatt]")
        |> mes("Manainne...")
        |> mes("You don't make jokes")
        |> mes("like that about the departed,")
        |> mes("especially if it's Kannaine.")
        |> mes("You know better than that!")
        |> mes("Where the hell's your respect?!")
        |> next()
        |> mes("[Manainne]")
        |> mes("''If you're the wind,")
        |> mes("I'll be the sky, so that you")
        |> mes("can fly freely in my arms...''")
        |> next()
        |> mes("[El Schatt]")
        |> mes("Huh...?!")
        |> next()
        |> mes("[Manainne]")
        |> mes("''My soul is just")
        |> mes("for you, the shining")
        |> mes("sun that brightens")
        |> mes("up my whole world.''")
        |> next()
        |> mes("[El Schatt]")
        |> mes("How do you...")
        |> mes("How do you know")
        |> mes("those words...?")
        |> next()
        |> mes("[Manainne]")
        |> mes("''In my dream, your")
        |> mes("eyes held the reflection")
        |> mes("of the ocean's clear waters... Someday I'll show them to you.''")
        |> next()
        |> mes("[Manainne]")
        |> mes("''Your lovely face,")
        |> mes("your enticing smile...")
        |> mes("They're forever be in my")
        |> mes("heart, so I'll never be lonely.''")
        |> next()
        |> mes("[El Schatt]")
        |> mes("Manainne...")
        |> mes("How do you")
        |> mes("know that song?")
        |> next()
        |> mes("[Manainne]")
        |> mes("El Schatt...")
        |> mes("It's me, Kanainne.")
        |> mes("You wrote this song")
        |> mes("just for me. But I died")
        |> mes("before you could finish it.")
        |> next()
        |> mes("[Manainne]")
        |> mes("That was your dream,")
        |> mes("wasn't it? To play your")
        |> mes("beautiful music to make")
        |> mes("people happy? Did you ever")
        |> mes("finish our song for me?")
        |> next()
        |> mes("[El Schatt]")
        |> mes("Hahahah, Manainne, alright.")
        |> mes("Your sister must have told")
        |> mes("you about that song. Ha ha...")
        |> mes("You're t-taking it too far...")
        |> mes("Please, just... Just stop.")
        |> next()
        |> mes("[Manainne]")
        |> mes("El Schatt...")
        |> mes("Listen to me.")
        |> mes("Look at me. It's")
        |> mes("really your Kanainne.")
        |> next()
        |> mes("[El Schatt]")
        |> mes("Kanainne...?")
        |> mes("It's too much to")
        |> mes("believe. I want to")
        |> mes("believe it so badly...")
        |> mes("Is it really you?")
        |> set_char_var(:hg_memory, 11)
        |> close()

      11 ->
        ctx |> mes("[Manainne]") |> mes("El Schatt...") |> close()

      12 ->
        ctx
        |> mes("^3355FFManainne is sobbing")
        |> mes("uncontrollably, and there's")
        |> mes("nothing you can do to comfort")
        |> mes("her. Nothing at all. You must")
        |> mes("leave her alone to her despair")
        |> mes("and unfathomable sense of loss.^000000")
        |> close()

      _ ->
        ctx
        |> mes("[Manainne]")
        |> mes("You know, even though")
        |> mes("it's not a wealthy area,")
        |> mes("I really love this small")
        |> mes("and quiet town. Even if")
        |> mes("I could live anywhere in")
        |> mes("the world, I'd live right here~")
        |> close()
    end
  end
end
