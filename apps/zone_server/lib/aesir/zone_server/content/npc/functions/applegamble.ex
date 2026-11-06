defmodule Aesir.ZoneServer.Content.Npc.Functions.Applegamble do
  @moduledoc """
  Plays the airship apple dice game.

  ## Behavior

  The staff member explains the rules, or takes a wager of up to 50 Apples and plays two rounds of
  dice against the player. Both sides roll two dice, the player may draw a third and then the house
  answers with one of its own. A total above 12 busts, the higher total wins twice the wager and a
  tie returns it. The player may also decline the third die, which closes the round with the
  outcome the current totals already imply.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script airports/airships.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Script.Ctx

  @apple 512
  @max_bet 50
  @bust 12
  @risky_house_total 8
  @high_player_roll 9
  @high_stake 39

  @doc """
  Callable rAthena global function `applegamble(npc_name)`; throws `{:script_end, ctx}` once the
  game is over.
  """
  @spec call(Ctx.t(), [term()]) :: no_return()
  def call(ctx, args) do
    npc = Enum.at(args, 0, 0)

    {ctx, choice} = select(ctx, ["Play Dice Game", "Learn Dice Game Rules", "Cancel"])

    case choice do
      3 -> halt(cancelled(ctx, npc))
      2 -> halt(rules(ctx, npc))
      _play -> play(ctx, npc)
    end
  end

  defp cancelled(ctx, npc) do
    ctx
    |> mes(name_page(npc))
    |> mes("I'm up for a game of")
    |> mes("dice whenever you feel")
    |> mes("like it. Just talk to me if")
    |> mes("you ever get hit with the")
    |> mes("sudden urge to gamble, kay?")
    |> close()
  end

  defp rules(ctx, npc) do
    ctx
    |> mes(name_page(npc))
    |> mes("The rules for the Dice game")
    |> mes("are pretty simple. First, you")
    |> mes("place a bet by wagering Apples.")
    |> mes("You can bet a maximum of 50")
    |> mes("Apples at a time. To keep things")
    |> mes("legal, I can only accept Apples.")
    |> next()
    |> mes(name_page(npc))
    |> mes("But hey, if all that zeny")
    |> mes("is burning a hole in your")
    |> mes("pocket, head over to Fruitz")
    |> mes("and you can buy as many")
    |> mes("Apples as you want, playah~")
    |> next()
    |> mes(name_page(npc))
    |> mes("Now, we begin with me")
    |> mes("rolling two 6-sided dice.")
    |> mes("When it's your turn, you'll")
    |> mes("roll two 6-sided dice. After")
    |> mes("that, both of us will have the")
    |> mes("option of rolling a third die.")
    |> next()
    |> mes(name_page(npc))
    |> mes("Now here's the important")
    |> mes("thing. If your total is higher")
    |> mes("than 12, you'll bust, meaning")
    |> mes("that you lose. Otherwise, the")
    |> mes("person with the higher total")
    |> mes("is the winner. Got it?")
    |> next()
    |> mes(name_page(npc))
    |> mes("Now, you'll be the first")
    |> mes("to decide whether or not")
    |> mes("you'll roll the third die. Then,")
    |> mes("depending on your result, I'll")
    |> mes("roll my third die... Or maybe not.")
    |> next()
    |> mes(name_page(npc))
    |> mes("When you win, you'll")
    |> mes("receive twice as many")
    |> mes("Apples as you wagered.")
    |> mes("But if we happen to tie, you")
    |> mes("get the Apples that you bet")
    |> mes("returned to you. Fair, right?")
    |> close()
  end

  @spec play(Ctx.t(), term()) :: no_return()
  defp play(ctx, npc) do
    ctx =
      ctx
      |> mes(name_page(npc))
      |> mes("Ooh, so you'll play with")
      |> mes("me? Great! How many")
      |> mes("Apples would you like to bet?")
      |> mes("Remember, you can wager")
      |> mes("up to 50 Apples. If you'd like")
      |> mes("to cancel, please enter '0'.")
      |> next()

    {ctx, wager} = ask_wager(ctx, npc)
    play_round(ctx, npc, wager)
  end

  defp ask_wager(ctx, npc) do
    {ctx, wager} = input(ctx, :int)

    cond do
      wager == 0 ->
        halt(
          ctx
          |> mes(name_page(npc))
          |> mes("Changed your mind?")
          |> mes("I understand. Well then,")
          |> mes("I hope we can play sometime.")
          |> close()
        )

      wager < 1 or wager > @max_bet ->
        ask_wager(
          ctx
          |> mes(name_page(npc))
          |> mes("You can't bet more than")
          |> mes("50 Apples. Remember, we")
          |> mes("need to keep these stakes")
          |> mes("reasonable. Please enter")
          |> mes("a value no greater than 50.")
          |> next(),
          npc
        )

      true ->
        confirm_wager(ctx, npc, wager)
    end
  end

  defp confirm_wager(ctx, npc, wager) do
    {ctx, choice} =
      ctx
      |> mes(name_page(npc))
      |> mes("So you'll be")
      |> mes("betting ^FF0000#{wager}^000000 Apples.")
      |> mes("Is that right?")
      |> next()
      |> select(["Yes", "No"])

    cond do
      choice == 2 ->
        ask_wager(
          ctx
          |> mes(name_page(npc))
          |> mes("Mm, made a mistake?")
          |> mes("Alright, please enter the")
          |> mes("number of Apples you")
          |> mes("wish to place in this bet")
          |> next(),
          npc
        )

      count_item(ctx, @apple) < wager ->
        ask_wager(
          ctx
          |> mes("I'm sorry, but you")
          |> mes("don't seem to have")
          |> mes("enough Apples for this")
          |> mes("bet... You can't gamble")
          |> mes("if you can't play, you know.")
          |> next(),
          npc
        )

      true ->
        ctx
        |> delitem(@apple, wager)
        |> mes(name_page(npc))
        |> mes("Good!")
        |> mes("Now we can start")
        |> mes("this game! I'll roll first~")
        |> then(fn ctx -> {ctx, wager} end)
    end
  end

  @spec play_round(Ctx.t(), term(), integer()) :: no_return()
  defp play_round(ctx, npc, wager) do
    ctx = ctx |> mes("^3355FF*Rolling and rumbling*^000000") |> next()

    house_first = Enum.random(1..6)
    house_second = Enum.random(1..6)
    house_total = house_first + house_second

    ctx =
      ctx
      |> mes(name_page(npc))
      |> mes("I got a ^0000FF#{house_first}^000000 and a ^0000FF#{house_second}^000000.")
      |> mes("That's a total of ^0000FF#{house_total}^000000.")
      |> mes("^FF0000#{char_name(ctx, 0)}^000000, now it's your turn.")
      |> next()

    {ctx, _choice} = select(ctx, ["Cast Dice."])
    ctx = mes(ctx, "^3355FF*Rolling and rumbling*^000000")

    player_first = Enum.random(1..6)
    player_second = Enum.random(1..6)

    {player_first, player_second, player_total} =
      if player_first + player_second > @high_player_roll and wager > @high_stake do
        first = Enum.random(1..6)
        second = Enum.random(1..6)
        {first, second, first + second}
      else
        {player_first, player_second, player_first + player_second}
      end

    ctx = ctx |> next() |> mes(name_page(npc))

    ctx =
      ctx
      |> mes(
        "^FF0000#{char_name(ctx, 0)}^000000, you have ^FF0000#{player_first}^000000 and ^FF0000#{player_second}^000000. The total is ^FF0000#{player_total}^000000 ."
      )
      |> next()
      |> mes(name_page(npc))

    ctx = standing(ctx, house_total, player_total)

    {ctx, choice} = ctx |> next() |> select(["Cast dice.", "Cancel."])

    ctx =
      case choice do
        1 -> draw_third_die(ctx, npc, wager, house_total, player_total)
        2 -> pass(ctx, npc, wager, house_total, player_total)
        _other -> ctx
      end

    house_third_die(ctx, npc, wager, house_total, player_total)
  end

  defp standing(ctx, house_total, player_total) do
    cond do
      player_total == house_total ->
        mes(
          ctx,
          "Currently my total is ^0000FF#{house_total}^000000 and ^FF0000#{char_name(ctx, 0)}^000000, your total is ^FF0000#{player_total}^000000. We are making an even game. Would you like to cast dice again?"
        )

      player_total > house_total ->
        mes(
          ctx,
          "Currently my total is ^0000FF#{house_total}^000000 and ^FF0000#{char_name(ctx, 0)}^000000, your total is ^FF0000#{player_total}^000000. ^FF0000#{char_name(ctx, 0)}^000000, you are currently winning this game. Would you like to cast dice again?"
        )

      true ->
        mes(
          ctx,
          "Currently my total is ^0000FF#{house_total}^000000 and ^FF0000#{char_name(ctx, 0)}^000000, your total is ^FF0000#{player_total}^000000. I am winning this game. Would you like to cast dice again?"
        )
    end
  end

  defp draw_third_die(ctx, npc, wager, house_total, player_total) do
    ctx = mes(ctx, "^3355FF*Rolling and rumbling*^000000")
    third = Enum.random(1..6)
    player_total = player_total + third
    ctx = ctx |> next() |> mes(name_page(npc))

    cond do
      player_total > @bust ->
        halt(
          ctx
          |> mes(
            "^FF0000#{char_name(ctx, 0)}^000000, you got ^FF0000#{third}^000000 and the total is now ^FF0000#{player_total}^000000. You lost this game. I am sorry but please try again."
          )
          |> close()
        )

      player_total < house_total ->
        halt(
          ctx
          |> mes(
            "^FF0000#{char_name(ctx, 0)}^000000, you got ^FF0000#{third}^000000 and the total is now ^FF0000#{player_total}^000000. Even though you casted dice again, still your total is smaller than mine. You lost the game. I am sorry and please try again."
          )
          |> close()
        )

      player_total == house_total ->
        draw_or_continue(
          ctx,
          house_total,
          wager,
          "^FF0000#{char_name(ctx, 0)}^000000, you got ^FF0000#{third}^000000 and the total is now ^FF0000#{player_total}^000000. I don't want to take any risk, let's end this game in a draw. Let's play again some other time~"
        )

      true ->
        mes(
          ctx,
          "^FF0000#{char_name(ctx, 0)}^000000, you got ^FF0000#{third}^000000 and the total is now ^FF0000#{player_total}^000000. Now it is my turn."
        )
    end
  end

  defp pass(ctx, npc, wager, house_total, player_total) do
    ctx = mes(ctx, name_page(npc))

    cond do
      player_total > house_total ->
        mes(
          ctx,
          "I see, you don't want to take risk of losing the game. Okay, let me cast dice again."
        )

      player_total == house_total ->
        draw_or_continue(
          ctx,
          house_total,
          wager,
          "I see, you don't want to take risk of losing this game. Neither do I, let's end this game in a draw. Let's play again some other time~"
        )

      true ->
        halt(
          ctx
          |> mes("It couldn't hurt to try.")
          |> mes("Well, I win this time.")
          |> mes("I'm sorry, let's try play")
          |> mes("again sometime.")
          |> close()
        )
    end
  end

  defp draw_or_continue(ctx, house_total, wager, draw_message) do
    if house_total > @risky_house_total do
      halt(ctx |> mes(draw_message) |> close() |> give_item(@apple, wager))
    else
      ctx |> mes("Alright.") |> mes("Let me cast the dice again.")
    end
  end

  @spec house_third_die(Ctx.t(), term(), integer(), integer(), integer()) :: no_return()
  defp house_third_die(ctx, npc, wager, house_total, player_total) do
    ctx = ctx |> next() |> mes("^3355FF*Rolling and rumbling*^000000")
    third = Enum.random(1..6)
    house_total = house_total + third
    ctx = ctx |> next() |> mes(name_page(npc))

    cond do
      house_total > @bust ->
        halt(
          ctx
          |> mes(
            "I got ^0000FF#{third}^000000 and the total is now ^0000FF#{house_total}^000000. I lost this game since my total exceeded 12. Let me give you my apples. Congratulations, that was a great game."
          )
          |> close()
          |> give_item(@apple, wager * 2)
        )

      player_total > house_total ->
        halt(
          ctx
          |> mes(
            "I got ^0000FF#{third}^000000 and the total is now ^0000FF#{house_total}^000000. With total ^FF0000#{player_total}^000000 you won this game, ^FF0000#{char_name(ctx, 0)}^000000. Let me give you my apples. It was a great game and I hope we will play again some other time."
          )
          |> close()
          |> give_item(@apple, wager * 2)
        )

      player_total == house_total ->
        halt(
          ctx
          |> mes(
            "I got ^0000FF#{third}^000000 and the total is now ^0000FF#{house_total}^000000. With total ^FF0000#{player_total}^000000 this game came out even, ^FF0000#{char_name(ctx, 0)}^000000. Let me give you your apple back. It was a great game and I hope we will play again some other time."
          )
          |> close()
          |> give_item(@apple, wager)
        )

      true ->
        halt(
          ctx
          |> mes(
            "I got ^0000FF#{third}^000000 and the total is now ^0000FF#{house_total}^000000. With total ^FF0000#{player_total}^000000 you lost this game, ^FF0000#{char_name(ctx, 0)}^000000. I am sorry but please try again."
          )
          |> close()
        )
    end
  end

  defp name_page(npc), do: "[#{npc}]"

  defp halt(ctx), do: throw({:script_end, ctx})
end
