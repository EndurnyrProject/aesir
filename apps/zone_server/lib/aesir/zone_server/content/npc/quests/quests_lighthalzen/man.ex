defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Man do
  @moduledoc """
  Lyozien coordinates package deliveries aboard the airship.

  ## Behavior

  - Guides the player through deliveries and defends the cargo from attackers.

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
        map: "airplane_01",
        x: 96,
        y: 48,
        dir: 3,
        sprite: 869,
        name: "Man",
        scope: :shared,
        unique_name: "Man#Lyozien"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :lhz_rekenber, 0) do
      stage when stage > 21 -> after_work(ctx)
      21 -> report_to_brother(ctx)
      20 -> complete_delivery(ctx)
      19 -> thank_after_second_fight(ctx)
      18 -> second_attack(ctx)
      17 -> discuss_obligations(ctx)
      16 -> wait_for_next_job(ctx)
      15 -> finish_second_delivery(ctx)
      14 -> deliver_after_attack(ctx)
      13 -> thank_after_first_fight(ctx)
      12 -> first_attack(ctx)
      11 -> ask_for_next_job(ctx)
      10 -> finish_first_delivery(ctx)
      9 -> find_ahman(ctx)
      8 -> begin_delivery(ctx)
      _ -> greeting(ctx)
    end
  end

  @impl true
  def on_event("OnEnter", ctx), do: enablenpc(ctx, "Man#Lyozien")
  def on_event("OnStop", ctx), do: disablenpc(ctx, "Man#Lyozien")

  defp after_work(ctx) do
    ctx
    |> cutin("lhz_ryo11", 2)
    |> mes("[Lyozien]")
    |> mes("Hey, I hear from my")
    |> mes("brother that you can't work")
    |> mes("with us anymore because")
    |> mes("of some scheduling conflict.")
    |> mes("I'm sorry to hear that: it was")
    |> mes("really good working with you...")
    |> close2()
    |> cutin("", 255)
  end

  defp report_to_brother(ctx) do
    ctx
    |> cutin("lhz_ryo03", 2)
    |> mes("[Lyozien]")
    |> mes("Oh good, you're back.")
    |> mes("Mr. Ahman just left and")
    |> mes("picked up his goods. We're")
    |> mes("done here, so all you have to")
    |> mes("do now is report to my")
    |> mes("brother in Lighthalzen.")
    |> next()
    |> mes("[Lyozien]")
    |> mes("You sure you're alright?")
    |> mes("You seem kind of upset.")
    |> mes("Do you need to take a")
    |> mes("break or something?")
    |> close2()
    |> cutin("", 255)
  end

  defp complete_delivery(ctx) do
    ctx
    |> cutin("lhz_ryo09", 2)
    |> mes("[Lyozien]")
    |> mes("Heya, keep up the")
    |> mes("good work. Once you")
    |> mes("talk to Mr. Ahman inside")
    |> mes("Izlude Airport, we'll be")
    |> mes("done with this delivery.")
    |> close2()
    |> cutin("", 255)
  end

  defp thank_after_second_fight(ctx) do
    ctx =
      ctx
      |> cutin("lhz_ryo06", 2)
      |> mes("[Lyozien]")
      |> mes("Whoa, you were great!")
      |> mes("There were more of them")
      |> mes("this time, but you easily")
      |> mes("dispatched them. Great job!")
      |> next()
      |> cutin("lhz_ryo01", 2)

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Thanks, but...")
    |> mes("Now I'm really worried")
    |> mes("about what could be in")
    |> mes("those packages. Are you")
    |> mes("sure you don't know, Lyozien?")
    |> next()
    |> cutin("lhz_ryo02", 2)
    |> mes("[Lyozien]")
    |> mes("You don't know when to")
    |> mes("stop, do you? Nah, I don't")
    |> mes("know at all. Besides, so long")
    |> mes("as my brother says it's a bad")
    |> mes("idea, then I don't wanna find")
    |> mes("out for myself. Oh, hey...")
    |> next()
    |> set_char_var(:lhz_rekenber, 20)
    |> give_item(504, 1)
    |> cutin("lhz_ryo12", 2)
    |> mes("[Lyozien]")
    |> mes("Here's a little")
    |> mes("something to refresh")
    |> mes("yourself after that fight.")
    |> mes("Keep up the good work, okay?")
    |> mes("Then, we'll be done once you")
    |> mes("contact Mr. Ahman in Izlude.")
    |> close2()
    |> cutin("", 255)
  end

  defp second_attack(ctx) do
    ctx
    |> cutin("lhz_ryo06", 2)
    |> mes("[Lyozien]")
    |> mes("Okay, just like before, we")
    |> mes("gotta get these packages to")
    |> mes("Mr. Ahmam. When we arrive")
    |> mes("in Izlude, find Mr. Ahman in")
    |> mes("the Airport and tell him that")
    |> mes("his packages have arrived.")
    |> next()
    |> cutin("lhz_ryo08", 2)
    |> mes("[Lyozien]")
    |> mes("W-wait...")
    |> mes("Did you hear that?")
    |> mes("I heard--I think it's them.")
    |> mes("Those thugs are back! Don't")
    |> mes("let them damage the packages!")
    |> close2()
    |> cutin("", 255)
    |> set_char_var(:lhz_rekenber, 19)
    |> donpcevent("#bully2::OnEnter")
    |> donpcevent("Man#Lyozien::OnStop")
  end

  defp discuss_obligations(ctx) do
    ctx
    |> cutin("lhz_ryo14", 2)
    |> mes("[Lyozien]")
    |> mes("I heard that you upset")
    |> mes("Kyozien a little bit with")
    |> mes("your questions. I mean,")
    |> mes("I totally understand, but")
    |> mes("you gotta remember that")
    |> mes("we've got obligations.")
    |> next()
    |> cutin("lhz_ryo12", 2)
    |> mes("[Lyozien]")
    |> mes("I know that these packages")
    |> mes("might be putting us in danger,")
    |> mes("but I trust my brother. If he says those thugs are bad guys, then")
    |> mes("they're definitely bad guys.")
    |> next()
    |> cutin("lhz_ryo13", 2)
    |> mes("[Lyozien]")
    |> mes("Yeah, ever since we were")
    |> mes("kids, Kyozien has always")
    |> mes("been right. Even though")
    |> mes("I'd like to know what's in the")
    |> mes("boxes, I don't ever wanna")
    |> mes("disappoint him, you know?")
    |> next()
    |> set_char_var(:lhz_rekenber, 18)
    |> cutin("lhz_ryo10", 2)
    |> mes("[Lyozien]")
    |> mes("Anyway, that's")
    |> mes("enough chit-chat")
    |> mes("for now. Let's get")
    |> mes("back to work, shall we?")
    |> close2()
    |> cutin("", 255)
  end

  defp wait_for_next_job(ctx) do
    ctx
    |> cutin("lhz_ryo12", 2)
    |> mes("[Lyozien]")
    |> mes("I'm lucky that you're")
    |> mes("around to keep those")
    |> mes("thugs off our backs, eh?")
    |> mes("Hey, when you're ready for")
    |> mes("another job, just talk to")
    |> mes("my brother Kazien, okay?")
    |> close2()
    |> cutin("", 255)
  end

  defp finish_second_delivery(ctx) do
    ctx
    |> cutin("lhz_ryo05", 2)
    |> mes("[Lyozien]")
    |> mes("So you spoke to")
    |> mes("Mr. Ahman already?")
    |> mes("Good, good. Now we can")
    |> mes("go back to the Schwarzwald")
    |> mes("Republic for our next job.")
    |> next()
    |> mes("[Lyozien]")
    |> mes("Just talk to my brother")
    |> mes("Kazien and he should give")
    |> mes("you any details you need")
    |> mes("to know. Man, it's good")
    |> mes("that you're working for us.")
    |> mes("Those thugs frighten me...")
    |> set_char_var(:lhz_rekenber, 16)
    |> cutin("lhz_ryo01", 2)
    |> mes("[Lyozien]")
    |> mes("Now I feeel much more secure.")
    |> close2()
    |> cutin("", 255)
  end

  defp deliver_after_attack(ctx) do
    ctx
    |> cutin("lhz_ryo13", 2)
    |> mes("[Lyozien]")
    |> mes("Now that those thugs are")
    |> mes("gone, let's concentrate on")
    |> mes("our task. Like before, just")
    |> mes("get off at Izlude and then tell")
    |> mes("Mr. Ahman that his packages")
    |> mes("have arrived. See you later~")
    |> close2()
    |> cutin("", 255)
  end

  defp thank_after_first_fight(ctx) do
    ctx
    |> cutin("lhz_ryo13", 2)
    |> mes("[Lyozien]")
    |> mes("Oh, thank you!")
    |> mes("You saved my life!")
    |> mes("As you can tell, I'm")
    |> mes("not much of a fighter...")
    |> mes("I just ran and hid when")
    |> mes("those thugs appeared.")
    |> next()
    |> cutin("lhz_ryo04", 2)
    |> mes("[Lyozien]")
    |> mes("That's one reason why")
    |> mes("my brother has been hiring")
    |> mes("you adventurers-- we need")
    |> mes("packages from those hoodlums.")
    |> mes("They're always after us...")
    |> next()
    |> cutin("lhz_ryo07", 2)
    |> mes("[Lyozien]")
    |> mes("Every time I see them,")
    |> mes("they're yelling things like")
    |> mes("we're the servants of evil,")
    |> mes("or that the packages must")
    |> mes("be destroyed. Boy, I sure")
    |> mes("am glad that you're here!")
    |> set_char_var(:lhz_rekenber, 14)
    |> close2()
    |> cutin("", 255)
  end

  defp first_attack(ctx) do
    ctx
    |> cutin("lhz_ryo11", 2)
    |> mes("[Lyozien]")
    |> mes("Hey, we already have another")
    |> mes("package to deliver all the way")
    |> mes("to the Rune-Midgarts Kingdom")
    |> mes("again. Can you believe it? We")
    |> mes("seem to be doing a lot of")
    |> mes("business around there lately.")
    |> next()
    |> cutin("lhz_ryo12", 2)
    |> mes("[Lyozien]")
    |> mes("It's so far away from")
    |> mes("home, but a job's a job.")
    |> mes("We're obliged to do what")
    |> mes("we're been assigned to do")
    |> mes("until we qui--whoa. You")
    |> mes("hear that? Wh-what was...?")
    |> next()
    |> cutin("lhz_ryo03", 2)
    |> mes("[Lyozien]")
    |> mes("Awwww, nuts!")
    |> mes("It's those thugs!")
    |> mes("I'll explain later, but")
    |> mes("for now, please protect")
    |> mes("the packages and make")
    |> mes("sure they don't get them!")
    |> close2()
    |> cutin("", 255)
    |> set_char_var(:lhz_rekenber, 13)
    |> donpcevent("Man#Lyozien::OnStop")
    |> donpcevent("#bully1::OnEnter")
  end

  defp ask_for_next_job(ctx) do
    ctx
    |> cutin("lhz_ryo12", 2)
    |> mes("[Lyozien]")
    |> mes("Hey, would you go see")
    |> mes("my brother Kazien to see")
    |> mes("if he's got another job for")
    |> mes("us to do? I'll just be over")
    |> mes("here waiting when you need")
    |> mes("to find me. See you later~")
    |> close2()
    |> cutin("", 255)
  end

  defp finish_first_delivery(ctx) do
    ctx =
      ctx
      |> cutin("lhz_ryo14", 2)
      |> mes("[Lyozien]")
      |> mes("Good work, Mr. Ahman just")
      |> mes("arrived and picked up his")
      |> mes("packages. It looks like we're")
      |> mes("done for today. When you're")
      |> mes("ready for another job, just")
      |> mes("ask to my brother Kazien, okay?")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Lyozien, do you know")
    |> mes("what kinds of things")
    |> mes("we're delivering?")
    |> next()
    |> cutin("lhz_ryo10", 2)
    |> mes("[Lyozien]")
    |> mes("No clue. I've been")
    |> mes("a little curious myself,")
    |> mes("but my brother warned me")
    |> mes("not to ask. Besides, I don't")
    |> mes("think it makes a difference")
    |> mes("to what we gotta do, right?")
    |> next()
    |> cutin("lhz_ryo13", 2)
    |> mes("[Lyozien]")
    |> mes("Anyway, it oughta be")
    |> mes("fine. I mean, our clients")
    |> mes("are entitled to their privacy")
    |> mes("anyway. You've been in that")
    |> mes("sort of situation, right? You")
    |> mes("know, embarassing orders...")
    |> next()
    |> set_char_var(:lhz_rekenber, 11)
    |> cutin("lhz_ryo01", 2)
    |> mes("[Lyozien]")
    |> mes("No? Eh, just meet up with")
    |> mes("my brother to see if he's")
    |> mes("got another job for us, okay?")
    |> mes("If you wanna find me again,")
    |> mes("I'll be waiting right here.")
    |> close2()
    |> cutin("", 255)
  end

  defp find_ahman(ctx) do
    ctx
    |> cutin("lhz_ryo05", 2)
    |> mes("[Lyozien]")
    |> mes("Alright, when this Airship")
    |> mes("arrives in Izlude, get off and")
    |> mes("enter the Airport to meet with")
    |> mes("a man named Mr. Ahman.")
    |> mes("Let him know his order has")
    |> mes("already arrived, okay?")
    |> close2()
    |> cutin("", 255)
  end

  defp begin_delivery(ctx) do
    ctx =
      ctx
      |> cutin("lhz_ryo02", 2)
      |> mes("[Lyozien]")
      |> mes("Um, would you mind")
      |> mes("treading lightly around")
      |> mes("this area, and kind of go")
      |> mes("around the piles? Yeah,")
      |> mes("these are all pretty fragile.")
      |> mes("Thanks, I appreciate it.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Excuse me, but")
      |> mes("are you Lyozien?")
      |> next()
      |> cutin("lhz_ryo07", 2)
      |> mes("[Lyozien]")
      |> mes("Hey, are you the one that")
      |> mes("my brother Kazien sent?")
      |> mes("Nice, I've been waiting")
      |> mes("for you. As you can see,")
      |> mes("I'm having trouble handling")
      |> mes("all of these packages here.")
      |> next()
      |> cutin("lhz_ryo14", 2)

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Wait, Kazien is")
    |> mes("your brother? That's")
    |> mes("weird, you figure he")
    |> mes("would mention that.")
    |> next()
    |> mes("[Lyozien]")
    |> mes("Oh, yeah, he's been like")
    |> mes("that ever since we lived")
    |> mes("in Lighthalzen's slums.")
    |> mes("Luckily, he joined the")
    |> mes("corporation and helped")
    |> mes("us improve our lots in life...")
    |> next()
    |> cutin("lhz_ryo13", 2)
    |> mes("[Lyozien]")
    |> mes("That's why I appreciate the")
    |> mes("fact that he lets me work for")
    |> mes("him. I can't let him down.")
    |> mes("Anyway, back to business: we")
    |> mes("gotta deliver these goods to")
    |> mes("the Rune-Midgarts Kingdom.")
    |> next()
    |> cutin("lhz_ryo12", 2)
    |> mes("[Lyozien]")
    |> mes("I have to ensure that these")
    |> mes("packages aren't damaged or")
    |> mes("stolen by thieves. Your job is")
    |> mes("to go to Izlude, find Mr. Ahman")
    |> mes("at the Airport, and tell him that his orders have safely arrived.")
    |> next()
    |> set_char_var(:lhz_rekenber, 9)
    |> changequest(12_011, 12_012)
    |> cutin("lhz_ryo11", 2)
    |> mes("[Lyozien]")
    |> mes("Once you tell Mr. Ahman")
    |> mes("that message, he'll take")
    |> mes("care of picking up his own")
    |> mes("packages. But yeah, I need")
    |> mes("to stay behind to guard these")
    |> mes("products in the meantime.")
    |> close2()
    |> cutin("", 255)
  end

  defp greeting(ctx) do
    ctx
    |> cutin("lhz_ryo12", 2)
    |> mes("[Lyozien]")
    |> mes("Um, would you mind")
    |> mes("treading lightly around")
    |> mes("this area, and kind of go")
    |> mes("around the piles? Yeah,")
    |> mes("these are all pretty fragile.")
    |> mes("Thanks, I appreciate it.")
    |> close2()
    |> cutin("", 255)
  end
end
