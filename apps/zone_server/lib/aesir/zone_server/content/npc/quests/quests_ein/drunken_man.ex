defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.DrunkenMan do
  @moduledoc """
  A drunken gambler knows secrets about Ymir's Heart.

  ## Behavior

  - Gambles with the player's apples and can advance the murder quest after winning.

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
        map: "airplane",
        x: 31,
        y: 77,
        dir: 5,
        sprite: 853,
        name: "Drunken Man",
        scope: :shared,
        unique_name: "Drunken Man#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :Shinokas_Quest, 0) do
      8 ->
        play_game(ctx)

      9 ->
        ctx
        |> mes("[Drunken Man]")
        |> mes("Hahahaha!")
        |> mes("You're great!")
        |> mes("I feel great!")
        |> mes("Everything's great!")
        |> mes("Bwahahahaahahah!")
        |> mes("^333333*Hiccup*^000000")
        |> close()

      _ ->
        ctx =
          ctx
          |> mes("[Drunken Man]")
          |> mes("Okay okay...")
          |> mes("Daddy's gonna")
          |> mes("win some Apples")
          |> mes("this time for sure!")
          |> next()
          |> mes("[Drunken Man]")
          |> mes("Let's do it!")
          |> mes("^3131FFYmir's Heart^000000 is")
          |> mes("on my side! GO!")
          |> emotion(:go)
          |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Huh...?")
        |> mes("What did he just say?")
        |> mes("It seemed important!")
        |> next()
        |> mes("^3355FF*Rolling and rumbling*^000000")
        |> next()
        |> emotion(:chup)
        |> mes("[Kaci]")
        |> mes("I have a total of ^FF00003^000000")
        |> mes("and you have total ^FF00002^000000.")
        |> mes("You lose this game. I'm")
        |> mes("sorry, but I hope we play")
        |> mes("again sometime.")
        |> next()
        |> mes("[Drunken Man]")
        |> mes("Waaaaaahhhhhhhhh!")
        |> mes("Apples! My apples!")
        |> close()
    end
  end

  defp play_game(ctx) do
    ctx =
      ctx
      |> mes("[Drunken Man]")
      |> mes("Okay okay...")
      |> mes("Daddy's gonna")
      |> mes("win some Apples")
      |> mes("this time for sure!")
      |> next()
      |> mes("[Drunken Man]")
      |> mes("Let's do it!")
      |> mes("^3131FFYmir's Heart^000000 is")
      |> mes("on my side! GO!")
      |> emotion(:go)
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Huh...?")
      |> mes("What did he just say?")
      |> mes("It seemed important!")
      |> next()
      |> mes("^3355FF*Rolling and rumbling*^000000")
      |> next()
      |> emotion(:chup)
      |> mes("[Kaci]")
      |> mes("I have a total of ^FF000011^000000")
      |> mes("and you have total ^FF00005^000000.")
      |> mes("You lose this game. I'm")
      |> mes("sorry, but I hope we play")
      |> mes("again sometime.")
      |> next()
      |> mes("[Drunken Man]")
      |> mes("Waaaaaahhhhhhhhh!")
      |> mes("Apples! My apples!")
      |> mes("Apples, I need more...!")

    cond do
      count_item(ctx, 512) < 11 ->
        close(ctx)

      count_item(ctx, 512) > 10 and count_item(ctx, 512) < 100 ->
        ctx = next(ctx)

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Do you want")
        |> mes("some of mine?")
        |> next()
        |> mes("[Drunken Man]")
        |> mes("What...?")
        |> mes("I can't do anything")
        |> mes("with so few Apples!")
        |> mes("I'm a high roller and")
        |> mes("this is a high stakes game!")
        |> close()

      true ->
        gamble(ctx)
    end
  end

  defp gamble(ctx) do
    ctx = ctx |> delitem(512, count_item(ctx, 512)) |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Do you want")
      |> mes("some of mine?")
      |> next()
      |> mes("[Drunken Man]")
      |> mes("Wha--? Yes...")
      |> mes("Hell yes! Gimme")
      |> mes("some of your Apples!")
      |> mes("Yeeeeeeeeeeehaw!")
      |> mes("I'm back, baby!")
      |> next()
      |> mes("[Drunken Man]")
      |> mes("Now, to win!")
      |> mes("Daddy needs love...")
      |> mes("Time to go from")
      |> mes("crappy to classy!")
      |> next()
      |> mes("^3355FF*Rolling and rumbling*^000000")
      |> next()

    if Enum.random(1..10) > 7 do
      ctx =
        ctx
        |> emotion(:chup)
        |> mes("[Kaci]")
        |> mes("I got a total of ^FF00008^000000,")
        |> mes("and you have total ^FF000011^000000.")
        |> mes("Congratulations, you won!")
        |> mes("Let me give you your winnings")
        |> mes("and we'll play again some time~")
        |> next()

      discuss_heart(ctx)
    else
      ctx
      |> emotion(:huk)
      |> mes("[Kaci]")
      |> mes("Oooh...")
      |> mes("I got a total of ^FF000010^000000,")
      |> mes("and you have a total of ^FF00007^000000.")
      |> mes("I'm sorry, but you lose")
      |> mes("again. Better luck next time...")
      |> next()
      |> mes("[Drunken Man]")
      |> mes("Waaaaahhhhhhhhhh!")
      |> mes("Waaaaaaahhhhhhh!")
      |> close()
    end
  end

  defp discuss_heart(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Drunken Man]")
      |> mes("Mwahhahahahaha!")
      |> mes("Whahahahahahahaha!")
      |> mes("That's why they call me")
      |> mes("the ''Resurrection Kid!''")
      |> mes("I always come back!")
      |> next()
      |> mes("[Drunken Man]")
      |> mes("Oh yes, right!")
      |> mes("You...! You lent")
      |> mes("me those lucky")
      |> mes("Apples. ^333333*Hiccup*^000000")
      |> next()
      |> mes("[Drunken Man]")
      |> mes("I'm Kurshenburg!")
      |> mes("Thanks to you, I'm")
      |> mes("on a winning streak!")
      |> mes("Hahaha! Th-thank you~")
      |> mes("^333333*Hic-hic-hiccup!*^000000")
      |> next()
      |> select(["So what was that about Ymir's Heart?", "Hehe, you're welcome."])

    case choice do
      1 ->
        ctx =
          ctx
          |> mes("[Drunken Man]")
          |> mes("What...?")
          |> mes("Ymir's Heart?")
          |> mes("How do you know")
          |> mes("about that? ^333333*Hiccup*^000000")
          |> next()

        {ctx, _} =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Y-you...!")
          |> mes("You were just yelling,")
          |> mes("''Ymir's Heart is on my")
          |> mes("side,'' while you were")
          |> mes("gambling with those Apples!")
          |> next()
          |> mes("[Drunken Man]")
          |> mes("What...?!")
          |> mes("No way~")
          |> mes("Err...? Did I...?")
          |> next()
          |> mes("[Drunken Man]")
          |> mes("Heh heh...")
          |> mes("I'm not really")
          |> mes("supposed to be talking")
          |> mes("about this. As head of")
          |> mes("the Laboratory, I'm sworn")
          |> mes("to secrecy about Ymir's Heart.")
          |> next()
          |> mes("[Drunken Man]")
          |> mes("But what do I care?!")
          |> mes("All they want are the")
          |> mes("results of my research!")
          |> mes("They don't appreciate")
          |> mes("my work at all! My title")
          |> mes("is completely worthless!")
          |> next()
          |> mes("[Drunken Man]")
          |> mes("You don't know how long I've")
          |> mes("been imprisoned in the lab and")
          |> mes(
            "that the work conditions just get worse and worse. Screw them! I'll keep getting paid as long as I show them some progress in our project!"
          )
          |> next()
          |> select(["Project?"])

        ctx =
          ctx
          |> next()
          |> mes("[Drunken Man]")
          |> mes("Yeah, we're researching")
          |> mes("Ymir's Heart. It was found")
          |> mes("a long time ago in ^3131FFEinbech^000000")
          |> mes("and it's in our lab now.")
          |> next()
          |> mes("[Drunken Man]")
          |> mes("Everyone knows it's supposed")
          |> mes("to hold some legendary power,")
          |> mes("but even I was surprised to see")
          |> mes("what it was capable of. It's both terrible and miraculous, scary")
          |> mes("and wondrous...")
          |> next()
          |> mes("[Drunken Man]")
          |> mes("So...")
          |> mes("I figure...")
          |> mes("It may even")
          |> mes("have the power to")
          |> mes("win me Dice games!")
          |> mes("Bwahaha--^333333*Hiccup!*^000000")
          |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("^333333(That thing I saw")
        |> mes("hooked up to all those")
        |> mes("wires in the Laboratory")
        |> mes("must have been a piece")
        |> mes("of ^3131FFYmir's Heart^333333. I better")
        |> mes("tell Shinokas about this.)^000000")
        |> changequest(2076, 2077)
        |> set_char_var(:Shinokas_Quest, 9)
        |> close()

      2 ->
        ctx
        |> mes("[Drunken Man]")
        |> mes("Hahahaha!")
        |> mes("You're great!")
        |> mes("And I feel great!")
        |> mes("Everything's great!")
        |> mes("Bwahahahaahahah!")
        |> mes("^333333*Hiccup*^000000")
        |> close()

      _ ->
        ctx
    end
  end
end
