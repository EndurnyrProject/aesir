defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.YoungMan do
  @moduledoc """
  Kazien hires couriers for secret deliveries and tests their discretion.

  ## Behavior

  - Tests the player's discretion before assigning deliveries with Lyozien.
  - Rewards completed deliveries and confronts the player about their contents.
  - Occasionally gives rejected applicants another chance.

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
      %{
        map: "lhz_in01",
        x: 174,
        y: 258,
        dir: 3,
        sprite: 868,
        name: "Young Man",
        scope: :shared,
        unique_name: "Young Man#reken"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :lhz_rekenber, 0) do
      stage when stage > 21 -> after_confrontation(ctx)
      21 -> confront_kazien(ctx)
      stage when stage > 16 -> final_delivery_reminder(ctx)
      16 -> assign_final_delivery(ctx)
      stage when stage > 11 -> delivery_reminder(ctx)
      11 -> assign_second_delivery(ctx)
      stage when stage > 7 -> lyozien_reminder(ctx)
      7 -> assign_first_delivery(ctx)
      6 -> rejected_applicant(ctx)
      5 -> passed_test(ctx)
      4 -> failed_test(ctx)
      3 -> test_reminder(ctx)
      2 -> assign_test(ctx)
      1 -> offer_work(ctx)
      _ -> busy_greeting(ctx)
    end
  end

  defp after_confrontation(ctx) do
    ctx
    |> cutin("lhz_kaz10", 2)
    |> mes("[Kazien]")
    |> mes("Just...")
    |> mes("Leave me alone.")
    |> mes("I feel nothing but")
    |> mes("guilt when I see you.")
    |> next()
    |> mes("[Kazien]")
    |> mes("Don't take it the wrong")
    |> mes("way. I mean, it's not like")
    |> mes("you did nothing wrong. I'm")
    |> mes("the one who's... Geez. I wish")
    |> mes("I could live the way you do.")
    |> mes("Someday I'll be strong enough...")
    |> close2()
    |> cutin("", 255)
  end

  defp confront_kazien(ctx) do
    ctx =
      ctx
      |> cutin("lhz_kaz03", 2)
      |> mes("[Kazien]")
      |> mes("Hey, you're back. As usual,")
      |> mes("you've done a good job. You")
      |> mes("look exhausted: did you run")
      |> mes("into those thugs again?")
      |> mes("Why don't you take a rest?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Kazien...")
      |> mes("While I was fighting")
      |> mes("those thugs, one of the")
      |> mes("packages was accidentally")
      |> mes("opened, and I saw what was")
      |> mes("inside of those packages.")
      |> next()
      |> cutin("lhz_kaz06", 2)
      |> next()
      |> mes("[Kazien]")
      |> mes("......")
      |> mes(".........")
      |> mes("............")
      |> cutin("lhz_kaz08", 2)
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Wh-why are you supplying")
      |> mes("those things? If we let those")
      |> mes("packages get imported by")
      |> mes("other countries, it can")
      |> mes("cause a lot of trouble...!")
      |> next()
      |> cutin("lhz_kaz10", 2)
      |> mes("[Kazien]")
      |> mes("Stop. Please.")
      |> mes("J-just stop it.")
      |> mes("I don't want to")
      |> mes("hear anymore.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Hold it, I deserve an")
      |> mes("answer! How can you turn")
      |> mes("a blind eye and provide just")
      |> mes("anyone with ^FF0000hi-tech weapons")
      |> mes("and guardians^000000? It's like you're")
      |> mes("promoting war and violence!")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("And what about your little")
      |> mes("brother Lyozien? He has")
      |> mes("no idea what he's doing!")
      |> mes("Don't we have a responsibility")
      |> mes("to the world to make sure these")
      |> mes("weapons aren't distributed?")
      |> next()
      |> cutin("lhz_kaz11", 2)
      |> mes("[Kazien]")
      |> mes("Shut up! You don't")
      |> mes("know anything! Just")
      |> mes("shut up! I'm doing this")
      |> mes("for the sake of my family!")
      |> mes("You don't know what it's like")
      |> mes("to live in Lighthalzen's slums!")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes(".................")
      |> next()
      |> cutin("lhz_kaz04", 2)
      |> mes("[Kazien]")
      |> mes("There'd be days when my")
      |> mes("brother and I'd have nothing")
      |> mes("to eat. So when I heard about")
      |> mes("this job, I took it. What good")
      |> mes("is world peace if I'm not even")
      |> mes("alive to enjoy it, huh?")
      |> next()
      |> cutin("lhz_kaz11", 2)
      |> mes("[Kazien]")
      |> mes("Now, my brother Lyozien is")
      |> mes("a gentle soul, has nothing")
      |> mes("but love for everybody. So, of")
      |> mes("course I can't tell him what")
      |> mes("I'm really doing--he'd never")
      |> mes("agree to it, believe me.")
      |> next()
      |> cutin("lhz_kaz10", 2)
      |> mes("[Kazien]")
      |> mes("I hate this job and what")
      |> mes("I'm doing and I want to quit.")
      |> mes("But then what? Go back to the")
      |> mes("slums? Forget it. As long as")
      |> mes("Lyozien is happy, I don't mind if I have to do the devil's work.")
      |> next()
      |> cutin("lhz_kaz11", 2)
      |> mes("[Kazien]")
      |> mes("At least this way, keeping")
      |> mes("it all secret, I can protect")
      |> mes("Lyozien from the ugly nature")
      |> mes("of this job, even if I'm dirtying my hands, making money")
      |> mes("off of other people's deaths.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("But that still isn't right.")
      |> mes("You're selling weapons so")
      |> mes("that people can kill each other! Even if it's for the sake of")
      |> mes("providing for your family...")
      |> next()
      |> cutin("lhz_kaz05", 2)
      |> mes("[Kazien]")
      |> mes("Look man, this is what")
      |> mes("I decided. I don't care")
      |> mes("what other people'll think.")
      |> mes("I might go to hell when")
      |> mes("I die, but that's my problem.")
      |> next()
      |> mes("[Kazien]")
      |> mes("Besides, you adventurers")
      |> mes("are always running around")
      |> mes("with your swords and magic spells... Isn't that just as bad?")
      |> mes("It's not the weapons or the power that's bad: it's how they're used.")
      |> next()
      |> cutin("lhz_kaz11", 2)
      |> mes("[Kazien]")
      |> mes("Granted, most of my clients")
      |> mes("are pretty questionable, and")
      |> mes("you adventurers usually use")
      |> mes("your powers for good, but...")
      |> mes("Damn it! Just... Don't come")
      |> mes("back. I can't work like this...")
      |> next()
      |> set_char_var(:lhz_rekenber, 22)

    ctx
    |> getexp(if(Rathena.truthy?(checkre(ctx, 3)), do: 55_000, else: 550_000), 0)
    |> completequest(12_013)
    |> cutin("lhz_kaz01", 2)
    |> mes("[Kazien]")
    |> mes("Look, I can't have")
    |> mes("you working with me")
    |> mes("and Lyozien anymore.")
    |> mes("Sorry, but it's for Lyozien's")
    |> mes("own good. That, and you")
    |> mes("make me feel guilty...")
    |> close2()
    |> cutin("", 255)
  end

  defp final_delivery_reminder(ctx) do
    ctx
    |> cutin("lhz_kaz02", 2)
    |> mes("[Kazien]")
    |> mes("Hey now, you better")
    |> mes("get a move on. You gotta")
    |> mes("assist another delivery to")
    |> mes("the Rune-Midgarts Kingdom.")
    |> close2()
    |> cutin("", 255)
  end

  defp assign_final_delivery(ctx) do
    ctx =
      ctx
      |> cutin("lhz_kaz03", 2)
      |> mes("[Kazien]")
      |> mes("Ah, I heard from Lyozien")
      |> mes("that you guys finished your")
      |> mes("delivery. You're probably")
      |> mes("the best part-timer that I've")
      |> mes("had in a long, long while.")
      |> next()
      |> cutin("lhz_kaz10", 2)
      |> mes("[Kazien]")
      |> mes("Anyway, we've got yet")
      |> mes("another delivery for the")
      |> mes("Rune-Midgarts Kingdom. It's")
      |> mes("weird that we're getting more")
      |> mes("orders from there, but orders from other countries are decreasing.")
      |> next()
      |> cutin("lhz_kaz07", 2)
      |> mes("[Kazien]")
      |> mes("Eh, I don't have the time")
      |> mes("to wonder about stuff like")
      |> mes("that. Lyozien's waiting for")
      |> mes("you, so get to it, okay?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("W-wait! During the last")
      |> mes("delivery, I was attacked")
      |> mes("by a group of thugs that")
      |> mes("wanted to destroy the")
      |> mes("packages? Why would")
      |> mes("they want to do that?")
      |> next()
      |> cutin("lhz_kaz02", 2)
      |> mes("[Kazien]")
      |> mes("Look... You're better")
      |> mes("off not knowing. Or are")
      |> mes("you asking me to pay you")
      |> mes("more for this job since")
      |> mes("you're risking your life?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("I understand that the")
      |> mes("customer's confidentiality")
      |> mes("is important, but I'd feel a")
      |> mes("lot better if I knew what was")
      |> mes("in those packages, and why me")
      |> mes("and Lyozien are being attacked.")
      |> next()
      |> cutin("lhz_kaz08", 2)
      |> mes("[Kazien]")
      |> mes("Listen, I'm not obligated--")
      |> mes("I can't tell you. Heck, I can't")
      |> mes("even tell my own brother what's")
      |> mes("in those packages. You can see")
      |> mes("that, can't you? Anyway, you")
      |> mes("can handle those thugs, right?")
      |> next()
      |> set_char_var(:lhz_rekenber, 17)

    ctx
    |> getexp(if(Rathena.truthy?(checkre(ctx, 3)), do: 45_000, else: 450_000), 0)
    |> cutin("lhz_kaz10", 2)
    |> mes("[Kazien]")
    |> mes("Right. Now get back to")
    |> mes("the Airship and talk to")
    |> mes("Lyozien again. Don't give")
    |> mes("him any trouble and make")
    |> mes("sure you protect him.")
    |> close2()
    |> cutin("", 255)
  end

  defp delivery_reminder(ctx) do
    ctx
    |> cutin("lhz_kaz08", 2)
    |> mes("[Kazien]")
    |> mes("What are you doing")
    |> mes("waiting around here")
    |> mes("for? You've got a job to")
    |> mes("do, so hurry up and do it~")
    |> close2()
    |> cutin("", 255)
  end

  defp assign_second_delivery(ctx) do
    ctx =
      ctx
      |> cutin("lhz_kaz05", 2)
      |> mes("[Kazien]")
      |> mes("Hey, you're back. I got a")
      |> mes("message from Rune-Midgarts,")
      |> mes("telling us they received their")
      |> mes("order. Good work! So how do")
      |> mes("you like working with Lyozien?")
      |> mes("He's one of my best men.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Wait, aren't you and")
      |> mes("Lyozien supposed")
      |> mes("to be brothers?")
      |> next()
      |> cutin("lhz_kaz03", 2)
      |> mes("[Kazien]")
      |> mes("Whoa, he told you that?")
      |> mes("I guess he feels that he")
      |> mes("can trust you enough with")
      |> mes("that kind of personal talk...")
      |> mes("Yeah, he's my little brother.")
      |> mes("And a better man than me...")
      |> next()
      |> mes("[Kazien]")
      |> mes("I've gotten my hands")
      |> mes("pretty dirty doing this...")
      |> mes("Oh, forget it. You came ")
      |> mes("here for a job, right?")
      |> mes("Luckily, I got another")
      |> mes("delivery for you to work on...")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Actually, Kazien...")
      |> mes("I was curious. What")
      |> mes("exactly are we delivering?")
      |> mes("I mean, not even Lyozien")
      |> mes("doesn't know exactly what")
      |> mes("is in those packages.")
      |> next()
      |> cutin("lhz_kaz06", 2)
      |> mes("[Kazien]")
      |> mes("Huh... Does that mean")
      |> mes("you can't work with us if")
      |> mes("you don't know exactly what")
      |> mes("you're doing?")
      |> next()
      |> mes("[Kazien]")
      |> mes(" Come on, I told")
      |> mes("you before--absolute secrecy.")
      |> mes("It goes both ways, you know.")
      |> next()
      |> mes("[Kazien]")
      |> mes("Look, for your own good,")
      |> mes("quit asking. Knowing what")
      |> mes("you're delivering wouldn't")
      |> mes("change a thing. Trust me.")
      |> next()
      |> mes("[Kazien]")
      |> mes("Anyway, this next job is")
      |> mes("more of the same. Meet")
      |> mes("Lyozien in the international")
      |> mes("flight Airship and protect")
      |> mes("another package destined")
      |> mes("for the Rune-Midgarts Kingdom.")
      |> next()
      |> set_char_var(:lhz_rekenber, 12)

    ctx
    |> getexp(
      if(Rathena.truthy?(checkre(ctx, 3)), do: 40_000, else: 400_000),
      0
    )
    |> cutin("lhz_kaz03", 2)
    |> mes("[Kazien]")
    |> mes("Alright, I'll see you")
    |> mes("later. The important")
    |> mes("thing is that you do the")
    |> mes("best job that you can.")
    |> mes("And don't give Lyozien")
    |> mes("any trouble: that's my job!")
    |> close2()
    |> cutin("", 255)
  end

  defp lyozien_reminder(ctx) do
    ctx
    |> cutin("lhz_kaz08", 2)
    |> mes("[Kazien]")
    |> mes("Lyozien is waiting for")
    |> mes("you on the international")
    |> mes("flight Airship, so go and")
    |> mes("meet him there as soon")
    |> mes("as you can. Alright then,")
    |> mes("I'll see you later.")
    |> close2()
    |> cutin("", 255)
  end

  defp assign_first_delivery(ctx) do
    ctx
    |> cutin("lhz_kaz05", 2)
    |> mes("[Kazien]")
    |> mes("Hey, you're back~")
    |> mes("Great, I guess that means")
    |> mes("that you've decided to work")
    |> mes("for us! Alright, let me tell you about your first real job. As")
    |> mes("always: ^FF0000keep it on the down-low^000000.")
    |> next()
    |> mes("[Kazien]")
    |> mes("Go to the Airship for the")
    |> mes("international flights, not")
    |> mes("the domestic ones, and meet")
    |> mes("a man named ^FF0000Lyozien^000000 inside.")
    |> mes("He's our courier that'll provide you with further instructions.")
    |> next()
    |> cutin("lhz_kaz06", 2)
    |> mes("[Kazien]")
    |> mes("Oh. You can talk to Lyozien")
    |> mes("about the job, but definitely")
    |> mes("not to anybody else. Anyway,")
    |> mes("when you're done with what")
    |> mes("he asks you to do, come back")
    |> mes("to me for another job, okay?")
    |> next()
    |> set_char_var(:lhz_rekenber, 8)
    |> changequest(12_010, 12_011)
    |> cutin("lhz_kaz01", 2)
    |> mes("[Kazien]")
    |> mes("Don't forget...")
    |> mes("Talk to ^FF0000Lyozien^000000, our")
    |> mes("courier, on the Airship")
    |> mes("for the international flights.")
    |> close2()
    |> cutin("", 255)
  end

  defp passed_test(ctx) do
    ctx =
      ctx
      |> cutin("lhz_kaz04", 2)
      |> mes("[Kazien]")
      |> mes("So, were you able to")
      |> mes("contact Garins? Or did")
      |> mes("you encounter any problems?")
      |> next()

    ctx =
      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat("[", char_name(ctx, 0)),
          "]"
        )
      )
      |> mes("Well, I came back to")
      |> mes("let you know that I haven't")
      |> mes("been able to find a way inside")
      |> mes("the Einbroch Laboratory. There")
      |> mes("was the guard, but I couldn't")
      |> mes("really tell him anything.")
      |> next()
      |> cutin("lhz_kaz10", 2)
      |> mes("[Kazien]")
      |> mes("Whaaaat~?")
      |> mes("I'm sure he would")
      |> mes("have let you in if you")
      |> mes("told him that you had")
      |> mes("to talk to Garins, right?")
      |> next()

    ctx =
      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat("[", char_name(ctx, 0)),
          "]"
        )
      )
      |> mes("But...")
      |> mes("I thought you said")
      |> mes("I'm not supposed to")
      |> mes("tell anyone the details")
      |> mes("of my assignment?")
      |> next()
      |> cutin("lhz_kaz06", 2)
      |> mes("[Kazien]")
      |> mes("Heh... Yeah.")
      |> mes("Yeah, that's right.")
      |> mes("Heh heh heh! Hahahaha!")
      |> mes("Great! I'm happy to say,")
      |> mes("buddy, you passed the test!")
      |> next()

    ctx =
      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat("[", char_name(ctx, 0)),
          "]"
        )
      )
      |> mes("H-huh? But I never")
      |> mes("even got to see Garins...")
      |> mes("I didn't finish the task")
      |> mes("that you assigned to me.")
      |> next()
      |> cutin("lhz_kaz09", 2)
      |> mes("[Kazien]")
      |> mes("Garins is just some")
      |> mes("cool name I made up.")
      |> mes("He doesn't really exist.")
      |> mes("I just wanted to test your")
      |> mes("trustworthiness, is all.")
      |> mes("Now do you understand?")
      |> next()

    ctx
    |> mes(
      Rathena.concat(
        Rathena.concat("[", char_name(ctx, 0)),
        "]"
      )
    )
    |> mes("I... I guess.")
    |> mes("Still, you just tricked")
    |> mes("me! How am I supposed")
    |> mes("to trust you now?")
    |> next()
    |> set_char_var(:lhz_rekenber, 7)
    |> cutin("lhz_kaz06", 2)
    |> mes("[Kazien]")
    |> mes("Oh... You...")
    |> mes("You got a point, there.")
    |> mes("Huh, now isn't that ironic? I'm sorry, pal, let me apologize.")
    |> mes("Take some time, consider working for me, and then come back, okay?")
    |> close2()
    |> cutin("", 255)
  end

  defp failed_test(ctx) do
    ctx =
      ctx
      |> cutin("lhz_kaz04", 2)
      |> mes("[Kazien]")
      |> mes("So, were you able to")
      |> mes("contact Garins? Or did")
      |> mes("you encounter any problems?")
      |> next()

    ctx =
      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat("[", char_name(ctx, 0)),
          "]"
        )
      )
      |> mes("Well, I wasn't able to")
      |> mes("find him. In fact, I don't")
      |> mes("think that Garins even works")
      |> mes("at the Einbroch Laboratory.")
      |> next()
      |> cutin("lhz_kaz08", 2)
      |> mes("[Kazien]")
      |> mes("Whaaaat~?")
      |> mes("That can't be true.")
      |> mes("Well, how'd you")
      |> mes("find that out?")
      |> next()

    ctx =
      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat("[", char_name(ctx, 0)),
          "]"
        )
      )
      |> mes("I happened to ask the")
      |> mes("Laboratory Guard, but")
      |> mes("he wouldn't even let me in.")
      |> next()
      |> set_char_var(:lhz_rekenber, 6)
      |> changequest(12_008, 12_009)
      |> cutin("lhz_kaz10", 2)
      |> mes("[Kazien]")
      |> mes("Uh oh...")
      |> mes("I thought so.")
      |> mes("I'm sorry, pal, but")
      |> mes("you failed the test.")
      |> next()

    ctx
    |> mes(
      Rathena.concat(
        Rathena.concat("[", char_name(ctx, 0)),
        "]"
      )
    )
    |> mes("H-huh? What?")
    |> mes("What do you mean?")
    |> next()
    |> mes("[Kazien]")
    |> mes("You told that to the guard,")
    |> mes("but you weren't supposed")
    |> mes("to let anyone know any detail")
    |> mes("about your assignment. Yeah...")
    |> mes("Garins is just a name I made")
    |> mes("up. He doesn't really exist.")
    |> next()
    |> mes("[Kazien]")
    |> mes("I know you meant well,")
    |> mes("you know, doing whatever")
    |> mes("you can to finish whatever")
    |> mes("goal you have, but you can't")
    |> mes("forget the details. Anyway,")
    |> mes("sorry, but we can't use you...")
    |> close2()
    |> cutin("", 255)
  end

  defp test_reminder(ctx) do
    ctx
    |> cutin("lhz_kaz01", 2)
    |> mes("[Kazien]")
    |> mes("Remember, visit ^FF0000Garins^000000")
    |> mes("in the ^FF0000Einbroch Laboratory^000000")
    |> mes("and ^FF0000confirm that he received")
    |> mes("his order^000000. We pride ourselves")
    |> mes("in our clients' confidentiality,^FFFFFF  ^000000 so keep it secret, got it?")
    |> next()
    |> mes("[Kazien]")
    |> mes("I'll just be waiting")
    |> mes("around over here, so")
    |> mes("once you're done with")
    |> mes("that, come back to me.")
    |> close2()
    |> cutin("", 255)
  end

  defp assign_test(ctx) do
    ctx
    |> cutin("lhz_kaz04", 2)
    |> mes("[Kazien]")
    |> mes("Okay, I got it! Your first")
    |> mes("assignment for us is pretty")
    |> mes("simple, but think of it as")
    |> mes("something of a trial run.")
    |> mes("You know, for us to see")
    |> mes("how reliable you are.")
    |> next()
    |> mes("[Kazien]")
    |> mes("All you gotta do is head")
    |> mes("to Einbroch, find the Lab")
    |> mes("there, and find a researcher")
    |> mes("named Garins. You need to")
    |> mes("confirm whether he safely")
    |> mes("received his order from us.")
    |> next()
    |> mes("[Kazien]")
    |> mes("Simple stuff, yeah?")
    |> mes("Now, you can't let anyone")
    |> mes("know about your assignment.")
    |> mes("Otherwise, we can't trust you")
    |> mes("for more important stuff. And")
    |> mes("I really wanna trust you.")
    |> next()
    |> cutin("lhz_kaz05", 2)
    |> mes("[Kazien]")
    |> mes("Remember, visit ^FF0000Garins^000000")
    |> mes("in the ^FF0000Einbroch Laboratory^000000")
    |> mes("and ^FF0000confirm that he received")
    |> mes("his order^000000. We pride ourselves")
    |> mes("in our clients' confidentiality, so keep it secret, got it?")
    |> next()
    |> set_char_var(:lhz_rekenber, 3)
    |> changequest(12_007, 12_008)
    |> mes("[Kazien]")
    |> mes("I'll just be waiting")
    |> mes("around over here, so")
    |> mes("once you're done with")
    |> mes("that, come back to me.")
    |> close2()
    |> cutin("", 255)
  end

  defp rejected_applicant(ctx) do
    ctx =
      if Enum.random(1..15) == 7 do
        ctx
        |> cutin("lhz_kaz04", 2)
        |> mes("[Kazien]")
        |> mes("Oh, hey, it's you again.")
        |> mes("Wait. No. You only remind")
        |> mes("me of someone I've met. Um,")
        |> mes("have we met before? I don't")
        |> mes("remember at all. Oooh, I hate")
        |> mes("being this busy, I can't focus!")
        |> next()
        |> set_char_var(:lhz_rekenber, 0)
        |> erasequest(12_009)
        |> mes("[Kazien]")
        |> mes("Arrgh, this is not good.")
        |> mes("We are this busy but we don't have enough people,")
        |> mes("yet it is not that extrememly bad")
        |> mes("to a point that we need to hire more people.")
        |> next()
        |> cutin("lhz_kaz01", 2)
        |> mes("[Kazien]")
        |> mes("Will you step back? You are hindering my vision.")
        |> close2()
      else
        ctx
        |> cutin("lhz_kaz10", 2)
        |> mes("[Kazien]")
        |> mes("Oh, hey, it's you again.")
        |> mes("Listen, you didn't come here")
        |> mes("looking for a part time job,")
        |> mes("did you? I already told you")
        |> mes("that I can't bring myself")
        |> mes("to trust you, you know?")
        |> next()
        |> mes("[Kazien]")
        |> mes("Look, you're not a bad guy,")
        |> mes("so I'm sure you'd be perfect")
        |> mes("for some other employer.")
        |> mes("Don't feel bad... Um, what")
        |> mes("was your name again? Wait,")
        |> mes("did you even give it to me...?")
        |> close2()
      end

    cutin(ctx, "", 255)
  end

  defp offer_work(ctx) do
    ctx =
      ctx
      |> cutin("lhz_kaz01", 2)
      |> mes("[Kazien]")
      |> mes("We're so busy, we barely")
      |> mes("have enough people to cover")
      |> mes("our workload right now. Still,")
      |> mes("it's not so bad that we gotta")
      |> mes("invest in some new hires.")
      |> next()
      |> mes("[Kazien]")
      |> mes("Oh hey, sorry buddy,")
      |> mes("but you mind stepping")
      |> mes("back? It's just that you're")
      |> mes("blocking my view is all.")
      |> next()

    ctx =
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
      |> mes("Wait, did you just say")
      |> mes("that you need help?")
      |> mes("I'd like to help solve")
      |> mes("your problem, er, for")
      |> mes("a nominal fee or some")
      |> mes("kind of reward. You know...")
      |> next()
      |> cutin("lhz_kaz10", 2)
      |> mes("[Kazien]")
      |> mes("Hey, alright~")
      |> mes("I could use an extra")
      |> mes("hand if you're willing")
      |> mes("to work part time. Plus,")
      |> mes("you're a straight shooter.")
      |> mes("I like that. Let's see now...")
      |> next()

    if base_level(ctx) < 70 do
      underleveled(ctx)
    else
      ask_discretion(ctx)
    end
  end

  defp underleveled(ctx) do
    ctx
    |> mes("[Kazien]")
    |> mes("Awww, I'm sorry, pal.")
    |> mes("I know you mean well, but")
    |> mes("to put it bluntly, you're not")
    |> mes("not strong enough for this")
    |> mes("kinda work. Hey, but if you put on")
    |> mes("some muscle, ask me again, okay?")
    |> close2()
    |> cutin("", 255)
  end

  defp ask_discretion(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Kazien]")
      |> mes("Yeah, okay. You look like")
      |> mes("you can handle this. But")
      |> mes("are you the type of person")
      |> mes("I can trust? Hey, you can")
      |> mes("keep confidential information")
      |> mes("without telling anyone, right?")
      |> next()
      |> select([
        "Yes, of course.",
        "Nope, I love giving away secrets."
      ])

    case choice do
      1 -> accept_applicant(ctx)
      2 -> decline_applicant(ctx)
      _ -> ctx
    end
  end

  defp accept_applicant(ctx) do
    ctx
    |> set_char_var(
      :lhz_rekenber,
      2
    )
    |> mes("[Kazien]")
    |> mes("Great, great.")
    |> mes("I guess we can just")
    |> mes("get down to business,")
    |> mes("then. Let me think. First,")
    |> mes("I should give you something")
    |> mes("easy to do to test you out...")
    |> close2()
    |> cutin("", 255)
  end

  defp decline_applicant(ctx) do
    ctx
    |> cutin("lhz_kaz04", 2)
    |> mes("[Kazien]")
    |> mes("Awww, man.")
    |> mes("I can't hire you")
    |> mes("if you're gonna blab")
    |> mes("your mouth. Sorry buddy,")
    |> mes("but I can't afford to take")
    |> mes("any risks. You understand...")
    |> close2()
    |> cutin("", 255)
  end

  defp busy_greeting(ctx) do
    ctx
    |> cutin("lhz_kaz01", 2)
    |> mes("[Kazien]")
    |> mes("We're so busy, we barely")
    |> mes("have enough people to cover")
    |> mes("our workload right now. Still,")
    |> mes("it's not so bad that we gotta")
    |> mes("invest in some new hires.")
    |> next()
    |> cutin("lhz_kaz04", 2)
    |> mes("[Kazien]")
    |> mes("Oh hey, sorry buddy,")
    |> mes("but you mind stepping")
    |> mes("back? It's just that you're")
    |> mes("blocking my view is all.")
    |> close2()
    |> cutin("", 255)
  end
end
