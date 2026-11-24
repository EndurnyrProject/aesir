defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.SickOldMan do
  @moduledoc """
  A sick old man in Einbroch who turns out to be Shinokas, the miner who betrayed his friends.

  ## Behavior

  - Once Hikeman has named Shinokas, the adventurer questions the old man until he gives
    himself away, then hears his confession.
  - Sends the adventurer to search the Kapellthaine Manor, the Factory and finally the
    Laboratory for the mysterious ore, advancing the Murder Quest at each step.
  - Dies after the adventurer returns with a name for the ore; answering "Ymir" brings his last
    memories of the discovery.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - MasterOfMuppets
    - Lupus
    - KarLaeda
    - SinSloth
    - L0ne_W0lf
    - Yommy
    - Paradox924X
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
        map: "ein_in01",
        x: 231,
        y: 163,
        dir: 7,
        sprite: 849,
        name: "Sick Old Man",
        scope: :shared,
        unique_name: "Sick Old Man#ein"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :Shinokas_Quest, 0) do
      quest when quest < 2 ->
        ctx
        |> writhe_in_bed()
        |> mes("^3355FFYou feel really awkward")
        |> mes("just staring at this old")
        |> mes("man violently rolling")
        |> mes("around in his bed.^000000")
        |> close()

      2 ->
        confront_old_man(ctx)

      3 ->
        confess(ctx)

      4 ->
        ctx
        |> mes("[Shinokas]")
        |> mes("Please...")
        |> mes("Find out if the Kapellthaines")
        |> mes("are keeping some kind of unique")
        |> mes("ore. Their manor is on the road")
        |> mes("that leads to the Airport.")
        |> close()

      5 ->
        suspect_factory(ctx)

      6 ->
        if get_char_var(ctx, :EinFactory, 0) > 12 do
          guess_hiding_place(ctx)
        else
          ctx
          |> mes("[Shinokas]")
          |> mes("I'm really in no position")
          |> mes("to ask and I'm not trying")
          |> mes("to give you a hard time on")
          |> mes("purpose, but would you please")
          |> mes("check for any traces of the ore")
          |> mes("in the Factory once again?")
          |> close()
        end

      9 ->
        last_words(ctx)

      quest when quest > 9 ->
        ctx
        |> mes("^3355FFShinokas's")
        |> mes("body has grown")
        |> mes("cold to the touch.^000000")
        |> close()

      _ ->
        ctx
        |> mes("[Shinokas]")
        |> mes("...")
        |> mes("......")
        |> close()
    end
  end

  defp writhe_in_bed(ctx) do
    ctx
    |> mes("[Sick Old Man]")
    |> mes("...!")
    |> next()
    |> mes("[Sick Old Man]")
    |> mes("Awwwk~")
    |> mes("It's killing me!")
    |> mes("Arrrgh! Awwwrgh!")
    |> mes("W-when will my son")
    |> mes("come back from")
    |> mes("the factory...?!")
    |> next()
  end

  defp confront_old_man(ctx) do
    player = player_tag(ctx)

    ctx
    |> writhe_in_bed()
    |> mes(player)
    |> mes("Shi...")
    |> mes("Shinokas?")
    |> next()
    |> mes("[Sick Old Man]")
    |> mes("Huh...?")
    |> mes("Noooo! M-my name is")
    |> mes("Shinotarous. Y-you've")
    |> mes("got the wrong person!")
    |> next()
    |> mes(player)
    |> mes("^333333This has to be the")
    |> mes("Shinokas that Hikeman")
    |> mes("was talking about in Einbech.")
    |> mes("Hmmm, but how can I get")
    |> mes("him to admit it?^000000")
    |> next()
    |> mes(player)
    |> mes("^333333*Ahem!*^000000")
    |> mes("Excuse me...")
    |> next()
    |> interrogate(0)
  end

  defp interrogate(ctx, suspicion) when suspicion > 6 do
    {ctx, choice} =
      select(ctx, [
        "Have you ever heard of ^3131FFHikeman^000000 before?",
        "Weren't you living in ^3131FFEinbech^000000?"
      ])

    if choice == 1 do
      unmask_shinokas(ctx)
    else
      ctx
      |> mes("[Sick Old Man]")
      |> mes("Einbech...?")
      |> mes("No! I've never")
      |> mes("lived there before!")
      |> next()
      |> mes("^3355FFIt doesn't seem")
      |> mes("like this old man")
      |> mes("is telling the truth...^000000")
      |> next()
      |> interrogate(0)
    end
  end

  defp interrogate(ctx, suspicion) do
    {ctx, choice} =
      select(ctx, [
        "Remember the mine tunnel collapse?",
        "Didn't you used to be a miner?",
        "Have you lived in Einbroch all your life?"
      ])

    case choice do
      1 ->
        ctx
        |> mes("[Sick Old Man]")
        |> mes("Noooo!")
        |> mes("I don't know")
        |> mes("what the hell")
        |> mes("you're talking")
        |> mes("about!")
        |> next()
        |> interrogate(suspicion + 1)

      2 ->
        ctx
        |> mes("[Sick Old Man]")
        |> mes("Nooo...!")
        |> mes("W-why would you")
        |> mes("even ask me that")
        |> mes("kind of question?!")
        |> next()
        |> interrogate(suspicion + 1)

      3 ->
        ctx
        |> mes("[Sick Old Man]")
        |> mes("Y-yes!")
        |> mes("Born and raised")
        |> mes("raised here in")
        |> mes("Einbe--Einbroch!")
        |> next()
        |> mes("^3355FFIt doesn't seem")
        |> mes("like this old man")
        |> mes("is telling the truth...^000000")
        |> next()
        |> interrogate(0)

      _ ->
        ctx
    end
  end

  defp unmask_shinokas(ctx) do
    player = player_tag(ctx)

    ctx
    |> mes(player)
    |> mes("Are you sure")
    |> mes("that you don't")
    |> mes("know anything")
    |> mes("about ^3131FFHikeman^000000?")
    |> next()
    |> mes("[Shinokas]")
    |> mes("No...!")
    |> mes("I've never met")
    |> mes("Buender Hikeman")
    |> mes("in my entire li--")
    |> next()
    |> mes("[Shinokas]")
    |> mes("...")
    |> mes(".......")
    |> emotion(:profusely_sweat)
    |> next()
    |> mes(player)
    |> mes("I was right.")
    |> mes("You're Shinokas!")
    |> emotion(:kik, playerattached(ctx))
    |> next()
    |> mes("[Shinokas]")
    |> mes("Curses!")
    |> mes("I've blown")
    |> mes("my cover!")
    |> mes("W-wait! How much")
    |> mes("do you know?!")
    |> emotion(:huk)
    |> next()
    |> mes("[Shinokas]")
    |> mes("Did ^3131FFthey^000000 send you?")
    |> mes("^333333*Sigh*^000000 I think that this")
    |> mes("is it. I'll never be")
    |> mes("able to solve the")
    |> mes("secret before I die.")
    |> next()
    |> mes("[Shinokas]")
    |> mes("Okay.")
    |> mes("Get on with it.")
    |> mes("I'm ready now...")
    |> next()
    |> mes(player)
    |> mes("Tell me everything")
    |> mes("you know related to")
    |> mes("that incident where")
    |> mes("the mine tunnel")
    |> mes("collapsed around")
    |> mes("you and Hikeman.")
    |> next()
    |> mes("[Shinokas]")
    |> mes("...?")
    |> mes("Errr....")
    |> mes("You're not")
    |> mes("here to kill me?")
    |> emotion(:question)
    |> next()
    |> mes(player)
    |> mes("No...!")
    |> mes("I'm here to find")
    |> mes("out the truth!")
    |> next()
    |> mes("[Shinokas]")
    |> mes("That means...")
    |> mes("I still have some time.")
    |> mes("This must be destiny!")
    |> mes("Alright, I'll tell you what")
    |> mes("happened. But it's a")
    |> mes("long story...")
    |> changequest(2072, 2073)
    |> set_char_var(:Shinokas_Quest, 3)
    |> close()
  end

  defp confess(ctx) do
    {ctx, _choice} =
      ctx
      |> mes("[Shinokas]")
      |> mes("How much do you know")
      |> mes("about the accident? No,")
      |> mes("wait. Don't answer that.")
      |> mes("I don't want to hear it.")
      |> next()
      |> mes("[Shinokas]")
      |> mes("I admit it. Yes.")
      |> mes("I stabbed my friends")
      |> mes("in the back. It was an")
      |> mes("unforgivable sin that will")
      |> mes("haunt me until the day I die.")
      |> next()
      |> mes("[Shinokas]")
      |> mes("I sold out my friends for")
      |> mes("money. I destroyed that")
      |> mes("tunnel and killed them. But")
      |> mes(
        "I suppose I was tricked as well. ^3131FFThey^000000 never intended to keep their end of our agreement."
      )
      |> next()
      |> mes("[Shinokas]")
      |> mes("After I destroyed the tunnel,")
      |> mes("they targeted me and I ended")
      |> mes(
        "spending the rest of my life being pursued and running from place to place. What the hell was that ^3131FFore^000000 and why was it so important?"
      )
      |> next()
      |> mes("[Shinokas]")
      |> mes("I need to know more about")
      |> mes(
        "that ore if it's worth killing for. That's why I've risked sneaking into Einbroch. Supposedly, an ore similar to the one we found has"
      )
      |> mes("been transported here recently.")
      |> next()
      |> select(["Did you find it?"])

    {ctx, _choice} =
      ctx
      |> mes("[Shinokas]")
      |> mes("No, not yet.")
      |> mes("I've been searching")
      |> mes("for that ore every night.")
      |> mes("During the day, this kind")
      |> mes("blacksmith has managed")
      |> mes("to hide me from those men.")
      |> next()
      |> mes("[Shinokas]")
      |> mes("But I won't be safe")
      |> mes("for very long. Look, I'm")
      |> mes("no saint, but before I die,")
      |> mes("I wanna do this one last")
      |> mes("thing and see what's so")
      |> mes("great about this ore...")
      |> next()
      |> select(["Wait, who's trying to get you?"])

    ctx
    |> mes("[Shinokas]")
    |> mes("Who's trying to kill me?")
    |> mes("The people who hired me and")
    |> mes(
      "my friends to dig up that ore in the first place. We thought they were ordinary businessmen,"
    )
    |> mes("but... They're dangerous.")
    |> next()
    |> mes("[Shinokas]")
    |> mes("So I told you everything")
    |> mes("and now you know that my")
    |> mes("days might be numbered.")
    |> mes("Please do an old man a favor")
    |> mes("and search Einbroch for that")
    |> mes("strange, mysterious ore.")
    |> next()
    |> mes("[Shinokas]")
    |> mes("Now, the first thing I learned")
    |> mes(
      "in this town is that the richest family is the Kapellthaines. Only the rich and powerful can possibly be involved in something so big."
    )
    |> next()
    |> mes("[Shinokas]")
    |> mes("Would you search")
    |> mes("Kappellthaine Manor")
    |> mes("for that ore? It's on the way")
    |> mes(
      "to the Airport and it shouldn't be hard to miss. They're the richest people in Einbroch, after all."
    )
    |> next()
    |> mes("[Shinokas]")
    |> mes("I'm too old and weak to leave")
    |> mes(
      "this house, and there's the chance that those men will find me. If you can sympathize with my situation, please find out if the Kapellthaine family has any unique ores..."
    )
    |> changequest(2073, 2074)
    |> set_char_var(:Shinokas_Quest, 4)
    |> close()
  end

  defp suspect_factory(ctx) do
    ctx
    |> mes("[Shinokas]")
    |> mes("So, did you find")
    |> mes("anything from the")
    |> mes("Kapellthaines?")
    |> next()
    |> mes(player_tag(ctx))
    |> mes("Well, Mr. Kapellthaine")
    |> mes("is kind of violent, but")
    |> mes("I didn't find anything")
    |> mes("really suspicious.")
    |> next()
    |> mes("[Shinokas]")
    |> mes("Huh...")
    |> mes("I must have")
    |> mes("been wrong, then...")
    |> mes("Where else could it be?")
    |> next()
    |> mes("[Shinokas]")
    |> mes("Oh, right! The huge")
    |> mes("factory in Einbroch!")
    |> mes("What could be more")
    |> mes("suspicious? There's a ton")
    |> mes("of workers, but no one really")
    |> mes("knows what they do there...")
    |> next()
    |> mes("[Shinokas]")
    |> mes("If they're so secretive,")
    |> mes("it's possible that they're")
    |> mes("keeping the ore over there.")
    |> mes("Please go and search the")
    |> mes("Factory for that ore as")
    |> mes("soon as you can.")
    |> changequest(2074, 2075)
    |> set_char_var(:Shinokas_Quest, 6)
    |> close()
  end

  defp guess_hiding_place(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Shinokas]")
      |> mes("So...?")
      |> mes("Did you learn")
      |> mes("anything new")
      |> mes("in the Factory?")
      |> next()
      |> mes(player_tag(ctx))
      |> mes("Well...")
      |> mes("There's a lot of")
      |> mes("suspicious business")
      |> mes("in the factory, but I don't")
      |> mes("think any of it is related")
      |> mes("to that ore you mentioned.")
      |> next()
      |> mes("[Shinokas]")
      |> mes("Damn it...")
      |> mes("Then where did")
      |> mes("they hide it? Where")
      |> mes("do you think that")
      |> mes("ore might be?")
      |> next()
      |> select(["Airport", "Factory", "Train Station", "Airship Repairshop", "Laboratory"])

    case choice do
      1 ->
        ctx
        |> mes("[Shinokas]")
        |> mes("No...")
        |> mes("The Airport is always")
        |> mes("crowded with people.")
        |> mes("It'd be a bad idea to hide")
        |> mes("something so important")
        |> mes("in that kind of place.")
        |> close()

      2 ->
        ctx
        |> mes("[Shinokas]")
        |> mes("Didn't you just")
        |> mes("check the factory?")
        |> mes("You couldn't find")
        |> mes("any clues to the")
        |> mes("ore over there...")
        |> close()

      3 ->
        ctx
        |> mes("[Shinokas]")
        |> mes("Hmm...")
        |> mes("People are always going")
        |> mes(
          "in and out of the Train Station. It's not the best place to hide something as important as the ore."
        )
        |> close()

      4 ->
        ctx
        |> mes("[Shinokas]")
        |> mes("The Airship? Hm, it does")
        |> mes("fly through some mysterious")
        |> mes("power... But I already checked")
        |> mes("the Airship Repairshop myself.")
        |> mes("I haven't found any trace of")
        |> mes("the ore over there.")
        |> close()

      5 ->
        ctx
        |> mes("[Shinokas]")
        |> mes("...!")
        |> mes("Yes. Yes...!")
        |> mes("That could be it!")
        |> mes("Why didn't I think")
        |> mes("about the Laboratory?")
        |> mes("It makes so much sense!")
        |> next()
        |> mes("[Shinokas]")
        |> mes("I have a good feeling")
        |> mes("about this. Please sneak")
        |> mes("into that Laboratory and")
        |> mes("see if you can find the ore!")
        |> next()
        |> mes("[Shinokas]")
        |> mes("Remember...")
        |> mes("Not just anybody")
        |> mes("can enter that kind")
        |> mes("of place. But I'm sure")
        |> mes("you'll figure something out.")
        |> changequest(2075, 2076)
        |> set_char_var(:Shinokas_Quest, 7)
        |> close()

      _ ->
        ctx
    end
  end

  defp last_words(ctx) do
    player = player_tag(ctx)

    {ctx, answer} =
      ctx
      |> mes(player)
      |> mes("Shinokas,")
      |> mes("I found something!")
      |> next()
      |> mes("[Shinokas]")
      |> mes("You...")
      |> mes("Came... back...")
      |> mes("Even... if... it's")
      |> mes("already... Too late.")
      |> mes("^333333*Cough Cough*^000000")
      |> next()
      |> mes("^3355FFYou help Shinokas")
      |> mes("sit up, but find that")
      |> mes("your hands have been")
      |> mes("stained with his blood.^000000")
      |> next()
      |> mes(player)
      |> mes("Blood...?!")
      |> mes("Shinokas!")
      |> mes("Who did this to you?")
      |> mes("W-we need to call for help!")
      |> next()
      |> mes("[Shinokas]")
      |> mes("No...")
      |> mes("It's already")
      |> mes("too late for me.")
      |> mes("I should have died")
      |> mes("a long time ago...")
      |> next()
      |> mes("[Shinokas]")
      |> mes("^333333*Cough*^000000")
      |> mes("I only regret that")
      |> mes("I've never been able")
      |> mes("to apologize to my")
      |> mes("friends... ^333333*Cough!*^000000")
      |> next()
      |> mes("[Shinokas]")
      |> mes("But did you")
      |> mes("find out? D-did")
      |> mes("you find out what's")
      |> mes("so special about")
      |> mes("that ore? W-what")
      |> mes("is it... Really?")
      |> next()
      |> mes(player)
      |> mes("It was...")
      |> next()
      |> input(:string)

    ctx
    |> mes(player)
    |> mes("It was")
    |> mes("^3131FF#{answer}^000000!")
    |> next()
    |> react_to_answer(answer)
    |> mes(player)
    |> mes("No...!")
    |> mes("Tell me who")
    |> mes("did this to you!")
    |> mes("Where are they?")
    |> mes("Speak to me, please!")
    |> next()
    |> mes("[Shinokas]")
    |> mes("W-wha...?")
    |> mes("I told you.")
    |> mes("Th-they we--")
    |> next()
    |> mes("[Shinokas]")
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes(player)
    |> mes("No!")
    |> mes("Shinokas!")
    |> mes("Why, God?")
    |> mes("Why...")
    |> changequest(2077, 2078)
    |> set_char_var(:Shinokas_Quest, 10)
    |> close()
  end

  defp react_to_answer(ctx, "Ymir") do
    ctx
    |> mes("[Shinokas]")
    |> mes("Y-Ymir...?")
    |> mes("The h-heart of Ymir?")
    |> mes("The power to control")
    |> mes("the world... We really")
    |> mes("did find something")
    |> mes("great, didn't we?")
    |> next()
    |> mes("[Shinokas]")
    |> mes("I remember...")
    |> mes("The first time")
    |> mes("we saw it. We...")
    |> mes("We were so excited.")
    |> mes("So amazed and proud...")
    |> next()
    |> mes("[Shinokas]")
    |> mes("But digging up...")
    |> mes("Something so great...")
    |> mes("Was only possible")
    |> mes("with-- ^333333*Cough*^000000 --")
    |> mes("M-my buddies...")
    |> next()
    |> mes("[Shinokas]")
    |> mes("^333333*Cough*^000000")
    |> mes("It's getting...")
    |> mes("Darker... I...")
    |> mes("Don't have to")
    |> mes("run anymore.")
    |> next()
  end

  defp react_to_answer(ctx, _answer) do
    ctx
    |> mes("[Shinokas]")
    |> mes("W-wait...!")
    |> mes("What did...")
    |> mes("I can't underst--")
    |> mes("^333333*Cough cough!*^000000")
    |> next()
  end

  defp player_tag(ctx), do: "[#{char_name(ctx, 0)}]"
end
