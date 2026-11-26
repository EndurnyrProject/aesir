defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Vincent do
  @moduledoc """
  Vincent hires adventurers to find a missing child and a stolen gem.

  ## Behavior

  - Starts and advances the search for Phobe and the gem.
  - Rewards the adventurer and requests a delivery to Sir Zhed.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ra_in01",
        x: 384,
        y: 246,
        dir: 3,
        sprite: 47,
        name: "Vincent",
        scope: :shared,
        unique_name: "Vincent#ra_in01"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      base_level(ctx) < 60 ->
        turn_away(ctx)

      get_char_var(ctx, :lost_boy, 0) < 1 ->
        offer_search(ctx)

      get_char_var(ctx, :lost_boy, 0) >= 1 and get_char_var(ctx, :lost_boy, 0) < 4 ->
        search_mansion(ctx)

      get_char_var(ctx, :lost_boy, 0) >= 4 and get_char_var(ctx, :lost_boy, 0) < 7 ->
        search_for_phobe(ctx)

      get_char_var(ctx, :lost_boy, 0) == 7 ->
        confession(ctx)

      get_char_var(ctx, :lost_boy, 0) == 8 ->
        repeat_plea(ctx)

      get_char_var(ctx, :lost_boy, 0) == 9 ->
        return_jewel(ctx)

      get_char_var(ctx, :lost_boy, 0) == 10 ->
        remind_jenny(ctx)

      get_char_var(ctx, :lost_boy, 0) == 11 ->
        reward(ctx)

      true ->
        thank_player(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp turn_away(ctx) do
    ctx
    |> mes("[Vincent]")
    |> mes("You're inside Sir Zhed's")
    |> mes("looking for new employees,")
    |> mes("I don't think you're suited")
    |> mes("for this kind of domestic")
    |> mes("work, brave adventurer.")
    |> close()
  end

  defp offer_search(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Vincent]")
      |> mes("I am Vincert, steward of")
      |> mes("this mansion and faithful")
      |> mes("servant to its master, Sir")
      |> mes("Zhed, the most powerful")
      |> mes("man in all of Arunafeltz.")
      |> next()
      |> mes("[Vincent]")
      |> mes("My master is currently out")
      |> mes("to attend the High Priest")
      |> mes("assembly, and has been gone")
      |> mes("for a few days. I would like to")
      |> mes("ask you for your help with")
      |> mes("a problem on his behalf.")
      |> next()
      |> select(["I'm too busy.", "Sure, why not?"])

    case choice do
      1 ->
        ctx
        |> mes("[Vincent]")
        |> mes("I understand.")
        |> mes("I'm sorry that you're")
        |> mes("too busy at the moment...")
        |> mes("If you should be available")
        |> mes("later, then I'd like to ask for")
        |> mes("your assistance once again.")
        |> close()

      2 ->
        ctx
        |> mes("[Vincent]")
        |> mes("Thank you. You see,")
        |> mes("the pope awarded Sir Zhed")
        |> mes("for his great contributions to")
        |> mes("Arunafeltz with a precious gem.")
        |> mes("However, this jewel is missing")
        |> mes("and I need your help to find it.")
        |> next()
        |> mes("[Vincent]")
        |> mes("I don't have any proof, but")
        |> mes("I suspect it was stolen by")
        |> mes("Phobe, a servant that")
        |> mes("disappeared about the same")
        |> mes("time the gem disappeared.")
        |> next()
        |> mes("[Vincent]")
        |> mes("Please retrieve this gem")
        |> mes("and find who stole it before")
        |> mes("Sir Zhed returns and finds")
        |> mes("out what happened. If you")
        |> mes("can keep this secret, I'd")
        |> mes("very much appreciate it.")
        |> next()
        |> mes("[Vincent]")
        |> mes("I believe that you'd want")
        |> mes("to interrogate Phobe, but")
        |> mes("he has run away somewhere.")
        |> mes("You might want to question the")
        |> mes("other servants of his whereabouts. Thanks again for your help.")
        |> set_char_var(:lost_boy, 1)
        |> setquest(8089)
        |> close()

      _ ->
        ctx
    end
  end

  defp search_mansion(ctx) do
    ctx
    |> mes("[Vincent]")
    |> mes("I suggest looking around")
    |> mes("the mansion and asking the")
    |> mes("servants for any clues about")
    |> mes("Phobe's current location.")
    |> close()
  end

  defp search_for_phobe(ctx) do
    ctx
    |> mes("[Vincent]")
    |> mes("We're running out")
    |> mes("of time... Please find")
    |> mes("the gem and Phobe")
    |> mes("as soon as you can.")
    |> close()
  end

  defp confession(ctx) do
    ctx =
      ctx
      |> mes("[Vincent]")
      |> mes("Ah...!")
      |> mes("H-hello! How are")
      |> mes("you still, er... That")
      |> mes("look on your face? Did")
      |> mes("you happen to find Logan?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("No! I actually got")
      |> mes("stabbed by Mogan, and")
      |> mes("then we had a talk. What's")
      |> mes("the big idea? I come to help")
      |> mes("you, and you try to have me")
      |> mes("killed! I want an explanation!")
      |> next()
      |> mes("[Vincent]")
      |> mes("I... Yes, you deserve")
      |> mes("the truth after wh-what")
      |> mes("I tried to do to you. First")
      |> mes("of all, Phobe is my son, but")
      |> mes("please don't tell anybody!")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("What?")
      |> mes("Why, what's")
      |> mes("the big deal?")
      |> next()
      |> mes("[Vincent]")
      |> mes("There's something of")
      |> mes("a class system here in")
      |> mes("Arunafeltz. No one talks")
      |> mes("about it, but those that")
      |> mes("immigrated here and built this")
      |> mes("city are the dominant class.")
      |> next()
      |> mes("[Vincent]")
      |> mes("The native people are")
      |> mes("second class citizens that")
      |> mes("are looked down upon by the")
      |> mes("descendents of the settlers")
      |> mes("that developed this city. It")
      |> mes("is a sad, undeniable truth.")
      |> next()
      |> mes("[Vincent]")
      |> mes("The native people typically")
      |> mes("suffer from lower class status,")
      |> mes("and usually do the hard, blue")
      |> mes("collar work in the city. Jenny,")
      |> mes("Phobe's mother, is one of them.")
      |> next()
      |> mes("[Vincent]")
      |> mes("It's taboo for me to love her,")
      |> mes("especially since Sir Zhed has")
      |> mes("taken me under his wing and")
      |> mes("been like a father to me. If")
      |> mes("I married her, it'd greatly")
      |> mes("damage his reputation.")
      |> next()
      |> mes("[Vincent]")
      |> mes("I tried to control my")
      |> mes("feelings but... Well,")
      |> mes("Phobe was born. And there's")
      |> mes("no going back now. We did")
      |> mes("get secretly married though,")
      |> mes("and I don't regret that.")
      |> next()
      |> mes("[Vincent]")
      |> mes("Phobe must resent me...")
      |> mes("I've had to treat him and")
      |> mes("his mother like slaves")
      |> mes("in front of other people.")
      |> mes("I know it's horrible... To be")
      |> mes("so cold to those you love.")
      |> next()
      |> mes("[Vincent]")
      |> mes("When he ran off with the")
      |> mes("jewel, I was actually more")
      |> mes("worried about Phobe than")
      |> mes("my master's treasure. So...")
      |> mes("I did what I could to try to")
      |> mes("get him back: I hired you.")
      |> next()
      |> mes("[Vincent]")
      |> mes("However, once you found")
      |> mes("Phobe, I planned to have")
      |> mes("you killed so that we could")
      |> mes("blame you for the theft. I'm")
      |> mes("sorry, I know it's wrong, but")
      |> mes("I was so worried about my boy!")
      |> next()
      |> mes("[Vincent]")
      |> mes("I hope you forgive me...")
      |> mes("I'll do what I should've")
      |> mes("done from the beginning...")
      |> mes("I'll take full responsibility")
      |> mes("for the gem's theft, and Sir")
      |> mes("Zhed can do to me what he will.")
      |> next()
      |> mes("[Vincent]")
      |> mes("The gem is very special...")
      |> mes("Our pope commanded my")
      |> mes("master to keep the jewel")
      |> mes("safely, as it has the power")
      |> mes("to save Arunafeltz and Rachel")
      |> mes("when the time comes.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("The gem is really that")
      |> mes("important, huh? Well, you")
      |> mes("almost had me killed, but")
      |> mes("since I'm still alive, I guess")
      |> mes("I can overlook it, you know?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("You won't get in trouble")
      |> mes("if I can find the jewel and")
      |> mes("Phobe before Sir Zhed")
      |> mes("returns, so I'll try to find")
      |> mes("them for you as soon as I can.")
      |> next()
      |> mes("[Vincent]")
      |> mes("You're willing to")
      |> mes("do that for me? ^333333*Sob*^000000")
      |> mes("Even after what I've put")
      |> mes("you through? ^333333*Sniff*^000000")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Eh, I went through all")
    |> mes("this trouble already, so")
    |> mes("I might as well finish the")
    |> mes("job. Besides, Phobe is")
    |> mes("just a kid, so he's probably")
    |> mes("hiding somewhere in town.")
    |> set_char_var(:lost_boy, 8)
    |> changequest(8094, 8095)
    |> close()
  end

  defp repeat_plea(ctx) do
    ctx =
      ctx
      |> mes("[Vincent]")
      |> mes("The gem is very special...")
      |> mes("Our pope commanded my")
      |> mes("master to keep the jewel")
      |> mes("safely, as it has the power")
      |> mes("to save Arunafeltz and Rachel")
      |> mes("when the time comes.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("The gem is really that")
      |> mes("important, huh? Well, you")
      |> mes("almost had me killed, but")
      |> mes("since I'm still alive, I guess")
      |> mes("I can overlook it, you know?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("You won't get in trouble")
      |> mes("if I can find the jewel and")
      |> mes("Phobe before Sir Zhed")
      |> mes("returns, so I'll try to find")
      |> mes("them for you as soon as I can.")
      |> next()
      |> mes("[Vincent]")
      |> mes("You're willing to")
      |> mes("do that for me? ^333333*Sob*^000000")
      |> mes("Even after what I've put")
      |> mes("you through? ^333333*Sniff*^000000")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Eh, I went through all")
    |> mes("this trouble already, so")
    |> mes("I might as well finish the")
    |> mes("job. Besides, Phobe is")
    |> mes("just a kid, so he's probably")
    |> mes("hiding somewhere in town...")
    |> close()
  end

  defp return_jewel(ctx) do
    ctx =
      ctx
      |> mes("[Vincent]")
      |> mes("You came back!")
      |> mes("Were you able to")
      |> mes("find Phobe?! H-how")
      |> mes("is he? Is he alright?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Huh? Oh yeah, he's")
      |> mes("just fine. I found Phobe")
      |> mes("loitering around Freya's")
      |> mes("Spring. Er, he's not willing")
      |> mes("to come home yet, but he did")
      |> mes("give me the gem he stole.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("So... I earned my")
      |> mes("reward now, right?")
      |> mes("And no one has to die?")
      |> next()
      |> mes("[Vincent]")
      |> mes("Yes, yes, thank you so")
      |> mes("much! I'll never forget")
      |> mes("what you've done for me.")
      |> mes("Oh, my boy is alright!")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("H-hey! Um, take")
      |> mes("this jewel! You need")
      |> mes("to return it to wherever")
      |> mes("it's supposed to go, right?")
      |> next()
      |> mes("[Vincent]")
      |> mes("Oh, yes, I'd better do")
      |> mes("that. While I return this")
      |> mes("jewel, would you please")
      |> mes("tell my wife Jenny that our")
      |> mes("boy is okay? She's been")
      |> mes("very worried about him, so...")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("You want me to tell")
    |> mes("Jenny about Phobe?")
    |> mes("Sure, sure, I'll do that.")
    |> set_char_var(:lost_boy, 10)
    |> changequest(8096, 8097)
    |> close()
  end

  defp remind_jenny(ctx) do
    ctx =
      ctx
      |> mes("[Vincent]")
      |> mes("Oh! While I return this")
      |> mes("jewel, would you please")
      |> mes("tell my wife Jenny that our")
      |> mes("boy is okay? She's been")
      |> mes("very worried about him, so...")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("You want me to tell")
    |> mes("Jenny about Phobe?")
    |> mes("Sure, sure, I'll do that.")
    |> close()
  end

  defp reward(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("I told Jenny that")
    |> mes("about Phobe, and that")
    |> mes("the gem was returned...")
    |> mes("She seemed pretty relieved...")
    |> next()
    |> mes("[Vincent]")
    |> mes("Thank you so much,")
    |> mes("adventurer. She's such")
    |> mes("a kind, loving woman, and")
    |> mes("I hate to see her go through")
    |> mes("all that torment. I don't deserve")
    |> mes("such a beautiful woman...")
    |> next()
    |> mes("[Vincent]")
    |> mes("It's very fortunate that")
    |> mes("you've come to save us...")
    |> mes("Please drop by the next")
    |> mes("time that you're in Rachel,")
    |> mes("and I'll try to help you if I can.")
    |> next()
    |> mes("[Vincent]")
    |> mes("Ah, actually, I have")
    |> mes("one last favor to ask")
    |> mes("of you. Would you please")
    |> mes("bring this note and package")
    |> mes("to my master? He should still")
    |> mes("be in the temple right now.")
    |> next()
    |> mes("[Vincent]")
    |> mes("If you ask for High")
    |> mes("Priest Zhed and mention")
    |> mes("that I sent you, then he")
    |> mes("will meet with you.")
    |> next()
    |> mes("[Vincent]")
    |> mes("Now is the time for")
    |> mes("me to give you your")
    |> mes("reward. How about that?")
    |> mes("I don't know what's inside,")
    |> mes("but I know these items are")
    |> mes("quite valuable nowadays...")
    |> set_char_var(:lost_boy, 12)
    |> changequest(8098, 8099)
    |> give_item(617, 1)
    |> next()
    |> mes("[Vincent]")
    |> mes("Ah, and this note is a")
    |> mes("letter of recommendation")
    |> mes("that I have written for you.")
    |> mes("Please deliver it to Sir Zhed")
    |> mes("as soon as possible. Good bye,")
    |> mes("and thank you for everything.")
    |> next()
    |> mes("^3355FFYou received a letter")
    |> mes("of recommendation")
    |> mes("from Vincent.^000000")
    |> close()
  end

  defp thank_player(ctx) do
    ctx
    |> mes("[Vincent]")
    |> mes("Thank you for everything")
    |> mes("that you've done for me")
    |> mes("and my family. If you ever")
    |> mes("need help, please don't")
    |> mes("hesitate to ask me, alright?")
    |> close()
  end
end
