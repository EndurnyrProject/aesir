defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAirship.Hallen do
  @moduledoc """
  Follows Hallen's search for the secret of airship flight.

  ## Behavior

  - Asks passengers to deliver a letter to Kaci and rewards their help.
  - Investigates the Rune Stone and directs the player to a dice-game patron.

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
      %{map: "airplane", x: 236, y: 63, dir: 4, sprite: 706, name: "Hallen", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    ctx = mes(ctx, "[Hallen]")
    thierry = get_char_var(ctx, :hg_ma1, 0)
    heart = get_char_var(ctx, :lhz_heart, 0)

    cond do
      thierry == 3 or base_level(ctx) < 60 -> greeting(ctx, thierry) |> close()
      not Rathena.truthy?(heart) -> introduction(ctx)
      true -> quest_dialogue(ctx, heart)
    end
  end

  defp greeting(ctx, thierry) do
    ctx =
      ctx
      |> mes("If you need me to")
      |> mes("do anything, just")
      |> mes("give me a holler.")
      |> mes("Bweh heh... hollah~")

    if thierry == 3 do
      {ctx, _} = ctx |> next() |> select(["Hey, do you know a guy named Thierry?"])

      ctx
      |> mes("[Hallen]")
      |> mes("Thierry? Um...I don't think so. Why don't you go ask Kaci? She might know.")
    else
      ctx
    end
  end

  defp introduction(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Howdy, howdy~")
      |> mes("Welcome to the Airship.")
      |> next()
      |> select(["I'm not a passenger.", "Hey kid, what are you doing?"])

    case choice do
      1 -> ctx |> passenger_reply() |> explain_kaci()
      2 -> ctx |> crew_reply() |> explain_kaci()
      _ -> ctx
    end
  end

  defp passenger_reply(ctx) do
    ctx
    |> emotion(:question)
    |> mes("[Hallen]")
    |> mes("Does that mean you're")
    |> mes("one of the crewmen, then?")
    |> mes("I don't think we've met before,")
    |> mes("and I should be familiar with")
    |> mes("everyone working here by now...")
    |> next()
    |> emotion(:surprise)
    |> mes("[Hallen]")
    |> mes("Hey...!")
    |> mes("If you're on duty,")
    |> mes("shouldn't you be in")
    |> mes("uniform? I guess you")
    |> mes("don't work here after all!")
    |> mes("Heh, figured it out myself~")
    |> next()
    |> mes("[Hallen]")
    |> mes("Eh, I need to finish")
    |> mes("sweeping this deck. Then,")
    |> mes("on my break, I can play a")
    |> mes("little game for Apples with")
    |> mes("Kaci. That's how I roll, yo.")
  end

  defp crew_reply(ctx) do
    ctx
    |> mes("[Hallen]")
    |> mes("Ummm... Isn't it obvious?")
    |> mes("I'm sweeping the deck. I'm")
    |> mes("the youngest crewman, so")
    |> mes("I get stuck with the lamest")
    |> mes("jobs. But once I'm done, it's")
    |> mes("Dice time with Kaci. Oh yeah~")
  end

  defp explain_kaci(ctx) do
    {ctx, _} = ctx |> next() |> select(["Kaci?"])

    ctx
    |> mes("[Hallen]")
    |> mes("Kaci... You know, the")
    |> mes("dealer of the Dice game?")
    |> mes("You should try it out: just")
    |> mes("roll some dice for a chance")
    |> mes("to win some Apples. Hey,")
    |> mes("you could get really lucky!")
    |> next()
    |> mes("[Hallen]")
    |> mes("Heh, there's one guy that")
    |> mes("won so many Apples from Kaci")
    |> mes("that he was able to become")
    |> mes("an Apple Merchant. Can you")
    |> mes("believe that? Yeah... Kaci")
    |> mes("doesn't like him so much...")
    |> close()
    |> set_char_var(:lhz_heart, 1)
  end

  defp quest_dialogue(ctx, 1) do
    {ctx, choice} =
      ctx
      |> mes("Oh hey, it's you~")
      |> mes("We talked earlier,")
      |> mes("didn't we? Yeah...")
      |> mes("I'm still here sweeping")
      |> mes("this floor. It's gonna")
      |> mes("take quite a while.")
      |> next()
      |> emotion(:surprise)
      |> mes("[Hallen]")
      |> mes("It doesn't look like")
      |> mes("I'm gonna finish this")
      |> mes("anytime soon. Hey, do")
      |> mes("you think you could do")
      |> mes("me a favor since I can't")
      |> mes("really leave this joint?")
      |> next()
      |> select(["Sorry, but I'm busy...", "What is it?"])

    case choice do
      1 ->
        ctx
        |> mes("[Hallen]")
        |> mes("Eh, alright. I guess")
        |> mes("I can understand. But")
        |> mes("still, I coulda made it")
        |> mes("worth your while, if you")
        |> mes("know what I mean~")
        |> close()

      2 ->
        ctx
        |> mes("[Hallen]")
        |> mes("Don't worry, it's not much")
        |> mes("work. I'm supposed to deliver")
        |> mes("letters from Juno Airport to")
        |> mes("the other crewmen, but I don't")
        |> mes("got the time. Now, I have")
        |> mes("this letter for Kaci here...")
        |> next()
        |> mes("[Hallen]")
        |> mes("Would you go and")
        |> mes("deliver this letter")
        |> mes("to her for me? It's")
        |> mes("from some guy named")
        |> mes("Mr. Mawong, her mentor")
        |> mes("or something like that.")
        |> next()
        |> mes("^3355FFHallen gave you")
        |> mes("Mawong's letter to")
        |> mes("be delivered to Kaci.^000000")
        |> setquest(8036)
        |> set_char_var(:lhz_heart, 2)
        |> next()
        |> mes("[Hallen]")
        |> mes("Hey, thanks a lot, pal~")
        |> mes("You can find Kaci hosting")
        |> mes("the Dice game in the Airship.")
        |> close()

      _ ->
        ctx
    end
  end

  defp quest_dialogue(ctx, 2) do
    ctx
    |> mes("^333333*Sigh...*^000000")
    |> mes("I'm so sick and")
    |> mes("tired of sweeping.")
    |> mes("It's like I'm some")
    |> mes("kinda lame cabin boy.")
    |> mes("But... I guess I am!")
    |> next()
    |> mes("[Hallen]")
    |> mes("Oh hey, were you")
    |> mes("able to give that")
    |> mes("letter to Kaci yet?")
    |> mes("I think it's pretty")
    |> mes("important, so try not")
    |> mes("to take too long, okay?")
    |> close()
  end

  defp quest_dialogue(ctx, 3) do
    ctx
    |> mes("^333333*Sigh...*^000000")
    |> mes("I'm so sick and")
    |> mes("tired of sweeping.")
    |> mes("It's like I'm some")
    |> mes("kinda lame cabin boy.")
    |> mes("But... I guess I am!")
    |> close()
  end

  defp quest_dialogue(ctx, 4) do
    {ctx, choice} =
      ctx
      |> mes("Hey, thanks for delivering")
      |> mes("that letter to Kaci for me.")
      |> mes("She wasn't too happy that")
      |> mes("I asked a passenger to do")
      |> mes("it, but she understood that")
      |> mes("I'm totally swamped with work.")
      |> next()
      |> mes("[Hallen]")
      |> mes("Wouldn't you agree")
      |> mes("that people should")
      |> mes("help each other in")
      |> mes("times of crisis?")
      |> next()
      |> select(["Not at all. Every man for himself!", "Yes, I do."])

    case choice do
      1 ->
        ctx
        |> mes("[Hallen]")
        |> mes("Wh-what...?")
        |> mes("I can't think")
        |> mes("that you really")
        |> mes("believe that...")
        |> set_char_var(:lhz_heart, 5)
        |> changequest(8038, 8039)
        |> close()

      2 ->
        agree_to_help(ctx)

      _ ->
        ctx
    end
  end

  defp quest_dialogue(ctx, 5) do
    {ctx, _} =
      ctx
      |> mes("Hey, hey~ How's it going?")
      |> mes("I know, I know, I'm supposed")
      |> mes("to be sweeping, and I'm not")
      |> mes("finished yet, but sometimes,")
      |> mes("you know, you just have to")
      |> mes("rest and take a break, yeah?")
      |> next()
      |> mes("[Hallen]")
      |> mes("Ahh, busy days like these")
      |> mes("remind me of working back")
      |> mes("home in Juno with my neighbor,")
      |> mes("Gyver. He's a genius inventor,")
      |> mes("you know, and sort of like")
      |> mes("a hero or role model to me.")
      |> next()
      |> mes("[Hallen]")
      |> mes("Guyver is so brilliant,")
      |> mes("he can pretty much make")
      |> mes("anything he wants. Someday,")
      |> mes("I want to reach his level, and")
      |> mes("create things that will help")
      |> mes("people and make them happy.")
      |> next()
      |> mes("[Hallen]")
      |> mes("That's pretty much my")
      |> mes("life ambition-- you know,")
      |> mes("the kind of thing I want to")
      |> mes("contribute to the world. Of")
      |> mes("course, I doubt I can compare")
      |> mes("to the great Sage Varmunt.")
      |> next()
      |> select(["Sage Varmunt?"])

    ctx =
      ctx
      |> mes("[Hallen]")
      |> mes("Yeah, Varmunt... He's like")
      |> mes("one of the greatest Sages in")
      |> mes("history. Well, nobody know too")
      |> mes("much about him, but 300 years")
      |> mes("ago, he was responsible for most ground breaking accomplishments.")
      |> next()
      |> mes("[Hallen]")
      |> mes("Supposedly, he single handedly")
      |> mes("revolutionized science. Many of")
      |> mes("the machines that are convenient to life today are his inventions.")
      |> mes("Sadly, he disappeared from history and no one know how he vanished.")
      |> next()
      |> mes("[Hallen]")
      |> mes("The great Sage Varmunt...")
      |> mes("It's a pretty well known")
      |> mes("legend in the Schwarzwald")
      |> mes("Republic. Anyway, for my")
      |> mes("project, I wanted to learn")
      |> mes("more about these Airships.")
      |> next()
      |> mes("[Hallen]")
      |> mes("These Airships are so huge")
      |> mes("and heavy, and I can scarcely")
      |> mes("believe that they can fly. How")
      |> mes("is it even possible? Well, if")
      |> mes("you could find out for me, ")
      |> mes("it'd be a really big help.")

    ctx =
      if isbegin_quest(ctx, 8039) == 0 do
        changequest(ctx, 8038, 8039)
      else
        ctx
      end

    ctx |> set_char_var(:lhz_heart, 6) |> close()
  end

  defp quest_dialogue(ctx, 6) do
    ctx =
      ctx
      |> mes("Hey, have you learned")
      |> mes("what makes such a big,")
      |> mes("heavy Airship like this fly")
      |> mes("for so long in the sky?")
      |> next()

    if get_char_var(ctx, :lght_air, 0) == 7 do
      learned_airship_secret(ctx)
    else
      awaiting_airship_secret(ctx)
    end
    |> close()
  end

  defp quest_dialogue(ctx, 7) do
    ctx |> recall_rune_stone() |> reward_investigation()
  end

  defp quest_dialogue(ctx, 8) do
    ctx
    |> mes("Hey, why don't you")
    |> mes("ask Kaci about that")
    |> mes("drunkard that's always")
    |> mes("playing her Dice game?")
    |> mes("You might learn more about")
    |> mes("Ymir's Heart Piece, you know?")
    |> close()
  end

  defp quest_dialogue(ctx, _progress) do
    ctx
    |> mes("Thanks for helping me")
    |> mes("out that last time. I guess")
    |> mes("learning about the Rune Stone")
    |> mes("kinda inspired me to build an")
    |> mes("Airship of my own someday...")
    |> close()
  end

  defp agree_to_help(ctx) do
    ctx =
      ctx
      |> mes("[Hallen]")
      |> mes("Aww, really?")
      |> mes("I knew that you'd")
      |> mes("feel the same way")
      |> mes("I do. You and me, we're")
      |> mes("on the same wavelength~")
      |> next()

    if checkweight(ctx, [{501, 1}]) != 1 do
      ctx
      |> mes("[Hallen]")
      |> mes("Oh... Hey, I was")
      |> mes("going to give you")
      |> mes("a little something,")
      |> mes("but you're carrying")
      |> mes("too much stuff right now...")
      |> close()
    else
      ctx
      |> set_char_var(:lhz_heart, 5)
      |> give_item(501, 1)
      |> mes("[Hallen]")
      |> mes("I know this isn't")
      |> mes("much, but I'd like you")
      |> mes("to have it. Besides, you")
      |> mes("never know what'll come in")
      |> mes("handy during an emergency.")
      |> mes("Alright then, see you later~")
      |> close()
    end
  end

  defp learned_airship_secret(ctx) do
    {ctx, _} = select(ctx, ["Umm, yeah, kind of."])

    {ctx, _} =
      ctx
      |> mes("[Hallen]")
      |> mes("Really...?")
      |> mes("Are you serious?")
      |> mes("So what's the secret?")
      |> mes("Tell me, I'm dying to know!")
      |> next()
      |> mes("^3355FFYou tell Hallen everything")
      |> mes("that you've learned from")
      |> mes("Captain Tarlock, but you're")
      |> mes("careful not to make any")
      |> mes("mention of Ymir's Heart Piece.^000000")
      |> next()
      |> mes("[Hallen]")
      |> mes("So... The propellers are")
      |> mes("powered through steam?")
      |> mes("That doesn't make sense.")
      |> mes("No way, it can't be that simple. Besides, steam has its limits.")
      |> mes("Are you sure that's everything?")
      |> next()
      |> select(["Actually, there's another power source."])

    ctx
    |> mes("^3355FFYou reveal what you")
    |> mes("learn about the Rune Stone,")
    |> mes("an imitation of Ymir's Heart")
    |> mes("Piece: Hallen is a well meaning")
    |> mes("kid who probably won't use this")
    |> mes("knowledge for evil purposes.")
    |> next()
    |> mes("[Hallen]")
    |> mes("A-awesome! So there is")
    |> mes("some special magic power")
    |> mes("source that helps this Airship")
    |> mes("fly! I knew it! Now, what was")
    |> mes("it called again? Ah, the")
    |> mes("Rune Stone, right?")
    |> next()
    |> mes("[Hallen]")
    |> mes("An imitation of Ymir's")
    |> mes("Heart Piece. Now where")
    |> mes("have I heard about that")
    |> mes("before? Mm, let me think...")
    |> changequest(8039, 8040)
    |> set_char_var(:lhz_heart, 7)
  end

  defp awaiting_airship_secret(ctx) do
    {ctx, _} = select(ctx, ["Actually..."])

    ctx
    |> mes("[Hallen]")
    |> mes("You didn't learn anything")
    |> mes("about the Airship yet, huh?")
    |> mes("Maybe Captain Ferlock might")
    |> mes("know something, or any one")
    |> mes("of the other Airship captains.")
    |> mes("Hopefully, one will tell you...")
    |> next()
    |> mes("[Hallen]")
    |> mes("I know that the secrets of")
    |> mes("Airship flight is considered")
    |> mes("classified information, but if")
    |> mes("anyone can wrest those secrets,")
    |> mes("it'll be one of you adventurers. So please help me out here...")
  end

  defp recall_rune_stone(ctx) do
    ctx =
      ctx
      |> mes("So the Rune Stone")
      |> mes("is an imitation of just")
      |> mes("a piece of Ymir's Heart.")
      |> mes("But where have I heard")
      |> mes("about that before...?")
      |> next()
      |> emotion(:surprise)
      |> mes("[Hallen]")
      |> mes("Oh, that's right!")
      |> mes("Kaci told me about a")
      |> mes("drunkard that always")
      |> mes("mentions Ymir's Heart")
      |> mes("when he plays the Dice")
      |> mes("game for Apples!")
      |> next()

    ctx =
      if get_char_var(ctx, :Shinokas_Quest, 0) > 9 do
        ctx
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("(^333333Wait, I met that guy when")
        |> mes("I was helping Shinokas. He")
        |> mes("was one of the directors of")
        |> mes("the Einbroch Laboratory that")
        |> mes("had a piece of Ymir's Heart.")
        |> mes("It's worth investigating...^000000)")
        |> next()
      else
        ctx
      end

    ctx
    |> mes("[Hallen]")
    |> mes("Anyway, it's not much,")
    |> mes("but let me give you a little")
    |> mes("something for going through")
    |> mes("the trouble of learning that")
    |> mes("secret information for me...")
    |> next()
  end

  defp reward_investigation(ctx) do
    if checkweight(ctx, [{501, 1}]) != 1 do
      ctx
      |> mes("[Hallen]")
      |> mes("Aw, nuts...")
      |> mes("You don't have")
      |> mes("enough room to")
      |> mes("receive my little gift.")
      |> mes("Please free up more space")
      |> mes("in your inventory for me, okay?")
      |> close()
    else
      ctx =
        if get_char_var(ctx, :Shinokas_Quest, 0) > 9 do
          ctx
          |> set_char_var(:lhz_heart, 9)
          |> changequest(8040, 8042)
        else
          ctx
          |> set_char_var(:lhz_heart, 8)
          |> changequest(8040, 8041)
        end

      ctx
      |> give_item(501, 1)
      |> mes("[Hallen]")
      |> mes("Here you go~")
      |> mes("I know it's pretty paltry")
      |> mes("compared to the rewards ")
      |> mes("you adventurers usually get,")
      |> mes("but hey... It's my thought that")
      |> mes("counts, right? See you later~")
      |> close()
    end
  end
end
