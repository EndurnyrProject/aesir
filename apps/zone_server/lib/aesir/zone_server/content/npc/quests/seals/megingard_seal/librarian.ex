defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.MegingardSeal.Librarian do
  @moduledoc """
  Librarian Jekan guards a misplaced classified file in the Prontera Library and later opens
  its Search Magic records for the Megingjard Seal quest.

  ## Behavior

  - Outside the Megingjard seal phase, or before the quest reaches him, he warns visitors away
    from his section; ignoring him gets the player thrown out of the library.
  - At first he refuses to talk about the file. Once the player names its subject (the 1st
    squad's final mission), he accepts help, and lending him Spectacles or Lanterns earns his
    trust and sends the player to search the files.
  - When the file is found he asks for copy materials (2 Slick Paper, 1 Oil Paper, 3 Squid Ink,
    3 Feather of Birds, 20 Blue Gemstones), takes them and reviews the document over a few
    visits.
  - Afterwards he offers Record Search: looking up the 3rd Company, 3rd Platoon, 1st Squad
    roster and its record advances the quest, and each former member's name tells where they
    are now.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Lupus
    - L0ne_W0lf
    - Samuray22
    - brianluau
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  - Naming the 1st Squad's final mission set `god_eremes` to 4 at any stage from 3 to 6, which
    sent a player at stage 5 or 6 back to 4 and made them lend Jekan a light again; it now
    advances the quest only from stage 3.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_in",
        x: 172,
        y: 106,
        dir: 0,
        sprite: 833,
        name: "Librarian",
        scope: :shared,
        unique_name: "Librarian#megin"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if get_server_var(ctx, "God1", 0) >= get_server_temp_var(ctx, "god_check1", 0) and
         get_server_var(ctx, "God2", 0) < get_server_temp_var(ctx, "god_check2", 0) do
      quest_talk(ctx, get_char_var(ctx, :god_eremes, 0))
    else
      ctx
      |> mes("[Librarian Jekan]")
      |> mes("Ah, please do not")
      |> mes("touch any books in")
      |> mes("that section. There's")
      |> mes("nothing useful over in")
      |> mes("that section anyway.")
      |> next()
      |> select(["Ignore him and check books.", "Step back."])
      |> books_choice(["I told you...!", "Don't touch", "the books here!"])
    end
  end

  defp quest_talk(ctx, stage) when stage > 2 and stage < 7 do
    ctx
    |> mes("[Librarian Jekan]")
    |> mes("Ah, please do")
    |> mes("not touch the files")
    |> mes("in this section.")
    |> next()
    |> mes("[Librarian Jekan]")
    |> mes("Some of the information")
    |> mes(
      "here is classified, and it is therefore prohibited by the Prontera Military to browse"
    )
    |> mes("through them.")
    |> next()
    |> mes("[Librarian Jekan]")
    |> mes(
      "I'm currently in the process of searching for the classified files in that section, so that I can separate it from the information that is public domain."
    )
    |> next()
    |> mes("[Librarian Jekan]")
    |> mes("I'd highly")
    |> mes("appreciate it")
    |> mes("if you ^660000didn't^000000")
    |> mes("interfere with my work.")
    |> next()
    |> mes("[Librarian Jekan]")
    |> mes("Darn it...!")
    |> mes(
      "I can't read anything when the light is this dim! It's bad enough my eyes have gone bad..."
    )
    |> help_menu()
  end

  defp quest_talk(ctx, 2) do
    ctx
    |> mes("[Librarian Jekan]")
    |> mes(
      "Ah, please do not touch the files in this section. Usually, it's public domain but it seems that a classified file managed to get misplaced there."
    )
    |> next()
    |> mes("[Librarian Jekan]")
    |> mes(
      "For now, I cannot let anyone without special authorization to look through that section. I must find that file and send it to the Prontera military as soon as I can."
    )
    |> next()
    |> mes("[Librarian Jekan]")
    |> mes(
      "Ergh! This light isn't bright enough for my eyes. They're starting to get sore again..."
    )
    |> next()
    |> mes("[Librarian Jekan]")
    |> mes(
      "So what brings you here? If you're looking for something in particular, you should try another section."
    )
    |> next()
    |> select([
      "I want to read some documents.",
      "Do you have bad eyes?",
      "Let me help you to find the files.",
      "What kind of files are you looking for?"
    ])
    |> classified_choice()
  end

  defp quest_talk(ctx, stage) when stage > 6 and stage < 12 do
    ctx
    |> search_progress(Enum.random(1..10) > 4)
    |> close()
  end

  defp quest_talk(ctx, 12) do
    ctx
    |> mes("[Librarian Jekan]")
    |> mes("Ah! There it is!")
    |> mes("Thank you so much!")
    |> mes(
      "I'm glad to see that there are still kind and thoughtful people like you in the world."
    )
    |> next()
    |> mes("[Librarian Jekan]")
    |> mes(
      "I really want to give you something to show you my gratitude, but I've got to send this back to the Prontera Military right away."
    )
    |> next()
    |> select(["I want to read the document."])
    |> elem(0)
    |> mes("[Librarian Jekan]")
    |> mes("Oh, right, you mentioned that, didn't you? It doesn't seem seem")
    |> mes("so important, but I'm not really quite sure...")
    |> next()
    |> mes("[Librarian Jekan]")
    |> mes(
      "Well, it couldn't hurt if I made a copy of this first for you to read, but I'll need some materials."
    )
    |> next()
    |> mes("[Librarian Jekan]")
    |> mes("I'll even cast the")
    |> mes(
      "Search Magic on it, so that it'll be just like the original. All right, I need the following things to make a copy..."
    )
    |> next()
    |> copy_materials()
    |> next()
    |> mes("[Librarian Jekan]")
    |> mes(
      "Please get those as soon as possible, and I'll be here making the other preparations to make a copy."
    )
    |> next()
    |> mes("[Librarian Jekan]")
    |> mes(
      "Also, I'll keep this copy in the Library for you to read, and to prevent it from being leaked to the public. So you'll have to come visit each time you wish to read it, okay?"
    )
    |> next()
    |> mes("[Librarian Jekan]")
    |> mes("Okay, now...")
    |> mes("Come back here")
    |> mes("as soon as you can.")
    |> set_char_var(:god_eremes, 13)
    |> close()
  end

  defp quest_talk(ctx, 13) do
    if count_item(ctx, 7111) > 1 and Rathena.truthy?(count_item(ctx, 7151)) and
         count_item(ctx, 1024) > 2 and count_item(ctx, 916) > 2 and count_item(ctx, 717) > 19 do
      ctx
      |> mes("[Librarian Jekan]")
      |> mes("Oh, you came back.")
      |> mes(
        "I didn't expect you to return here so quickly. Whatever's inside must be really important for you to know."
      )
      |> next()
      |> mes("[Librarian Jekan]")
      |> mes("Anyway, please")
      |> mes("give me a moment")
      |> mes("while I make that")
      |> mes("copy for you.")
      |> delitem(7111, 2)
      |> delitem(7151, 1)
      |> delitem(1024, 3)
      |> delitem(916, 3)
      |> delitem(717, 20)
      |> set_char_var(:god_eremes, 14)
      |> next()
      |> mes("[Librarian Jekan]")
      |> mes("Alright then...")
      |> mes("I'll see you in a bit.")
      |> close()
    else
      ctx
      |> mes("[Librarian Jekan]")
      |> mes("Have you forgotten")
      |> mes("what you need to make")
      |> mes("a copy? Alright, let me")
      |> mes("tell you again...")
      |> next()
      |> copy_materials()
      |> next()
      |> mes("[Librarian Jekan]")
      |> mes("Please come")
      |> mes("back with those items")
      |> mes("as soon as you can.")
      |> close()
    end
  end

  defp quest_talk(ctx, stage) when stage > 13 and stage < 16 do
    ctx =
      ctx
      |> mes("[Librarian Jekan]")
      |> mes("Let me go over and review the document before I make a copy...")

    if Enum.random(1..10) > 4 do
      close(ctx)
    else
      ctx
      |> set_char_var(:god_eremes, get_char_var(ctx, :god_eremes, 0) + 1)
      |> close()
    end
  end

  defp quest_talk(ctx, 16) do
    ctx
    |> mes("[Librarian Jekan]")
    |> mes(
      "There you go. As I thought, the document didn't seem to contain any crucially important data."
    )
    |> next()
    |> mes("[Librarian Jekan]")
    |> mes(
      "Just remember, this copy needs to stay in the Prontera Library. That means you have to come back if you need to read the document again."
    )
    |> set_char_var(:god_eremes, 17)
    |> close()
  end

  defp quest_talk(ctx, stage) when stage > 16 do
    ctx
    |> mes("[Librarian Jekan]")
    |> mes("Welcome, my friend!")
    |> mes("So, what do you need today?")
    |> next()
    |> search_menu()
  end

  defp quest_talk(ctx, _stage) do
    ctx
    |> mes("[Librarian Jekan]")
    |> mes(
      "Ah, please do not touch any books in that section. ...I'm sure there's nothing there that could be useful to you."
    )
    |> next()
    |> select(["Ignore him and check books.", "Step back."])
    |> books_choice(["Hey...!", "I thought I said", "not to touch those!"])
  end

  defp search_progress(ctx, true) do
    ctx
    |> mes("[Librarian Jekan]")
    |> mes(
      "Hmm? So did you find it? I've been searching for that file for a long time, but I haven't been able to find it."
    )
    |> next()
    |> mes("[Librarian Jekan]")
    |> mes("I'll go ahead and search the right side, so do you think you could search the left?")
  end

  defp search_progress(ctx, false) do
    ctx
    |> mes("[Librarian Jekan]")
    |> mes(
      "Did you find it yet? All this time, and I still haven't been able to dig up that file."
    )
    |> next()
    |> mes("[Librarian Jekan]")
    |> mes(
      "I'll go ahead and check the left side, so would you look for it in the middle or the right side?"
    )
  end

  defp books_choice({ctx, 1}, warning) do
    warning
    |> Enum.reduce(mes(ctx, "[Librarian Jekan]"), &mes(&2, &1))
    |> close2()
    |> warp("prontera", 120, 264)
  end

  defp books_choice({ctx, 2}, _warning) do
    ctx
    |> mes("[Librarian Jekan]")
    |> mes("Thank you. Feel")
    |> mes("free to browse through")
    |> mes("the other sections.")
    |> next()
    |> mes("[Librarian Jekan]")
    |> mes(
      "It's really nice to have visitors in the Library, especially when so many people don't read books nowadays."
    )
    |> close()
  end

  defp books_choice({ctx, _choice}, _warning), do: ctx

  defp classified_choice({ctx, 1}) do
    ctx
    |> mes("[Librarian Jekan]")
    |> mes(
      "I told you already! The files in this section aren't open to the public right now! Don't make me repeat myself!"
    )
    |> close()
  end

  defp classified_choice({ctx, 2}) do
    ctx
    |> mes("[Librarian Jekan]")
    |> mes("Since I have worked under a dim light for a long time, my eyes have gone bad.")
    |> mes("They should get me a new light, otherwise I will be gone blind sooner or later...")
    |> close()
  end

  defp classified_choice({ctx, 3}) do
    ctx
    |> mes("[Librarian Jekan]")
    |> mes("Um? How do you know what file I am looking for?")
    |> mes("You don't even know what is written inside?")
    |> mes("Stop interrupting me, leave!")
    |> close()
  end

  defp classified_choice({ctx, 4}) do
    ctx =
      ctx
      |> mes("[Librarian Jekan]")
      |> mes("Hmm... I am not supposed to reveal anything related to the file.")
      |> next()
      |> mes("[#{char_name(ctx, 0)}]")
      |> ask_file_subject("Isn't the file...")

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("^0000FF#{get_temp_var(ctx, :"str$", "")}?")
    |> next()
    |> mes("[Librarian Jekan]")
    |> mes("Maybe...")
    |> mes("Maybe not~")
    |> close()
  end

  defp classified_choice({ctx, _choice}), do: ctx

  defp help_menu(ctx) do
    {ctx, choice} =
      ctx
      |> next()
      |> select([
        "You have bad eyes?",
        "I want to read some documents.",
        "Let me help you find those files...",
        "What kind of files are you looking for?"
      ])

    help_choice(ctx, choice)
  end

  defp help_choice(ctx, 1) do
    ctx =
      ctx
      |> mes("[Librarian Jekan]")
      |> mes("I've worked")
      |> mes("under dim light")
      |> mes("for so long, my eyes have")
      |> mes(
        "gone bad. They should get me ^0000FFa new light^000000, otherwise I'll go blind sooner or later..."
      )

    stage = get_char_var(ctx, :god_eremes, 0)

    cond do
      stage == 5 and (count_item(ctx, 2203) > 0 or count_item(ctx, 1041) > 0) ->
        ctx
        |> next()
        |> mes("[Librarian Jekan]")
        |> mes(
          "Hey, that's some pretty useful stuff that you've got with you. Do you mind letting me borrow it for a while? It'll help me in finding those files..."
        )
        |> next()
        |> select(["Yes, I mind!", "No, I don't mind."])
        |> lend_choice()

      stage > 5 ->
        ctx
        |> next()
        |> mes("[Librarian Jekan]")
        |> mes("Thank you...")
        |> mes("The stuff you let")
        |> mes("me borrow will really")
        |> mes("help me in looking for")
        |> mes("all of those files...")
        |> help_menu()

      true ->
        help_menu(ctx)
    end
  end

  defp help_choice(ctx, 2) do
    if get_char_var(ctx, :god_eremes, 0) == 6 do
      ctx
      |> mes("[Librarian Jekan]")
      |> mes("Read some documents?")
      |> mes("Well, you've come here")
      |> mes("to the Library. That's")
      |> mes("a good start.")
      |> next()
      |> mes("[Librarian Jekan]")
      |> mes("Well, as long as")
      |> mes("you know what kind")
      |> mes("of document you're")
      |> mes("looking for, you might")
      |> mes("be able to find it.")
      |> next()
      |> mes("[Librarian Jekin]")
      |> mes("I've got to find that")
      |> mes("classified file as soon")
      |> mes("as I can!")
      |> close2()
      |> set_char_var(:god_eremes, 7)
    else
      ctx
      |> mes("[Librarian Jekan]")
      |> mes("Hmm...?")
      |> mes("Hey, haven't")
      |> mes("I told you already?")
      |> next()
      |> mes("[Librarian Jekan]")
      |> mes(
        "The public is prohibited from browsing the files in this section! How many times do I need to repeat myself?"
      )
      |> close()
    end
  end

  defp help_choice(ctx, 3) do
    stage = get_char_var(ctx, :god_eremes, 0)

    cond do
      stage == 4 ->
        ctx
        |> mes("[Librarian Jekan]")
        |> mes("I'd gladly accept your")
        |> mes(
          "help if it weren't for the fact that I cannot allow classified information to be released to the public."
        )
        |> next()
        |> mes("[Librarian Jekan]")
        |> mes(
          "I have no idea how something so important was shuffled into the files here in Prontera Library, but we can't allow the public to access it."
        )
        |> next()
        |> mes("[Librarian Jekan]")
        |> mes(
          "Still, that file doesn't seem to be that important, but I still have to waste my time on finding it..."
        )
        |> next()
        |> mes("[Librarian Jekan]")
        |> mes("Damn, my eyes are sore.")
        |> mes(
          "Working as a government official is easy except for the times when the beaucrats make you do stuff like this."
        )
        |> set_char_var(:god_eremes, 5)
        |> help_menu()

      stage > 4 ->
        ctx
        |> mes("[Librarian Jekan]")
        |> mes("I think I'm going to go")
        |> mes("insane looking for this file...!")
        |> next()
        |> mes("[Librarian Jekan]")
        |> mes("Huh...?")
        |> mes("Did you just say")
        |> mes("that you wanted to")
        |> mes("help me? I-I'd appreciate it.")
        |> help_menu()

      true ->
        ctx
        |> mes("[Librarian Jekan]")
        |> mes("Um, you're not even")
        |> mes("supposed to know what")
        |> mes(
          "kind of file I'm looking for. Even if you did, I'm not allowed to show you what's inside!"
        )
        |> close()
    end
  end

  defp help_choice(ctx, 4) do
    ctx =
      ctx
      |> mes("[Librarian Jekan]")
      |> mes(
        "Hmm. I'm not really allowed to disclose any information related to that file. I'm sorry about that."
      )
      |> next()
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("But isn't")
      |> ask_file_subject("the file about...")

    subject = get_temp_var(ctx, :"str$", "")
    ctx = ctx |> mes("^0000FF#{subject}?") |> next()

    if subject == "the 1st squad's final mission" do
      ctx
      |> mes("[Librarian Jekan]")
      |> mes("Hmm...?")
      |> mes("How did you")
      |> mes("know about that?")
      |> advance(3, 4)
      |> help_menu()
    else
      ctx
      |> mes("[Librarian Jekan]")
      |> mes("Errmmm...")
      |> mes("I don't think so....?")
      |> help_menu()
    end
  end

  defp help_choice(ctx, _choice), do: ctx

  defp ask_file_subject(ctx, prompt) do
    {ctx, subject} = ctx |> mes(prompt) |> input(:string)
    set_temp_var(ctx, :"str$", subject)
  end

  defp lend_choice({ctx, 1}) do
    ctx
    |> mes("[Librarian Jekan]")
    |> mes("^333333*Sniff*^000000")
    |> mes("N-never mind...")
    |> close()
  end

  defp lend_choice({ctx, 2}) do
    ctx
    |> mes("[Librarian Jekan]")
    |> mes("Oh, you are so kind!")
    |> mes("Y-you really do want")
    |> mes("to help me, don't you?")
    |> hand_over_light()
    |> set_char_var(:god_eremes, 6)
    |> next()
    |> mes("[Librarian Jekan]")
    |> mes("Thank you...")
    |> mes("Now I won't have to")
    |> mes("worry so much about")
    |> mes("finding that file.")
    |> next()
    |> mes("[Librarian Jekan]")
    |> mes("If it's alright,")
    |> mes("would you help me")
    |> mes("look for it...?")
    |> close()
  end

  defp lend_choice({ctx, _choice}), do: ctx

  defp hand_over_light(ctx) do
    spectacles? = Rathena.truthy?(count_item(ctx, 2203))
    lanterns? = Rathena.truthy?(count_item(ctx, 1041))

    cond do
      spectacles? and lanterns? -> ctx |> delitem(1041, count_item(ctx, 1041)) |> delitem(2203, 1)
      spectacles? -> delitem(ctx, 2203, 1)
      lanterns? -> delitem(ctx, 1041, count_item(ctx, 1041))
      true -> ctx
    end
  end

  defp copy_materials(ctx) do
    ctx
    |> mes("[Librarian Jekan]")
    |> mes("2 Slick Paper,")
    |> mes("1 Oil Paper,")
    |> mes("3 Squid Ink,")
    |> mes("3 Feather of Birds and")
    |> mes("20 Blue Gemstones.")
  end

  defp search_menu(ctx) do
    {ctx, choice} = select(ctx, ["Record Search.", "Quit searching.", "Search Help", "Converse."])
    search_choice(ctx, choice)
  end

  defp search_choice(ctx, 1) do
    {ctx, input} =
      ctx
      |> mes("^663300- Search Magic Initiated -")
      |> mes("- Please enter a keyword. -")
      |> mes(" ")
      |> mes("*Search Magic is")
      |> mes(" case sensitive.")
      |> mes("Please do not use")
      |> mes("capital letters.^000000")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"input$", input)

    ctx
    |> record_search(get_local(ctx, :"input$", ""))
    |> search_menu()
  end

  defp search_choice(ctx, 2) do
    ctx
    |> mes("^663300- Search Magic -")
    |> mes("- is being shut down. -^000000")
    |> next()
    |> mes("^663300- ... -^000000")
    |> next()
    |> mes("^663300- ... -^000000")
    |> mes("^663300- ... -^000000")
    |> next()
    |> mes("^663300- Search Magic -")
    |> mes("- Deactivated. -^000000")
    |> close()
  end

  defp search_choice(ctx, 3) do
    ctx
    |> mes("[Librarian Jekan]")
    |> mes("Well...")
    |> mes("This is a pretty")
    |> mes("obsolete version")
    |> mes("of Search Magic,")
    |> mes("so I understand if")
    |> mes("it's giving you trouble.")
    |> next()
    |> mes("[Librarian Jekan]")
    |> mes("Now...")
    |> mes(
      "First, if you're going to enter a single search term, like someone's name, you would enter '^660000lee_hester^000000' if you were looking up 'Lee Hester.'"
    )
    |> next()
    |> mes("[Librarian Jekan]")
    |> mes("Don't use any")
    |> mes("capital letters!")
    |> mes("And use underscores to")
    |> mes("indicate spaces between first and last names and within military unit names.")
    |> next()
    |> mes("[Librarian Jekan]")
    |> mes(
      "For example, the Fourth Company would be entered as ^6600004th_company^000000. Now... bear with me."
    )
    |> next()
    |> mes("[Librarian Jekan]")
    |> mes(
      "If you're looking for information on a specific squad, you need to know the Platoon and Company it falls under."
    )
    |> next()
    |> mes("[Librarian Jekan]")
    |> mes(
      "For example, if you wanted to look up the Crusader 4th Squad of the 4th Platoon of the 4th Company, you would input..."
    )
    |> next()
    |> mes("[Librarian Jekan]")
    |> mes(
      "'^660000crusader 4th_company 4th_platoon 4th_squad record^000000' all in one line exactly like that. I hope this helps you in your search..."
    )
    |> next()
    |> search_menu()
  end

  defp search_choice(ctx, 4) do
    ctx
    |> mes("[Librarian Jekan]")
    |> mes("You can tell our")
    |> mes("government doesn't")
    |> mes("really know how to")
    |> mes("allocate its funds")
    |> mes("and resources.")
    |> next()
    |> mes("[Librarian Jekan]")
    |> mes("First, there's Jawaii.")
    |> mes("Do newlyweds really need")
    |> mes("an entire island for themselves? Then again, I am single so I'm probably biased.")
    |> next()
    |> mes("[Librarian Jekan]")
    |> mes("And look at me.")
    |> mes(
      "Geniuses aren't supposed to waste their precious time doing useless things for libraries!"
    )
    |> close()
  end

  defp search_choice(ctx, _choice), do: ctx

  defp record_search(ctx, keyword) do
    cond do
      found?(keyword, "crusader") ->
        ctx
        |> mes("^663300[Keyword: ^996633Crusader^663300]")
        |> mes(
          "Crusaders are warriors preparing for the upcoming Holy War against Evil. Experienced swordsmen, usually with remarkable spiritual prowess.^000000"
        )
        |> close2()
        |> crusader_search(keyword)

      found?(keyword, "3rd_company") ->
        ctx
        |> mes(keyword_title(keyword))
        |> third_company(keyword, :company)

      found?(keyword, "3rd_platoon") ->
        ctx
        |> mes(keyword_title(keyword))
        |> mes("The 3rd Platoon : ")
        |> mes("- No result has been found.-")
        |> mes("- Suggested to enter a more specific keyword.-")
        |> close2()

      found?(keyword, "1st_squad") ->
        ctx
        |> mes(keyword_title(keyword))
        |> mes("The 3rd Company : ")
        |> mes("- No result has been found.-")
        |> mes("- Suggested to enter a more specific keyword.-")
        |> close2()

      found?(keyword, "record") and get_char_var(ctx, :god_eremes, 0) > 17 ->
        ctx
        |> mes(keyword_title(keyword))
        |> mes("- No result has been found.-")
        |> mes("- Suggested to enter a specific name of the force for a better research.-")
        |> next()
        |> close2()

      found?(keyword, "rebarev_doug") ->
        member_profile(
          ctx,
          keyword,
          [
            "Former leader of",
            "3rd Company, 3rd Platoon,",
            "1st Squad. Serves as instructor of Crusader Boot Camp and is currently",
            "conducting research by royal edict.^000000"
          ],
          "^996633Prontera Castle, Prontera^663300.^000000"
        )

      found?(keyword, "egnigem") ->
        ctx
        |> mes(keyword_title(keyword))
        |> mes("^FF0000Prohibited Search Term!^000000")
        |> close2()

      found?(keyword, "zan.huadoku") ->
        member_profile(
          ctx,
          keyword,
          [
            "Former member of",
            "3rd Company, 3rd Platoon",
            "1st Squad. Serving as weapon quartermaster since disbanding",
            "of 1st Squad."
          ],
          "^996633Blacksmith Guild, Geffen^663300.^000000"
        )

      found?(keyword, "cuaque_donon") ->
        member_profile(
          ctx,
          keyword,
          [
            "Former member of",
            "3rd Company, 3rd Platoon",
            "1st Squad. Retired from service",
            "and now works at an Inn."
          ],
          "^996633Inn, Morocc^663300.^000000"
        )

      found?(keyword, "jack_o") ->
        member_profile(
          ctx,
          keyword,
          [
            "Former member of",
            "3rd Company, 3rd Platoon",
            "1st Squad. Serving as recruiting officer since disbanding of 1st Squad."
          ],
          "^996633Alberta Port^663300.^000000"
        )

      found?(keyword, "emma_searth") ->
        member_profile(
          ctx,
          keyword,
          [
            "Former member of",
            "3rd Company, 3rd Platoon",
            "1st Squad. Retired since",
            "disbanding of 1st Squad."
          ],
          "^996633Al De Baran^663300.^000000"
        )

      found?(keyword, "royal_myst") ->
        member_profile(
          ctx,
          keyword,
          ["Former member of", "3rd Company, 3rd Platoon", "1st Squad. Current duty is unknown."],
          "^996633Casino, Comodo^663300.^000000"
        )

      found?(keyword, "the_nineball") ->
        member_profile(
          ctx,
          keyword,
          [
            "Former member of",
            "3rd Company, 3rd Platoon",
            "1st Squad. Serves as security officer since disbanding of 1st Squad."
          ],
          "^996633Tavern, Jawaii^663300.^000000"
        )

      true ->
        ctx
        |> mes(keyword_title(keyword))
        |> mes(keyword_title(keyword))
        |> mes(keyword_title(keyword))
        |> mes("No result has been found.")
        |> close2()
    end
  end

  defp crusader_search(ctx, keyword) do
    cond do
      found?(keyword, "3rd_company") ->
        third_company(ctx, keyword, :crusader)

      found?(keyword, "3rd_platoon") ->
        ctx
        |> mes(keyword_title(keyword))
        |> mes("Each Company consists")
        |> mes("of 4 Platoons. Please")
        |> mes("specify Company.^000000")
        |> next()
        |> close2()

      found?(keyword, "1st_squad") ->
        ctx
        |> mes(keyword_title(keyword))
        |> mes("The 1st Squad : Crusaders.")
        |> mes(
          "Each platoon consists of 4 squads. Please specify Company and Platoon for information on a specific squad.^000000"
        )
        |> close2()

      found?(keyword, "record") ->
        ctx
        |> mes(keyword_title(keyword))
        |> mes("- No result has been found.-")
        |> close2()

      true ->
        ctx
        |> mes(keyword_title(keyword))
        |> mes(keyword_title(keyword))
        |> mes("-search with a keyword : #{keyword} -")
        |> mes("- No result has been found.-")
        |> close2()
    end
  end

  defp third_company(ctx, keyword, search) do
    ctx =
      ctx
      |> mes("^663300[Keyword: ^9966333rd Company^663300]")
      |> mes(
        "Only the best Crusaders are selected to form the ranks of all squads in the 3rd Company. Most transfer records for 3rd Company Squads are unavailable.^000000"
      )
      |> next()
      |> mes("^663300[Keyword: ^9966333rd Company^663300]")
      |> mes(
        "The 1st Squad of the 3rd Platoon is an exception, as all members retired or were transferred to other forces. More specific information can be found by searching ^9966333rd Platoon^663300."
      )
      |> close2()

    if found?(keyword, "3rd_platoon") do
      ctx
      |> mes("^663300[Keyword: ^9966333rd Platoon^663300]")
      |> mes(
        "The 3rd Platoon is considered the elite force in the 3rd Company. Only records for the 1st Squad in the 3rd Platoon currently exist due to special circumstances.^000000"
      )
      |> next()
      |> mes("^663300[Keyword: ^9966333rd Platoon^663300]")
      |> mes("More specific information can be found by searching ^9966331st Squad^663300.")
      |> close2()
      |> first_squad(keyword, search)
    else
      ctx
    end
  end

  defp first_squad(ctx, keyword, search) do
    if found?(keyword, "1st_squad") do
      ctx
      |> squad_roster(search)
      |> squad_record(keyword)
    else
      ctx
      |> mes(keyword_title(keyword))
      |> mes("- No result has been found.-")
      |> close2()
    end
  end

  defp squad_roster(ctx, :crusader), do: ctx |> roster_pages() |> advance(17, 18) |> close2()
  defp squad_roster(ctx, :company), do: ctx |> roster_pages() |> close2() |> advance(17, 18)

  defp roster_pages(ctx) do
    ctx
    |> mes("^663300[Keyword: ^9966331st Squad^663300]")
    |> mes("1st Squad.")
    |> mes("Complete")
    |> mes("Member Roster")
    |> mes("...^000000")
    |> next()
    |> mes("^663300[Keyword: ^9966331st Squad^663300]")
    |> mes("^0000FF : Rebarev Doug")
    |> mes(" : Jack O")
    |> mes(" : Zan.Huadoku")
    |> mes(" : Cuaque Donon")
    |> mes(" : Emma Searth")
    |> mes(" : Royal Myst")
    |> mes(" : The Nineball^000000")
  end

  defp squad_record(ctx, keyword) do
    if found?(keyword, "record") do
      ctx
      |> mes("^663300[Keyword: ^9966331st Squad Record^663300]")
      |> mes(
        "The 1st Squad was famous as the most skilled search party within the Crusaders. However, it was disbanded as a result of its final mission.^000000"
      )
      |> next()
      |> mes("^663300[Keyword: ^9966331st Squad Record^663300]")
      |> mes("The 1st Squad was secretly")
      |> mes("assigned by the royal court to find and acquire ^996633godly artifacts^663300.")
      |> mes(
        "However, the mission failed due to a factional dispute caused by one member's act of insubordination.^000000"
      )
      |> next()
      |> mes("^663300[Keyword: ^9966331st Squad Record^663300]")
      |> mes(
        "The member guilty of insubordination was dropped from the squad during this mission. However, his actions were enough to result in the failure of the 1st Squad's final mission.^000000"
      )
      |> next()
      |> mes("^663300[Keyword: ^9966331st Squad Record^663300]")
      |> mes("Due to this disgraceful incident, the 1st Squad was disbanded and")
      |> mes("its members have been sent to disciplinary retraining for 3 months.")
      |> next()
      |> mes("^663300[Keyword: ^9966331st Squad Record^663300]")
      |> mes(
        "Most of the members of the 1st Squad were transferred to other squads or retired. Their former leader, Rebarev Doug, is currently in charge of researching godly artifacts under royal edict.^000000"
      )
      |> close2()
      |> advance(18, 19)
    else
      ctx
    end
  end

  defp member_profile(ctx, keyword, record, location) do
    record
    |> Enum.reduce(mes(ctx, keyword_title(keyword)), &mes(&2, &1))
    |> next()
    |> mes(keyword_title(keyword))
    |> mes("Current location:")
    |> mes(location)
    |> close2()
  end

  defp advance(ctx, from, to) do
    if get_char_var(ctx, :god_eremes, 0) == from,
      do: set_char_var(ctx, :god_eremes, to),
      else: ctx
  end

  defp keyword_title(keyword), do: "^663300[Keyword: ^996633#{keyword}^663300]"

  defp found?(keyword, term), do: Rathena.compare(keyword, term) == 1
end
