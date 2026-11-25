defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Digotz do
  @moduledoc """
  Digotz recalls his friendship with Maku.

  ## Behavior

  - Relays messages between estranged friends and reads Benkaistein’s journal.
  - Advances the friendship quest and gives the player a knife.

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
      %{map: "lhz_in02", x: 201, y: 210, dir: 5, sprite: 869, name: "Digotz", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if base_level(ctx) < 50 do
      welcome_new_adventurer(ctx)
    else
      friendship_dialogue(ctx, get_char_var(ctx, :friendship, 0))
    end
  end

  defp friendship_dialogue(ctx, stage) when stage > 14, do: remember_digotz(ctx)
  defp friendship_dialogue(ctx, 14), do: dying_digotz(ctx)
  defp friendship_dialogue(ctx, 13), do: prepare_to_meet_maku(ctx)

  defp friendship_dialogue(ctx, 12) do
    if count_item(ctx, 7351) > 0, do: offer_journal(ctx), else: greeting(ctx)
  end

  defp friendship_dialogue(ctx, 7), do: miss_benkaistein(ctx)
  defp friendship_dialogue(ctx, 6), do: hear_makus_response(ctx)
  defp friendship_dialogue(ctx, stage) when stage in [4, 5], do: repeat_message(ctx)
  defp friendship_dialogue(ctx, 3), do: send_message(ctx)
  defp friendship_dialogue(ctx, 2), do: upset_about_maku(ctx)
  defp friendship_dialogue(ctx, 1), do: meet_digotz(ctx)
  defp friendship_dialogue(ctx, _), do: greeting(ctx)

  defp welcome_new_adventurer(ctx) do
    ctx
    |> mes("[Digotz]")
    |> mes("Oh, an adventurer?")
    |> mes("Welcome to Uptown")
    |> mes("Lighthalzen. However,")
    |> mes("I'm afraid this area won't")
    |> mes("have much to offer you")
    |> mes("in the way of excitement.")
    |> next()
    |> mes("[Digotz]")
    |> mes("Not to be rude or")
    |> mes("anything, but this town")
    |> mes("should be safe enough for")
    |> mes("you to explore. I mean, you")
    |> mes("just seem to be kind of new")
    |> mes("at this adventurer thing...")
    |> close()
  end

  defp remember_digotz(ctx) do
    ctx
    |> cutin("lhz_diguts05.bmp", 2)
    |> mes("^3355FFDigotz has passed")
    |> mes("away, but the look on")
    |> mes("his face seems very")
    |> mes("peaceful and content.^000000")
    |> close()
    |> cutin("", 255)
  end

  defp dying_digotz(ctx) do
    ctx =
      ctx
      |> mes("^3355FFDigotz is seriously")
      |> mes("injured from a wound")
      |> mes("by a knife that is still")
      |> mes("embedded in his belly.^000000")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Digotz...?")
    |> mes("Oh no, let me")
    |> mes("get you some help!")
    |> next()
    |> cutin("lhz_diguts04.bmp", 2)
    |> mes("[Digotz]")
    |> mes("H-hey... It's the")
    |> mes("adventurer... Man,")
    |> mes("that Maku. He always")
    |> mes("did bring me bad luck...")
    |> mes("It's too late for me and")
    |> mes("I don't have much time...")
    |> next()
    |> mes("[Digotz]")
    |> mes("Those guards I told you")
    |> mes("about... The ones who don't")
    |> mes("want the poor and the rich to")
    |> mes("mingle? I... Guess they found")
    |> mes("I was gonna meet my old pal.")
    |> mes("I just wanted to see him...")
    |> next()
    |> mes("[Digotz]")
    |> mes("This guy... In a black")
    |> mes("suit... He just... He just")
    |> mes("stabbed me! I... God. It's")
    |> mes("been so long since I've talked")
    |> mes("to him. We'll hang out and have")
    |> mes("fun, just like the good old days.")
    |> next()
    |> cutin("lhz_diguts05.bmp", 2)
    |> mes("[Digotz]")
    |> mes("I missed my buddies, but now...")
    |> mes("Now I can hear them calling me.")
    |> mes("Now we can all be together just")
    |> mes("like we all promised. Yeah...")
    |> mes("I was wrong. Life's too short")
    |> mes("to be angry with your frie--")
    |> next()
    |> mes("[Digotz]")
    |> mes("..............")
    |> next()
    |> mes("[Digotz]")
    |> mes("..............")
    |> mes(".......................")
    |> next()
    |> mes("[Digotz]")
    |> mes("..............")
    |> mes(".......................")
    |> mes("...............................")
    |> next()
    |> mes("^3355FFDigotz stopped breathing.")
    |> mes("You remove the Knife from")
    |> mes("his lifeless body as a final")
    |> mes("courtesy to a man who")
    |> mes("dearly loved his friends.^000000")
    |> next()
    |> set_char_var(:friendship, 15)
    |> changequest(12_005, 12_006)
    |> give_item(1201, 1)
    |> cutin("", 255)
    |> close()
  end

  defp prepare_to_meet_maku(ctx) do
    ctx
    |> cutin("lhz_diguts08.bmp", 2)
    |> mes("[Digotz]")
    |> mes("Wh-whoa, I need to")
    |> mes("get ready! That Maku's")
    |> mes("gonna make fun of me if")
    |> mes("I look too rich and pampered.")
    |> mes("Damn! Where did I put all of")
    |> mes("my fashionable street clothes?")
    |> close()
    |> cutin("", 255)
  end

  defp miss_benkaistein(ctx) do
    ctx
    |> cutin("lhz_diguts03.bmp", 2)
    |> mes("[Digotz]")
    |> mes("Even if Benkaistein came")
    |> mes("back from wherever he was")
    |> mes("studying, I don't think he'd be")
    |> mes("able to get Maku to apologize")
    |> mes("to me. That guy is just way")
    |> mes("too stubborn for his own good!")
    |> close()
    |> cutin("", 255)
  end

  defp hear_makus_response(ctx) do
    ctx =
      ctx
      |> cutin("lhz_diguts01.bmp", 2)
      |> mes("[Digotz]")
      |> mes("Oh, it's been a while.")
      |> mes("What are you doing back")
      |> mes("over here? And, um, did")
      |> mes("you deliver that message")
      |> mes("to Maku? Now when I think")
      |> mes("about it, I was kind of--")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("I delivered your message")
    |> mes("word for word, and Maku")
    |> mes("got angry, called you names")
    |> mes("and has been threatening to")
    |> mes("beat you up pretty badly.")
    |> next()
    |> cutin("lhz_diguts08.bmp", 2)
    |> mes("[Digotz]")
    |> mes("That no-good, dirty")
    |> mes("lying rotten scoundrel!")
    |> mes("If it weren't for those")
    |> mes("guards, I'd head over to")
    |> mes("the ghetto and beat Maku")
    |> mes("up myself! That stupid guy!")
    |> next()
    |> cutin("lhz_diguts03.bmp", 2)
    |> mes("[Digotz]")
    |> mes("During times like this,")
    |> mes("I really miss ^FF0000Benkaistein^000000.")
    |> mes("That guy would always have")
    |> mes("an answer for this kind of")
    |> mes("situation. Yeah, I think he's")
    |> mes("in some far off town, studying.")
    |> next()
    |> mes("[Digotz]")
    |> mes("Supposedly he's in that")
    |> mes("place, whatever it's called,")
    |> mes("since there's a ton of books")
    |> mes("there that he can use. But")
    |> mes("yeah, Benkaistein would")
    |> mes("always be the mediator...")
    |> next()
    |> mes("[Digotz]")
    |> mes("Even back then, when")
    |> mes("me, him and Maku used to")
    |> mes("hang out, Benkaistein would")
    |> mes("mediate if we got into some")
    |> mes("argument. Still, he couldn't")
    |> mes("do anything about Maku now...")
    |> set_char_var(:friendship, 7)
    |> changequest(12_002, 12_003)
    |> next()
    |> cutin("", 255)
    |> mes("[Digotz]")
    |> mes("I don't know why,")
    |> mes("but I'm so angry!")
    |> mes("Why am I stressing")
    |> mes("out so much over this?!")
    |> close()
  end

  defp repeat_message(ctx) do
    ctx
    |> cutin("lhz_diguts01.bmp", 2)
    |> mes("[Digotz]")
    |> mes("Still checking out")
    |> mes("Uptown Lighthalzen?")
    |> mes("Not like I'd care, but if you")
    |> mes("do happen to see Maku,")
    |> mes("deliver this little message")
    |> mes("for me, sentence by sentence.")
    |> next()
    |> mes("[Digotz]")
    |> mes("^FF0000Hopeless bastard!")
    |> mes("^FF0000You're still a stubborn jerk!")
    |> mes("^FF0000You owe me at least 3 lunches!")
    |> mes("^FF0000Not to mention an apology!")
    |> mes("^FF0000But who cares what you think?!")
    |> mes("I'm so goddamn happy without you!^000000")
    |> close()
    |> cutin("", 255)
  end

  defp send_message(ctx) do
    {ctx, _} =
      ctx
      |> cutin("lhz_diguts01.bmp", 2)
      |> mes("[Digotz]")
      |> mes("I know that the")
      |> mes("opulence of Uptown")
      |> mes("seems rather attractive,")
      |> mes("but trust me. This place")
      |> mes("is colorless. Now, have")
      |> mes("you visited the poor district?")
      |> next()
      |> select(["Yes, I did already..."])

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Yes, I did already...")
    |> mes("And I met someone")
    |> mes("named Maku there.")
    |> next()
    |> mes("[Digotz]")
    |> mes("Maku?! Oh, he must have")
    |> mes("mentioned something about")
    |> mes("me. But I don't care what he")
    |> mes("says, unless it's an apology")
    |> mes("for being a fully blown jerk.")
    |> mes("Ever since we were kids...")
    |> cutin("", 255)
    |> next()
    |> cutin("lhz_diguts08.bmp", 2)
    |> mes("[Digotz]")
    |> mes("Anyway, we used to be close,")
    |> mes("but that guy was never a true")
    |> mes("friend of mine! Like that one")
    |> mes("time he cheated to beat me at")
    |> mes("arm wrestling! Or when he never")
    |> mes("thanked me for buying us lunch!")
    |> next()
    |> mes("[Digotz]")
    |> mes("Sure, he might have helped")
    |> mes("me a little in meeting my first")
    |> mes("girlfriend, but I'll never ever")
    |> mes("forgive him for fixing me up")
    |> mes("on the worst blind dates a")
    |> mes("man can possibly experience!")
    |> next()
    |> cutin("lhz_diguts01.bmp", 2)
    |> mes("[Digotz]")
    |> mes("Maku doesn't know a damn")
    |> mes("about friendship! Even if I did")
    |> mes("want to see him, there are these")
    |> mes("people who don't want the rich")
    |> mes("to ever meet with the poor.")
    |> next()
    |> mes("[Digotz]")
    |> mes("If Maku's fine, that's")
    |> mes("good enough to hear for")
    |> mes("me! There's no need for me")
    |> mes("to go all the way over there")
    |> mes("and check up on him! I only")
    |> mes("have one regret though...")
    |> next()
    |> cutin("lhz_diguts07.bmp", 2)
    |> mes("[Digotz]")
    |> mes("I only wish I had one")
    |> mes("last chance to see Maku...")
    |> mes("So that I could kick his sorry")
    |> mes("ass myself! Yeah, that's right!")
    |> mes("Arrogant bastard! But still,")
    |> mes("I'm not able to do that...")
    |> next()
    |> mes("[Digotz]")
    |> mes("The security guards here")
    |> mes("will never allow the rich and")
    |> mes("poor to meet, fearing that")
    |> mes("the poor will disturb the peace")
    |> mes("and order of the city. It's a dumb rule made for dumb people.")
    |> next()
    |> mes("[Digotz]")
    |> mes("Still, it's pretty scary that")
    |> mes("someone can get punished")
    |> mes("for violating such a stupid")
    |> mes("taboo, actually. Anyway, if")
    |> mes("you see Maku again, tell")
    |> mes("him this for me, got it?")
    |> next()
    |> mes("[Digotz]")
    |> mes("^FF0000Hopeless bastard!")
    |> mes("^FF0000You're still a stubborn jerk!")
    |> mes("^FF0000You owe me at least 3 lunches!")
    |> mes("^FF0000Not to mention an apology!")
    |> mes("^FF0000But who cares what you think?!")
    |> mes("I'm so goddamn happy without you!^000000")
    |> set_char_var(:friendship, 4)
    |> close()
    |> cutin("", 255)
  end

  defp upset_about_maku(ctx) do
    ctx
    |> cutin("lhz_diguts01.bmp", 2)
    |> mes("[Digotz]")
    |> mes("What are you still")
    |> mes("doing hanging around")
    |> mes("here? There's nothing")
    |> mes("interesting in Uptown")
    |> mes("for you to see, adventurer.")
    |> next()
    |> mes("[Digotz]")
    |> mes("Gosh...!")
    |> mes("Just hearing about")
    |> mes("Maku makes me so feel")
    |> mes("so upset for some reason!")
    |> close()
    |> cutin("", 255)
  end

  defp meet_digotz(ctx) do
    {ctx, _} =
      ctx
      |> cutin("lhz_diguts02.bmp", 2)
      |> mes("[Digotz]")
      |> mes("Oh, an adventurer?")
      |> mes("Welcome to Uptown")
      |> mes("Lighthalzen. However,")
      |> mes("I'm afraid this area won't")
      |> mes("have much to offer you")
      |> mes("in the way of excitement.")
      |> next()
      |> mes("[Digotz]")
      |> mes("My name is Digotz,")
      |> mes("just another citizen")
      |> mes("of Upper Lighthalzen.")
      |> mes("I hope that you enjoy")
      |> mes("your stay in my hometown.")
      |> next()
      |> select(["Do you know someone named Maku?"])

    ctx
    |> cutin("lhz_diguts01.bmp", 2)
    |> mes("[Digotz]")
    |> mes("Maku? Maku. Yes, he's my")
    |> mes("childhood friend. Or he was,")
    |> mes("anyway. Now he's just a jerk.")
    |> mes("In any case, we can't hang")
    |> mes("out, even if we wanted to,")
    |> mes("for several reasons.")
    |> next()
    |> mes("[Digotz]")
    |> mes("Hey, why am I even")
    |> mes("talking about this? It's")
    |> mes("not like I'm bothered by")
    |> mes("the fact me and Maku aren't")
    |> mes("pals anymore. You know what?")
    |> mes("Just forget everything I said.")
    |> set_char_var(:friendship, 2)
    |> changequest(12_000, 12_001)
    |> close()
    |> cutin("", 255)
  end

  defp offer_journal(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("lhz_diguts08.bmp", 2)
      |> mes("[Digotz]")
      |> mes("Even if Benkaistein")
      |> mes("did come back, I don't")
      |> mes("think I could forgive Maku.")
      |> mes("In fact, you know what?")
      |> mes("I think I'd even be madder!")
      |> next()
      |> select(["Show Benkaistein's Journal.", "Don't show Benkaistein's Journal."])

    if choice == 1, do: read_journal(ctx), else: decline_journal(ctx)
  end

  defp read_journal(ctx) do
    ctx
    |> cutin("", 255)
    |> mes("[Digotz]")
    |> mes("Why am I so ticked off?")
    |> mes("^3355FF*Sigh*^000000 You have something")
    |> mes("to show me? Huh? Benkaistein")
    |> mes("wanted me to read this diary")
    |> mes("of his? Sure, why not? I do")
    |> mes("owe him a lot over the years...")
    |> next()
    |> mes("[Benkaistein's Journal]")
    |> mes("^856363Today, me, Digotz and")
    |> mes("Maku played this crazy flying")
    |> mes("game. Basically, we make")
    |> mes("these wings out of wood and")
    |> mes("paper, jump off these hills")
    |> mes("and try to fly. Dumb, I know.^000000")
    |> next()
    |> mes("[Benkaistein's Journal]")
    |> mes("^856363Today it was my turn to")
    |> mes("jump and flap my arms with")
    |> mes("these fake, badly made wings.")
    |> mes("It's not really a fun game when")
    |> mes("I think about it. Boy, I hope")
    |> mes("we don't do that again.^000000")
    |> next()
    |> cutin("lhz_diguts02.bmp", 2)
    |> mes("[Digotz]")
    |> mes("Oh yeah, I remember that!")
    |> mes("Maku wore the wings most")
    |> mes("of the time, but I still hold")
    |> mes("the record for staying in the")
    |> mes("air the longest! Yeah, I was")
    |> mes("a regular Kid Pegasus~")
    |> next()
    |> cutin("", 255)
    |> mes("[Benkaistein's Journal]")
    |> mes("^856363Maku, Digotz and me went")
    |> mes("outside of town. Of course,")
    |> mes("we didn't tell anyone or else")
    |> mes("we'd get in trouble. It was")
    |> mes("a really exciting day. But")
    |> mes("then, we ran into a monster!^000000")
    |> next()
    |> mes("[Benkaistein's Journal]")
    |> mes("^856363I wanted to run away but Maku")
    |> mes("and Digotz wanted to beat it so")
    |> mes("that we could become heroes.")
    |> mes("Of course, we got hurt pretty")
    |> mes("bad and the monster got away.")
    |> mes("Boy, mom was not happy...^000000")
    |> next()
    |> cutin("lhz_diguts03.bmp", 2)
    |> mes("[Digotz]")
    |> mes("Huh. I don't remember")
    |> mes("that so well. But I know that")
    |> mes("Benkaistein, me and Maku")
    |> mes("weren't afraid of anything back")
    |> mes("then. We must have been totally")
    |> mes("nuts to fight a monster, though.")
    |> next()
    |> cutin("", 255)
    |> mes("[Benkaistein's Journal]")
    |> mes("^856363Digotz's been sick for three")
    |> mes("days now. It's just a normal")
    |> mes("cold and Maku keeps saying")
    |> mes("it's Digotz's fault he got sick.^FFFFFF ^856363 But he's always asking me to")
    |> mes("go visit him and see if he's okay.^000000")
    |> next()
    |> cutin("lhz_diguts01.bmp", 2)
    |> mes("[Digotz]")
    |> mes("I think I remember being")
    |> mes("pretty sick. Maku was worried?")
    |> mes("I... I must have had a horrible")
    |> mes("life threatening disease like,")
    |> mes("um, Gonorrhitis. You know.")
    |> mes("That might have been it.")
    |> next()
    |> cutin("", 255)
    |> mes("[Benkaistein's Journal]")
    |> mes("^856363Mom and dad keep telling")
    |> mes("me not to hang out with Maku")
    |> mes("anymore. Their reason is really")
    |> mes("dumb, and I don't care if he is")
    |> mes("poor. He's one of the best guys")
    |> mes("that I'll ever know.^000000")
    |> next()
    |> mes("[Benkaistein's Journal]")
    |> mes("^856363Digotz's family is really")
    |> mes("rich and they don't want him")
    |> mes("to see Maku anymore either.")
    |> mes("But Digotz doesn't care.")
    |> mes("I know he likes Maku a lot.^000000")
    |> next()
    |> cutin("lhz_diguts07.bmp", 2)
    |> mes("[Digotz]")
    |> mes("Well, we were a lot")
    |> mes("younger and closer back")
    |> mes("then, so... ^333333*Ahem!*^000000 Why did")
    |> mes("Benkaistein even write that?!")
    |> next()
    |> cutin("", 255)
    |> mes("[Benkaistein's Journal]")
    |> mes("^856363Today, the three of us")
    |> mes("made an oath of brotherhood,")
    |> mes("just like we read in the comic")
    |> mes("book. We swore we'd always")
    |> mes("be friends no matter what.")
    |> mes("For always and for always.^000000")
    |> next()
    |> cutin("lhz_diguts07.bmp", 2)
    |> mes("[Digotz]")
    |> mes("I... I was forced to make")
    |> mes("that oath! And people do")
    |> mes("change, you know! I mean,")
    |> mes("we were basically just kids,")
    |> mes("it's not like that oath really")
    |> mes("means anything now, does it?")
    |> next()
    |> cutin("", 255)
    |> set_char_var(:friendship, 13)
    |> mes("[Digotz]")
    |> mes("That does it. I'm gonna")
    |> mes("go see that Maku. I don't")
    |> mes("miss him or anything, but")
    |> mes("I gotta get him to cancel")
    |> mes("that oath. And maybe I'll")
    |> mes("beat up him a little bit.")
    |> close()
  end

  defp decline_journal(ctx) do
    ctx
    |> mes("[Digotz]")
    |> mes("I don't understand")
    |> mes("why I'm so angry!")
    |> mes("I'm starting to act")
    |> mes("more like Maku, though,")
    |> mes("don't get me wrong, it's")
    |> mes("not like I care about the guy.")
    |> close()
    |> cutin("", 255)
  end

  defp greeting(ctx) do
    ctx
    |> cutin("lhz_diguts02.bmp", 2)
    |> mes("[Digotz]")
    |> mes("Oh, an adventurer?")
    |> mes("Welcome to Uptown")
    |> mes("Lighthalzen. However,")
    |> mes("I'm afraid this area won't")
    |> mes("have much to offer you")
    |> mes("in the way of excitement.")
    |> next()
    |> mes("[Digotz]")
    |> mes("Feel free to take")
    |> mes("a look around if you")
    |> mes("so wish. I'm actually")
    |> mes("glad to see somebody")
    |> mes("aside from the stuck up")
    |> mes("rich people who live here.")
    |> close()
    |> cutin("", 255)
  end
end
