defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.MrIbanoff do
  @moduledoc """
  Mr. Ibanoff helps adventurers reach Whale Island aboard his ship.

  ## Behavior

  - Shares stories, requests ship repair materials, and sails when the tide permits.
  - Helps the adventurer pursue and report discoveries about Whale Island.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moscovia",
        x: 135,
        y: 49,
        dir: 5,
        sprite: 964,
        name: "Mr. Ibanoff",
        scope: :shared,
        unique_name: "Mr. Ibanoff#npc"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :mos_whale_edq, 0) == 0 ->
        greeting(ctx)

      get_char_var(ctx, :mos_whale_edq, 0) == 1 or get_char_var(ctx, :mos_whale_edq, 0) == 2 ->
        first_conversation(ctx)

      get_char_var(ctx, :mos_whale_edq, 0) == 3 ->
        repair_ship(ctx)

      get_char_var(ctx, :mos_whale_edq, 0) == 4 ->
        first_departure(ctx)

      get_char_var(ctx, :mos_whale_edq, 0) < 15 ->
        return_departure(ctx)

      get_char_var(ctx, :mos_whale_edq, 0) == 15 ->
        whale_report(ctx)

      get_char_var(ctx, :mos_whale_edq, 0) < 18 ->
        csar_reminder(ctx)

      get_char_var(ctx, :mos_whale_edq, 0) == 18 ->
        retry_voyage(ctx)

      get_char_var(ctx, :mos_whale_edq, 0) == 19 ->
        retry_departure(ctx)

      get_char_var(ctx, :mos_whale_edq, 0) < 32 ->
        welcome_back(ctx)

      get_char_var(ctx, :mos_whale_edq, 0) == 32 ->
        instrument_report(ctx)

      get_char_var(ctx, :mos_whale_edq, 0) < 39 ->
        island_departure(ctx)

      get_char_var(ctx, :mos_whale_edq, 0) < 41 ->
        adventure_complete(ctx)

      get_char_var(ctx, :mos_whale_edq, 0) == 41 ->
        performance_complete(ctx)

      get_char_var(ctx, :mos_whale_edq, 0) > 90 and get_char_var(ctx, :mos_whale_edq, 0) < 100 ->
        reset_first_voyage(ctx)

      get_char_var(ctx, :mos_whale_edq, 0) > 200 and get_char_var(ctx, :mos_whale_edq, 0) < 300 ->
        reset_second_voyage(ctx)

      true ->
        tide_too_high(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Mr. Ibanoff]")
    |> mes("You are also an adventurer from another province. I also was a great adventurer.")
    |> next()
    |> mes("[Mr. Ibanoff]")
    |> mes(
      "Uf...I just want to be 20 years younger, so I can travel here and there with invigorating youth such as you... Time is an enemy. Hahahahaha!"
    )
    |> close()
  end

  defp first_conversation(ctx) do
    {ctx, conversation_choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Hello. Are you Mr. Ibanoff?")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("Yes. I am Mr. Ibanoff.")
      |> mes("What's up?")
      |> next()
      |> select(["Tell me an adventure story.", "Lend me your ship."])

    if conversation_choice == 1 do
      ctx =
        ctx
        |> mes("[Mr. Ibanoff]")
        |> mes("You are an adventurer, right?")
        |> mes("You come from a strange land?")
        |> mes("Well, well, well...")
        |> mes("You are welcome here.")
        |> next()
        |> mes("[Mr. Ibanoff]")
        |> mes("When I adventured around")
        |> mes("Rune-Midgarts, maybe it was")
        |> mes("well before you were born.")
        |> mes("Ah... I miss those days...")
        |> next()
        |> mes("[Mr. Ibanoff]")
        |> mes("Now, I'm so tired;")
        |> mes("my body and my heart.")
        |> mes("I get reminded of fond")
        |> mes("memories just by looking at the sea...")
        |> next()
        |> mes("[Mr. Ibanoff]")
        |> mes("Um... Stories...")
        |> mes("What to talk about first?")
        |> mes("Right, I'll talk about that time I")
        |> mes("fought against a huge flock of Porings...")
        |> next()

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Hahaha...")
        |> next()
        |> mes("[Mr. Ibanoff]")
        |> mes("You'll be happy that you")
        |> mes("listened to the adventure story.")
        |> mes("Well, well, well...")
        |> mes("When I was 24 years old...")
        |> mes("My colleagues and I were passing by")
        |> mes("a forest near Payon...")
        |> next()
        |> mes("when...")
        |> next()
        |> mes("and....")
        |> next()
        |> mes("then.....")
        |> next()
        |> mes("Finally......")
        |> next()
        |> mes("[Mr. Ibanoff]")
        |> mes("I did a very good")
        |> mes("job in the fight, so")
        |> mes("my colleagues and I were")
        |> mes("able to get back safely.")
        |> next()
        |> mes("[Mr. Ibanoff]")
        |> mes("What did you think?")
        |> mes("Next... Let's talk about")
        |> mes("the haunting of a Goblin mob...!")

      ctx =
        if Rathena.truthy?(isbegin_quest(ctx, 18102)) do
          changequest(ctx, 18102, 18103)
        else
          if Rathena.truthy?(isbegin_quest(ctx, 18101)) do
            changequest(ctx, 18101, 18103)
          else
            ctx
          end
        end

      {ctx, story_choice} =
        ctx |> next() |> select(["I'll listen next time...", "Interesting. Keep talking."])

      if story_choice == 1 do
        ctx
        |> mes("[Mr. Ibanoff]")
        |> mes("If not...Ooo, I can just")
        |> mes("keep going and going...")
        |> mes("No? Too bad... Hehe...")
        |> mes("Let's talk next time.")
        |> close()
      else
        ctx =
          ctx
          |> mes("[Mr. Ibanoff]")
          |> mes("Yeah? Ohohoh... my friend,")
          |> mes("we are in sync with each other...!")
          |> next()
          |> mes("[Mr. Ibanoff]")
          |> mes("Ok, this time I'll talk")
          |> mes("about the bloody fight at the")
          |> mes("haunting of a Goblin mob...")
          |> next()
          |> mes("You see...")
          |> next()
          |> mes("and....")
          |> next()
          |> mes("also.....")
          |> next()
          |> mes("Lastly......")
          |> next()
          |> mes("[Mr. Ibanoff]")
          |> mes("So, the day's great bloody")
          |> mes("fight was over like that...")
          |> mes("Ohwee...")
          |> next()
          |> mes("[Mr. Ibanoff]")
          |> mes("Hah! You are the first")
          |> mes("to listen carefully to")
          |> mes("my stories, for a long time.")
          |> mes("Feels so good...")
          |> next()
          |> mes("[Mr. Ibanoff]")
          |> mes("You absolutely have talent,")
          |> mes("as a great adventurer.")
          |> mes("You can become a good friend to me.")
          |> next()
          |> mes("[Mr. Ibanoff]")
          |> mes("Next time, we talk about your")
          |> mes("adventure story... eh? ~")
          |> mes("If you ever need anything,")
          |> mes("come talk to me whenever, hahaha!")
          |> set_char_var(:mos_whale_edq, 2)

        ctx =
          if Rathena.truthy?(isbegin_quest(ctx, 18103)) do
            changequest(ctx, 18103, 18104)
          else
            ctx
          end

        close(ctx)
      end
    else
      if get_char_var(ctx, :mos_whale_edq, 0) == 2 do
        ctx =
          ctx
          |> mes("[Mr. Ibanoff]")
          |> mes("Ah! The good listener!")
          |> mes("What will you do if you")
          |> mes("borrow my ship? I wonder...")
          |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("I'm going to adventure out")
        |> mes("to sea, to find a moving")
        |> mes("island which has brought")
        |> mes("many a legend to this neighboring village.")
        |> next()
        |> mes("[Mr. Ibanoff]")
        |> mes("The Moving Island?")
        |> mes("I have never seen that really...")
        |> mes("You are young! Hawhawhaw!")
        |> next()
        |> mes("[Mr. Ibanoff]")
        |> mes("I hope that you find")
        |> mes("the island without fail,")
        |> mes("and that you bring back")
        |> mes("surprising news to us!")
        |> next()
        |> mes("[Mr. Ibanoff]")
        |> mes("Let it be so!")
        |> mes("First, I should check")
        |> mes("the state of the ship...")
        |> mes("You have some work to do,")
        |> mes("if you want to help me.")
        |> next()
        |> mes("[Mr. Ibanoff]")
        |> mes("She has not floated")
        |> mes("for a long time,")
        |> mes("so we should check")
        |> mes("and repair the parts")
        |> mes("that power her up.")
        |> next()
        |> mes("[Mr. Ibanoff]")
        |> mes("Preparing the tools for repairs, in")
        |> mes("this place, takes several days...")
        |> mes("if you can possibly prepare them.")
        |> next()
        |> mes("[Mr. Ibanoff]")
        |> mes("The materials needed are:")
        |> mes(
          "^0000FFStrange Steel Piece 10, Rusty Screw 10, Flexible Tube 5, Jubilee 10^000000."
        )
        |> next()
        |> mes("[Mr. Ibanoff]")
        |> mes("When you've prepared all the")
        |> mes("materials, bring them to me. I'll")
        |> mes("repair the ship.")
        |> set_char_var(:mos_whale_edq, 3)
        |> changequest(18104, 18105)
        |> close()
      else
        ctx =
          ctx
          |> emotion(:anger)
          |> mes("[Mr. Ibanoff]")
          |> mes("You want to borrow")
          |> mes("my ship so spontaneously??")
          |> mes("I don't even know you!!")
          |> mes("You are more rude than you look.")
          |> next()
          |> mes("[Mr. Ibanoff]")
          |> mes("I don't know, how you know")
          |> mes("that I have a ship...")
          |> mes("Anyway, I can't lend my ship")
          |> mes("willingly to strangers.")

        ctx =
          if Rathena.truthy?(isbegin_quest(ctx, 18102)) do
            changequest(ctx, 18102, 18103)
          else
            if Rathena.truthy?(isbegin_quest(ctx, 18101)) do
              changequest(ctx, 18101, 18103)
            else
              ctx
            end
          end

        close(ctx)
      end
    end
  end

  defp repair_ship(ctx) do
    ctx =
      ctx
      |> mes("[Mr. Ibanoff]")
      |> mes("Did you bring all the materials?")
      |> mes("If we have all the materials,")
      |> mes("we can prepare for departure!")
      |> next()

    if count_item(ctx, 7167) > 9 and count_item(ctx, 7317) > 9 and count_item(ctx, 7325) > 4 and
         count_item(ctx, 7312) > 9 do
      ctx
      |> mes("[Mr. Ibanoff]")
      |> mes("Oh! You got the all materials.")
      |> mes("It's enough.")
      |> next()
      |> delitem(7167, 10)
      |> delitem(7317, 10)
      |> delitem(7325, 5)
      |> delitem(7312, 10)
      |> set_char_var(:mos_whale_edq, 4)
      |> mes("[Mr. Ibanoff]")
      |> mes("Okay, we are at the ready.")
      |> mes("When would you like to depart?")
      |> mes("I'll say one thing...")
      |> mes("It's difficult to keep this")
      |> mes("ship afloat after the sun has set.")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("In these neighboring waters,")
      |> mes("there are many raging waves.")
      |> mes("After the sun sets, the tide does")
      |> mes("not get any easier... even for an")
      |> mes("expert seaman.")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("Remember, the poor condition of")
      |> mes("this ship also factors when")
      |> mes("attempting to plow through the")
      |> mes("raging waves.")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("If you are ready to depart, tell")
      |> mes("me, and we can check the tides.")
      |> changequest(18105, 18106)
      |> close()
    else
      ctx
      |> mes("[Mr. Ibanoff]")
      |> mes("These materials are insufficient.")
      |> mes("Perhaps you forgot some of them?")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("The materials needed are:")
      |> mes("^0000FFStrange Steel Piece 10, Rusty Screw 10, Flexible Tube 5, Jubilee 10^000000.")
      |> close()
    end
  end

  defp first_departure(ctx) do
    ctx =
      ctx
      |> mes("[Mr. Ibanoff]")
      |> mes("Oh. Are you ready to depart?")
      |> mes("Good, let's see...")
      |> next()

    if low_tide?(ctx) do
      sail(ctx)
    else
      tide_too_high(ctx)
    end
  end

  defp return_departure(ctx) do
    {ctx, departure_choice} =
      ctx
      |> mes("[Mr. Ibanoff]")
      |> mes("That last sailing was tough...")
      |> mes("But, all adventures")
      |> mes("are like that...")
      |> mes("Hahaha!")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("If you keep a mind to")
      |> mes("depart again... tell me")
      |> mes("and we can check the tides.")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("Will you depart?")
      |> next()
      |> select(["I'm not ready.", "Let's go."])

    if departure_choice == 1 do
      ctx |> mes("[Mr. Ibanoff]") |> mes("When you are ready to depart, tell me.") |> close()
    else
      if low_tide?(ctx) do
        ctx |> set_char_var(:mos_whale_edq, 4) |> sail()
      else
        tide_too_high(ctx)
      end
    end
  end

  defp whale_report(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Mr. Ibanoff]")
      |> mes("Hey you... You are alive!")
      |> mes("When you were swept away by the")
      |> mes("waves, I thought that was the last")
      |> mes("I would ever see of you!")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("Anyway, where were you all this time?")
      |> next()
      |> select(["Explain the whole story."])

    ctx =
      ctx
      |> mes("[Mr. Ibanoff]")
      |> mes("Oh... that's really marvelous.")
      |> mes("Well I never...")
      |> mes("The island truly exists...?")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("What's more...")
      |> mes("The island is not an island?!?")
      |> mes("It's a gigantic whale???")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("And trees grow... and water")
      |> mes("streams... along the whale's")
      |> mes("back!!?")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("That's unbelievable!")
      |> mes("The most marvelous incident I have")
      |> mes("ever heard in my lifetime!")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("Also, I am surprised at the")
      |> mes("presence of an aged person on Whale")
      |> mes("Island!")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("He must be a man strong in")
      |> mes("spirit... with experience and high")
      |> mes("discipline.")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("The story of the island has")
      |> mes("advanced enough until this part.")
      |> mes("Why don't you announce your")
      |> mes("findings to our dearest Csar")
      |> mes("and receive aid to find Whale")
      |> mes("Island?")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("Our dear Csar likes it very")
      |> mes("much to hear stories about")
      |> mes("valuable things, so if he")
      |> mes("listens to your story, he may give")
      |> mes("you a prize...")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("And if you have any plans to go")
      |> mes("back to the island, I want to go")
      |> mes("together with you! Eh? Hahaha!")
      |> set_char_var(:mos_whale_edq, 16)

    ctx =
      if Rathena.truthy?(isbegin_quest(ctx, 18111)) do
        changequest(ctx, 18111, 18112)
      else
        ctx
      end

    close(ctx)
  end

  defp csar_reminder(ctx) do
    ctx
    |> mes("[Mr. Ibanoff]")
    |> mes("If our dear Csar listens to this")
    |> mes("kind of story, he would find it a")
    |> mes("pleasure.")
    |> next()
    |> mes("[Mr. Ibanoff]")
    |> mes("He might even give you a prize...")
    |> close()
  end

  defp retry_voyage(ctx) do
    {ctx, retry_choice} =
      ctx
      |> mes("[Mr. Ibanoff]")
      |> mes("Hm. Our dear Csar requested")
      |> mes("evidence of the whale island?...")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("That may prove a little")
      |> mes("difficult...")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("Do you have a guarantee that you")
      |> mes("can find Whale Island again?")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("I think you won't give up.")
      |> mes("How about if we depart")
      |> mes("once more, and I will gladly help")
      |> mes("you find Whale Island!")
      |> next()
      |> select(["Try again to find Whale Island.", "Give up."])

    if retry_choice == 1 do
      ctx =
        ctx
        |> mes("[Mr. Ibanoff]")
        |> mes("That does it! I expected it.")
        |> mes("I knew you weren't the type to give up an adventure!")
        |> next()
        |> mes("[Mr. Ibanoff]")
        |> mes("Again, let's get the ship ready and sail before the sun sets!")
        |> set_char_var(:mos_whale_edq, 19)

      ctx =
        if Rathena.truthy?(isbegin_quest(ctx, 18113)) do
          changequest(ctx, 18113, 18114)
        else
          ctx
        end

      close(ctx)
    else
      ctx
      |> mes("[Mr. Ibanoff]")
      |> mes("I see...")
      |> mes("Even though you like adventure,")
      |> mes("it might be impossible to find")
      |> mes("Whale Island again...")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("If you change your mind,")
      |> mes("anytime, come tell me.")
      |> mes("Frankly, I would love to see you")
      |> mes("prove the existence of Whale Island")
      |> mes("to our dear Csar.")
      |> close()
    end
  end

  defp retry_departure(ctx) do
    {ctx, departure_choice} =
      ctx
      |> mes("[Mr. Ibanoff]")
      |> mes("Oh! Are you ready to depart?")
      |> next()
      |> select(["I'm not ready.", "Let's go."])

    if departure_choice == 1 do
      ctx |> mes("[Mr. Ibanoff]") |> mes("When you are ready to depart, tell me.") |> close()
    else
      if low_tide?(ctx) do
        sail(ctx)
      else
        tide_too_high(ctx)
      end
    end
  end

  defp welcome_back(ctx) do
    ctx =
      ctx
      |> mes("[Mr. Ibanoff]")
      |> mes("What a surprise!!")
      |> mes("Where have you been??")
      |> mes("I was worried that you had")
      |> mes("disappeared forever!")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("I don't care... Wherever you have")
      |> mes("been, it's very good to see you")
      |> mes("again.")
      |> set_char_var(:mos_whale_edq, 19)
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("I can guess you'd like to go to")
      |> mes("Whale Island once again...")
      |> next()

    if low_tide?(ctx) do
      sail(ctx)
    else
      tide_too_high(ctx)
    end
  end

  defp instrument_report(ctx) do
    ctx
    |> mes("[Mr. Ibanoff]")
    |> mes("Oh. You came back!")
    |> mes("So, how did you do?")
    |> next()
    |> mes("[Mr. Ibanoff]")
    |> mes("You say...")
    |> mes("If you bring the materials, the old")
    |> mes("man makes the instrument...")
    |> next()
    |> mes("[Mr. Ibanoff]")
    |> mes("And he promised that he won't move")
    |> mes("the island until you go back")
    |> mes("again...")
    |> next()
    |> mes("[Mr. Ibanoff]")
    |> mes("I see. I remember the exact")
    |> mes("directions. Let's leave")
    |> mes("immediately, as soon as you are")
    |> mes("ready.")
    |> set_char_var(:mos_whale_edq, 33)
    |> close()
  end

  defp island_departure(ctx) do
    {ctx, island_choice} =
      ctx
      |> mes("[Mr. Ibanoff]")
      |> mes("Oh. Did you get all the")
      |> mes("materials you needed?")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("If so, do you want to go now?")
      |> next()
      |> select(["Not yet.", "Let's go."])

    if island_choice == 1 do
      ctx |> mes("[Mr. Ibanoff]") |> mes("I see. I will wait.") |> close()
    else
      ctx
      |> mes("[Mr. Ibanoff]")
      |> mes("Ok, let's go!")
      |> close2()
      |> warp("mosk_fild01", 93, 94)
    end
  end

  defp adventure_complete(ctx) do
    ctx
    |> mes("[Mr. Ibanoff]")
    |> mes("Finally, everything has ended")
    |> mes("successfully. With this, I add 1")
    |> mes("more page to my... no, OUR adventure story!")
    |> next()
    |> mes("[Mr. Ibanoff]")
    |> mes("Someday, I want to have another")
    |> mes("chance to have another fantastic")
    |> mes("adventure with a person like you!")
    |> close()
  end

  defp performance_complete(ctx) do
    ctx
    |> mes("[Mr. Ibanoff]")
    |> mes("I heard that you played a great")
    |> mes("performance, with the instrument")
    |> mes("from Whale Island, at the Imperial")
    |> mes("Palace. Eh? You must have quite the talent!")
    |> next()
    |> mes("[Mr. Ibanoff]")
    |> mes("Finally, everything has ended")
    |> mes("successfully. With this, I add 1")
    |> mes("more page to my... no, OUR adventure story!")
    |> next()
    |> mes("[Mr. Ibanoff]")
    |> mes("Someday, I want to have another")
    |> mes("chance to have another fantastic")
    |> mes("adventure with a person like you!")
    |> close()
  end

  defp reset_first_voyage(ctx) do
    ctx
    |> mes("[Mr. Ibanoff]")
    |> mes("What's going on?")
    |> mes("You should ride a ship now? Let's ready to leave hurry up.")
    |> set_char_var(:mos_whale_edq, 4)
    |> close()
  end

  defp reset_second_voyage(ctx) do
    ctx
    |> mes("[Mr. Ibanoff]")
    |> mes("What's going on?")
    |> mes("You should ride a ship now? Let's ready to leave hurry up.")
    |> set_char_var(:mos_whale_edq, 19)
    |> close()
  end

  defp low_tide?(ctx) do
    (gettime(ctx, 3) >= 0 and gettime(ctx, 3) < 3) or
      (gettime(ctx, 3) >= 6 and gettime(ctx, 3) < 9) or
      (gettime(ctx, 3) >= 12 and gettime(ctx, 3) < 15) or
      (gettime(ctx, 3) >= 18 and gettime(ctx, 3) < 21)
  end

  defp sail(ctx) do
    ctx
    |> mes("[Mr. Ibanoff]")
    |> mes("Hmm. It's not a bad time.")
    |> mes("We should hurry up")
    |> mes("while the tides are low.")
    |> mes("The ship is prepared already")
    |> mes("at a dock nearby, so we can depart")
    |> mes("right away.")
    |> close2()
    |> warp("mosk_ship", 94, 110)
  end

  defp tide_too_high(ctx) do
    ctx
    |> mes("[Mr. Ibanoff]")
    |> mes("Gee. The tide is too high.")
    |> mes("It's too dangerous to depart")
    |> mes("right now because of the waves")
    |> mes("getting too rugged.")
    |> next()
    |> mes("[Mr. Ibanoff]")
    |> mes("When the sea calmes down a bit,")
    |> mes("you can come back. We can't depart")
    |> mes("right now.")
    |> close()
  end
end
