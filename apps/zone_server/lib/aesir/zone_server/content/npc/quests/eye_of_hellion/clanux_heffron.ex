defmodule Aesir.ZoneServer.Content.Npc.Quests.EyeOfHellion.ClanuxHeffron do
  @moduledoc """
  Clanux Heffron shares clues to the Hellion's gem while competing for its treasure.

  ## Behavior

  - Checks inventory capacity before discussing the quest.
  - Sends helpers to the old Swordman Training Grounds and shares cogwheel clues.
  - Reacts to reports from the Tool Shop and advances the Prontera investigation.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - L0ne_W0lf
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prontera",
        x: 269,
        y: 326,
        dir: 3,
        sprite: 50,
        name: "Clanux Heffron",
        scope: :shared,
        unique_name: "Clanux Heffron#hellion"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :MaxWeight, 0) - weight(ctx) < 2000 or
         checkweight(ctx, [{1201, 1}]) == 0 do
      ctx
      |> mes("^3355FFHold it right there!")
      |> mes(
        "You're carrying too many items and don't have enough inventory space to receive any rewards. Please make more inventory space available and come back to take this challenge."
      )
      |> close()
    else
      quest_progress(ctx, get_char_var(ctx, :HELLIONQ, 0))
    end
  end

  defp quest_progress(ctx, step) when step < 36 do
    ctx
    |> mes("[Clanux Heffron]")
    |> mes("What's wrong with")
    |> mes("this map?! I can't")
    |> mes("find a blasted thing")
    |> mes("on it! How can finding")
    |> mes("something be so hard?")
    |> close()
  end

  defp quest_progress(ctx, 36), do: meet_clanux(ctx)
  defp quest_progress(ctx, 38), do: offer_partnership(ctx)

  defp quest_progress(ctx, 39) do
    ctx
    |> mes("[Clanux Heffron]")
    |> mes("Look pal, I found this broken")
    |> mes("sword, a bonafide clue if I ever saw one, in the old Swordman")
    |> mes("Training Grounds in Prontera.")
    |> mes("You should be able to find")
    |> mes("something else there... maybe.")
    |> close()
  end

  defp quest_progress(ctx, 40), do: report_search(ctx)

  defp quest_progress(ctx, 41) do
    ctx
    |> mes("[Clanux Heffron]")
    |> mes("Hey... Didn't I tell")
    |> mes("you to check out the")
    |> mes("Tool Shop in case there")
    |> mes("was anything I missed?")
    |> mes("Now go! That's an order!")
    |> close()
  end

  defp quest_progress(ctx, 42) do
    ctx
    |> mes("[Clanux Heffron]")
    |> mes("Wha--? I had no idea")
    |> mes("that sort of thing could")
    |> mes("be hidden in that training")
    |> mes("I missed it. Oh, so the Veggie Lady gave you a password and all?")
    |> next()
    |> mes("[Clanux Heffron]")
    |> mes("Huh, I can't make heads")
    |> mes("or tails of that password.")
    |> mes("I guess I have no choice but")
    |> mes("to give you this, the cogwheel clue I found from the Tool Shop.")
    |> next()
    |> mes("[Clanux Heffron]")
    |> mes("I mean, you've been lucky")
    |> mes("enough till now, so you'll")
    |> mes("probably be able to stumble")
    |> mes("upon the answer behind this")
    |> mes("weird, weird riddle. But you")
    |> mes("gotta tell me the answer too!")
    |> next()
    |> mes("[Clanux Heffron]")
    |> mes("Alright, now take your")
    |> mes("cogwheel and get outta")
    |> mes("here. The sooner you get")
    |> mes("that clue, the sooner I'll")
    |> mes("get that Hellion's gem.")
    |> set_char_var(:HELLIONQ, 43)
    |> give_item(7093, 1)
    |> close()
  end

  defp quest_progress(ctx, 43) do
    ctx
    |> mes("[Clanux Heffron]")
    |> mes("Hey, hurry up and check")
    |> mes("the Tool Shop and figure")
    |> mes("out the meaning of that")
    |> mes("password! Maybe that weird")
    |> mes("machine there is a part of")
    |> mes("this whole puzzle? Nah...")
    |> close()
  end

  defp quest_progress(ctx, 44), do: report_tool_shop(ctx)
  defp quest_progress(ctx, 45), do: report_password(ctx)

  defp quest_progress(ctx, step) when step > 45 and step < 71 do
    ctx
    |> mes("[Clanux Heffron]")
    |> mes("Oh hey, it's you.")
    |> mes("Listen I got this number")
    |> mes("pad to pop out of that old")
    |> mes("machine in the Tool Shop,")
    |> mes("I still don't know what the")
    |> mes("password for it might be.")
    |> next()
    |> mes("[Clanux Heffron]")
    |> mes("If I couldn't figure")
    |> mes("it out, and I understand")
    |> mes("if you couldn't figure this")
    |> mes("out, then this puzzle must")
    |> mes("be freakin' impossible!")
    |> close()
  end

  defp quest_progress(ctx, _step) do
    ctx
    |> mes("[Clanux Heffron]")
    |> mes("Oh man, I am totally")
    |> mes("lost. What the heck")
    |> mes("should I be looking for?")
    |> close()
  end

  defp meet_clanux(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Excuse me, but are")
      |> mes("you Clanux Heffron?")
      |> next()
      |> mes("[Clanux Heffron]")
      |> mes("Why, who are you")
      |> mes("and what the heck")
      |> mes("do you want? Oh...")
      |> mes("Sent by Chilias, eh?")
      |> mes("What does he want?")
      |> next()
      |> select(["He wants me to help you.", "He wants you to help me."])

    if choice == 1 do
      ask_about_clues(ctx)
    else
      ctx
      |> mes("[Clanux Heffron]")
      |> mes("Help you...? What, with")
      |> mes("clues to the location of")
      |> mes("the Hellion's gem? Screw")
      |> mes("that, pal! Why should I help")
      |> mes("you if we're gonna compete")
      |> mes("for the same prize?!")
      |> set_char_var(:HELLIONQ, 38)
      |> close()
    end
  end

  defp ask_about_clues(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Clanux Heffron]")
      |> mes("So he sent me an")
      |> mes("assistant, huh? Well...")
      |> mes("Seeing as he gave me this")
      |> mes("clue and I've taken so long")
      |> mes("and still don't have anything to show for it, I don't blame him.")
      |> next()
      |> mes("[Clanux Heffron]")
      |> mes("Well, if he sent you to")
      |> mes("help me out, I guess I can")
      |> mes("tell you everything. For the")
      |> mes("clues he had me look for,")
      |> mes("I've only found two so far.")
      |> mes("But I can't figure them out...")
      |> next()
      |> mes("[Clanux Heffron]")
      |> mes("Let's see, there's this")
      |> mes("broken sword and this")
      |> mes("strange lookin' cogwheel.")
      |> mes("What do these clues mean?!")
      |> mes("Did the old man give you")
      |> mes("any hints to help me out?")
      |> next()
      |> select(["Where did you find these?", "No, I'm sorry."])

    if choice == 1 do
      ctx
      |> mes("[Clanux Heffron]")
      |> mes("Oh, these I found in Prontera.")
      |> mes("That old coot hid these real")
      |> mes("good. But yeah, I doubt you'd")
      |> mes("find anything, but would you try")
      |> mes("checking out the old Swordman")
      |> mes("Training ground for more clues?")
      |> next()
      |> mes("[Clanux Heffron]")
      |> mes("Man, that Hellion's gem")
      |> mes("must really be worth a pretty")
      |> mes("penny if the old man went")
      |> mes("through so much trouble to")
      |> mes("even hide these clues. Oh")
      |> mes("man, I want it so bad...")
      |> set_char_var(:HELLIONQ, 39)
      |> close()
    else
      ctx
      |> mes("[Clanux Heffron]")
      |> mes("Wha--? Then why are")
      |> mes("you even here to help")
      |> mes("me then? Huh. That old")
      |> mes("coot must not trust me")
      |> mes("enough, but I can't exactly")
      |> mes("blame him. Alright then...")
      |> next()
      |> mes("[Clanux Heffron]")
      |> mes("If you're gonna help me,")
      |> mes("go search the old Swordman")
      |> mes("Training Grounds over here in")
      |> mes("Prontera. I doubt it, but there's")
      |> mes("a chance I mighta missed")
      |> mes("something there. Get to it!")
      |> set_char_var(:HELLIONQ, 39)
      |> close()
    end
  end

  defp offer_partnership(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Clanux Heffron]")
      |> mes("Hey, why do you keep")
      |> mes("botherin' me?! Go and")
      |> mes("find your own clues for the")
      |> mes("Hellion's gem on your own,")
      |> mes("jerkface! Now getouttahere!")
      |> next()
      |> select(["W-wait! Let's work together!", "Fine. I don't need your help!"])

    if choice == 1 do
      ctx
      |> mes("[Clanux Heffron]")
      |> mes("Work together, eh? You")
      |> mes("know, normally I'd tell you")
      |> mes("to make like a moonwalker")
      |> mes("and just beat it, but I gotta")
      |> mes("admit that I ain't doin' so")
      |> mes("good on my own on this...")
      |> next()
      |> mes("[Clanux Heffron]")
      |> mes("Alright, fine.")
      |> mes("First, look through")
      |> mes("the old Swordman Training")
      |> mes("Grounds here in Prontera.")
      |> mes("There might be some clues left over there for you to find...")
      |> set_char_var(:HELLIONQ, 39)
      |> close()
    else
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Fine.")
      |> mes("I don't need")
      |> mes("your help!")
      |> next()
      |> mes("[Clannux Heffron]")
      |> mes("Yeah right!")
      |> mes("You'll be back!")
      |> mes("...They always")
      |> mes("come back.")
      |> close()
    end
  end

  defp report_search(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Clanux Heffron]")
      |> mes("Hey, you're done")
      |> mes("searching? Were you")
      |> mes("able to find anything?")
      |> next()
      |> select(["Nothing...", "In fact, I found this."])

    if choice == 1 do
      ctx =
        ctx
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("^333333(This guy's a real punk!")
        |> mes("I better not share any new")
        |> mes("information I've found, just")
        |> mes("in case he doesn't already")
        |> mes("know about it.)^000000")
        |> next()

      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("I... I wasn't able to")
      |> mes("find anything that looked")
      |> mes("like a clue. I'm sorry, but")
      |> mes("I let you down big time...")
      |> next()
      |> mes("[Clanux Heffron]")
      |> mes("Aw nuts! Alright, if you")
      |> mes("go back to the old man, let")
      |> mes("him know that I found a broken")
      |> mes("sword from the old Swordman")
      |> mes("Training Grounds and this")
      |> mes("cogwheel from the Tool Shop.")
      |> next()
      |> mes("[Clanux Heffron]")
      |> mes("The clues I've found so")
      |> mes("far don't make any sense!")
      |> mes("So if you can, convince him to")
      |> mes("drop me a couple more hints.")
      |> mes("And give this to the old guy")
      |> mes("to prove I found it, will you?")
      |> set_char_var(:HELLIONQ, 41)
      |> give_item(7093, 1)
      |> next()
      |> mes("[Clanux Heffron]")
      |> mes("That's all I know.")
      |> mes("At this point you're")
      |> mes("probably better off")
      |> mes("searching for these")
      |> mes("clues on your own...")
      |> close()
    else
      ctx
      |> mes("[Clanux Heffron]")
      |> mes("So that's what you")
      |> mes("found? Huh. I'm even")
      |> mes("more confused. Alright.")
      |> mes("Well, I found a broken")
      |> mes("sword in the Swordman")
      |> mes("Training Grounds.")
      |> next()
      |> mes("[Clanux Heffron]")
      |> mes("Oh, and I also found")
      |> mes("this old cogwheel in the")
      |> mes("Tool Shop around here.")
      |> mes("Here, just take it. Maybe")
      |> mes("you'll have better luck")
      |> mes("figuring out what it means.")
      |> next()
      |> mes("[Clanux Heffron]")
      |> mes("But once you do")
      |> mes("learn anything new,")
      |> mes("to me and let me know!")
      |> mes("That's an order, got it?")
      |> set_char_var(:HELLIONQ, 41)
      |> give_item(7093, 1)
      |> close()
    end
  end

  defp report_tool_shop(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Clanux Heffron]")
      |> mes("Hey...")
      |> mes("Didja find anything")
      |> mes("new in the Tool Shop?")
      |> next()
      |> select([
        "Pretend that nothing happened.",
        "Share what you learned."
      ])

    if choice == 1 do
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Nope...")
      |> mes("I couldn't find any")
      |> mes("new leads. I guess")
      |> mes("I have no choice but to")
      |> mes("go back to Chilias'Tyus,")
      |> mes("unless you know anything...")
      |> next()
      |> mes("[Clanux Heffron]")
      |> mes("Bah!")
      |> mes("Freakin' useless!")
      |> mes("What kind of assistant")
      |> mes("are you anyway, huh?")
      |> close()
    else
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Well, I put that cogwheel")
      |> mes("into that weird machine in")
      |> mes("the Tool Shop and some kind")
      |> mes("of number pad came out. Then...")
      |> mes("Uh, I couldn't figure out what")
      |> mes("the password was. I'm stuck!")
      |> next()
      |> mes("[Clanux Heffron]")
      |> mes("Oh yeah? Hah! Well, now")
      |> mes("that the easy part is done, I'll just figure out that secret")
      |> mes("password myself! Hahaha! That Hellion's gem is as good as mine!")
      |> close()
    end
  end

  defp report_password(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Clanux Heffron]")
      |> mes("Hey, so you have")
      |> mes("anything new to report?")
      |> mes("Oh, and did you learn")
      |> mes("anything from that weird")
      |> mes("machine in the Tool Shop?")
      |> next()
      |> select([
        "Tell him just a little bit.",
        "Don't tell him."
      ])

    if choice == 1 do
      ctx =
        ctx
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("Well, I put that cogwheel")
        |> mes("into that weird machine in")
        |> mes("the Tool Shop and some kind")
        |> mes("of number pad came out. Then...")
        |> next()

      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("^333333(Wait, I can't trust this")
      |> mes("guy!)^000000 I put in every single")
      |> mes("password that I could think")
      |> mes("of, but nothing happened!")
      |> mes("I think I'm stuck...")
      |> next()
      |> mes("[Clanux Heffron]")
      |> mes("Oh yeah? Hah! Well, now")
      |> mes("that the easy part is done, I'll just figure out that secret")
      |> mes("password myself! Hahaha! That Hellion's gem is as good as mine!")
      |> set_char_var(:HELLIONQ, 46)
      |> close()
    else
      ctx
      |> mes("[Clanux Heffron]")
      |> mes("Huh. You should be able")
      |> mes("to get some number pad to")
      |> mes("come out from that machine.")
      |> mes("Yeah, I was able to get that")
      |> mes("far, but I haven't been able")
      |> mes("to figure out the password...")
      |> set_char_var(:HELLIONQ, 46)
      |> close()
    end
  end
end
