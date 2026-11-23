defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAirship.Crewman do
  @moduledoc """
  Guides passengers and enlists their help reuniting Kain with his daughter.

  ## Behavior

  - Discusses the airship and accepts passenger comments.
  - Assigns deliveries and a search for his wife's journal, rewarding their completion.

  ## Credits

  - Original from rAthena, authors and contributors:
    - Samuray22
    - SinSloth
    - L0ne_W0lf
    - brianluau
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "airplane", x: 47, y: 61, dir: 7, sprite: 833, name: "Crewman", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    ctx = mes(ctx, "[Kain Himere]")
    progress = get_char_var(ctx, :kain_ticket, 0)

    if progress == 4 do
      deliver_package(ctx)
    else
      ctx = welcome(ctx)
      talk_by_progress(ctx, progress)
    end
  end

  defp deliver_package(ctx) do
    ctx
    |> mes("Ah...")
    |> mes("Here it is!")
    |> next()
    |> mes("[Kain Himere]")
    |> mes("A few days ago, a customer")
    |> mes("from Einbroch left this on the")
    |> mes("Airship. He called and let us")
    |> mes("know that he can't come back")
    |> mes("to get it, but he is staying")
    |> mes("over at the Einbroch Hotel.")
    |> next()
    |> mes("[Kain Himere]")
    |> mes("I know it's a strange")
    |> mes("favor to ask, but would")
    |> mes("you deliver this to Defru")
    |> mes("Ark at the Einbroch Hotel?")
    |> mes("Of course, I'll repay you")
    |> mes("upon your return.")
    |> next()
    |> setquest(2079)
    |> set_char_var(:kain_ticket, 5)
    |> mes("^3355FFKain Himere has given you a small box.^000000")
    |> close()
  end

  defp welcome(ctx) do
    ctx
    |> mes("Welcome to the Airship~")
    |> mes("If you have questions or")
    |> mes("need any assistance, please")
    |> mes("don't hesitate to ask me or")
    |> mes("any one of the other crewmen.")
    |> next()
  end

  defp talk_by_progress(ctx, progress) when progress in [0, 1], do: initial_menu(ctx)
  defp talk_by_progress(ctx, 2), do: ask_about_airship(ctx)

  defp talk_by_progress(ctx, 3) do
    ctx
    |> mes("[Kain Himere]")
    |> mes("Oh, how are you?")
    |> mes("If you don't mind me")
    |> mes("asking, where are you")
    |> mes("headed this time?")
    |> choose_destination()
  end

  defp talk_by_progress(ctx, progress) when progress > 4 and progress < 10 do
    ctx
    |> mes("[Kain Himere]")
    |> mes("Oh hello!")
    |> mes("Things are a little")
    |> mes("hectic right now, but")
    |> mes("did you delive-- Oh!")
    |> mes("Wait, excuse me! Sir--!")
    |> next()
    |> mes("^3355FFKain seems too")
    |> mes("busy to speak to")
    |> mes("you right now...^000000")
    |> close()
  end

  defp talk_by_progress(ctx, 10), do: discuss_tarsha(ctx)

  defp talk_by_progress(ctx, progress) when progress in [11, 12] do
    ctx
    |> mes("[Kain Himere]")
    |> mes("Would you find my wife's")
    |> mes("journal and see if Tarsha")
    |> mes("is really my daughter? The")
    |> mes("journal should be buried")
    |> mes("underneath a tree in Einbech.")
    |> close()
  end

  defp talk_by_progress(ctx, 13) do
    ctx
    |> mes("^3355FFYou better fulfill Kain's")
    |> mes("request by finding his wife's")
    |> mes("journal and confronting Tarsha")
    |> mes("before you speak to him again.^000000")
    |> close()
  end

  defp talk_by_progress(ctx, 14), do: finish_journal(ctx)

  defp talk_by_progress(ctx, _) do
    ctx
    |> mes("[Kain Himere]")
    |> mes("Oh, how are you")
    |> mes("lately, my friend?")
    |> mes("I've been doing great,")
    |> mes("especially since you've")
    |> mes("helped me find my daughter.")
    |> mes("Enjoy your travels~")
    |> close()
  end

  defp initial_menu(ctx) do
    {ctx, choice} = select(ctx, ["About the Airship...", "Leave a Comment"])

    case choice do
      1 -> airship_information(ctx)
      2 -> leave_comment(ctx)
      _ -> ctx
    end
  end

  defp airship_information(ctx) do
    ctx = mes(ctx, "[Kain Himere]")
    ctx = set_char_var(ctx, :kain_ticket, get_char_var(ctx, :kain_ticket, 0) + 1)

    ctx =
      if get_char_var(ctx, :kain_ticket, 0) == 1 do
        ctx
        |> mes("Is this your first time flying?")
        |> mes(
          "I understand if you feel nervous. Before I worked here, I used to feel the same way. Still, this"
        )
        |> mes("Airship is pretty amazing. It's incredible what science can do...")
        |> next()
        |> mes("[Kain Himere]")
        |> mes("I hear from the scholars")
        |> mes("who developed the Airship")
        |> mes("technology that just a little")
        |> mes("piece of the heart of Ymir")
        |> mes("generates the power for")
        |> mes("this ship to fly. Incredible...")
        |> next()
        |> mes("[Kain Himere]")
        |> mes("You know, scientific research")
        |> mes("has made living easier and more")
        |> mes("comfortable in the Schwarzwald")
        |> mes("Republic, much in the way magic")
        |> mes("research has changed life in the Rune-Midgarts Kingdom.")
      else
        ctx
        |> mes("You want to hear more")
        |> mes("about the Airship? Hmm,")
        |> mes("there's not too much that")
        |> mes("I know, but let me see...")
        |> next()
        |> mes("[Kain Himere]")
        |> mes("Well, it's rumored that this")
        |> mes("really big corporation runs")
        |> mes("this Airship. Supposedly,")
        |> mes("they've got their hands in")
        |> mes("all sorts of enterprises.")
        |> next()
        |> mes("[Kain Himere]")
        |> mes("Since the Airships are our")
        |> mes("form of national transportation,")
        |> mes("the higher-ups must be making")
        |> mes("a ton of money. It's pretty crazy.")
      end

    close(ctx)
  end

  defp leave_comment(ctx) do
    {ctx, comment} =
      ctx
      |> mes("[Kain Himere]")
      |> mes("You wish to leave")
      |> mes("a comment about our")
      |> mes("service? Tell me your")
      |> mes("message and I'll report")
      |> mes("it to the higher ups.")
      |> mes("To cancel, press '0'.")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"comment$", comment)

    ctx =
      case get_local(ctx, :"comment$", "") do
        "kafra" ->
          ctx
          |> mes("[Kain Himere]")
          |> mes("K-Kafra...?")
          |> mes("Hmm, maybe I better")
          |> mes("not send this up after all...")
          |> emotion(:fret)

        "0" ->
          ctx
          |> mes("[Kain Himere]")
          |> mes("Ah, well, if you have any")
          |> mes("helpful criticism about our")
          |> mes("service, feel free to leave")
          |> mes("me a comment at any time.")

        _ ->
          ctx = mes(ctx, "[#{char_name(ctx, 0)}]")

          ctx
          |> mes(Rathena.concat(get_local(ctx, :"comment$", ""), "."))
          |> next()
          |> mes("[Kain Himere]")
          |> mes("Hmmmm...")
          |> mes("I see. Well, I'll")
          |> mes("send your message")
          |> mes("to my superiors as")
          |> mes("soon as possible.")
          |> mes("Thank you very much.")
      end

    close(ctx)
  end

  defp ask_about_airship(ctx) do
    {ctx, _} = select(ctx, ["About the Airship..."])

    {ctx, choice} =
      ctx
      |> next()
      |> mes("[Kain Himere]")
      |> mes(
        "You must really want to know all about the Airship, don't you? I'm sorry, but I don't know much more than what I've already told you."
      )
      |> next()
      |> mes("[Kain Himere]")
      |> mes(
        "I guess if you'd want to know more, you should study to become a Sage in Juno and do your own Airship research..."
      )
      |> next()
      |> mes("[Kain Himere]")
      |> mes("^666666*Sob...*^000000")
      |> mes("E-excuse me...")
      |> mes("^666666*Sniff*^000000")
      |> next()
      |> select(["What the hell...?", "What's wrong?"])

    case choice do
      1 ->
        ctx
        |> mes("[Kain Himere]")
        |> mes("I-I'm sorry...")
        |> mes("That was so")
        |> mes("unprofessional.")
        |> mes("H-have a safe trip")
        |> mes("and th-thank you for")
        |> mes("using the Airship! ^333333*Sob*^000000")
        |> close()

      2 ->
        ctx |> tell_kains_story() |> choose_destination()

      _ ->
        ctx
    end
  end

  defp tell_kains_story(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Kain Himere]")
      |> mes("I'm sorry, but it's")
      |> mes("a long story. Plus,")
      |> mes("you wouldn't understand...")
      |> next()
      |> select(["I have time for a long story."])

    {ctx, _} =
      ctx
      |> mes("[Kain Himere]")
      |> mes("Alright, I might as well get")
      |> mes("this off my chest. I guess it")
      |> mes("all started when I was a young")
      |> mes("man living in Einbech.")
      |> next()
      |> mes("[Kain Himere]")
      |> mes("Those days, I was pretty hot")
      |> mes("headed and short tempered,")
      |> mes("but working as a miner used to")
      |> mes(
        "always bring me a sense of peace. Staking my life with my friends, mining pick in hand. Yeah..."
      )
      |> next()
      |> mes("[Kain Himere]")
      |> mes("It might have been dangerous,")
      |> mes(
        "but it was good, hard and honest work. You know, the mines that connected to the Einbech lode"
      )
      |> mes("used to be everything to our little town. But then, things changed...")
      |> next()
      |> mes("[Kain Himere]")
      |> mes("The factories started popping")
      |> mes("up and all the ores were moved")
      |> mes("to where the smokestacks never")
      |> mes("stopped churning. More miners")
      |> mes("started working in the factories and the mines became lonelier...")
      |> next()
      |> mes("[Kain Himere]")
      |> mes("But I loved working on the")
      |> mes("land so much, I kept at it")
      |> mes("until the accident happened.")
      |> mes("Now I can't use my right arm")
      |> mes("the way I used to, so I had to")
      |> mes("quit my job as a miner...")
      |> next()
      |> select(["I'm sorry to hear that."])

    {ctx, _} =
      ctx
      |> next()
      |> mes("[Kain Himere]")
      |> mes("Yeah...")
      |> mes("I was really devastated")
      |> mes("when it happened. Those")
      |> mes("were probably the worst")
      |> mes("years of my entire life.")
      |> next()
      |> mes("[Kain Himere]")
      |> mes("I couldn't think about")
      |> mes("life without mining and")
      |> mes("I just lost all enthusiasm")
      |> mes(
        "for life. I developed a drinking problem and started shutting out my family. I was so stupid..."
      )
      |> next()
      |> mes("[Kain Himere]")
      |> mes("I still can't believe how")
      |> mes("supportive my wife was during")
      |> mes("those days. Even when I was at")
      |> mes("my lowest, she tried to sooth my sorrow and even took on a job")
      |> mes("to support me and our daughter.")
      |> next()
      |> mes("[Kain Himere]")
      |> mes("^666666*Sob*^000000 It was only after she")
      |> mes("died that I realized how much")
      |> mes("she must have suffered. To make")
      |> mes("matters worse, I had to leave my daughter behind with a neighbor")
      |> mes("while I searched for work...")
      |> next()
      |> mes("[Kain Himere]")
      |> mes("I spent years wandering")
      |> mes("from town to town, living")
      |> mes(
        "a pretty wild life until I could pick myself up again. And finally, I became an Airship crewman."
      )
      |> next()
      |> mes("[Kain Himere]")
      |> mes("It's been twenty years")
      |> mes("since I've lost my family.")
      |> mes("My daughter is somewhere")
      |> mes("out there, but I can't even")
      |> mes("remember her name...")
      |> next()
      |> select(["Have you tried looking for her?"])

    ctx
    |> mes("[Kain Himere]")
    |> mes("I tried going to the house")
    |> mes("where my neighbor had lived,")
    |> mes("but they moved out years ago.")
    |> mes("I really have no clue where she")
    |> mes("could be. But I don't deserve to see her. I was a horrible father!")
    |> next()
    |> mes("[Kain Himere]")
    |> mes("^666666*Sob*^000000 I'm sorry you")
    |> mes("had to hear all of that,")
    |> mes("but I really appreciate that")
    |> mes("you've listened to me. Now")
    |> mes("tell me, where are you headed?")
  end

  defp choose_destination(ctx) do
    {ctx, choice} = ctx |> next() |> select(["Einbroch", "Juno"])

    case choice do
      1 ->
        ctx = set_char_var(ctx, :kain_ticket, 4)

        ctx
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("I'm heading")
        |> mes("to Einbroch.")
        |> next()
        |> mes("[Kain Himere]")
        |> mes("Perfect...!")
        |> mes("If you don't mind,")
        |> mes("would you do a favor")
        |> mes("for me? First, let me")
        |> mes("find that package...")
        |> close()

      2 ->
        ctx = set_char_var(ctx, :kain_ticket, 3)

        ctx
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("I'm heading")
        |> mes("to Juno.")
        |> next()
        |> mes("[Kain Himere]")
        |> mes("Ah, I see...")
        |> mes("There was something")
        |> mes("I needed sent to Einbroch.")
        |> mes("Anyway, have a good trip.")
        |> mes("Oh, and thanks for listening.")
        |> close()

      _ ->
        ctx
    end
  end

  defp discuss_tarsha(ctx) do
    ctx =
      ctx
      |> mes("[Kain Himere]")
      |> mes("Welcome back to the Airship. So did you deliver that little box safely?")
      |> next()

    {ctx, choice} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("No, unfortunately. He was away when I got there. Let me give this box back to you.")
      |> next()
      |> mes("[Kain Himere]")
      |> mes("Oh...")
      |> mes("What should I do now? Oh well, sorry for putting you through so much trouble.")
      |> next()
      |> select(["Casually mention Miner's Song", "Suavely mention Tarsha"])

    case choice do
      1 -> ctx |> mention_song() |> explain_tarsha() |> close()
      2 -> ctx |> mention_tarsha() |> explain_tarsha() |> close()
      _ -> ctx
    end
  end

  defp mention_song(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("While we're on the topic")
    |> mes("of boxes and deliveries,")
    |> mes("have you ever heard of")
    |> mes("the ''Miner's Song?''")
    |> next()
    |> mes("[Kain Himere]")
    |> mes("''Miner's Song...''")
    |> mes("I miss singing that")
    |> mes("while working the mines.")
    |> mes("I used to sing it all the time")
    |> mes("when I was younger, actually.")
    |> next()
    |> mes("[Kain Himere]")
    |> mes("I think I sang it so")
    |> mes("much, I even got my little")
    |> mes("daughter to sing it with me~")
    |> mes("(But what was her name?!)")
  end

  defp mention_tarsha(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("^333333*Cough cough*")
    |> mes("*Cou--TARSHA--Cough*^000000")
    |> next()
    |> mes("[Kain Himere]")
    |> mes("What the...?")
    |> mes("Wait. T-Tarsha...")
    |> mes("Why does it feel like that")
    |> mes("name means something?")
  end

  defp explain_tarsha(ctx) do
    ctx = next(ctx)

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("You know...")
      |> mes("I met a little girl in Einbroch")
      |> mes("who was singing the ''Miner's")
      |> mes("Song.'' It seems her mother")
      |> mes("Tarsha had taught it to her.")
      |> next()
      |> mes("[Kain Himere]")
      |> mes("Interesting. But usually,")
      |> mes("only miners would know ")
      |> mes("that song. Does this have")
      |> mes("anything to do with me?")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Well, this little girl's mother, Tarsha, learned the song from")
      |> mes("her father who might have been")
      |> mes("a miner. But he mysteriously")
      |> mes("disappeared years ago...")
      |> next()
      |> mes("[Kain Himere]")
      |> mes("Poor girl...!")
      |> mes("Her father just")
      |> mes("left her?! Why,")
      |> mes("she's just like...")
      |> next()
      |> mes("[Kain Himere]")
      |> mes("Wait...")
      |> mes("Sweet Christ...")
      |> mes("The miner who taught")
      |> mes("Tarsha that song might")
      |> mes("have been... ^0000FFme^000000.")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Well, for now, we can't")
    |> mes("be too sure. Do you have")
    |> mes("anything that might prove")
    |> mes("you're Tarsha's father?")
    |> next()
    |> mes("[Kain Himere]")
    |> mes("Ehhmmm...")
    |> mes("Before I left own, I buried")
    |> mes("some of my stuff underneath")
    |> mes("a tree in Einbech. I can't exactly remember where, but my wife's")
    |> mes("journal should be there.")
    |> next()
    |> mes("[Kain Himere]")
    |> mes("Since my wife kept track")
    |> mes("of everything in her journal,")
    |> mes("she should have written enough")
    |> mes(
      "about our daughter for us to know whether or not this Tarsha could be my long lost daughter."
    )
    |> next()
    |> mes("[Kain Himere]")
    |> mes("Now, I can't really leave")
    |> mes("the Airship, so would you help")
    |> mes("me by finding that journal and")
    |> mes("seeing if Tarsha is really related to me somehow? I'd be grateful")
    |> mes("if you could do that for me...")
    |> changequest(2081, 2082)
    |> set_char_var(:kain_ticket, 11)
  end

  defp finish_journal(ctx) do
    ctx =
      if count_item(ctx, 7276) == 1 do
        ctx
        |> mes("^3355FFYou give his wife's")
        |> mes("journal to Kain and tell")
        |> mes("him that you learn that Tarsha")
        |> mes("is really his daughter and that")
        |> mes("she is happily married and is")
        |> mes("an inventor in Einbroch.^000000")
        |> next()
        |> mes("^3355FFKain's eyes well")
        |> mes("with tears and his")
        |> mes("entire body trembles")
        |> mes("with unrestrainable joy.")
        |> next()
        |> mes("[Kain Himere]")
        |> mes("She must have")
        |> mes("had a hard time...")
        |> mes("But she doesn't")
        |> mes("hate me at all.")
        |> next()
        |> mes("[Kain Himere]")
        |> mes("Rashelle?")
        |> mes("Can you see me?")
        |> mes("Can I really be this")
        |> mes("happy? I'm so sorry,")
        |> mes("my love... ^666666*Sob...*^000000")
        |> next()
        |> mes("[Kain Himere]")
        |> mes("Thank you for all of")
        |> mes("your help, youngster.")
        |> mes("And please, take this")
        |> mes("as a token of my gratitude.")
        |> next()
        |> mes("[Kain Himere]")
        |> mes("I know this isn't")
        |> mes("much, but please")
        |> mes("understand that it's")
        |> mes("all I have to give you.")
        |> mes("God bless you for all")
        |> mes("you've done for me~")
        |> completequest(2085)
        |> set_char_var(:kain_ticket, 15)
        |> delitem(7276, 1)
        |> give_item(7311, 4)
      else
        ctx
        |> mes("^3355FFHmmm...")
        |> mes("It would be better")
        |> mes("if you approached")
        |> mes("Kain with the Doodled")
        |> mes("Letter that you received.^000000")
      end

    close(ctx)
  end
end
