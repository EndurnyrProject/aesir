defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.MoonhoAhn do
  @moduledoc """
  Moonho Ahn challenges adventurers to a game of Coin Shake.

  ## Behavior

  - Explains the game and charges a fee to play during the quest.
  - Awards the White Meteor title and advances the quest when the player wins.

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
  - Corrected `number_right` and `number_false` to round-local counters for the repeat prompt.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "payon", x: 244, y: 62, dir: 3, sprite: 897, name: "Moonho Ahn", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :zdan_edq, 0) do
      5 -> introduce_game(ctx)
      6 -> offer_game(ctx)
      _ -> reminisce(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp introduce_game(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Moonho Ahn]")
      |> mes("Hahaha, now what brings")
      |> mes("a youngster like you before")
      |> mes("me? You're not here for what")
      |> mes("I think you are... Are you?")
      |> next()
      |> select(["Are you the White Meteor?", "I'm here to challenge you."])

    case choice do
      1 -> recall_title(ctx)
      2 -> explain_challenge(ctx)
      _ -> ctx
    end
  end

  defp recall_title(ctx) do
    ctx
    |> mes("[Moonho Ahn]")
    |> mes("It's been so long since")
    |> mes("I've heard that name...")
    |> mes("I'm retired now, and it")
    |> mes("seems no one wants to")
    |> mes("challenge me anymore.")
    |> next()
    |> mes("[Moonho Ahn]")
    |> mes("Those were some good")
    |> mes("times. Back then, only")
    |> mes("Dalho Kwak was able to")
    |> mes("give me a real challenge.")
    |> mes("I wonder what he's doing now?")
    |> close()
  end

  defp explain_challenge(ctx) do
    ctx
    |> mes("[Moonho Ahn]")
    |> mes("Oh, I was right...!")
    |> mes("You're here to challenge")
    |> mes("me! It's been a long time...")
    |> mes("Alright. I accept. However,")
    |> mes("I set all of the terms.")
    |> next()
    |> mes("[Moonho Ahn]")
    |> mes("I'm too old to play the")
    |> mes("complicated games I loved")
    |> mes("in the past. Let's just")
    |> mes("play a simple game that")
    |> mes("I call Coin Shake.")
    |> next()
    |> mes("[Moonho Ahn]")
    |> mes("This is basically")
    |> mes("a guessing game played")
    |> mes("in rounds, best 2 out of 3.")
    |> mes("One of us will be the coin")
    |> mes("shaker, and the other will")
    |> mes("be the guesser.")
    |> next()
    |> mes("[Moonho Ahn]")
    |> mes("The coin shaker begins")
    |> mes("the round by grabbing")
    |> mes("a random amount of coins,")
    |> mes("shaking them in his closed")
    |> mes("hands, and then stopping,")
    |> mes("keeping the coins concealed.")
    |> next()
    |> mes("[Moonho Ahn]")
    |> mes("The other person, the")
    |> mes("guesser, will then declare")
    |> mes("a guess on whether the total")
    |> mes("value of the coins is ^0000FFOdd^000000 or")
    |> mes("^0000FFEven^000000. Afterwards, the coin")
    |> mes("shaker reveals the coins...")
    |> next()
    |> mes("[Moonho Ahn]")
    |> mes("If the guesser is right,")
    |> mes("then he wins the round.")
    |> mes("However, if he guessed")
    |> mes("wrong, then it's a victory")
    |> mes("for the coin shaker. ")
    |> next()
    |> mes("[Moohno Ahn]")
    |> mes("We each take turns,")
    |> mes("switching roles.")
    |> mes("If it's your turn to")
    |> mes("guess, remember to")
    |> mes("call out ^0000FFOdd^000000 or ^0000FFEven^000000.")
    |> next()
    |> mes("[Moonho Ahn]")
    |> mes("Lastly, I'm the house,")
    |> mes("so I'll charge a game")
    |> mes("participation fee. It's")
    |> mes("not much, just 500 zeny.")
    |> mes("We're only playing for fun,")
    |> mes("not to break the bank.")
    |> next()
    |> mes("[Moonho Ahn]")
    |> mes("Why don't you give me")
    |> mes("some time to prep the")
    |> mes("game? When you return,")
    |> mes("we'll be ready to play~")
    |> changequest(3123, 3124)
    |> set_char_var(:zdan_edq, 6)
    |> close()
  end

  defp offer_game(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Moonho Ahn]")
      |> mes("Are you ready to")
      |> mes("play Coin Shake?")
      |> next()
      |> select(["Yes, let's play!", "How does this game work again?"])

    case choice do
      1 -> start_game(ctx)
      2 -> explain_rules(ctx)
      _ -> ctx
    end
  end

  defp start_game(ctx) do
    if zeny(ctx) > 500 do
      ctx =
        ctx
        |> pay_zeny(500)
        |> mes("[Moonho Ahn]")
        |> mes("Good, let's get started!")
        |> mes("I'll let you go first~")
        |> next()
        |> mes("*Shake Shake*")
        |> mes("Guess! Is it")
        |> mes("Odd or Even?")
        |> next()
        |> player_guesses(:first)
        |> mes("[Moonho Ahn]")
        |> mes("It's time for the")
        |> mes("second round. This")
        |> mes("time, I'll be the one")
        |> mes("declaring my guess,")
        |> mes("and you'll shake the coins.")
        |> next()
        |> moonho_guesses()

      cond do
        get_local(ctx, :win, 0) == 2 -> celebrate_win(ctx)
        get_local(ctx, :lose, 0) == 2 -> acknowledge_loss(ctx)
        true -> final_round(ctx)
      end
    else
      ctx
      |> mes("[Moonho Ahn]")
      |> mes("Hm? You don't even")
      |> mes("have 500 zeny to play")
      |> mes("a game? Well, whenever")
      |> mes("you feel like playing Coin")
      |> mes("Shake, drop on by.")
      |> close()
    end
  end

  defp final_round(ctx) do
    ctx =
      ctx
      |> mes("[Moonho Ahn]")
      |> mes("Ooh, this is exciting~")
      |> mes("We each both won a round:")
      |> mes("the next round will decide")
      |> mes("who wins and loses!")
      |> next()
      |> mes("[Moonho Ahn]")
      |> mes("It's my turn to shake")
      |> mes("the coins. Let's see")
      |> mes("how you fare this time...")
      |> next()
      |> mes("^3355FF*Shake Shake*")
      |> mes("Guess! Is it")
      |> mes("Odd or Even?^000000")
      |> next()
      |> player_guesses(:final)

    cond do
      get_local(ctx, :win, 0) >= 2 -> celebrate_win(ctx)
      get_local(ctx, :lose, 0) == 2 -> acknowledge_loss(ctx)
      true -> ctx
    end
  end

  defp celebrate_win(ctx) do
    ctx
    |> mes("[Moonho Ahn]")
    |> mes("You really are amazing!")
    |> mes("It's time that the title of")
    |> mes("White Meteor be passed")
    |> mes("onto someone more worthy...")
    |> mes("You are the new White Meteor!")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Really? Uh, can I get")
    |> mes("that in writing please?")
    |> mes("It'd mean so much to me!")
    |> next()
    |> mes("[Moonho Ahn]")
    |> mes("Ah, you want a letter")
    |> mes("of recommendation or")
    |> mes("my seal of approval, right?")
    |> mes("Heh, you must be very proud.")
    |> mes("Hold still for a second.")
    |> next()
    |> mes("^3355FF*Scribble Scribble*^000000")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("What does this")
    |> mes("scribble on my")
    |> mes("wrist mean?")
    |> next()
    |> mes("[Moonho Ahn]")
    |> mes("That is the sign of")
    |> mes("the White Meteor.")
    |> mes("Everyone that knows")
    |> mes("me will recognize it")
    |> mes("and its authenticity.")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Thank you so much")
    |> mes("for the fun game!")
    |> mes("I better get going now,")
    |> mes("but maybe we can play")
    |> mes("again sometime~")
    |> next()
    |> mes("[Moonho Ahn]")
    |> mes("Hahahaa!")
    |> mes("After so long, it")
    |> mes("feels good to have")
    |> mes("played with a worthy")
    |> mes("opponent. Thank you~")
    |> changequest(3124, 3125)
    |> set_char_var(:zdan_edq, 7)
    |> close()
  end

  defp acknowledge_loss(ctx) do
    ctx
    |> mes("[Moonho Ahn]")
    |> mes("I'm sorry, but I've won")
    |> mes("the game. I had a really")
    |> mes("great time, and I could")
    |> mes("tell that it was really close.")
    |> mes("It's been a while since I've")
    |> mes("had this much fun gambling~")
    |> next()
    |> mes("[Moonho Ahn]")
    |> mes("Oh, did you want to")
    |> mes("play again? I can tell")
    |> mes("that you're a bit eager to")
    |> mes("beat me so you're welcome")
    |> mes("to play me again anytime.")
    |> mes("I'll be right here, hahaha~")
    |> close()
  end

  defp explain_rules(ctx) do
    ctx
    |> mes("[Moonho Ahn]")
    |> mes("This is basically")
    |> mes("a guessing game played")
    |> mes("in rounds, best 2 out of 3.")
    |> mes("One of us will be the coin")
    |> mes("shaker, and the other will")
    |> mes("be the guesser.")
    |> next()
    |> mes("[Moonho Ahn]")
    |> mes("The coin shaker begins")
    |> mes("the round by grabbing")
    |> mes("a random amount of coins,")
    |> mes("shaking them in his closed")
    |> mes("hands, and then stopping,")
    |> mes("keeping the coins concealed.")
    |> next()
    |> mes("[Moonho Ahn]")
    |> mes("The other person, the")
    |> mes("guesser, will then declare")
    |> mes("a guess on whether the total")
    |> mes("value of the coins is ^0000FFOdd^000000 or")
    |> mes("^0000FFEven^000000. Afterwards, the coin")
    |> mes("shaker reveals the coins...")
    |> next()
    |> mes("[Moonho Ahn]")
    |> mes("If the guesser is right,")
    |> mes("then he wins the round.")
    |> mes("However, if he guessed")
    |> mes("wrong, then it's a victory")
    |> mes("for the coin shaker. ")
    |> next()
    |> mes("[Moohno Ahn]")
    |> mes("We each take turns,")
    |> mes("switching roles.")
    |> mes("If it's your turn to")
    |> mes("guess, remember to")
    |> mes("call out ^0000FFOdd^000000 or ^0000FFEven^000000.")
    |> next()
    |> mes("[Moonho Ahn]")
    |> mes("Lastly, I'm the house,")
    |> mes("so I'll charge a game")
    |> mes("participation fee. It's")
    |> mes("not much, just 500 zeny.")
    |> mes("We're only playing for fun,")
    |> mes("not to break the bank.")
    |> close()
  end

  defp reminisce(ctx) do
    ctx
    |> mes("[Moonho Ahn]")
    |> mes("I still remember that")
    |> mes("last legendary match with")
    |> mes("Dalho Kwak. Now that man was")
    |> mes("a worthy opponent: he could")
    |> mes("read others' hands three times")
    |> mes("faster than the normal eye!")
    |> next()
    |> mes("[Moonho Ahn]")
    |> mes("God, I miss those")
    |> mes("days competing against")
    |> mes("him. I wonder how he's")
    |> mes("been doing lately...")
    |> close()
  end

  defp player_guesses(ctx, round) do
    {right_key, wrong_key} =
      if round == :first,
        do: {:number_right, :number_false},
        else: {:number_right_3, :number_false_3}

    {ctx, guess} = ctx |> set_local(:number, Enum.random(1..2)) |> input(:string)
    ctx = set_local(ctx, :"input$", guess)
    number = get_local(ctx, :number, 0)

    ctx =
      cond do
        (guess == "Odd" and number == 1) or (guess == "Even" and number == 2) ->
          color = if round == :first, do: "^0000ff", else: "^0000FF"

          ctx
          |> set_local(right_key, get_local(ctx, right_key, 0) + 1)
          |> mes("[Moonho Ahn]")
          |> mes(Rathena.concat(Rathena.concat(color, guess), "^000000?"))
          |> mes("Okay, you won.")
          |> next()
          |> repeat_guess_prompt(right_key, wrong_key)

        (guess == "Odd" and number == 2) or (guess == "Even" and number == 1) ->
          ctx =
            ctx
            |> set_local(wrong_key, get_local(ctx, wrong_key, 0) + 1)
            |> mes("[Moonho Ahn]")

          ctx =
            if round == :first do
              ctx |> mes("Well, it's ^0000FFEven^000000.") |> mes("I won.")
            else
              ctx
              |> mes(Rathena.concat(Rathena.concat("Well, it's ^0000FF", guess), "^000000."))
              |> mes("Looks like I won.")
            end

          ctx |> next() |> repeat_guess_prompt(right_key, wrong_key)

        true ->
          ctx
      end

    cond do
      get_local(ctx, right_key, 0) == 2 ->
        ctx =
          if round == :first do
            ctx
            |> mes("[Moonho Ahn]")
            |> mes("Ah, you win this round.")
            |> mes("However, the game has")
            |> mes("just started. The next")
            |> mes("round will be mine~")
          else
            ctx |> mes("[Moonho Ahn]") |> mes("Oh... You won...")
          end

        ctx |> set_local(:win, get_local(ctx, :win, 0) + 1) |> next()

      get_local(ctx, wrong_key, 0) == 2 ->
        ctx =
          if round == :first do
            ctx
            |> mes("[Moonho Ahn]")
            |> mes("It looks like I win")
            |> mes("this round. I guess")
            |> mes("my gambling skills")
            |> mes("haven't left me yet~")
          else
            ctx
            |> mes("[Moonho Ahn]")
            |> mes("Hahaha! I'm sorry, but")
            |> mes("I won. I guess I still got it!")
          end

        ctx |> set_local(:lose, get_local(ctx, :lose, 0) + 1) |> next()

      true ->
        ctx =
          if guess != "Even" and guess != "Odd" do
            ctx
            |> mes("[Moonho Ahn]")
            |> mes("You can only declare")
            |> mes("your guess as ^0000FFOdd^000000 or ^0000FFEven^000000.")
            |> mes("Please try entering it again.")
            |> next()
          else
            ctx
          end

        player_guesses(ctx, round)
    end
  end

  defp repeat_guess_prompt(ctx, right_key, wrong_key) do
    if get_local(ctx, right_key, 0) < 2 and get_local(ctx, wrong_key, 0) < 2 do
      ctx
      |> mes("^3355FF*Shake Shake*")
      |> mes("Guess! Is it")
      |> mes("Odd or Even?^000000")
      |> next()
    else
      ctx
    end
  end

  defp moonho_guesses(ctx) do
    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("(^666666What should I guess?^000000)")
      |> next()
      |> set_local(:amuro, Enum.random(1..2))
      |> select(["Odd", "Even"])

    number = get_local(ctx, :amuro, 0)

    ctx =
      case {choice, number} do
        {1, 1} ->
          ctx
          |> set_local(:number_false_2, get_local(ctx, :number_false_2, 0) + 1)
          |> mes("[Moonho Ahn]")
          |> mes("Let's see...")
          |> mes("It's ^0000FFOdd^000000, isn't it?")
          |> next()
          |> mes("[Moonho Ahn]")
          |> mes("Looks like I won!")
          |> mes("Hahahahahahaha!")
          |> next()

        {1, 2} ->
          ctx
          |> set_local(:number_right_2, get_local(ctx, :number_right_2, 0) + 1)
          |> mes("[Moonho Ahn]")
          |> mes("Let's see...")
          |> mes("It's Even, isn't it?")
          |> next()
          |> mes("[Moonho Ahn]")
          |> mes("I lost?")
          |> mes("So it's ^0000FFOdd^000000...")
          |> next()

        {_, 1} ->
          ctx
          |> set_local(:number_right_2, get_local(ctx, :number_right_2, 0) + 1)
          |> mes("[Moonho Ahn]")
          |> mes("Let's see...")
          |> mes("It's odd, isn't it?")
          |> next()
          |> mes("[Moonho Ahn]")
          |> mes("I lost, huh?")
          |> mes("So it was ^0000ffEven^000000...")
          |> next()

        {_, 2} ->
          ctx
          |> set_local(:number_false_2, get_local(ctx, :number_false_2, 0) + 1)
          |> mes("[Moonho Ahn]")
          |> mes("Let's see...")
          |> mes("It's ^0000FFEven^000000, isn't it?")
          |> next()
          |> mes("[Moonho Ahn]")
          |> mes("Looks like I won!")
          |> mes("Hahahahahahaha!")
          |> next()
      end

    cond do
      get_local(ctx, :number_right_2, 0) == 2 ->
        ctx
        |> set_local(:win, get_local(ctx, :win, 0) + 1)
        |> mes("[Moonho Ahn]")
        |> mes("Nice job. I didn't")
        |> mes("expect for you to")
        |> mes("really beat me...")
        |> mes("Hahahahahahah~")
        |> next()

      get_local(ctx, :number_false_2, 0) == 2 ->
        ctx
        |> set_local(:lose, get_local(ctx, :lose, 0) + 1)
        |> mes("[Moonho Ahn]")
        |> mes("Hahaha! I'm sorry, but")
        |> mes("I won. I guess I still got it!")
        |> next()

      true ->
        moonho_guesses(ctx)
    end
  end
end
