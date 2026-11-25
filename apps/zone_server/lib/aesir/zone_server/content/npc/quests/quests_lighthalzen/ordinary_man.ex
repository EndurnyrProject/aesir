defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.OrdinaryMan do
  @moduledoc """
  Ghalstein recruits the player into a secret investigation.

  ## Behavior

  - Introduces Secret Wing and assigns missions against Rekenber.
  - Collects laboratory evidence and rewards the completed investigation.

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
        map: "lighthalzen",
        x: 179,
        y: 170,
        dir: 4,
        sprite: 98,
        name: "Ordinary Man",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :lhz_boss, 0) do
      0 ->
        introduction(ctx)

      1 ->
        weather(ctx)

      2 ->
        overheard(ctx)

      3 ->
        confront(ctx)

      4 ->
        recruit(ctx)

      5 ->
        ctx
        |> mes("[Ghalstein]")
        |> mes("So how are you feeling?")
        |> mes("Any nausea that you may")
        |> mes("be experiencing should")
        |> mes("be going away very soon.")
        |> mes("Anyway, let's get started.")
        |> next()
        |> mes("[Ghalstein]")
        |> mes("Rekenber Corporation")
        |> mes("is closely affiliated with")
        |> mes("Regenschirm, an underground")
        |> mes("laboratory inhabited by strange")
        |> mes("and suspicious creatures.")
        |> next()
        |> mes("[Ghalstein]")
        |> mes("Your mission will be to")
        |> mes("infiltrate this underground lab")
        |> mes("and bring back evidence which")
        |> mes("proves the existence of these")
        |> mes("creatures. You must gather")
        |> mes("various kinds of proof.")
        |> next()
        |> mes("[Ghalstein]")
        |> mes("But more importantly,")
        |> mes("there is ^FF0000something there")
        |> mes("that you have to bring")
        |> mes("back to me^000000. I can't tell")
        |> mes("you exactly what it is,")
        |> mes("but trust me. You'll know.")
        |> next()
        |> mes("[Ghalstein]")
        |> mes("If you search the")
        |> mes("Laboratory enough,")
        |> mes("you'll find what I'm")
        |> mes("talking about. In any")
        |> mes("case, you'll need to find")
        |> mes("a way to get inside the lab.")
        |> next()
        |> mes("[Ghalstein]")
        |> mes("It might be helpful to")
        |> mes("know that we've received")
        |> mes("reports about disappearances")
        |> mes("of people from the ^FF0000eastside")
        |> mes("slums^000000. We believe they are")
        |> mes("perhaps traveling illegally...")
        |> next()
        |> mes("[Ghalstein]")
        |> mes("If someone there is")
        |> mes("transporting people")
        |> mes("without authorization,")
        |> mes("maybe you can find a")
        |> mes("contact who can sneak")
        |> mes("you inside the Laboratory.")
        |> set_char_var(:lhz_boss, 6)
        |> changequest(12_015, 12_016)
        |> close()

      6 ->
        ctx
        |> mes("[Ghalstein]")
        |> mes("For now, it may be best")
        |> mes("to start investigating the")
        |> mes("eastside slums to see if you")
        |> mes("can find somebody who can")
        |> mes("get you inside the Laboratory.")
        |> close()

      7 ->
        collect_evidence(ctx)

      8 ->
        ctx
        |> mes("[Ghalstein]")
        |> mes("Please find Gushaar")
        |> mes("in the vicinity of Juno.")
        |> mes("He will give you all the")
        |> mes("details for your next mission.")
        |> close()

      stage when stage < 25 ->
        ctx
        |> mes("[Ghalstein]")
        |> mes("You've made the decision")
        |> mes("to help us in order to learn")
        |> mes("more about our organzation.")
        |> mes("We appreciate all the help we")
        |> mes("can get, but I hope you don't")
        |> mes("regret getting in this deep.")
        |> next()
        |> mes("[Ghalstein]")
        |> mes("There's a certain price")
        |> mes("for knowledge. I believe")
        |> mes("you're capable of paying it,")
        |> mes("but whether or not this ordeal")
        |> mes("will be worthwhile to you is")
        |> mes("difficult to determine.")
        |> close()

      stage when stage < 43 ->
        ctx
        |> mes("[Ghalstein]")
        |> mes("You're so close to")
        |> mes("accomplishing your")
        |> mes("mission. If all goes as")
        |> mes("planned, we can do some")
        |> mes("real damage to our enemy.")
        |> mes("And you'll finally be free.")
        |> close()

      43 ->
        reward(ctx)

      _ ->
        ctx
        |> mes("[Ghalstein]")
        |> mes("I hate being patient,")
        |> mes("but the old adage is")
        |> mes("true. He who runs away,")
        |> mes("lives to fight another day.")
        |> mes("But that day seems so")
        |> mes("far off into the future...")
        |> close()
    end
  end

  defp introduction(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Ghalstein]")
      |> mes("Hello there~")
      |> mes("Isn't Lighthalzen such")
      |> mes("a wonder to behold with")
      |> mes("all of its splendor and")
      |> mes("magnificent beauty?")
      |> next()
      |> select(["I guess.", "Yes, it is.", "Well, I don't know."])

    case choice do
      1 ->
        introduction_continue(
          ctx
          |> mes("[Ghalstein]")
          |> mes("Oh, and the weather is")
          |> mes("so nice today, perfect")
          |> mes("for a stroll in the park")
          |> mes("or a lovely picnic. Ah~")
        )

      2 ->
        introduction_continue(
          ctx
          |> mes("[Ghalstein]")
          |> mes("Oh, I'm so glad you")
          |> mes("agree. The people who")
          |> mes("live here are so kind and")
          |> mes("so happy, you can literally")
          |> mes("feel everyone's gentle warmth.")
        )

      3 ->
        introduction_continue(
          ctx
          |> mes("[Ghalstein]")
          |> mes("Well, maybe if you")
          |> mes("don't see it right this")
          |> mes("moment, I'm sure you'll")
          |> mes("discover something to")
          |> mes("love about this city soon.")
        )

      _ ->
        ctx
    end
  end

  defp introduction_continue(ctx) do
    ctx = next(ctx)

    if base_level(ctx) < 60 do
      ctx
      |> mes("[Ghalstein]")
      |> mes("Ha ha ha!")
      |> mes("Anyway, I hope you")
      |> mes("have a good day today~")
      |> close()
    else
      ctx
      |> mes("[Ghalstein]")
      |> mes("Yes, Lighthalzen")
      |> mes("couldn't be perfecter.")
      |> mes("Ahahahaha... But still...")
      |> mes("Hm. Um. Oh, never mind.")
      |> next()
      |> mes("[Ghalstein]")
      |> mes("Ha ha ha!")
      |> mes("Anyway, I hope you")
      |> mes("have a good day today~")
      |> set_char_var(:lhz_boss, 1)
      |> close()
    end
  end

  defp weather(ctx) do
    if Enum.random(1..5) == 4 do
      ctx
      |> mes("[Ghalstein]")
      |> mes("Hm? It's a little")
      |> mes("cloudy today, isn't it?")
      |> mes("It would be nice to stay")
      |> mes("inside, listening to some")
      |> mes("nice music while enjoying")
      |> mes("a hot cup of tea, wouldn't it?")
      |> close()
    else
      ctx
      |> mes("[Ghalstein]")
      |> mes("Ahhh!")
      |> mes("Such pleasant weather~")
      |> mes("I'm so glad I'm outside")
      |> mes("and enjoying the sunlight.")
      |> mes("Feel it. It's so warm and")
      |> mes("nice on your face, isn't it?")
      |> close()
    end
  end

  defp overheard(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Ghalstein]")
      |> mes("The sun is gently")
      |> mes("shining, the breeze is")
      |> mes("gently blowing. Oh, this")
      |> mes("weather could not be better!")
      |> next()
      |> select(["Yes, you're right.", "Uh, what were you doing just now?"])

    case choice do
      1 ->
        ctx
        |> mes("[Ghalstein]")
        |> mes("Yes, right now is the")
        |> mes("best time to be outside")
        |> mes("and to enjoy all of this")
        |> mes("fresh, wonderful air. Come,")
        |> mes("take a deep breath with me.")
        |> mes("Ooooh. Ahhhhhh~ Excellent!")
        |> close()

      2 ->
        {ctx, answer} =
          ctx
          |> mes("[Ghalstein]")
          |> mes("...")
          |> mes("......")
          |> mes("I don't quite follow what")
          |> mes("you're saying. I was merely")
          |> mes("enjoying the sunny perfection")
          |> mes("of Lighthalzen as usual...")
          |> next()
          |> select(["But I heard you talking about something..."])

        case answer do
          1 ->
            ctx
            |> mes("[Ghalstein]")
            |> mes("No! You must")
            |> mes("have mistaken me")
            |> mes("for somebody else!")
            |> mes("Now, if you'll excuse me...")
            |> set_char_var(:lhz_boss, 3)
            |> next()
            |> mes("^3355FFEven if it wasn't")
            |> mes("Ghalstein that you")
            |> mes("just heard, he reacted")
            |> mes("pretty strongly to what")
            |> mes("you said to him. Almost")
            |> mes("as if he had something to hide... ^000000")
            |> close()

          _ ->
            ctx
        end

      _ ->
        ctx
    end
  end

  defp confront(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Ghalstein]")
      |> mes("Hm? Judging from the")
      |> mes("look on your face, you")
      |> mes("apparently still believe")
      |> mes("that I was involved in some")
      |> mes("kind of clandestine meeting.")
      |> next()
      |> select(["Yes, I'm sure of it!", "Well..."])

    case choice do
      1 ->
        insist(ctx)

      2 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Well...")
        |> mes("Now I don't know.")
        |> mes("I suppose I could")
        |> mes("be wrong, I guess.")
        |> next()
        |> mes("[Ghalstein]")
        |> mes(".......")
        |> mes("Yes, I wouldn't")
        |> mes("recommend running")
        |> mes("around, indiscriminately")
        |> mes("accusing random people")
        |> mes("of doing strange things.")
        |> close()

      _ ->
        ctx
    end
  end

  defp insist(ctx) do
    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Yes, I'm sure of it!")
      |> mes("That was definitely you!")
      |> mes("Your voice, your way of")
      |> mes("speaking is unmistakable!")
      |> next()
      |> mes("[Ghalstein]")
      |> mes("......")
      |> mes("..........")
      |> mes("...............")
      |> next()
      |> mes("[Ghalstein]")
      |> mes("Alright. Yes, it's")
      |> mes("true that I did meet")
      |> mes("someone in secret. But")
      |> mes("what gives you the right")
      |> mes("to interrogate me in this")
      |> mes("rather aggressive fashion?")
      |> next()
      |> select(["I'm not interrogating...", "Sorry about that."])

    case choice do
      1 ->
        interrogate(ctx)

      2 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Sorry about that.")
        |> mes("I didn't mean to")
        |> mes("stick my nose into")
        |> mes("your personal business.")
        |> next()
        |> mes("[Ghalstein]")
        |> mes("Well, that's quite")
        |> mes("alright. I accept")
        |> mes("your apology, but")
        |> mes("I must warn you")
        |> mes("not to pry into my")
        |> mes("personal affairs.")
        |> close()

      _ ->
        ctx
    end
  end

  defp interrogate(ctx) do
    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("I'm not interrogating")
      |> mes("you. No, not at all.")
      |> mes("It's, um, it's just...")
      |> next()
      |> select(["Who are you dealing with?", "I was just curious."])

    case choice do
      1 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Who are you dealing")
        |> mes("with? I heard something")
        |> mes("about some organization")
        |> mes("that's supposedly very")
        |> mes("powerful and I'm starting")
        |> mes("to get really concerned.")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("I don't think I can")
        |> mes("ignore hearing about")
        |> mes("any kind of dangerous")
        |> mes("corporation, even if")
        |> mes("I wanted to. Turning my")
        |> mes("back to this seems wrong...")
        |> next()
        |> mes("[Ghalstein]")
        |> mes("Hm...")
        |> mes("You really")
        |> mes("feel that way?")
        |> next()
        |> mes("[Ghalstein]")
        |> mes("Please give me")
        |> mes("a moment. I need")
        |> mes("some time to think")
        |> mes("about how I can best")
        |> mes("handle this situation.")
        |> set_char_var(:lhz_boss, 4)
        |> close()

      2 ->
        ctx
        |> mes("[Ghalstein]")
        |> mes("Just curious...?")
        |> mes("Well, I hope that")
        |> mes("you don't interfere")
        |> mes("too much with other")
        |> mes("people's lives just")
        |> mes("out of curiosity.")
        |> next()
        |> mes("[Ghalstein]")
        |> mes("You really shouldn't")
        |> mes("make something your")
        |> mes("business if you're not")
        |> mes("interested or willing")
        |> mes("to commit. Now, if you")
        |> mes("would excuse me...")
        |> close()

      _ ->
        ctx
    end
  end

  defp recruit(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Ghalstein]")
      |> mes("I've come into a")
      |> mes("decision and found")
      |> mes("a way that I can let")
      |> mes("you into my confidence")
      |> mes("without putting the efforts")
      |> mes("of my organization at risk.")
      |> next()
      |> mes("[Ghalstein]")
      |> mes("As you may have already")
      |> mes("guessed, I'm a member of an")
      |> mes("organization whose ultimate")
      |> mes("goal is to put an end to the")
      |> mes("Rekenber Corporation.")
      |> next()
      |> mes("[Ghalstein]")
      |> mes("However, before I relate")
      |> mes("more information regarding")
      |> mes("my organization and its work, I shall require your cooperation.")
      |> next()
      |> select(["How can I cooperate?"])

    case choice do
      1 -> offer(ctx)
      _ -> ctx
    end
  end

  defp offer(ctx) do
    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("How can I cooperate?")
      |> mes("Um, what exactly is it")
      |> mes("that you want me to do?")
      |> next()
      |> mes("[Ghalstein]")
      |> mes("You do seem interested")
      |> mes("in knowing more about us,")
      |> mes("and we can also use your")
      |> mes("expertise as an adventurer.")
      |> mes("But first you must decide if")
      |> mes("you will commit to cooperation.")
      |> next()
      |> select(["I still don't get it...", "Sure, I'll cooperate.", "No, thanks."])

    case choice do
      1 -> explain_choices(ctx)
      2 -> offer_red(ctx)
      3 -> reject(ctx)
      _ -> ctx
    end
  end

  defp explain_choices(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Ghalstein]")
      |> mes("Alright, let me make this ")
      |> mes("clearer for you. You have")
      |> mes("two choices.")
      |> next()
      |> select(["Two choices?"])

    case choice do
      1 -> explain_red(ctx)
      _ -> ctx
    end
  end

  defp explain_red(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Ghalstein]")
      |> mes(" If you choose")
      |> mes("to cooperate with us, you'll")
      |> mes("need to periodically drink")
      |> mes("this red magic tonic.")
      |> next()
      |> mes("[Ghalstein]")
      |> mes("The red tonic will allow")
      |> mes("us to monitor your every")
      |> mes("move so that we know you")
      |> mes("won't betray us. You'll have to")
      |> mes("continue cooperating or else")
      |> mes("we won't give you the cure.")
      |> next()
      |> mes("[Ghalstein]")
      |> mes("Throughout our mission,")
      |> mes("you'll need to take a red")
      |> mes("tonic every so often to avoid")
      |> mes("suffering fron unpleasant")
      |> mes("consequences. When we")
      |> mes("finish, you get the antidote.")
      |> next()
      |> select(["........."])

    case choice do
      1 -> explain_blue(ctx)
      _ -> ctx
    end
  end

  defp explain_blue(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Ghalstein]")
      |> mes("If you choose not to")
      |> mes("cooperate, simply drink")
      |> mes("this blue tonic, which will")
      |> mes("erase every fragment of your")
      |> mes("memory regarding our meeting.")
      |> next()
      |> mes("[Ghalstein]")
      |> mes("So, what have")
      |> mes("you decided to do?")
      |> next()
      |> select(["Don't cooperate", "Cooperate"])

    case choice do
      1 -> reject(ctx)
      2 -> offer_red(ctx)
      _ -> ctx
    end
  end

  defp offer_red(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Ghalstein]")
      |> mes("Ah, good choice.")
      |> mes("So will you take")
      |> mes("this red tonic?")
      |> next()
      |> select(["Do not take it.", "Take it."])

    case choice do
      1 ->
        reject(ctx)

      2 ->
        ctx
        |> mes("[Ghalstein]")
        |> mes("Very good.")
        |> mes("Then please,")
        |> mes("drink this right away.")
        |> next()
        |> mes("^3355FFYou drink the red tonic.")
        |> mes("It doesn't feel any different")
        |> mes("from a Red Potion, but it")
        |> mes("would be wise to cooperate")
        |> mes("with Ghalstein until this")
        |> mes("mission is accomplished.^000000")
        |> next()
        |> mes("[Ghalstein]")
        |> mes("You may feel a little")
        |> mes("disoriented after drinking")
        |> mes("this tonic for the first time.")
        |> mes("I'll give you a moment to")
        |> mes("steady yourself before we")
        |> mes("talk about our mission.")
        |> set_char_var(:lhz_boss, 5)
        |> close()

      _ ->
        ctx
    end
  end

  defp reject(ctx) do
    ctx =
      ctx
      |> mes("[Ghalstein]")
      |> mes("You really feel")
      |> mes("that way? Well, that's")
      |> mes("a shame. Pity, really...")
      |> next()
      |> mes("^3355FFYou suddenly get the")
      |> mes("weird feeling that someone")
      |> mes("has been behind you this")
      |> mes("entire time. As you slowly")
      |> mes("turn around to look, you")
      |> mes("were knocked unconscious...^000000")
      |> percent_heal(hp: 100, sp: 0)
      |> percent_heal(hp: -50, sp: 0)
      |> next()
      |> mes("..........")
      |> mes("........")
      |> mes(".....")
      |> mes("..")
      |> next()
      |> mes("[??????]")
      |> mes("^666666Now...^000000")

    ctx =
      if sex(ctx) == 1,
        do: mes(ctx, "^666666Make him^000000"),
        else: mes(ctx, "^666666Make her^000000")

    ctx
    |> mes("^666666swallow this pill.^000000")
    |> next()
    |> mes("^3355FFYou're forced to swallow")
    |> mes("some strange pill which")
    |> mes("immediately makes all your")
    |> mes("thoughts hazier until it begins")
    |> mes("to feel like your entire mind")
    |> mes("is getting bleached somehow.^000000")
    |> set_char_var(:lhz_boss, 0)
    |> close2()
    |> warp("lighthalzen", 217, 313)
  end

  defp collect_evidence(ctx) do
    cond do
      not Rathena.truthy?(:erlang.band(get_char_var(ctx, :MISC_QUEST, 0), 512)) ->
        ctx |> mes("[Ghalstein]") |> mes("An error occurred.") |> close()

      Rathena.truthy?(count_item(ctx, 7346)) and count_item(ctx, 7347) > 9 and
          count_item(ctx, 7345) > 9 ->
        ctx
        |> mes("[Ghalstein]")
        |> mes("Ah, this looks like a")
        |> mes("sufficient amount of")
        |> mes("evidence for us to be")
        |> mes("able to effectively attack")
        |> mes("our enemy. I believe you're")
        |> mes("ready for the next mission.")
        |> next()
        |> mes("[Ghalstein]")
        |> mes("But first, I believe it's")
        |> mes("time for another red tonic")
        |> mes("dose so that we can keep")
        |> mes("monitoring you. Oh, and")
        |> mes("don't worry, it's not addictive")
        |> mes("or anything strange like that.")
        |> next()
        |> mes("[Ghalstein]")
        |> mes("Now, find ^FF0000Gusharr^000000, one of")
        |> mes("our members, ^FF0000near Juno^000000.")
        |> mes("He will tell you about your")
        |> mes("next mission. Show this to")
        |> mes("him to prove that you are")
        |> mes("working with us. Don't forget.")
        |> delitem(7346, 1)
        |> delitem(7347, 10)
        |> delitem(7345, 10)
        |> set_char_var(:lhz_boss, 8)
        |> give_item(7348, 1)
        |> changequest(12_016, 12_017)
        |> close()

      not Rathena.truthy?(count_item(ctx, 7346)) and not Rathena.truthy?(count_item(ctx, 7347)) and
          not Rathena.truthy?(count_item(ctx, 7345)) ->
        ctx
        |> mes("[Ghalstein]")
        |> mes("When you get inside the")
        |> mes("Laboratory, make sure that")
        |> mes("you search around for any")
        |> mes("records and get any sort of")
        |> mes("concrete evidence we can")
        |> mes("use. I'll be counting on you.")
        |> close()

      true ->
        ctx
        |> mes("[Ghalstein]")
        |> mes("We'll need more evidence")
        |> mes("than this from the Laboratory")
        |> mes("to make any impact against our")
        |> mes("enemy. I know what we need is")
        |> mes("difficult to find, but I'm sure")
        |> mes("that you can pull this off.")
        |> close()
    end
  end

  defp reward(ctx) do
    ctx =
      ctx
      |> mes("[Ghalstein]")
      |> mes("I can't believe what")
      |> mes("happened. I just heard")
      |> mes("that the president was")
      |> mes("betrayed! This is horrible!")
      |> mes("We'll have to start all over.")
      |> mes("Was it all for nothing?!")
      |> next()
      |> mes("[Ghalstein]")
      |> mes("No. No, Jargeah would be")
      |> mes("so disappointed in me if")
      |> mes("I just gave up. I'll have to")
      |> mes("follow our dream, no matter")
      |> mes("what the obstacles are.")
      |> mes("Jargeah, give me strength!")
      |> next()
      |> mes("[Ghalstein]")
      |> mes("Also, you've done a great")
      |> mes("service for us. Although we")
      |> mes("failed, you carried out your")
      |> mes("missions perfectly. Here,")
      |> mes("take this antidote so that")
      |> mes("you'll finally be free of us.")
      |> next()
      |> mes("[Ghalstein]")
      |> mes("I'd like you to take")
      |> mes("this small gift, as way")
      |> mes("of apology. We asked you")
      |> mes("to do so much, but ultimately,")
      |> mes("we weren't able to accomplish")
      |> mes("what we set out to do. Still...")
      |> set_char_var(:lhz_boss, 44)
      |> give_item(617, 1)

    ctx
    |> getexp(
      if(Rathena.truthy?(checkre(ctx, 3)),
        do: 180_000,
        else: 1_800_000
      ),
      0
    )
    |> completequest(12_028)
    |> next()
    |> mes("[Ghalstein]")
    |> mes("I'd like to thank you")
    |> mes("for everything. Hopefully,")
    |> mes("you found the answers")
    |> mes("that you were looking for")
    |> mes("when you decided to help")
    |> mes("us. Farewell, faithful friend.")
    |> close()
  end
end
