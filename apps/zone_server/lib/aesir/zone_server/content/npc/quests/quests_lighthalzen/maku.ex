defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Maku do
  @moduledoc """
  Maku recounts his estrangement from his childhood friends.

  ## Behavior

  - Sends the player between Maku and Digotz as their friendship unfolds.
  - Reads Benkaistein's journal and rewards the player for delivering it.

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
      %{map: "lighthalzen", x: 337, y: 232, dir: 3, sprite: 870, name: "Maku", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    ctx = mes(ctx, "[Maku]")
    friendship = get_char_var(ctx, :friendship, 0)

    case friendship do
      4 ->
        relay_message(ctx)

      _ ->
        ctx =
          cond do
            friendship > 14 -> waiting_angrily(ctx)
            friendship == 14 -> waiting_worried(ctx)
            friendship == 13 and count_item(ctx, 7351) > 0 -> read_journal(ctx)
            friendship > 5 and friendship < 13 -> missing_friend(ctx)
            friendship == 5 -> rage(ctx)
            friendship == 3 -> grudge(ctx)
            friendship == 2 -> heard_about_digotz(ctx)
            true -> introduction(ctx)
          end

        ctx |> close2() |> cutin("", 255)
    end
  end

  defp waiting_angrily(ctx) do
    ctx
    |> cutin("lhz_macu07", 2)
    |> mes("Why is this guy so")
    |> mes("late? Once he shows")
    |> mes("up, I swear, I'm gonna...!")
    |> next()
    |> mes("[Maku]")
    |> mes("Eh, he might have")
    |> mes("some kinda reason for")
    |> mes("being late, but if he don't,")
    |> mes("I've been saving a whole")
    |> mes("six pack of kickass to open,")
    |> mes("just for him. Heh heh heh~")
  end

  defp waiting_worried(ctx) do
    ctx
    |> cutin("lhz_macu05", 2)
    |> mes("Why is Digotz")
    |> mes("so late? This isn't")
    |> mes("like him at all. Maybe")
    |> mes("something's wrong?")
  end

  defp read_journal(ctx) do
    ctx =
      ctx
      |> cutin("lhz_macu06", 2)
      |> mes("Hey, what is that? You want")
      |> mes("I should read this journal?")
      |> mes("Er, okay, but I'm none too")
      |> mes("comfortable going through")
      |> mes("somebody's diary. It's just")
      |> mes("kinda... creepy, you know?")
      |> next()
      |> mes("[Maku]")
      |> mes("Hey, this thing is")
      |> mes("Benkaistein's. I haven't")
      |> mes("seen that guy in a long while.")
      |> mes("Ah, so he gave it to you for me")
      |> mes("to read? Alright, I owe him a")
      |> mes("favor or two, so I oughta...")
      |> next()
      |> cutin("lhz_macu06", 255)
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
      |> cutin("lhz_macu03", 2)
      |> mes("[Maku]")
      |> mes("What is he talking about?!")
      |> mes("That game was real fun!")
      |> mes("Yeah, I usually wore the")
      |> mes("wings and Digotz always")
      |> mes("wanted to wear them too.")
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
      |> cutin("lhz_macu03", 2)
      |> mes("[Maku]")
      |> mes("That's right! Back then,")
      |> mes("the three of us weren't")
      |> mes("afraid of anything! Of course,")
      |> mes("Digotz got beat up the most.")
      |> mes("But I gotta say, he was also")
      |> mes("the most fearless of us.")
      |> next()
      |> cutin("", 255)
      |> mes("[Benkaistein's Journal]")
      |> mes("^856363Digot's been sick for three")
      |> mes("days now. It's just a normal")
      |> mes("cold and Maku keeps saying")
      |> mes("it's Digotz's fault he got sick.^FFFFFF ^856363 But he's always asking me to")
      |> mes("go visit him and see if he's okay.^000000")
      |> next()
      |> cutin("lhz_macu04", 2)
      |> mes("[Maku]")
      |> mes("Wh-what?! No, I wasn't")
      |> mes("worried at all! That must")
      |> mes("have been the time Digot")
      |> mes("caught Clymonia. You know,")
      |> mes("that, uh, horrible disease. No")
      |> mes("one should have that one!")
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
      |> cutin("lhz_macu01", 2)
      |> mes("[Benkaistein's Journal]")
      |> mes("^856363Digotz's family is really")
      |> mes("rich and they don't want him")
      |> mes("to see Maku anymore either.")
      |> mes("But Digotz doesn't care.")
      |> mes("I know he likes Maku a lot.^000000")
      |> next()
      |> mes("[Maku]")
      |> mes("...")
      |> mes("......")
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
      |> cutin("lhz_macu06", 2)
      |> mes("[Maku]")
      |> mes("Well, that's true,")
      |> mes("I guess, but people")
      |> mes("change! Besides, we got")
      |> mes("that idea from a comic book!")
      |> mes("Well, if he apologizes first,")
      |> mes("I guess I better forgive him.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Good...")
      |> mes("Because Digotz said")
      |> mes("that he'll be coming")
      |> mes("by in a few days.")
      |> next()
      |> cutin("lhz_macu07", 2)
      |> mes("[Maku]")
      |> mes("What?! He's really coming")
      |> mes("here? What for? It's too late")
      |> mes("to patch things up! Still, I'd be")
      |> mes("a real prick if I didn't see him. Alright, fine! I'll teach that guy")
      |> mes("a lesson once he's here!")
      |> next()
      |> mes("[Maku]")
      |> mes("And, um, gimme that")
      |> mes("journal! I'm gonna read")
      |> mes("more of it so I can make")
      |> mes("fun of Digotz. Bwahahaha!")
      |> mes("But yeah, um, thanks. Not")
      |> mes("that I'm grateful or anything.")
      |> cutin("lhz_macu07", 255)
      |> next()
      |> delitem(7351, 1)
      |> set_char_var(:friendship, 14)

    experience =
      cond do
        base_level(ctx) > 90 -> 70_000
        base_level(ctx) > 75 -> 40_000
        true -> 20_000
      end

    experience = if Rathena.truthy?(checkre(ctx, 3)), do: experience, else: experience * 10
    ctx = getexp(ctx, experience, 0)

    ctx
    |> cutin("lhz_macu04", 2)
    |> mes("[Maku]")
    |> mes("So, uh, I guess")
    |> mes("I'll see you later.")
    |> mes("Um, now I gotta get")
    |> mes("ready for something.")
    |> mes("^333333(But not to see Digotz!)^000000")
  end

  defp missing_friend(ctx) do
    ctx
    |> cutin("lhz_macu06", 2)
    |> mes("Arrrrgh! Whenever I hear")
    |> mes("about that Digotz, I get so")
    |> mes("peeved! Is that guy giving")
    |> mes("me the brushoff just because")
    |> mes("I'm not a rich guy like he is?!")
    |> next()
    |> mes("[Maku]")
    |> mes("I can't...")
    |> mes("I can't even beat him up")
    |> mes("all properly because of")
    |> mes("all those freakin' guards!")
    |> mes("Arrrrrrrgh! Man, where's")
    |> mes("Benkaistein when I need him?")
  end

  defp rage(ctx) do
    ctx
    |> mes("RrrrRrrrr....")
    |> mes("RrrrrRRRrrRR....")
    |> mes("GGGGGRRRRR...")
    |> next()
    |> mes("^3355FFUh oh...")
    |> mes("It looks like Maku")
    |> mes("is starting to rage")
    |> mes("just a bit too much.^000000")
    |> next()
    |> mes("...")
    |> mes("......")
    |> mes(".........")
    |> next()
    |> cutin("lhz_macu06", 2)
    |> mes("[Maku]")
    |> mes("Gggrrrr...")
    |> next()
    |> mes("[Maku]")
    |> mes("GRAAAAAAAAH~!")
    |> mes("Who the hell does he")
    |> mes("think he is, telling me")
    |> mes("all sorts of crap!? Digotz,")
    |> mes("you're not getting away")
    |> mes("with this! Gonna wreck you!!")
    |> next()
    |> mes("^3355FFMaku's seething quickly")
    |> mes("explodes into pure, violent")
    |> mes("rage. You manage to calm")
    |> mes("him down after a while, but")
    |> mes("barely keep yourself from")
    |> mes("getting killed in this outburst.^000000")
    |> percent_heal(hp: -50, sp: 0)
    |> next()
    |> mes("[Maku]")
    |> mes("^333333*Pant pant* *Whew~*^000000")
    |> mes("D-don't worry, I've got")
    |> mes("a grip on myself now.")
    |> mes("Thanks for not letting me")
    |> mes("get too crazy. Times like")
    |> mes("this, I really miss ^FF0000Benkaistein^000000.")
    |> next()
    |> mes("[Maku]")
    |> mes("Benkaistein would always")
    |> mes("make sure that I'd stay out")
    |> mes("of fights. I really miss that")
    |> mes("guy. Still, he ain't around...")
    |> next()
    |> set_char_var(:friendship, 6)
    |> mes("[Maku]")
    |> mes("Damn those guards!")
    |> mes("If they weren't there,")
    |> mes("I could just go over and")
    |> mes("kick Digotz's ass! I swear,")
    |> mes("if it weren't for them...!")
  end

  defp grudge(ctx) do
    ctx
    |> cutin("lhz_macu03", 2)
    |> mes("Man, I need to blow off some")
    |> mes("steam! Sure, me and Digotz")
    |> mes("were buds before and maybe")
    |> mes("we might seem like friends now,")
    |> mes("but not anymore, though we used")
    |> mes("to be closer than this. Argh!")
    |> next()
    |> mes("[Maku]")
    |> mes("Don't get me wrong, I don't")
    |> mes("miss the guy or anything like")
    |> mes("that and I don't feel sorry about")
    |> mes("what happened. But if he ever")
    |> mes("came to apologize to me, I'd")
    |> mes("probably accept, you know.")
    |> next()
    |> mes("[Maku]")
    |> mes("Well, after thinking")
    |> mes("about it, of course.")
    |> mes("I mean, I'm not the one")
    |> mes("holding a grudge. It's all")
    |> mes("that guy's fault! Sheeeesh!")
  end

  defp heard_about_digotz(ctx) do
    {ctx, _} =
      ctx
      |> mes("Hey, what are you")
      |> mes("doing back over here?")
      |> mes("I thought I recommended")
      |> mes("going over to check out")
      |> mes("Uptown Lighthalzen. This")
      |> mes("place is pretty run-down...")
      |> next()
      |> select(["I actually met Digotz and..."])

    ctx
    |> cutin("lhz_macu05", 2)
    |> mes("[Maku]")
    |> mes("You what...?!")
    |> mes("You saw my old pal,")
    |> mes("Digotz?! Er, I mean,")
    |> mes("Mister Alexander Digotz,")
    |> mes("who usedta be my buddy,")
    |> mes("but obviously not anymore.")
    |> next()
    |> cutin("lhz_macu02", 2)
    |> mes("[Maku]")
    |> mes("Sure, we were real close")
    |> mes("at one time, but that was")
    |> mes("too long ago. It's been a")
    |> mes("long time since we hung")
    |> mes("out and he probably hates")
    |> mes("my penniless guts and...")
    |> set_char_var(:friendship, 3)
    |> changequest(12_001, 12_002)
    |> next()
    |> mes("[Maku]")
    |> mes("Crud, just listen to")
    |> mes("me, I sound like a wuss.")
    |> mes("I don't miss Digotz! In fact,")
    |> mes("I hate the guy, one hundred")
    |> mes("percent! The next time I see")
    |> mes("him, I'll beat him to a pulp!")
  end

  defp introduction(ctx) do
    ctx =
      ctx
      |> cutin("lhz_macu01", 2)
      |> mes("Hey, you're one of")
      |> mes("those adventurers, eh?")
      |> mes("Welcome to the ghetto.")
      |> mes("Nothing too adventurous")
      |> mes("here, but hey, you can")
      |> mes("explore all you want.")
      |> next()
      |> mes("[Maku]")
      |> mes("I don't know if you know,")
      |> mes("but actually, the people who")
      |> mes("live here ain't allowed to")
      |> mes("explore this whole city. It's")
      |> mes("kind of taboo to talk about,")
      |> mes("but what do I care, right?")
      |> next()
      |> mes("[Maku]")
      |> mes("Yeah, basically the rich")
      |> mes("people here are too afraid")
      |> mes("of the poor people comin' to")
      |> mes("see them, so the security in")
      |> mes("this city is pretty tight! Those")
      |> mes("upper class guys are trash...")
      |> next()
      |> mes("[Maku]")
      |> mes("I didn't used to think")
      |> mes("this way. I actually used")
      |> mes("to have a pretty rich friend")
      |> mes("till I found out he's not all")
      |> mes("I thought he was. That")
      |> mes("moron! Why's he like that?!")
      |> next()
      |> mes("[Maku]")
      |> mes("Eh, forget about it.")
      |> mes("Why am I even talking")
      |> mes("about my personal life")
      |> mes("to someone I just met")
      |> mes("anyway? Sure, we all")
      |> mes("do it, but still...")
      |> set_char_var(:friendship, 1)

    ctx =
      if isbegin_quest(ctx, 12_000) == 0 do
        setquest(ctx, 12_000)
      else
        ctx
      end

    ctx
    |> next()
    |> mes("[Maku]")
    |> mes("Well, when you get")
    |> mes("bored of the ghetto,")
    |> mes("you really oughta check")
    |> mes("out the rich section of town.")
    |> mes("I'm bitter, but I'll also admit")
    |> mes("it's way nicer than this place.")
  end

  defp relay_message(ctx) do
    {ctx, _} =
      ctx
      |> cutin("lhz_macu05", 2)
      |> mes("What the hell are you")
      |> mes("still doing around here?")
      |> mes("You must have better things")
      |> mes("to do than talk to a ruffian")
      |> mes("like me or that snobby and")
      |> mes("totally prickish Digotz.")
      |> next()
      |> select(["Speaking of which..."])

    with {:ok, ctx} <- first_message(ctx),
         {:ok, ctx} <- second_message(ctx),
         {:ok, ctx} <- third_message(ctx),
         {:ok, ctx} <- fourth_message(ctx),
         {:ok, ctx} <- fifth_message(ctx),
         {:ok, ctx} <- sixth_message(ctx) do
      ctx
      |> set_char_var(:friendship, 5)
      |> cutin("lhz_macu06", 2)
      |> mes("[Maku]")
      |> mes("That's it.")
      |> mes("It's decided. The")
      |> mes("next time I see Digotz,")
      |> mes("I'm gonna plaster his")
      |> mes("face all over the floor.")
      |> close2()
      |> cutin("lhz_macu06", 255)
    else
      {:error, ctx} ->
        ctx
        |> mes("[Maku]")
        |> mes("Wha...? I dunno if Digotz")
        |> mes("would say something like")
        |> mes("that. You sure you heard")
        |> mes("him carefully enough? It's")
        |> mes("been a while, but I know")
        |> mes("how Digotz talks, man.")
        |> close2()
        |> cutin("", 255)
    end
  end

  defp first_message(ctx) do
    {ctx, response} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Speaking of which...")
      |> mes("I spoke to Digotz again.")
      |> mes("He told me to give you a")
      |> mes("message, but I'm not sure th--")
      |> next()
      |> mes("[Maku]")
      |> mes("That no-good bastard")
      |> mes("has a message for me?!")
      |> mes("Oh, I'm soooo honored~")
      |> mes("Tell me what that fink")
      |> mes("has to say, line by line!")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"input$", response)
    if get_local(ctx, :"input$", "") == "Hopeless bastard!", do: {:ok, ctx}, else: {:error, ctx}
  end

  defp second_message(ctx) do
    {ctx, response} =
      ctx
      |> mes("[Maku]")
      |> mes("''Hopeless bastard?!''")
      |> mes("Well, at least he had")
      |> mes("the stomach to say that.")
      |> mes("Through somebody else")
      |> mes("anyway! What else'd he say?!")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"input$", response)

    if get_local(ctx, :"input$", "") == "You're still a stubborn jerk!",
      do: {:ok, ctx},
      else: {:error, ctx}
  end

  defp third_message(ctx) do
    {ctx, response} =
      ctx
      |> mes("[Maku]")
      |> mes("''Stubborn jerk?!''")
      |> mes("Takes one to know one,")
      |> mes("bastard! Why I oughta--")
      |> mes("Grrr! What'd he say next?!")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"input$", response)

    if get_local(ctx, :"input$", "") == "You owe me at least 3 lunches!",
      do: {:ok, ctx},
      else: {:error, ctx}
  end

  defp fourth_message(ctx) do
    {ctx, response} =
      ctx
      |> mes("[Maku]")
      |> mes("Three lunches?!")
      |> mes("I treated that guy to")
      |> mes("lunch, like, fifteen times!")
      |> mes("I tell you, the guy does not")
      |> mes("know the meaning of friendship!")
      |> mes("What else did that moron say?!")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"input$", response)

    if get_local(ctx, :"input$", "") == "Not to mention an apology!",
      do: {:ok, ctx},
      else: {:error, ctx}
  end

  defp fifth_message(ctx) do
    {ctx, response} =
      ctx
      |> cutin("lhz_macu05", 255)
      |> mes("[Maku]")
      |> mes("Me, apologize?!")
      |> mes("He should be on his hands")
      |> mes("and knees begging for my")
      |> mes("frickin' forgiveness! That...")
      |> mes("That selfish no-good stupid...")
      |> mes("W-what else did he tell you?!")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"input$", response)

    if get_local(ctx, :"input$", "") == "But who cares what you think?!",
      do: {:ok, ctx},
      else: {:error, ctx}
  end

  defp sixth_message(ctx) do
    {ctx, response} =
      ctx
      |> mes("[Maku]")
      |> mes("''Who cares what I think?!''")
      |> mes("GRRRAAAH~!! Who cares")
      |> mes("what he thinks!! ^333333*Pant Pant*^000000")
      |> mes("I'm gonna murderlize that")
      |> mes("dumb creep! He can't possibly")
      |> mes("make me angrier than I am now!")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"input$", response)

    if get_local(ctx, :"input$", "") == "I'm so goddamn happy without you!",
      do: {:ok, ctx},
      else: {:error, ctx}
  end
end
