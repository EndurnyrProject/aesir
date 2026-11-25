defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Fishbone do
  @moduledoc """
  Fishbone offers access to the laboratory through a secret maze.

  ## Behavior

  - Guides eligible adventurers through a Jellopy request and sends them to the maze.
  - Reminds players of the sewer entrance after the quest is complete.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "lighthalzen", x: 341, y: 224, dir: 3, sprite: 868, name: "Fishbone", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      Rathena.truthy?(:erlang.band(get_char_var(ctx, :MISC_QUEST, 0), 512)) ->
        completed(ctx)

      get_char_var(ctx, :lhz_boss, 0) == 6 or base_level(ctx) >= 60 ->
        quest(ctx, get_char_var(ctx, :lhz_sincube, 0))

      base_level(ctx) < 60 ->
        too_young(ctx)

      get_char_var(ctx, :lhz_boss, 0) > 6 ->
        greet(ctx)

      true ->
        ctx
    end
  end

  defp quest(ctx, progress) do
    case progress do
      0 -> first_meeting(ctx)
      1 -> second_meeting(ctx)
      2 -> learn_about_lab(ctx)
      3 -> beg_for_access(ctx)
      4 -> request_jellopy(ctx)
      5 -> deliver_jellopy(ctx)
      6 -> first_trip(ctx)
      progress when progress < 10 -> repeat_trip(ctx)
      10 -> completed_trip(ctx)
      _ -> greet(ctx)
    end
  end

  defp completed(ctx) do
    ctx
    |> mes("[Fishbone]")
    |> mes("Oh hey, it's you!")
    |> mes("Now, listen. If you wanna")
    |> mes("get into Regenschirm again,")
    |> mes("you gotta enter that Sewer Pipe")
    |> mes("that's like, northeast from me.")
    |> mes("It's gross, but you gotta...")
    |> next()
    |> mes("[Fishbone]")
    |> mes("Anyway, good luck in")
    |> mes("whatever it is you're doing")
    |> mes("here in Lighthalzen. Oh, and")
    |> mes("be real careful! Something")
    |> mes("shadier than me is going")
    |> mes("on in this big city~")
    |> close()
  end

  defp too_young(ctx) do
    ctx
    |> mes("Hey kid, get")
    |> mes("outta here! Can't")
    |> mes("you tell I'm dealin'")
    |> mes("in something shady")
    |> mes("here? This is no place")
    |> mes("for baby faced guys like you!")
    |> close()
  end

  defp greet(ctx) do
    ctx
    |> mes("[Fishbone]")
    |> mes("Heya pal!")
    |> mes("It's been a while.")
    |> mes("You doin' good? I'm")
    |> mes("just peachy, thanks~")
    |> close()
  end

  defp first_meeting(ctx) do
    ctx
    |> mes("[Fishbone]")
    |> mes("What...?")
    |> mes("Is there something")
    |> mes("on my face? Quit looking")
    |> mes("at me and let me do my work.")
    |> set_char_var(:lhz_sincube, 1)
    |> close()
  end

  defp second_meeting(ctx) do
    ctx
    |> mes("[Fishbone]")
    |> mes("Hey. Hey you.")
    |> mes("You're still looking")
    |> mes("at me. Quit it. I'm busy")
    |> mes("here and you're bothering me.")
    |> set_char_var(:lhz_sincube, 2)
    |> close()
  end

  defp learn_about_lab(ctx) do
    ctx
    |> mes("[Fishbone]")
    |> mes("Seriously, you are")
    |> mes("starting to really get")
    |> mes("on my nerves! What could")
    |> mes("you possibly want from me?!")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", get_local(ctx, :"player_name$", "")), "]"))
    |> mes("Nothing really.")
    |> mes("I just feel like")
    |> mes("watching you work.")
    |> mes("What exactly are you")
    |> mes("doing anyway, huh?")
    |> next()
    |> mes("[Fishbone]")
    |> mes("Hey! If I could just show")
    |> mes("you what I'm doing, I wouldn't")
    |> mes("be so uptight about you looking")
    |> mes("at what I'm doing, now would I?")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", get_local(ctx, :"player_name$", "")), "]"))
    |> mes("Nah...")
    |> mes("I just think")
    |> mes("you're uptight")
    |> mes("in general.")
    |> next()
    |> mes("[Fishbone]")
    |> mes("Muthafruit!")
    |> mes("So you're just")
    |> mes("gonna sit and watch")
    |> mes("me all day?! Fine! Then")
    |> mes("I'll just ignore you, jerk!")
    |> next()
    |> mes("[Fishbone]")
    |> mes("...")
    |> mes("......")
    |> mes("Damn it!")
    |> mes("This is really")
    |> mes("ticking me off! Why")
    |> mes("don't you go away?!")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", get_local(ctx, :"player_name$", "")), "]"))
    |> mes("Well, I was also")
    |> mes("wondering why you're")
    |> mes("working in a place that's")
    |> mes("so, um... depressing.")
    |> next()
    |> mes("[Fishbone]")
    |> mes("Alright, fine!")
    |> mes("But once I tell you")
    |> mes("what I do here, you're")
    |> mes("outta here! Okay? Now,")
    |> mes("your lips are frickin' sealed.")
    |> mes("See, what I do is kinda illegal.")
    |> next()
    |> mes("[Fishbone]")
    |> mes("I provide routes that let")
    |> mes("people enter Lighthalzen,")
    |> mes("or even go anywhere in this")
    |> mes("city, without authorization.")
    |> mes("Hell, I could even get you")
    |> mes("into that Laboratory...")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", get_local(ctx, :"player_name$", "")), "]"))
    |> mes("W-wait!")
    |> mes("Laboratory?!")
    |> mes("Are you serious?")
    |> mes("Can you get me")
    |> mes("into that place?")
    |> next()
    |> mes("[Fishbone]")
    |> mes("Sonuva--You're not")
    |> mes("gonna leave me alone,")
    |> mes("are you? Look, you seem")
    |> mes("okay, even if you are kinda")
    |> mes("stubborn, kid. But I don't trust")
    |> mes("or serve strangers, period.")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", get_local(ctx, :"player_name$", "")), "]"))
    |> mes("But isn't there")
    |> mes("anything I can do")
    |> mes("so you can help me")
    |> mes("get into the Laboratory?")
    |> next()
    |> mes("[Fishbone]")
    |> mes("No way, no how.")
    |> mes("No matter how much you")
    |> mes("beg, I can't take a chance")
    |> mes("and just trust anyone who")
    |> mes("wants to know a secret")
    |> mes("route. Now get outta here!")
    |> set_char_var(:lhz_sincube, 3)
    |> close()
  end

  defp beg_for_access(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Please...")
    |> mes("Please tell me")
    |> mes("how I can get inside")
    |> mes("the Laboratory. I'm...")
    |> mes("I'm begging you!")
    |> next()
    |> mes("[Fishbone]")
    |> mes("No! Now shaddup")
    |> mes("and stop begging, okay?")
    |> mes("You're only embarassing")
    |> mes("yourself! Good grief...")
    |> set_char_var(:lhz_sincube, 4)
    |> close()
  end

  defp request_jellopy(ctx) do
    ctx = set_local(ctx, :"player_name$", char_name(ctx, 0))

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", get_local(ctx, :"player_name$", "")), "]"))
      |> mes("Why won't you")
      |> mes("heeeeelp meee?")
      |> mes("Pleeeeeeeease~")
      |> mes("You're the only one")
      |> mes("who knoooooows~")
      |> next()
      |> mes("[Fishbone]")
      |> mes("Yeesh, you're a nutty")
      |> mes("kid. Look, ''no'' means")
      |> mes("''no.'' That's it. That's")
      |> mes("final. How many times do")
      |> mes("you gotta make me spell it out?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", get_local(ctx, :"player_name$", "")), "]"))
      |> mes("But there's gotta")
      |> mes("be something I can")
      |> mes("do so you'll help me?")
      |> mes("Th-that's the way i-it")
      |> mes("always w-works. You")
      |> mes("can't just-- You c-can't...")
      |> next()
      |> mes("[Fishbone]")
      |> mes("Alright, you got me.")
      |> mes("But if I'm gonna risk")
      |> mes("my life to help you get")
      |> mes("into that Laboratory I want")
      |> mes("something in return. Okay?")
      |> next()
      |> mes("[Fishbone]")
      |> mes("All you need to do is")
      |> mes("come back here with")
      |> mes("^FF000071,381,305,294,921,000 zeny^000000.")
      |> mes("Then I'll give you all the help")
      |> mes("you need. Alright, good luck")
      |> mes("to you, brave adventurer.")
      |> next()

    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", get_local(ctx, :"player_name$", "")), "]"))
      |> mes("You're joking right?!")
      |> mes("There's no way I can ever")
      |> mes("get that much zeny! I'd...")
      |> mes("I'd have to at least take")
      |> mes("over the world or, or...")
      |> next()
      |> mes("[Fishbone]")
      |> mes("Good point.")
      |> mes("Fine, maybe that")
      |> mes("price is a little high.")
      |> mes("I'll just cut it in half,")
      |> mes("then. Still want my")
      |> mes("help? Then bring me...")
      |> next()
      |> mes("[Fishbone]")
      |> mes(" ")
      |> mes(" ")
      |> mes("...^FF000020 Jellopy^000000.")
      |> next()
      |> mes("[Fishbone]")
      |> mes("Gosh.")
      |> mes("It's like I'm")
      |> mes("doing this for free...")
      |> next()
      |> select(["Okay.", "No! It's impossible!"])

    if choice == 1 do
      ctx
      |> mes("[Fishbone]")
      |> mes("Alright, then")
      |> mes("bring me back a")
      |> mes("total of 20 Jellopy.")
      |> mes("But you gotta have")
      |> mes("exactly 20 Jellopy on")
      |> mes("you, okay? Seeya pal~")
      |> set_char_var(:lhz_sincube, 5)
      |> setquest(12_014)
      |> close()
    else
      ctx
      |> mes("[Fishbone]")
      |> mes("What are you--")
      |> mes("Okay, now you're the")
      |> mes("one who's joking around.")
      |> mes("Look, it's either bring me")
      |> mes("20 Jellopy or 71,381,3--")
      |> mes("whatever number I said-- zeny!")
      |> close()
    end
  end

  defp deliver_jellopy(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Fishbone]")
      |> mes("So...")
      |> mes("Did you bring")
      |> mes("the stuff?")
      |> next()
      |> select(["I'm still working on it.", "Here you go!", "Um... Stuff?"])

    case choice do
      1 ->
        ctx
        |> mes("[Fishbone]")
        |> mes("Still working on it?")
        |> mes("Okay, I know I didn't")
        |> mes("ask you for very much,")
        |> mes("but gimme some respect")
        |> mes("and get serious about it!")
        |> mes("It's 20 friggin' Jellopies!")
        |> close()

      2 ->
        if count_item(ctx, 909) < 20 do
          ctx
          |> mes("[Fishbone]")
          |> mes("Uh...")
          |> mes("I said 20 Jellopies,")
          |> mes("didn't I? This ain't")
          |> mes("enough pal, so go out")
          |> mes("and get some more!")
          |> close()
        else
          ctx
          |> mes("[Fishbone]")
          |> mes("Ooh. Hey, good work.")
          |> mes("Okay, I can see you're")
          |> mes("the reliable type. A deal")
          |> mes("is a deal, so I'll tell you")
          |> mes("how you can get inside")
          |> mes("that Laboratory.")
          |> next()
          |> mes("[Fishbone]")
          |> mes("Now, if you're wondering")
          |> mes("why I don't got much qualm")
          |> mes("against helping you, it's")
          |> mes("because I used to work in")
          |> mes("the Laboratory... But then")
          |> mes("they laid me off unfairly.")
          |> next()
          |> mes("[Fishbone]")
          |> mes("Anyway, anything I can")
          |> mes("do to cause them trouble")
          |> mes("is good in my book. Let me")
          |> mes("get some stuff ready and")
          |> mes("then I'll tell you what you")
          |> mes("really need to know.")
          |> delitem(909, 20)
          |> set_char_var(:lhz_sincube, 6)
          |> close()
        end

      3 ->
        ctx
        |> mes("[Fishbone]")
        |> mes("What the...?")
        |> mes("How could you forget")
        |> mes("something like that?")
        |> mes("Anyway, I asked you to")
        |> mes("bring 20 Jellopies.")
        |> close()

      _ ->
        ctx
    end
  end

  defp first_trip(ctx) do
    ctx = mes(ctx, "[Fishbone]")

    ctx =
      if get_char_var(ctx, :lhz_boss, 0) == 6 do
        ctx
        |> mes("way to get into Regenschrim")
        |> mes("Lab. However, I do know of")
        |> mes("this secret maze that should")
        |> mes("get you there. Still, if you're")
        |> mes("willing and ready to go...")
      else
        ctx
        |> mes("Okay...")
        |> mes("Are you ready now?")
        |> mes("I'm gonna send you")
        |> mes("someplace where you")
        |> mes("can find the Lab entrance.")
      end

    {ctx, choice} = ctx |> next() |> select(["Not yet.", "Yes."])

    if choice == 1 do
      ctx
      |> mes("[Fishbone]")
      |> mes("Eh...?")
      |> mes("Alright, it's")
      |> mes("not a problem.")
      |> mes("Just take your time.")
      |> close()
    else
      ctx
      |> mes("[Fishbone]")
      |> mes("Great!")
      |> mes("Okay then,")
      |> mes("here we go!")
      |> close2()
      |> set_char_var(:lhz_sincube, 7)
      |> send_to_maze()
    end
  end

  defp repeat_trip(ctx) do
    ctx =
      ctx
      |> mes("[Fishbone]")
      |> mes("Hm, you must not have")
      |> mes("accomplished whatever")

    ctx =
      if get_char_var(ctx, :lhz_boss, 0) == 6 do
        ctx |> mes("it is you need to do in the") |> mes("Regenschirm Laboratory yet.")
      else
        ctx |> mes("it was you were doing") |> mes("in the Laboratory. Do")
      end

    {ctx, choice} =
      ctx
      |> mes("you want me to send")
      |> mes("you there again?")
      |> next()
      |> select(["No.", "Yes."])

    if choice == 1 do
      ctx
      |> mes("[Fishbone]")
      |> mes("Geez, you must have")
      |> mes("really had a hard time")
      |> mes("there. Okay, well, when")
      |> mes("you're ready to go there,")
      |> mes("just let me know, got it?")
      |> close()
    else
      ctx
      |> mes("[Fishbone]")
      |> mes("Got a lot of")
      |> mes("spirit in you,")
      |> mes("don't you? Heh!")
      |> mes("I like you style~")
      |> mes("Get ready, 'cuz")
      |> mes("here we go...!")
      |> close2()
      |> set_char_var(:lhz_sincube, 7)
      |> send_to_maze()
    end
  end

  defp completed_trip(ctx) do
    ctx =
      ctx
      |> mes("[Fishbone]")
      |> mes("Hey, you came back!")
      |> mes("Good, I was starting")
      |> mes("to get a little worried")
      |> mes("about what happened to")
      |> mes("you. So did you get what")
      |> mes("you wanted over there?")

    ctx =
      if isbegin_quest(ctx, 12_014) == 1 do
        completequest(ctx, 12_014)
      else
        ctx
      end

    ctx = next(ctx)

    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Yeah...")
      |> mes("I hope so,")
      |> mes("anyway.")
      |> next()
      |> mes("[Fishbone]")
      |> mes("Good! Whatever you did,")
      |> mes("I hope it messes them up big")
      |> mes("time! I usedta be a respected")
      |> mes("scientist for Regenschirm till")
      |> mes("they laid me off! Serves those")
      |> mes("ungrateful jerkoffs right!")
      |> next()
      |> mes("[Fishbone]")
      |> mes("Then again, my current")
      |> mes("line of work seems to suit")
      |> mes("me much better. And I don't")
      |> mes("gotta worry about formulas")
      |> mes("and algorithms anymore.")
      |> next()
      |> mes("[Fishbone]")
      |> mes("Oh yeah, the place you")
      |> mes("just went to? There's a")
      |> mes("secret path the Laboratory")
      |> mes("there. If you want, I can")
      |> mes("send you back there. So")
      |> mes("what do you say?")
      |> next()
      |> select(["Sure", "No thanks~"])

    if choice == 1 do
      ctx
      |> mes("[Fishbone]")
      |> mes("Okay then, here")
      |> mes("we go! Good luck")
      |> mes("to you, buddy.")
      |> close2()
      |> send_to_maze()
    else
      ctx
      |> mes("[Fishbone]")
      |> mes("Alright, it's your")
      |> mes("choice. Oh, and that")
      |> mes("pass you have should")
      |> mes("let you into the Laboratory")
      |> mes("anyway. Good luck to you, pal.")
      |> close()
    end
  end

  defp send_to_maze(ctx) do
    case Enum.random(1..3) do
      1 -> warp(ctx, "lhz_cube", 67, 193)
      2 -> warp(ctx, "lhz_cube", 66, 136)
      3 -> warp(ctx, "lhz_cube", 66, 74)
      _ -> ctx
    end
  end
end
