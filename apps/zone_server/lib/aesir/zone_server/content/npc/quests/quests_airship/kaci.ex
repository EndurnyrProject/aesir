defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAirship.Kaci do
  @moduledoc """
  Kaci hosts dice games and helps with airship quests.

  ## Behavior

  - Shares information about Thierry and the laboratory as quests progress.
  - Discusses Hallen, Mawong, and the airship after receiving a letter.

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
    spawn: [%{map: "airplane", x: 33, y: 69, dir: 4, sprite: 73, name: "Kaci", scope: :shared}]

  alias Aesir.ZoneServer.Content.Npc.Functions.Applegamble
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    ctx = mes(ctx, "[Kaci]")
    ticket = get_char_var(ctx, :hg_ma1, 0)

    result =
      cond do
        ticket == 3 ->
          {:ok, discuss_thierry(ctx)}

        ticket == 4 ->
          {:ok,
           mes(
             ctx,
             "The airship captain might be able to help you in finding Thierry's whereabouts."
           )}

        true ->
          heart_quest(ctx, get_char_var(ctx, :lhz_heart, 0))
      end

    case result do
      {:ok, ctx} -> close(ctx)
      {:stop, ctx} -> ctx
    end
  end

  defp heart_quest(ctx, 2), do: {:ok, deliver_letter(ctx)}
  defp heart_quest(ctx, 3), do: discuss_people(ctx)
  defp heart_quest(ctx, 8), do: {:ok, discuss_laboratory(ctx)}

  defp heart_quest(ctx, _) do
    {ctx, _} =
      ctx
      |> mes("You must be sooo")
      |> mes("bored, adventurer~")
      |> mes("How would you like")
      |> mes("to play a game of Dice?")
      |> next()
      |> Applegamble.call(["Kaci"])

    {:ok, ctx}
  end

  defp discuss_thierry(ctx) do
    {ctx, _} =
      ctx
      |> mes("You must be sooo")
      |> mes("bored, adventurer~")
      |> mes("How would you like")
      |> mes("to play a game of Dice?")
      |> next()
      |> select(["Do you know a guy named Thierry?"])

    ctx
    |> mes("[Kaci]")
    |> mes("Thierry? Um...that sounds familiar...")
    |> next()
    |> mes("[Kaci]")
    |> mes("....................")
    |> mes(".............")
    |> mes(".......")
    |> mes("...")
    |> next()
    |> mes("[Kaci]")
    |> mes("Oh, right! Thierry, Thierry, Thierry! Right?")
    |> next()
    |> mes("[Kaci]")
    |> mes("- She suddenly called out the name several times,  -")
    |> mes("- so you were startled and dropped your half eaten apple. -")
    |> next()
    |> mes("[Kaci]")
    |> mes(
      "Oops, sorry, if I startled you. I could not remember the name because it has been a while since I heard of his name the last time."
    )
    |> next()
    |> mes("[Kaci]")
    |> mes(
      "Thierry was a guy living in the next door while I was learning games and tricks from Mr. Mawong."
    )
    |> mes("I remember that he was a very smart guy and was doing many research stuffs.")
    |> next()
    |> mes("[Kaci]")
    |> mes("Oh yeah, and he was in love with Eukran's sister.")
    |> mes("And Eukran and I were studying games together under Mr. Mawong at that time.")
    |> mes("Hmm...I wonder how they have been doing.")
    |> next()
    |> mes(
      "- You told her that Euslan and Thierry got engaged, but Thierry had to leave her to find medicine for her illness. -"
    )
    |> next()
    |> mes("[Kaci]")
    |> mes("Oh...gosh...I can't believe that Euslan is has become ill....Oh......")
    |> next()
    |> mes("- Kaci seemed to be shocked by such devastating news. -")
    |> mes("- She was mumbling something for a while, and then came back to her senses again. -")
    |> next()
    |> mes("[Kaci]")
    |> mes(
      "I am so sorry for her...I really want to give here some help...but, it has been a while for me since I saw them. So, I don't know where he is."
    )
    |> next()
    |> mes("[Kaci]")
    |> mes("But, let me think if...")
    |> next()
    |> mes("[Kaci]")
    |> mes(
      "Oh, right! The airship captain might be able to help you, because he is the one who is in charge of the passenger list."
    )
    |> next()
    |> mes("[Kaci]")
    |> mes(
      "Although the passenger list is classified and strictly restricted from releasing to public..."
    )
    |> next()
    |> mes("[Kaci]")
    |> mes(
      "But, if you tell him the story, he might be able to help you. Please go ask him if you can."
    )
    |> next()
    |> mes("[Kaci]")
    |> mes("And if you see Euslan again, please send my regard and blessing to her.")
    |> next()
    |> mes("- You promised her to send her regards and blessings to Euslan. -")
    |> changequest(8044, 8045)
    |> set_char_var(:hg_ma1, 4)
  end

  defp deliver_letter(ctx) do
    {ctx, _} =
      ctx
      |> mes("You must be sooo")
      |> mes("bored, adventurer~")
      |> mes("How would you like")
      |> mes("to play a game of Dice?")
      |> next()
      |> select(["Give her the letter from Hallen."])

    ctx
    |> mes("[Kaci]")
    |> mes("Oh, Hallen must have")
    |> mes("asked you to deliver this.")
    |> mes("He should be doing this sort")
    |> mes("of thing himself, instead of")
    |> mes("asking customers for favors!")
    |> mes("But still, he's really busy...")
    |> next()
    |> changequest(8036, 8037)
    |> set_char_var(:lhz_heart, 3)
    |> mes("[Kaci]")
    |> mes("Thank you for bringing")
    |> mes("this to me. If you ever")
    |> mes("need a little favor from")
    |> mes("me, feel free to ask me,")
    |> mes("alright? See you later~")
  end

  defp discuss_people(ctx) do
    ctx =
      ctx
      |> mes("Oh, hello. Thanks for")
      |> mes("delivering that letter from")
      |> mes("Mr. Mawong to me, especially")
      |> mes("since Hallen was too busy to")
      |> mes("do it himself. Reading that")
      |> mes("letter really made my day~")
      |> next()

    case ask_about_people(ctx) do
      {:stop, ctx} ->
        {:stop, ctx}

      {:ok, ctx} ->
        ctx
        |> mes("[Kaci]")
        |> mes("By the way, if Hallen")
        |> mes("bothers you with another")
        |> mes("request, please refuse to")
        |> mes("help him next time, okay?")
        |> mes("I won't allow him to get")
        |> mes("spoiled! Ho ho ho ho~")
        |> next()
        |> mes("[Kaci]")
        |> mes("Well, I better get")
        |> mes("back to work now.")
        |> mes("Have a nice day,")
        |> mes("and I'll see you later~")
        |> changequest(8037, 8038)
        |> set_char_var(:lhz_heart, 4)
        |> then(&{:ok, &1})
    end
  end

  defp discuss_laboratory(ctx) do
    {ctx, _} =
      ctx
      |> mes("Hello, #{char_name(ctx, 0)}.")
      |> mes("It's nice to see you again.")
      |> mes("So is there anything I can")
      |> mes("help you with today?")
      |> next()
      |> select(["Who's that drunk over there?"])

    ctx =
      ctx
      |> mes("[Kaci]")
      |> mes("Oh, him? He's one of my")
      |> mes("regulars, some guy who's")
      |> mes("supposed to be an Einbroch")
      |> mes("Lab Director. He keeps losing")
      |> mes("Apples whenever he plays Dice:")
      |> mes("I think he's a gambling addict~")
      |> next()
      |> mes("[Kaci]")
      |> mes("In fact, his losses make up")
      |> mes("for all the Apples I lost when")
      |> mes("that Apple Merchant played here. Now, it's a legendary tale that")
      |> mes("we all think fondly of, but at")
      |> mes("the time, it nearly broke me.")
      |> next()
      |> mes("[Kaci]")
      |> mes("Anyway, aside from the fact")
      |> mes("that the Einbroch Lab Director")
      |> mes("is kind of a whiny person when")
      |> mes("he's drunk, and a poor gambler,")
      |> mes("I don't know much about him.")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("(^333333Einbroch Laboratory...")
      |> mes("It's so suspicious. That")
      |> mes("director knows about Ymir's")
      |> mes("Heart Piece, so they must be")
      |> mes("keeping something really")
      |> mes("important over there.^000000)")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("(^333333I better investigate")
    |> mes("that laboratory in Einbroch")
    |> mes("as soon as I can, even if it's")
    |> mes("a heavily restricted area.^000000)")
    |> changequest(8041, 8042)
    |> set_char_var(:lhz_heart, 9)
  end

  defp ask_about_people(ctx) do
    if get_local(ctx, :a, 0) == 0 or get_local(ctx, :b, 0) == 0 or get_local(ctx, :c, 0) == 0 do
      ctx =
        if Rathena.truthy?(get_local(ctx, :a, 0)) or Rathena.truthy?(get_local(ctx, :b, 0)) or
             Rathena.truthy?(get_local(ctx, :c, 0)) do
          ctx
          |> mes("[Kaci]")
          |> mes("Please don't hesitate")
          |> mes("to ask me anything if")
          |> mes("you need a small favor,")
          |> mes("or if you're just curious")
          |> mes("about me in general~")
          |> next()
        else
          ctx
        end

      {ctx, topic} =
        select(ctx, ["Ask about Hallen", "Ask about Mawong", "Ask about the Airship"])

      ctx =
        case topic do
          1 ->
            ctx
            |> set_local(:a, 1)
            |> mes("[Kaci]")
            |> mes("Hallen? Well, he and I are")
            |> mes("pretty close. Did you know")
            |> mes("that we're cousins? In fact,")
            |> mes("his dad, my uncle, brought")
            |> mes("me as a child after my father")
            |> mes("passed away 20 years ago.")
            |> next()
            |> mes("[Kaci]")
            |> mes("There was some kind of")
            |> mes("mine explosion accident in")
            |> mes("Einbech. I don't remember.")
            |> mes("Anyway, me and Hallen are")
            |> mes("like sister and brother, and")
            |> mes("we always stick together.")
            |> next()
            |> mes("[Kaci]")
            |> mes("When Captain Ferlock saw me")
            |> mes("host a Dice game by coincidence")
            |> mes("and then hired me to work on his Airship, Hallen insisted on coming")
            |> mes("along. He's stubborn like that,")
            |> mes("but he's also very sweet.")

          2 ->
            ctx
            |> set_local(:b, 1)
            |> mes("[Kaci]")
            |> mes("Mr. Mawong? Oh, don't get")
            |> mes("the wrong idea! He's my")
            |> mes("mentor, the one who taught")
            |> mes("me how to play all of these")
            |> mes("wonderful games. He's pretty")
            |> mes("famous around Juno, you know.")
            |> next()
            |> mes("[Kaci]")
            |> mes("I used to be so depressed,")
            |> mes("not caring about the world")
            |> mes("at all, after my father died.")
            |> mes("Then, I ran into Mr. Mawong,")
            |> mes("and he taught me how to find")
            |> mes("the joy in life once again.")
            |> next()
            |> mes("[Kaci]")
            |> mes("Because of him, I decided")
            |> mes("to learn his games and to")
            |> mes("help people forget their")
            |> mes("worries and just enjoy")
            |> mes("themselves, even if it's")
            |> mes("just for a little while.")

          3 ->
            ctx =
              ctx
              |> set_local(:c, 1)
              |> mes("[Kaci]")
              |> mes("The Airship? It's so")
              |> mes("huge and beautiful, and")
              |> mes("I'm always amazed that it")
              |> mes("can fly so gracefully through")
              |> mes("the air. I've always wanted to live someplace close to the sky...")
              |> next()
              |> mes("[Kaci]")
              |> mes("A place where I can see")
              |> mes("the clouds and bask in the")
              |> mes("sun. So, when Captain Ferlock")
              |> mes("invited me to work here, it was")
              |> mes("like a dream come true~")

            ctx

          _ ->
            {:stop, ctx}
        end

      case ctx do
        {:stop, ctx} -> {:stop, ctx}
        ctx -> ctx |> next() |> ask_about_people()
      end
    else
      {:ok, ctx}
    end
  end
end
