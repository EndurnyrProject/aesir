defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Muff do
  @moduledoc """
  Helps Muff recover his lost bond of debt.

  ## Behavior

  - Guides players through the debt recovery quest and rewards their help.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "comodo", x: 224, y: 187, dir: 3, sprite: 86, name: "Muff", scope: :shared}]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{907, 200}]) == 0 ->
        ctx
        |> mes("[Muff]")
        |> mes("You're carrying way too")
        |> mes("much stuff right now.")
        |> mes("Come back after you put")
        |> mes("your stuff in Kafra Storage.")
        |> close()

      get_char_var(ctx, :diamond_edq, 0) == 0 ->
        {ctx, choice} =
          ctx
          |> mes("[Muff]")
          |> mes("What th-?! Geez,")
          |> mes("you didn't have to")
          |> mes("scare me like that!")
          |> mes("What is it that you want?")
          |> next()
          |> select(["You look troubled.", "Nothing. Take care!"])

        case choice do
          1 ->
            if base_level(ctx) < 61 do
              ctx
              |> mes("[Muff]")
              |> mes("Oh. That's awfully")
              |> mes("thoughtful of you.")
              |> mes("I was thinking about")
              |> mes("asking you for help,")
              |> mes("but you don't look like")
              |> mes("you could handle it. Sorry.")
              |> set_char_var(:diamond_edq, 3)
              |> close()
            else
              {ctx, choice} =
                describe_debt(ctx)
                |> select(["Do you know where you lost it?", "I'm sorry to hear that. Bye!"])

              case choice do
                1 ->
                  ctx
                  |> mes("[Muff]")
                  |> mes("If I knew where I lost")
                  |> mes("it, then it wouldn't be")
                  |> mes("lost now, would it? Well,")
                  |> mes("I remember going to a union")
                  |> mes("meeting, and I had a drink")
                  |> mes("or two. Okay, I had a lot.")
                  |> next()
                  |> mes("[Muff]")
                  |> mes("On the way home,")
                  |> mes("I stumbled in a field")
                  |> mes("near Comodo... I remember")
                  |> mes("seeing some water... That")
                  |> mes("must be where I dropped my")
                  |> mes("wallet with the bond of debt.")
                  |> next()
                  |> mes("[Muff]")
                  |> mes("If you can find my")
                  |> mes("wallet, I'll make sure")
                  |> mes("to repay you. Please")
                  |> mes("help me if you can!")
                  |> setquest(3100)
                  |> set_char_var(:diamond_edq, 1)
                  |> close()

                2 ->
                  ctx
                  |> mes("[Muff]")
                  |> mes("H-hey! Where are you")
                  |> mes("going?! You can't just")
                  |> mes("leave me here! I need help!")
                  |> close()

                _ ->
                  ctx
              end
            end

          2 ->
            {ctx, choice} =
              ctx
              |> mes("[Muff]")
              |> mes("What, are you trying to")
              |> mes("make me mad on purpose?")
              |> mes("I get it. You're working for")
              |> mes("Belder! I'm gonna get")
              |> mes("my treasure from that")
              |> mes("bastard, no matter what!")
              |> next()
              |> select(["I don't understand.", "I'm sorry, I was just kidding..."])

            case choice do
              1 ->
                ctx
                |> mes("[Muff]")
                |> mes("You think you can")
                |> mes("fool me?! Get lost!")
                |> mes("I'm not telling you")
                |> mes("anything, you snake!")
                |> close()

              2 ->
                ctx
                |> mes("[Muff]")
                |> mes("So you're not spying on")
                |> mes("me for Belder? Well, then")
                |> mes("why are you pestering me?")
                |> close()

              _ ->
                ctx
            end

          _ ->
            ctx
        end

      get_char_var(ctx, :diamond_edq, 0) == 3 and base_level(ctx) < 61 ->
        ctx
        |> mes("[Muff]")
        |> mes("Wait a second...")
        |> mes("You're not as strong")
        |> mes("as you were earlier.")
        |> mes("You'd better train first")
        |> mes("so you can be better")
        |> mes("prepared to help me.")
        |> close()

      get_char_var(ctx, :diamond_edq, 0) == 3 and base_level(ctx) > 60 ->
        {ctx, choice} =
          describe_debt(ctx)
          |> select(["Do you know where you lost it?", "What was the collateral?", "Bye!"])

        case choice do
          1 ->
            ctx
            |> mes("[Muff]")
            |> mes("If I knew where I lost")
            |> mes("it, then it wouldn't be")
            |> mes("lost now, would it? Well,")
            |> mes("I remember going to a union")
            |> mes("meeting, and I had a drink")
            |> mes("or two. Okay, I had a lot.")
            |> next()
            |> mes("[Muff]")
            |> mes("I took this path in the")
            |> mes("Papuchicha Forest to head")
            |> mes("back home, and I must have")
            |> mes("passed out near a river.")
            |> mes("After that, my wallet with the")
            |> mes("bond of debt was missing.")
            |> next()
            |> mes("[Muff]")
            |> mes("I don't care about the")
            |> mes("other stuff in my wallet,")
            |> mes("but I really need my bond")
            |> mes("of debt to get my collateral")
            |> mes("back from that Belder.")
            |> setquest(3100)
            |> set_char_var(:diamond_edq, 1)
            |> close()

          2 ->
            ctx
            |> mes("[Muff]")
            |> mes("Well, the collateral was")
            |> mes("this huge, stunningly")
            |> mes("beautiful jewel. It's really")
            |> mes("precious to me. But well,")
            |> mes("I don't want to tell you")
            |> mes("more about it.")
            |> next()
            |> mes("[Muff]")
            |> mes("I understand if you don't")
            |> mes("want to help me after")
            |> mes("hearing that, but if you")
            |> mes("change your mind, please")
            |> mes("come talk to me again.")
            |> close()

          3 ->
            ctx
            |> mes("[Muff]")
            |> mes("H-hey! Where are you")
            |> mes("going?! You can't just")
            |> mes("leave me here! I need help!")
            |> close()

          _ ->
            ctx
        end

      get_char_var(ctx, :diamond_edq, 0) == 1 or get_char_var(ctx, :diamond_edq, 0) == 2 ->
        ctx
        |> mes("[Muff]")
        |> mes("You didn't leave to")
        |> mes("look for my wallet yet?")
        |> mes("I think it's somewhere")
        |> mes("in the Papuchicha Forest.")
        |> mes("Please find the bond of debt")
        |> mes("inside as soon as you can.")
        |> close()

      get_char_var(ctx, :diamond_edq, 0) == 4 ->
        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Is this wet, tattered")
          |> mes("piece of paper the bond")
          |> mes("of debt that you need?")
          |> next()
          |> mes("[Muff]")
          |> mes("Yes, that's it!")
          |> mes("Ugh, but look at it...")
          |> mes("It's ruined! You can't")
          |> mes("even read what's written")
          |> mes("on it! I need... I need")
          |> mes("to fix this somehow!")
          |> next()

        {ctx, choice} =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Do you have any ideas?")
          |> mes("I mean, if we dried the")
          |> mes("paper, the letters would")
          |> mes("still be faded, right?")
          |> next()
          |> mes("[Muff]")
          |> mes("I got it! There's this")
          |> mes("famous inventor named")
          |> mes("^FF0000Dorian^000000 in Izlude. I heard")
          |> mes("he just invented something")
          |> mes("like a Magic Dryer. Yeah,")
          |> mes("that should work perfectly!")
          |> next()
          |> mes("[Muff]")
          |> mes("I don't know exactly")
          |> mes("how it works, but it")
          |> mes("should be able to restore")
          |> mes("my bond of debt. I mean...")
          |> mes("It's magic, right? Will you")
          |> mes("ask Dorian to help me out?")
          |> next()
          |> select(["Accept His Request", "Decline His Request"])

        case choice do
          1 ->
            ctx
            |> mes("[Muff]")
            |> mes("Thank you so much!")
            |> mes("Please talk to Inventor")
            |> mes("Dorian in Izlude, and ask")
            |> mes("him to restore my bond of")
            |> mes("debt. I'll be waiting for")
            |> mes("you right here, okay?")
            |> changequest(3102, 3103)
            |> set_char_var(:diamond_edq, 6)
            |> close()

          2 ->
            ctx
            |> mes("[Muff]")
            |> mes("Really? I was hoping")
            |> mes("that you'd continue to")
            |> mes("help me, but... Alright.")
            |> mes("I'm sure you've got other")
            |> mes("problems. If you change your")
            |> mes("mind, though, just come back.")
            |> set_char_var(:diamond_edq, 5)
            |> close()

          _ ->
            ctx
        end

      get_char_var(ctx, :diamond_edq, 0) == 5 ->
        {ctx, choice} =
          ctx
          |> mes("[Muff]")
          |> mes("Oh, I knew you'd come")
          |> mes("back and help me restore")
          |> mes("my bond of debt! You look")
          |> mes("too nice to just leave")
          |> mes("me hanging like that.")
          |> next()
          |> select(["Accept His Request", "Decline His Request"])

        case choice do
          1 ->
            ctx
            |> mes("[Muff]")
            |> mes("Thank you so much!")
            |> mes("Please talk to Inventor")
            |> mes("Dorian in Izlude, and ask")
            |> mes("him to restore my bond of")
            |> mes("debt. I'll be waiting for")
            |> mes("you right here, okay?")
            |> changequest(3102, 3103)
            |> set_char_var(:diamond_edq, 6)
            |> close()

          2 ->
            ctx
            |> mes("[Muff]")
            |> mes("Really? I was hoping")
            |> mes("that you'd continue to")
            |> mes("help me, but... Alright.")
            |> mes("I'm sure you've got other")
            |> mes("problems. If you change your")
            |> mes("mind, though, just come back.")
            |> close()

          _ ->
            ctx
        end

      get_char_var(ctx, :diamond_edq, 0) > 5 and get_char_var(ctx, :diamond_edq, 0) < 13 ->
        ctx
        |> mes("[Muff]")
        |> mes("Would you please visit")
        |> mes("^FF0000Inventor Dorian^000000 in Izlude,")
        |> mes("and ask him to use his")
        |> mes("Magic Dryer to restore")
        |> mes("my bond of debt?")
        |> close()

      get_char_var(ctx, :diamond_edq, 0) == 13 and count_item(ctx, 7722) > 0 ->
        ctx
        |> mes("[Muff]")
        |> mes("You're back! So how")
        |> mes("did it go? I was getting")
        |> mes("pretty anxious... So did")
        |> mes("Dorian's Magic Dryer work?")
        |> next()
        |> delitem(7722, 1)
        |> mes("[Muff]")
        |> mes("Oh! It worked much better")
        |> mes("than I expected! Belder")
        |> mes("can't complain now! Haha!")
        |> mes("You've done well, my friend.")
        |> mes("Here, please take these as")
        |> mes("a meager reward for your help.")
        |> completequest(3109)
        |> set_char_var(:diamond_edq, 14)
        |> give_item(603, 1)
        |> give_item(608, 4)
        |> next()
        |> mes("[Muff]")
        |> mes("Now that I have my bond")
        |> mes("of debt, I should get my")
        |> mes("jewel back from Belder.")
        |> mes("He won't have any excuse")
        |> mes("to keep my treasure now!")
        |> close()

      get_char_var(ctx, :diamond_edq, 0) == 13 and count_item(ctx, 7722) < 1 ->
        ctx
        |> mes("[Muff]")
        |> mes("H-hey! Where's my")
        |> mes("bond of debt?! Don't")
        |> mes("tell me you lost it!")
        |> mes("You'd better go back")
        |> mes("to Dorian... Hopefully")
        |> mes("you left it with him!")
        |> set_char_var(:diamond_edq, 10)
        |> close()

      get_char_var(ctx, :diamond_edq, 0) > 13 ->
        ctx
        |> mes("[Muff]")
        |> mes("Yes! Finally, I'm")
        |> mes("free of debt! I've got")
        |> mes("my jewel back, business")
        |> mes("is doing well... Life sure")
        |> mes("is good right now. Hahaha!")
        |> close()

      true ->
        ctx
        |> mes("[Muff]")
        |> mes("Listen to me: never")
        |> mes("take out a loan if you")
        |> mes("can help it. And if you do,")
        |> mes("borrow from someone")
        |> mes("more reputable than...")
        |> mes("Well, you know my story.")
        |> mes("*Sigh*")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp describe_debt(ctx) do
    ctx
    |> mes("[Muff]")
    |> mes("Well, I'm actually in")
    |> mes("pretty big trouble.")
    |> mes("I borrowed some money")
    |> mes("from this loan shark")
    |> mes("named ^0000FFBelder^000000 in Alberta.")
    |> mes("It was a bad move!")
    |> next()
    |> mes("[Muff]")
    |> mes("My business hasn't been")
    |> mes("good, but I felt like I didn't")
    |> mes("have a choice. I made enough")
    |> mes("money to repay him now, but")
    |> mes("then I lost my bond of debt.")
    |> next()
    |> mes("[Muff]")
    |> mes("When I asked Belder if")
    |> mes("I could pay him back without")
    |> mes("that bond, he insisted that")
    |> mes("he didn't remember loaning")
    |> mes("money to me. I bet he just")
    |> mes("wants to keep my collateral!")
    |> next()
    |> mes("[Muff]")
    |> mes("I knew that guy was shady!")
    |> mes("Would you help me find my")
    |> mes("lost bond of debt? You see,")
    |> mes("the collateral I gave him")
    |> mes("is really valuable to me.")
    |> next()
  end
end
