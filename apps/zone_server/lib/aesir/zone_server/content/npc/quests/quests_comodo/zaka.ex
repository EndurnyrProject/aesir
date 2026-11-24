defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsComodo.Zaka do
  @moduledoc """
  Zaka prepares the Book of the Lamb for doomed sword seekers.

  ## Behavior

  - Requests scales in stages to complete the book.
  - Directs the adventurer to Won after completing it.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Evera
    - Samuray22
    - Brainstorm

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "morocc",
        x: 201,
        y: 30,
        dir: 4,
        sprite: 99,
        name: "Zaka",
        scope: :shared,
        unique_name: "Zaka#cmd"
      }
    ]

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :dmdswrd_Q, 0)

    ctx =
      case progress do
        17 ->
          ctx
          |> mes("[Zaka]")
          |> mes("...You there! Hold it!")
          |> mes("Yes, I can feel it from")
          |> mes("you... The power of the")
          |> mes("Awakening Stone... And...")
          |> mes("The Slate of Muriniel?")
          |> mes("Finally, you've come.")
          |> next()
          |> mes("[Zaka]")
          |> mes("I'm fully aware that only")
          |> mes("those that seek to own one")
          |> mes("of the doomed swords would")
          |> mes("trouble themselve to obtain")
          |> mes("those items. All that is left for you is the Book of the Lamb...")
          |> next()
          |> mes("[Zaka]")
          |> mes("I've been waiting for so")
          |> mes("long for the opportunity to")
          |> mes("create the Book of the Lamb.")
          |> mes("If you really want the book,")
          |> mes("I will help you so long as")
          |> mes("you will help me.")
          |> next()
          |> mes("[Zaka]")
          |> mes("However, creating the book")
          |> mes("is a complicated process and")
          |> mes("requires multiple stages of")
          |> mes("preparation. Therefore, I shall")
          |> mes("ask you to bring me the items")
          |> mes("I require in separate batches.")
          |> next()
          |> mes("[Zaka]")
          |> mes("Alright...")
          |> mes("What was it now?")
          |> mes("Ah, yes. The first thing")
          |> mes("I need is ^3355FF2 Snake Scales^000000,")
          |> mes("so please bring those soon.")
          |> set_char_var(:dmdswrd_Q, 18)

        18 ->
          if count_item(ctx, 926) > 1 do
            ctx
            |> delitem(926, 2)
            |> set_char_var(:dmdswrd_Q, 19)
            |> mes("[Zaka]")
            |> mes("Ah, you've brought")
            |> mes("the Snake Scales? Good,")
            |> mes("let me take them now and")
            |> mes("begin work on the Book of")
            |> mes("the Lamb. Now, I need you")
            |> mes("to bring me ^3355FF1 Scale Shell^000000.")
            |> next()
            |> mes("[Zaka]")
            |> mes("I know it would be more")
            |> mes("convenient for you if I told")
            |> mes("you everything I needed at")
            |> mes("once, but actually, this way")
            |> mes("is much more convenient for")
            |> mes("me. I'll be waiting right here!")
          else
            ctx
            |> mes("[Zaka]")
            |> mes("The first thing I'll")
            |> mes("need to begin creating")
            |> mes("the Book of the Lamb is")
            |> mes("^3355FF2 Snake Scales^000000. Come back")
            |> mes("to me once you get them,")
            |> mes("alright? I'll be right here.")
          end

        19 ->
          if count_item(ctx, 936) > 0 do
            ctx
            |> mes("[Zaka]")
            |> mes("Oh, nice! You've brought")
            |> mes("this Scale Shell for me,")
            |> mes("right? Great, great, this will")
            |> mes("help enhance the book's")
            |> mes("physical durability, but it")
            |> mes("still needs magic durability...")
            |> next()
            |> mes("[Zaka]")
            |> mes("Next, you need to bring")
            |> mes("me ^3355FF1 Shining Shell^000000. Hurry")
            |> mes("and bring you to me before")
            |> mes("I finish this part of the process, okay? Wait, actually, I think")
            |> mes("you can take your time...")
            |> delitem(936, 1)
            |> set_char_var(:dmdswrd_Q, 20)
          else
            ctx
            |> mes("[Zaka]")
            |> mes("I'll be waiting right")
            |> mes("here while you go and")
            |> mes("look for a ^3355FFScale Shell^000000")
            |> mes("that you can bring to me.")
            |> mes("I'll need that in order to")
            |> mes("finish this Book of the Lamb.")
          end

        20 ->
          if count_item(ctx, 954) > 0 do
            ctx
            |> mes("[Zaka]")
            |> mes("Ah, you're just in time!")
            |> mes("Have you got the Shining")
            |> mes("Scale? Perfect. Now, there")
            |> mes("is just one more item that")
            |> mes("I want to ask you to bring me:")
            |> mes("^3355FF1 Stinky Scale^000000. Easy, right?")
            |> delitem(954, 1)
            |> set_char_var(:dmdswrd_Q, 21)
            |> next()
            |> mes("[Zaka]")
            |> mes("The energy of a Stinky")
            |> mes("Scale can be used to")
            |> mes("regulate the power of")
            |> mes("incredibly potent artifacts.")
            |> mes("Without that item, the Book")
            |> mes("of the Lamb isn't much use...")
          else
            ctx
            |> mes("[Zaka]")
            |> mes("If you want me to")
            |> mes("finish this Book of")
            |> mes("the Lamb, you need")
            |> mes("to come back here with")
            |> mes("^3355FF1 Shining Scale^000000. There's")
            |> mes("no way to work around it...")
          end

        21 ->
          if count_item(ctx, 959) > 0 do
            ctx
            |> mes("[Zaka]")
            |> mes("What's that sme--?")
            |> mes("Oh, right. I asked you to")
            |> mes("bring me a Stinky Scale.")
            |> mes("Now I can finally complete")
            |> mes("this Book of the Lamb! I've")
            |> mes("been looking forward to this...")
            |> next()
            |> mes("^3355FFZaka completes")
            |> mes("the creation of the")
            |> mes("Book of the Lamb.^000000")
            |> delitem(959, 1)
            |> set_char_var(:dmdswrd_Q, 22)
            |> next()
            |> mes("[Zaka]")
            |> mes("What...?!")
            |> mes("That's it? Well, um,")
            |> mes("it's done. That felt")
            |> mes("rather anticlimatic, but")
            |> mes("I can finally see this")
            |> mes("thing with my own eyes!")
            |> next()
            |> mes("[Zaka]")
            |> mes("Alright, you've eaten of the")
            |> mes("Awakening Stone, obtained the")
            |> mes("Slate of Muriniel, and now have")
            |> mes("the Book of the Lamb. You're")
            |> mes("getting very close to owning")
            |> mes("one of the doomed swords.")
            |> next()
            |> mes("[Zaka]")
            |> mes("There is man that you")
            |> mes("must find in Comodo named")
            |> mes("^3355FFWon^000000. He will judge you, and")
            |> mes("then give you the proof that")
            |> mes("shows you are qualified to")
            |> mes("be a doomed sword bearer.")
            |> next()
            |> mes("[Zaka]")
            |> mes("He looks like a simple")
            |> mes("man, but he is a true living")
            |> mes("legend renown for his wisdom.")
            |> mes("If you really want a doomed")
            |> mes("sword, you need to speak to")
            |> mes("Won and ask him to guide you.")
          else
            ctx
            |> mes("[Zaka]")
            |> mes("The last thing that I need")
            |> mes("to complete the Book of the")
            |> mes("Lamb is ^3355FF1 Stinky Scale^000000. Please")
            |> mes("bring that to me as soon as")
            |> mes("you can. Thank you for being")
            |> mes("patient, young adventurer.")
          end

        22 ->
          ctx
          |> mes("[Zaka]")
          |> mes("Now, you need to visit a")
          |> mes("man named ^3355FFWon^000000 in Comodo")
          |> mes("in order to get the proof that")
          |> mes("shows that you're qualified to")
          |> mes("possess a doomed sword.")
          |> mes("Hopefully, you'll get it...")

        _ ->
          ctx
          |> mes("[Zaka]")
          |> mes("Have you heard that swords")
          |> mes("with the power to change the")
          |> mes("world actually exist? It's true")
          |> mes("that three swords contain this")
          |> mes("immense power, but they are")
          |> mes("also bound to powerful curses.")
          |> next()
          |> mes("[Zaka]")
          |> mes("Therefore, the Mysteltainn,")
          |> mes("Ogretooth, and Executioner")
          |> mes("have all been sealed away.")
          |> mes("Only a truly great adventurer")
          |> mes("can release these doomed swords and actually wield them...")
      end

    close(ctx)
  end
end
