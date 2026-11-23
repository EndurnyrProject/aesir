defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAirship.AirshipCaptain236163 do
  @moduledoc """
  Guides passengers through Ferlock's airship and Thierry investigations.

  ## Behavior

  - Searches the passenger list for Thierry and advances his quest.
  - Exchanges letters and supplies, and reveals the Rune Stone investigation.

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
      %{
        map: "airplane",
        x: 236,
        y: 163,
        dir: 5,
        sprite: 873,
        name: "Airship Captain",
        scope: :shared,
        unique_name: "Airship Captain#03"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    ctx = ctx |> cutin("fly_trock.bmp", 2) |> mes("[Ferlock]")
    thierry = get_char_var(ctx, :hg_ma1, 0)
    airship = get_char_var(ctx, :lght_air, 0)
    heart = get_char_var(ctx, :lhz_heart, 0)

    cond do
      thierry in [3, 4] -> thierry_inquiry(ctx)
      thierry == 5 -> ctx |> mes("Please tell his fiance where he is.") |> finish()
      airship == 7 and heart == 11 -> heart_inquiry(ctx)
      airship == 7 and heart == 12 -> conclude_investigation(ctx)
      airship == 7 and heart == 13 -> investigation_reminder(ctx) |> finish()
      true -> passenger_menu(ctx)
    end
  end

  defp thierry_inquiry(ctx) do
    {ctx, _} =
      ctx
      |> mes("Welcome to the airship. I am the captain Ferlock.")
      |> mes("Is there anything that I can help you with today?")
      |> next()
      |> select(["I am looking for a man named Thierry."])

    {ctx, _} =
      ctx
      |> mes("[Ferlock]")
      |> mes("Thierry? Well, I do not think that I know that person.")
      |> mes("I can guarantee you at least that he is not working for me.")
      |> next()
      |> select(["Will you let me check the history of passenger lists?"])

    ctx =
      ctx
      |> mes("[Ferlock]")
      |> mes(
        "I am sorry, but I cannot release such personal information to an unauthorized person."
      )

    if get_char_var(ctx, :hg_ma1, 0) == 3 do
      close(ctx)
    else
      ctx
      |> next()
      |> mes(
        "- Captain Ferlock was carefully listening to you while you were explaining the reason why you have been looking for Thierry. -"
      )
      |> next()
      |> mes("[Ferlock]")
      |> mes(
        "Ummm....I see, I fully understand the siatuation. But, this is my situation that I am not allowed to release our passenger lists to unauthorized people..."
      )
      |> next()
      |> mes("[Ferlock]")
      |> mes(
        "*Sigh*....I guess that rules exist only to be broken one of these days... Okay, I will let you check our passenger lists. Please give me a moment."
      )
      |> next()
      |> mes(
        "- Captain Ferlock took out a heavy book from somewhere, and wrote the name 'Thierry' on the first blank page. -"
      )
      |> mes(
        "- As the letters slowly disappeared, pages of the book started being turned by themselves. -"
      )
      |> next()
      |> mes("- The pages stopped turning at a page that the name 'Thierry' was written on. -")
      |> next()
      |> mes("[Ferlock]")
      |> mes(
        "Haha, you must be surprised by this, huh? As you see, this book is a magic book which you do not need to turn the pages to find a specific page."
      )
      |> mes("Well, this is how we, Schwarzwald Republicans adopt magic in their lives.")
      |> next()
      |> mes("[Ferlock]")
      |> mes(
        "My old friend has given me this....well, it is not important at this moment anyways."
      )
      |> next()
      |> mes("[Ferlock]")
      |> mes(
        "Let's see, Thierry, Thierry.... Yes, he was in the airship about a month ago. He was heading to Hugel, and he was one of the very first passengers of the Hugel route."
      )
      |> next()
      |> mes("[Ferlock]")
      |> mes(
        "....Oh, did you say that he was good at researching stuffs? Now I remember him, he was the guy!"
      )
      |> next()
      |> mes("[Ferlock]")
      |> mes(
        "It was the very first day that we operated the Hugel route. While we were heading to Hugel, a group of dragons raided our airship. "
      )
      |> mes(
        "We were unprepared for a such attack, so basically we were at the very dangerous moment."
      )
      |> next()
      |> mes("[Ferlock]")
      |> mes(
        "It was all my fault because I knew that dragons were one of the reasons why people had not dared to visit Hugel."
      )
      |> mes(
        "How stupid of me! Even until then, I did not even think twice about preparing our crews for those brutal dragons' attacks."
      )
      |> next()
      |> mes("[Ferlock]")
      |> mes(
        "So the dragons seriously damaged our airship, and we were about to fall into the ground. Then this young man came forward and repaired the airship as if he knew that it would be coming."
      )
      |> mes("I am very sure that Thierry was that guy who saved our lives.")
      |> next()
      |> mes("[Ferlock]")
      |> mes(
        "At that time, I wondered what made him look so sad and depressed. And now I know why."
      )
      |> mes(
        "I am so glad that I decided to help you in finding this amazing guy. Now you can go tell his fiance where he is."
      )
      |> next()
      |> mes("[Ferlock]")
      |> mes("If you meet him, please send my regard to him.")
      |> changequest(8045, 8046)
      |> set_char_var(:hg_ma1, 5)
      |> finish()
    end
  end

  defp heart_inquiry(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Ah, thank you for coming.")
      |> mes("Now, I wanted to ask you")
      |> mes("why you were investigating")
      |> mes("Ymir's Heart Piece. Are you")
      |> mes("merely curious, or did you")
      |> mes("have some special reason?")
      |> next()
      |> select(["Just curious...", "Well, there's someone I need to help..."])

    case choice do
      1 ->
        ctx
        |> mes("[Ferlock]")
        |> mes("Just curious...?")
        |> mes("I don't know if satisfying")
        |> mes("your curiosity is worth the")
        |> mes("risks that you have already")
        |> mes("taken. You should be more ")
        |> mes("careful in the future...")
        |> finish()

      2 ->
        explain_rune_stones(ctx) |> finish()

      _ ->
        ctx
    end
  end

  defp explain_rune_stones(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Ferlock]")
      |> mes("Well, I shouldn't be")
      |> mes("trusting you this much,")
      |> mes("but since you've helped")
      |> mes("me and my brother, I feel")
      |> mes("that you must be one of those altruistic adventurers. Very well.")
      |> next()
      |> mes("[Ferlock]")
      |> mes("If you promise that you'll")
      |> mes("never tell what I reveal to")
      |> mes("you, then I suppose I can")
      |> mes("tell you know about the Rune")
      |> mes("Stone and Ymir's Heart Piece.")
      |> next()
      |> select(["I promise..."])

    {ctx, _} =
      ctx
      |> mes("[Ferlock]")
      |> mes("Alright, then. I expect you")
      |> mes("to keep your word. Now, you")
      |> mes("already know that the Airships")
      |> mes("are powered by Rune Stones, imitations of Ymir's Heart pieces.")
      |> next()
      |> mes("[Ferlock]")
      |> mes("Although Rune Stones are")
      |> mes("inferior to true Ymir Heart")
      |> mes("pieces, we can make as many")
      |> mes("as want. As for true Ymir Heart")
      |> mes("Pieces, they're difficult to find or effectively reproduce.")
      |> next()
      |> mes("[Ferlock]")
      |> mes("You may have already")
      |> mes("figured this out, but all")
      |> mes("Rune Stones are produced")
      |> mes("in the Einbroch Laboratory")
      |> mes("for use in the Airships. So")
      |> mes("you see what's going on?")
      |> next()
      |> select(["Wait, what's the Varmunt Project?"])

    ctx
    |> mes("[Ferlock]")
    |> mes("The Varmunt Project is")
    |> mes("a continuation of one of")
    |> mes("the projects started by the")
    |> mes("great Sage, Varmunt. Even as")
    |> mes("a child, he was renown as an")
    |> mes("incredible genius, a prodigy.")
    |> next()
    |> mes("[Ferlock]")
    |> mes("However, no matter how")
    |> mes("much academic success he")
    |> mes("enjoyed--he even became a")
    |> mes("tenured professor at Juno")
    |> mes("University--Varmunt was never able to finance his own research.")
    |> next()
    |> mes("[Ferlock]")
    |> mes("Eventually, he accepted an")
    |> mes("offer from Rekenber Co. to")
    |> mes("develop an energy source in")
    |> mes("exchange for funding. The")
    |> mes("result of his work for them is the invention of the Rune Stone.")
    |> next()
    |> mes("[Ferlock]")
    |> mes("However, the public isn't")
    |> mes("supposed to know that Varmunt")
    |> mes("invented the Rune Stones. Now,")
    |> mes("Varmunt disappeared before he")
    |> mes("could perfect the Rune Stone")
    |> mes("creation process.")
    |> next()
    |> mes("[Ferlock]")
    |> mes("Therefore, the Rune Stones")
    |> mes("we have now are unstable and")
    |> mes("become useless after a while.")
    |> mes("The Varmunt Project aims to")
    |> mes("correct these flaws and perfect")
    |> mes("the Ymir Heart replication...")
    |> next()
    |> mes("[Ferlock]")
    |> mes("Er, anyway, that's why")
    |> mes("I was at the Einbroch")
    |> mes("Laboratory today. My Rune")
    |> mes("Stone was close to empty,")
    |> mes("so I went there to pick up")
    |> mes("a fully charged one.")
    |> next()
    |> mes("[Ferlock]")
    |> mes("^333333*Phew...*^000000")
    |> mes("Would you give me")
    |> mes("a moment to catch")
    |> mes("my breath before")
    |> mes("I continue? Yes,")
    |> mes("there's a little more...")
    |> set_char_var(:lhz_heart, 12)
  end

  defp conclude_investigation(ctx) do
    ctx =
      ctx
      |> mes("Now, #{char_name(ctx, 0)},")
      |> mes("you must be wondering")
      |> mes("why I'm telling you all")
      |> mes("this. I believe that some")
      |> mes("party wishes to steal the")
      |> mes("Rune Stones from the Airships.")
      |> next()
      |> mes("[Ferlock]")
      |> mes("Have you noticed the")
      |> mes("Gremlins and Beholders")
      |> mes("that attack my brother's")
      |> mes("ship? Believe it or not,")
      |> mes("Gremlins are usually just")
      |> mes("harmless and mischievous.")
      |> next()
      |> mes("[Ferlock]")
      |> mes("Gremlin wings also aren't")
      |> mes("naturally powerful enough to")
      |> mes("enable them to fly. However,")
      |> mes("if someone implants Wills of")
      |> mes("the Darkness into them, their")
      |> mes("powers increase exponentially.")
      |> next()
      |> mes("[Ferlock]")
      |> mes("Although Gremlins tend")
      |> mes("not to attack humans unless")
      |> mes("provoked, and that they tend")
      |> mes("to shy away from people, they")
      |> mes("are being controlled to steal")
      |> mes("our Airships' Rune Stones.")
      |> next()
      |> mes("[Ferlock]")
      |> mes("Whoever is controlling the")
      |> mes("Gremlins also sends those")
      |> mes("Beholder monsters in order")
      |> mes("to monitor their progress")
      |> mes("and observe our resistance.")
      |> next()
      |> mes("[Ferlock]")
      |> mes("My brother and I have been")
      |> mes("investigating this matter, but")
      |> mes("so far, we haven't learned very")
      |> mes("much. Now, my Airship only")
      |> mes("provides domestic flights")
      |> mes("and hasn't been attacked.")
      |> next()
      |> mes("[Ferlock]")
      |> mes("Now, my brother's Airship")
      |> mes("specializes in international")
      |> mes("flights and suffers from the")
      |> mes("Gremlin invasions, so we are")
      |> mes("guessing the attackers are from outside the Schwarzwald Republic.")
      |> next()
      |> mes("[Ferlock]")
      |> mes("In any case, that is all")
      |> mes("I really know. Please keep")
      |> mes("this information to yourself")
      |> mes("and let me know if you learn anything new about this situation.")
      |> next()
      |> mes("[Ferlock]")
      |> mes("If I manage to uncover")
      |> mes("anything about the ones")
      |> mes("that are using the Wills")
      |> mes("of Darkness to control the")
      |> mes("Gremlins and steal our Rune")
      |> mes("Stones, I'll let you know.")
      |> next()
      |> mes("[Ferlock]")
      |> mes("Who is sending these")
      |> mes("monsters to invade our")
      |> mes("Airships, and for what")
      |> mes("purpose do they want the")
      |> mes("Rune Stones? Hmm. Well, this")
      |> mes("is goodbye for now, adventurer.")
      |> close()
      |> specialeffect2(:absorbspirits)
      |> completequest(8043)
      |> set_char_var(:lhz_heart, 13)

    ctx =
      if Rathena.truthy?(checkre(ctx, 3)) do
        getexp(ctx, 70_000, 40_000)
      else
        getexp(ctx, 700_000, 400_000)
      end

    cutin(ctx, "", 255)
  end

  defp investigation_reminder(ctx) do
    ctx
    |> mes("I'll be quite busy with my")
    |> mes("captaining duties and my")
    |> mes("private investigation of the")
    |> mes("attempted Rune Stone robberies.")
    |> mes("Hopefully, we'll be able to meet again later. For now, take care.")
  end

  defp passenger_menu(ctx) do
    ctx =
      ctx
      |> mes("Hey there, welcome")
      |> mes("aboard the Airship. I'm")
      |> mes("Ferlock, your captain")
      |> mes("on this flight. How can")
      |> mes("I be of service to you?")
      |> next()

    ctx =
      case get_char_var(ctx, :lght_air, 0) do
        2 -> set_local(ctx, :"question2$", "Give him Tarlock's Letter.")
        3 -> set_local(ctx, :"question2$", "Here are the items I've found.")
        _ -> ctx
      end

    {ctx, choice} =
      select(
        ctx,
        Enum.flat_map(
          [
            "How does this Airship fly?",
            get_local(ctx, :"question2$", ""),
            "Cancel."
          ],
          &String.split(&1, ":")
        )
      )

    case choice do
      1 ->
        ctx
        |> mes("[Ferlock]")
        |> mes("I'm sorry, but I can't")
        |> mes("give you that kind of")
        |> mes("classified information.")
        |> mes("It's too important to the")
        |> mes("security and safety of")
        |> mes("this Airship, you see.")
        |> finish()

      2 ->
        deliver_supplies(ctx, get_char_var(ctx, :lght_air, 0)) |> finish()

      3 ->
        ctx
        |> mes("[Ferlock]")
        |> mes("Well, I hope that")
        |> mes("you enjoy your time")
        |> mes("here on the Airship")
        |> mes("and that you have a")
        |> mes("very pleasant journey.")
        |> finish()

      _ ->
        ctx
    end
  end

  defp deliver_supplies(ctx, 2) do
    ctx
    |> changequest(8032, 8033)
    |> set_char_var(:lght_air, 3)
    |> mes("^3131FFYou give Captain Ferlock")
    |> mes("the letter that his brother")
    |> mes("Tarlock has written for him.^000000")
    |> next()
    |> mes("[Ferlock]")
    |> mes("Oh, this is from my")
    |> mes("brother? Hey, thanks so")
    |> mes("much for bringing this to")
    |> mes("me for him. Ah, give me")
    |> mes("a minute to read all of")
    |> mes("this, would you now?")
    |> next()
    |> mes("[Ferlock]")
    |> mes("...")
    |> mes("So that's what he's been")
    |> mes("up to. Huh. Hahaha! Oh, that's")
    |> mes("funny. Ah, it's always good to")
    |> mes("hear from Tarlock. Anyway,")
    |> mes("I'm sorry to make you wait.")
    |> next()
    |> mes("[Ferlock]")
    |> mes("Anyway, my brother wrote")
    |> mes("about the usual stuff, but")
    |> mes("he mentioned that he was")
    |> mes("hoping to finally return a few")
    |> mes("things he borrowed from me.")
    |> mes("However, he lost them...")
    |> next()
    |> mes("[Ferlock]")
    |> mes("It turns that those nasty")
    |> mes("gremlins that sometimes")
    |> mes("attack his ship stole my")
    |> mes("things, so was he actually")
    |> mes("hoping that you would")
    |> mes("help me get them back.")
    |> next()
    |> mes("[Ferlock]")
    |> mes("Yeah, yeah. He specifically")
    |> mes("mentioned that I shouldn't")
    |> mes("give you my reply until you")
    |> mes("hunt those monsters and get")
    |> mes("my stuff back. I'm sorry, but")
    |> mes("I guess you owe big bro, huh?")
    |> next()
    |> mes("[Ferlock]")
    |> mes("Well, if you're willing to")
    |> mes("help me, would you get my")
    |> mes("^ff00002 Will of the Darkness^000000 and")
    |> mes("^ff00002 Prickly Fruit^000000 back for me?")
    |> next()
    |> mes("[Ferlock]")
    |> mes("The monsters that attack")
    |> mes("Tarlock's Airship should")
    |> mes("have them. I'd appreciate")
    |> mes("it if you'd help me out on")
    |> mes("this, adventurer. Thanks")
    |> mes("in advance and good luck~")
  end

  defp deliver_supplies(ctx, 3) do
    if count_item(ctx, 7340) >= 2 and count_item(ctx, 576) >= 2 do
      ctx
      |> delitem(7340, 2)
      |> delitem(576, 2)
      |> changequest(8033, 8034)
      |> set_char_var(:lght_air, 4)
      |> mes("[Ferlock]")
      |> mes("Oh this is great! Finally,")
      |> mes("I have my stuff back! Still,")
      |> mes("I have no idea why Tarlock")
      |> mes("wanted these things to begin")
      |> mes("with. Oh well. Would you please take this reply to Tarlock for me?")
      |> next()
      |> mes("[Ferlock]")
      |> mes("Thanks again")
      |> mes("for all of your help!")
      |> mes("I don't think I'd ever")
      |> mes("see these things again")
      |> mes("if it weren't for you~")
      |> next()
      |> mes("^3355FFYou have received")
      |> mes("Captain Ferlock's letter")
      |> mes("to deliver to his elder")
      |> mes("brother, Captain Tarlock.^000000")
    else
      ctx
      |> mes("[Ferlock]")
      |> mes("Oh, I'm sorry, but it looks")
      |> mes("like you're missing something.")
      |> mes("Would you please go and find")
      |> mes("^ff00002 Will of the Darkness^000000 and")
      |> mes("^ff00002 Prickly Fruit^000000? Thanks,")
      |> mes("brave adventurer~")
    end
  end

  defp deliver_supplies(ctx, _airship), do: ctx

  defp finish(ctx), do: ctx |> close() |> cutin("", 255)
end
