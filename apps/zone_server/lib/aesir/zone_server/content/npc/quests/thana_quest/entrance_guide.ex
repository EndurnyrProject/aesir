defmodule Aesir.ZoneServer.Content.Npc.Quests.ThanaQuest.EntranceGuide do
  @moduledoc """
  Burled guides contracted workers into Thanatos Tower and shares its secrets.

  ## Behavior

  - Opens the third-floor gate when enough workers gather.
  - Discusses the tower and advances the investigation.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "tha_t02",
        x: 231,
        y: 161,
        dir: 5,
        sprite: 874,
        name: "Entrance Guide",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    ctx = mes(ctx, "[Burled]")

    if get_char_var(ctx, :thana_tower, 0) == 0 do
      ctx
      |> mes("You are in front of the entrance to the 3rd Floor. Only contracted")
      |> mes("temp employees are authorized")
      |> mes("to enter that area. For Rekenber temp contract information, please")
      |> mes("speak to the 2nd Floor Guide.")
      |> close()
    else
      {ctx, choice} =
        ctx
        |> mes("This is the path to the 3rd floor.")
        |> mes("Only the contracted staff are allowed to enter.")
        |> mes("How can I help you?")
        |> next()
        |> select(["Let me go to 3rd floor.", "Tower Information.", "Start a conversation."])

      case choice do
        1 ->
          enter_third_floor(ctx)

        2 ->
          tower_information(ctx)

        3 ->
          conversation(ctx)

        _ ->
          ctx
      end
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp enter_third_floor(ctx) do
    ctx =
      ctx
      |> mes("[Burled]")
      |> mes("Oh, alright. Let me")
      |> mes("check and see if you're")
      |> mes("on our temp list. Hmmm...")

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("Ah, you're ", char_name(ctx, 0)), ", right?"))
      |> next()
      |> mes("[Burled]")

    if getareausers(ctx, "tha_t02", 226, 156, 236, 166) < 5 do
      ctx =
        ctx
        |> mes("First, we need to wait until")
        |> mes("at least 5 temps are gathered")
        |> mes("to form a work group. Right")
        |> mes("now, there are a total of")

      ctx
      |> mes(
        Rathena.concat(
          getareausers(ctx, "tha_t02", 226, 156, 236, 166),
          " temp workers waiting to"
        )
      )
      |> mes("enter the 3rd Floor.")
      |> next()
      |> mes("[Burled]")
      |> mes("If you can, try to get")
      |> mes("your friends to help you")
      |> mes("by coming near me. Please")
      |> mes("understand that we have this")
      |> mes("temp worker group requirement")
      |> mes("for various safety reasons.")
      |> close()
    else
      ctx =
        ctx
        |> mes("Great, you're just")
        |> mes("in time. We just met")
        |> mes("the minimum 5 temp group")
        |> mes("requirement, so we'll open")
        |> mes("the gate to the 3rd Floor soon.")
        |> next()
        |> mes("[Burled]")
        |> mes("The gate to the 3rd Floor")
        |> mes("will close shortly, so enter it")
        |> mes("as soon as you can. We have")
        |> mes("to close it quickly because we")
        |> mes("can't have the tower monsters")
        |> mes("entering the lower floors...")

      ctx =
        if get_char_var(ctx, :thana_tower, 0) > 3 do
          ctx
          |> next()
          |> mes("^4d4dffBurled is smiling lightly so that only I notice.")
          |> mes("I nod, then watch him open the gate.^000000")
        else
          ctx
        end

      ctx |> close2() |> donpcevent("3rdf_warp#tt::OnEnable")
    end
  end

  defp tower_information(ctx) do
    ctx
    |> mes("[Burled]")
    |> mes("This gate is the only passage")
    |> mes("that connects to the 3rd Floor.")
    |> mes("After the 4th Floor, passages")
    |> mes("between floors only travel one")
    |> mes("way, meaning you can't exit the")
    |> mes("same way you that you entered.")
    |> next()
    |> mes("[Burled]")
    |> mes("You see, there's a strange")
    |> mes("power that affects the 5th")
    |> mes("Floor, and all floors above,")
    |> mes("which doesn't allow people to")
    |> mes("backtrack through the passage in which they entered the floor.")
    |> next()
    |> mes("[Burled]")
    |> mes("So if you ascend past the")
    |> mes("4th Floor, please be careful")
    |> mes("and make sure that you find")
    |> mes("a way to get back.")
    |> next()
    |> mes("[Burled]")
    |> mes("The top is the 12th floor,")
    |> mes("and the monsters grow more powerful")
    |> mes("as you ascend the tower.")
    |> mes("The geographical features also change considerably.")
    |> next()
    |> mes("[Burled]")
    |> mes("Because the higher levels are")
    |> mes("too dangerous, we only open the")
    |> mes("3rd Floor Gate when 5 or more")
    |> mes("are gathered here. Therefore,")
    |> mes("you may need to wait if less")
    |> mes("than 5 temps have gathered.")
    |> close()
  end

  defp conversation(ctx) do
    cond do
      get_char_var(ctx, :thana_tower, 0) < 3 ->
        initial_conversation(ctx)

      get_char_var(ctx, :thana_tower, 0) == 3 ->
        {ctx, _} = scoped_call(ctx, [], &request/2)
        close(ctx)

      get_char_var(ctx, :thana_tower, 0) == 4 ->
        ctx
        |> mes("[Burled]")
        |> mes("Rekenber Corporation must have another intention,")
        |> mes("since they don't seem interested in the tower much.")
        |> mes("I want to know their intention.")
        |> next()
        |> mes("[Burled]")
        |> mes("This tower is sealed and separated from the outside.")
        |> mes("We need to break those seals, explore inside and develop it.")
        |> next()
        |> mes("[Burled]")
        |> mes("We are developing the 3rd and 4th floors now...")
        |> mes("There are still seals there.")
        |> mes("You can find out some clues when you search around them.")
        |> close()

      get_char_var(ctx, :thana_tower, 0) > 4 and get_char_var(ctx, :thana_tower, 0) < 9 ->
        ctx
        |> mes("[Burled]")
        |> mes("The magical key and messages?")
        |> mes("...we absolutely haven't learned all the tower's secrets...")
        |> next()
        |> mes("[Burled]")
        |> mes("Who made the seals?")
        |> mes("...can you investigate more?")
        |> mes("There must be definitive evidence...")
        |> close()

      get_char_var(ctx, :thana_tower, 0) == 9 ->
        journal(ctx)

      true ->
        ctx =
          ctx
          |> mes("[Burled]")
          |> mes("Are you keeping the secrets well?")
          |> mes("Is there a Phantom on the top of this tower?")

        ctx =
          if :rand.uniform(3) - 1 == 1 do
            ctx
            |> mes("You look tired. This isn't a big deal, but it's for you.")
            |> npcskill(28, 11, 50, 70)
          else
            ctx
          end

        close(ctx)
    end
  end

  defp journal(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Burled]")
      |> mes("Any new progress?")
      |> next()
      |> select(["I found Varmunt's Journal..."])

    ctx =
      ctx
      |> mes("- You show him Varmunt's Journal.")
      |> mes("Burled reads it. -")
      |> next()
      |> mes("[Burled]")
      |> mes("...I recognize this.")
      |> mes("This is the hologragh of the wise man Varmunt.")
      |> mes("Regenschirm from Rekenber's huge research institute has...")
      |> next()
      |> mes("[Burled]")
      |> mes("...isn't this the one they are looking for now?!")
      |> mes("Isn't their mission to find out Varmunt's research materials...?")
      |> next()
      |> mes("[Burled]")
      |> mes("For assisting uncompleted research...")
      |> mes("Varmunt's research materials are needed...")
      |> mes("...so their mission isn't just an investigation of the tower.")
      |> next()
      |> mes("[Burled]")
      |> mes("Something to get as an advantage...")
      |> mes("Even they don't know where it is...")
      |> mes("...anyways, this is the one of their main objects.")
      |> next()
      |> mes("[Burled]")
      |> mes("It's absolutely great. The wise man Varmunt's belongings. How unbelievable!")
      |> mes("Now, what do we do with this?")
      |> next()
      |> mes("[Burled]")
      |> mes(
        "Originally everything we found out in this tower was under control of the Rekenber Corporation."
      )
      |> mes("This is supposed to theirs, but...")
      |> next()
      |> mes("[Burled]")

    ctx =
      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat("How would you like to keep this, ", char_name(ctx, 0)),
          "?"
        )
      )
      |> mes("Definitely this should be a secret.")
      |> mes("...um, this is a little revenge for them.")
      |> next()
      |> mes("[Burled]")
      |> mes("I can guess that there are several secrets in this tower through this note.")

    ctx =
      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat(
            "This secret should be disclosed by you, ",
            char_name(ctx, 0)
          ),
          ", before Rekenber does."
        )
      )
      |> next()
      |> mes("[Burled]")
      |> mes("No matter how much power they obtain... they won't get to know about this tower...")
      |> mes("Haha...")
      |> next()
      |> mes("[Burled]")
      |> mes("...haha...")
      |> mes("I feel a bit relieved.")
      |> mes("Thanks.")
      |> mes("This isn't much, but here's a return present.")
      |> next()
      |> mes("[Burled]")

    ctx
    |> mes(
      Rathena.concat(
        Rathena.concat(
          "I hope that these will be useful for you, ",
          char_name(ctx, 0)
        ),
        "."
      )
    )
    |> next()
    |> mes("- Burled gives you the note and an Old Violet Box. -")
    |> mes(" ")
    |> mes("^4d4dffYou acquire one Old Violet Box,")
    |> mes("as well as a little EXP.^000000")
    |> set_char_var(:thana_tower, 10)
    |> completequest(7053)
    |> getexp(120_000, 10000)
    |> give_item(617, 1)
    |> close()
  end

  defp initial_conversation(ctx) do
    {ctx, question} =
      ctx
      |> mes("[Burled]")
      |> mes("...?")
      |> mes("Do you have any questions?")
      |> next()
      |> select([
        "About the development.",
        "The relationship of Cool Event Corporation and Rekenber Corporation.",
        "Nope."
      ])

    if question == 3 do
      ctx |> mes("[Burled]") |> mes("Take care.") |> close()
    else
      ask_favor(ctx)
    end
  end

  defp ask_favor(ctx) do
    {ctx, response} =
      ctx
      |> mes("[Burled]")
      |> mes("...um, you're quite curious.")
      |> mes("If you want to know more, would you do me a favor?")
      |> mes("Since you asked for our confidential info...")
      |> next()
      |> select([
        "Really? Don't make me afraid of it.",
        "Just tell me about it.",
        "I'll listen about it later."
      ])

    if response == 3 do
      ctx |> mes("[Burled]") |> mes("As you wish...") |> mes("Take care!") |> close()
    else
      explain_accident(ctx)
    end
  end

  defp explain_accident(ctx) do
    {ctx, reaction} =
      ctx
      |> mes("[Burled]")
      |> mes("Haha. That's not a big deal.")
      |> mes("We, Cool Event, are the corporation that works in many areas of business.")
      |> mes("From simple events, guides for dungeons, and trading items.")
      |> next()
      |> mes("[Burled]")
      |> mes(
        "Though our business started as a small one, we've been getting bigger with assistance from the Rekenber Corporation."
      )
      |> mes("They suggested to develop this tower together.")
      |> next()
      |> mes("[Burled]")
      |> mes("The Rekenber Corporation is only digging out the remains for studies.")
      |> mes(
        "The rest would be made into sightseeing place, which Cool Event Corporation can manage well."
      )
      |> next()
      |> mes("[Burled]")
      |> mes("It's the biggest business ever.")
      |> mes("Also quite profitable as tourist attractions.")
      |> mes("But...")
      |> next()
      |> mes("[Burled]")
      |> mes("Considerably strong monsters spawn inside the tower.")
      |> mes("The monsters weren't spawned there before.")
      |> mes("The day after that happened...")
      |> next()
      |> mes("[Burled]")
      |> mes("...anyway, there were some accidently spawned monsters and some troubles...")
      |> mes("We and the Rekenber Corporation are in shock.")
      |> mes("We were influenced economically, but the more serious thing is...")
      |> next()
      |> mes("[Burled]")
      |> mes("Many staff involved in development are")
      |> mes("sacrificing themselves by coming to 3rd floor.")
      |> next()
      |> mes("[Burled]")
      |> mes("While we've pumped our all into the business, that accident happened...")
      |> mes("We eventually merged with the Rekenber Corporation.")
      |> next()
      |> mes("[Burled]")
      |> mes("The development is on hold temporarily.")
      |> mes("Recruiting adventurers to defeat monsters...")
      |> mes("Isn't this funny?")
      |> next()
      |> mes("[Burled]")
      |> mes("No matter what happened there, they wouldn't be hurt.")
      |> mes("Even if they don't get at the root of the accident....")
      |> next()
      |> select(["Oh...", "What accident are you referring to?"])

    case reaction do
      1 ->
        ctx
        |> mes("[Burled]")
        |> mes("Yes, it's not that big of a deal. Haha....")
        |> mes("If we are working here like this....")
        |> mes("we would know about the death of animals.")
        |> next()
        |> mes("[Burled]")
        |> mes("Cool Event Corporation is considered the follower...")
        |> mes("They don't clear up how many people")
        |> mes("died or any reasons for it.")
        |> next()
        |> mes("[Burled]")
        |> mes("Now you're curious about this case.")
        |> mes("What do they sacrifice for?")
        |> next()
        |> mes("[Burled]")
        |> mes("I talked a lot.")
        |> mes("Sorry, I am not supposed to talk about this case like this...")
        |> mes("I've been quite concerned about it, that's all.")
        |> set_char_var(:thana_tower, 3)
        |> close()

      2 ->
        {ctx, promise} =
          ctx
          |> mes("[Burled]")
          |> mes("If you promise me that")
          |> mes("you will do me a favor...")
          |> next()
          |> select(["Ok! I will.", "No, I won't."])

        case promise do
          1 ->
            {ctx, _} = scoped_call(ctx, [], &request/2)
            ctx = next(ctx)

            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("(What's the accident...?")
            |> mes("He might let me know later...)")
            |> close()

          2 ->
            ctx
            |> mes("[Burled]")
            |> mes("...there is no way...")
            |> mes("They request you to explore the internal part.")
            |> mes("You're employed for this exploration.")
            |> close()

          _ ->
            ctx
        end

      _ ->
        ctx
    end
  end

  defp request(ctx, _args) do
    ctx =
      ctx
      |> mes("[Burled]")
      |> mes("Ah, it's not that difficult.")
      |> mes("After you explore the tower, let me know in detail anything you learn.")
      |> next()
      |> mes("[Burled]")
      |> mes(
        "...I can't believe the Rekenber Corporation. Many colleagues and friends died for them."
      )
      |> mes("But the Rekenber Corporation doesn't expose the reason they are dead.")
      |> next()
      |> mes("[Burled]")
      |> mes("The conditions were bad for us from beginning...")
      |> mes(
        "All of the developed places except research materials would be turned into tourist attractions..."
      )
      |> mes("Honestly, all the personnel are from Cool Event Corp.")
      |> next()
      |> mes("[Burled]")
      |> mes("They know about it as well.")
      |> mes("This business needs much sacrifice as well as personnel who are up for it.")
      |> next()
      |> mes("[Burled]")
      |> mes(
        "Now I don't feel victimized anymore, but I just want to know what drives these accidents..."
      )
      |> mes("^4d4dffWhat makes us victimized...?^000000")
      |> mes("That's what I want to know.")
      |> next()
      |> mes("[Burled]")
      |> mes("What's this tower?")
      |> mes("Why did they develop this dangerous place?")
      |> mes("And for what? Should my colleagues be dead for it?")
      |> next()
      |> mes("[Burled]")
      |> mes("I seriously want to know about it.")
      |> mes("Why they must sacrifice themselves...")
      |> mes("Let me know...")
      |> next()
      |> mes("He seriously wants to know about it.")
      |> mes("His hands are trembling now...")
      |> mes("I nodd without answering.")
      |> set_char_var(:thana_tower, 4)
      |> setquest(7048)

    {ctx, nil}
  end
end
