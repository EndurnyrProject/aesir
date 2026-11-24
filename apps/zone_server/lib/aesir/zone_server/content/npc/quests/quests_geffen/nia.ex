defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsGeffen.Nia do
  @moduledoc """
  Nia, in Geffen, hosts the Number Match game: guess her secret three-digit number.

  ## Behavior

  - Explains the rules: the number has three distinct digits from 1 to 9, and each guess is
    answered with how many digits are right and how many are in the right place.
  - Practice games allow unlimited guesses; real games allow five and reveal the answer when
    they run out. Entering a number outside 100-999 cancels the game.
  - A real win is timed and, when it ties or beats the server-wide record (or no record exists),
    stores the player's name and time as the new record.
  - Shows the current record holder and time on request.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Samuray22
    - Lupus
    - Silent
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "geffen",
        x: 122,
        y: 77,
        dir: 4,
        sprite: 700,
        name: "Nia",
        scope: :shared,
        unique_name: "Nia#yagu"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @record_name "050908_minus1_yagu$"
  @record_time "050908_minus1_yagu"
  @guesses 5

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Nia]")
      |> mes("Hello, I'm Nia, the fifth")
      |> mes("disciple of Mawong, the")
      |> mes("gaming mastermind. Now,")
      |> mes("how would you like to play a")
      |> mes("Number Match game with me?")
      |> next()
      |> select([
        "Number Match Game?",
        "Practice Number Match",
        "Play Number Match",
        "Record Holder",
        "Cancel"
      ])

    case choice do
      1 -> explains_the_rules(ctx)
      2 -> ctx |> starts_practice() |> play(true)
      3 -> ctx |> starts_game() |> play(false)
      4 -> shows_the_record(ctx)
      5 -> farewell(ctx)
      _ -> ctx
    end
  end

  defp explains_the_rules(ctx) do
    ctx
    |> mes("[Nia]")
    |> mes("Ah, well, the objective of")
    |> mes("the Number Match game is to")
    |> mes("guess the number I'm thinking")
    |> mes("of. Of course, there are a few")
    |> mes("rules that limit the numbers")
    |> mes("that I can choose from.")
    |> next()
    |> mes("[Nia]")
    |> mes("All the numbers that I make")
    |> mes("up must be 3 digits, I can't")
    |> mes("use 0 for any of the digits,")
    |> mes("and I can't use the same")
    |> mes("number for any of the digits")
    |> mes("more than once.")
    |> next()
    |> mes("[Nia]")
    |> mes("So, for example, I can't")
    |> mes("use the numbers 103, 112,")
    |> mes("252, or 701. Those numbers")
    |> mes("either have a 0, or they use")
    |> mes("the same number in the digits")
    |> mes("more than once. Got it now?")
    |> next()
    |> mes("[Nia]")
    |> mes("Now, you only get 5 guesses,")
    |> mes("and after each guess, I'll tell")
    |> mes("you how many digits you guessed")
    |> mes("correctly, followed by the number of correctly guessed digits in")
    |> mes("the correct digit place.")
    |> next()
    |> mes("[Nia]")
    |> mes("For example, let's say the")
    |> mes("number I come up with is 168.")
    |> mes("If your first guess is 678, then you guessed two of the digits,")
    |> mes("6 and 8, correctly. However,")
    |> mes("only 8 is in the correct place.")
    |> next()
    |> mes("[Nia]")
    |> mes("You know, it'd be a good idea")
    |> mes("if you try the Practice Mode")
    |> mes("first. Then, when you're more")
    |> mes("comfortable, play the actual")
    |> mes("Number Match game. Don't forget that speed counts for your score!")
    |> next()
    |> mes("[Nia]")
    |> mes("Ah, if you happen to")
    |> mes("make a new record in the")
    |> mes("Number Match game, you'll")
    |> mes("have your name recorded,")
    |> mes("so don't miss this chance for")
    |> mes("fame and maybe even fortune~")
    |> close()
  end

  defp starts_practice(ctx) do
    ctx
    |> mes("[Nia]")
    |> mes("Great, let's do a practice")
    |> mes("Number Match game. Please")
    |> mes("try to guess my number, okay?")
    |> mes("If you want to cancel, then please enter a number greater than 1,000.")
  end

  defp starts_game(ctx) do
    ctx
    |> mes("[Nia]")
    |> mes("Great, let's play Number Match!")
    |> mes("You will have 5 chances to guess the number that I'm thinking of.")
    |> mes("If you want to cancel, then please enter a number greater than 1,000.")
  end

  defp shows_the_record(ctx) do
    {name, time} = record(ctx)

    ctx
    |> mes("[Nia]")
    |> mes("^ff0000#{name}^000000 is the")
    |> mes("record holder for the Number")
    |> mes("Match game with a time of")
    |> mes("^ff0000#{duration(time)}^000000.")
    |> close()
  end

  defp farewell(ctx) do
    ctx
    |> mes("[Nia]")
    |> mes("Take care of yourself,")
    |> mes("adventurer. If you ever")
    |> mes("feel like playing a Number")
    |> mes("Match game, come and talk")
    |> mes("to me, alright? See you~")
    |> close()
  end

  defp play(ctx, practice?) do
    ctx = next(ctx)
    answer = secret_digits()

    game = %{
      answer: answer,
      number: Integer.undigits(answer),
      practice?: practice?,
      start_time: gettimetick(ctx, 2)
    }

    play_round(ctx, game, 1)
  end

  defp secret_digits do
    digits = for _ <- 1..3, do: Enum.random(1..9)
    if distinct?(digits), do: digits, else: secret_digits()
  end

  defp play_round(ctx, game, round) do
    with {:guess, ctx, number, guess} <- ask_guess(ctx) do
      ctx =
        ctx
        |> mes("[Nia]")
        |> mes("^ff0000#{char_name(ctx, 0)}^000000,")
        |> mes("your guess is ^0000ff#{number}^000000.")
        |> mes("Give me a moment to")
        |> mes("come up with your results.")
        |> next()

      strikes = game.answer |> Enum.zip(guess) |> Enum.count(fn {a, g} -> a == g end)
      balls = Enum.count(game.answer, &(&1 in guess)) - strikes

      cond do
        strikes == 3 and game.practice? ->
          wins_practice(ctx, game)

        strikes == 3 ->
          wins_game(ctx, game)

        game.practice? ->
          ctx |> practice_hint(balls, strikes) |> next() |> play_round(game, round + 1)

        round == @guesses ->
          ctx
          |> game_hint(balls, strikes)
          |> mes("The answer was ^ff0000#{game.number}^000000.")
          |> close()

        true ->
          ctx
          |> game_hint(balls, strikes)
          |> mes(guesses_left(round))
          |> next()
          |> play_round(game, round + 1)
      end
    else
      {:cancel, ctx} -> ctx
    end
  end

  defp ask_guess(ctx) do
    {ctx, raw} = input(ctx, :int)

    case Rathena.input_int(raw, 100, 999) do
      {0, number} ->
        guess = Integer.digits(number)

        if 0 not in guess and distinct?(guess) do
          {:guess, ctx, number, guess}
        else
          ctx |> rejects_guess() |> ask_guess()
        end

      _out_of_range ->
        {:cancel, cancels_game(ctx)}
    end
  end

  defp distinct?(digits), do: Enum.uniq(digits) == digits

  defp cancels_game(ctx) do
    ctx
    |> mes("[Nia]")
    |> mes("You've canceled the")
    |> mes("Number Match game.")
    |> close()
  end

  defp rejects_guess(ctx) do
    ctx
    |> mes("[Nia]")
    |> mes("You entered one of the")
    |> mes("digits as 0, or input the")
    |> mes("same numerical value in")
    |> mes("the digits more than once.")
    |> mes("Please enter another guess.")
    |> next()
  end

  defp practice_hint(ctx, balls, strikes) do
    ctx
    |> mes("[Nia]")
    |> mes("Your guess has ^ff0000#{balls}^000000 of the")
    |> mes("correct numbers. ^ff0000#{strikes}^000000 of the")
    |> mes("digits in your guess have")
    |> mes("the correct number in the")
    |> mes("correct digit placement.")
    |> mes("Alright, try it again~")
  end

  defp game_hint(ctx, balls, strikes) do
    ctx
    |> mes("[Nia]")
    |> mes("Your last guess had ^ff0000#{balls}^000000")
    |> mes("of the correct numbers,")
    |> mes("and ^ff0000#{strikes}^000000 digits in your guess")
    |> mes("had the correct number in")
    |> mes("the correct digit placement.")
  end

  defp guesses_left(1), do: "You have four guesses left."
  defp guesses_left(2), do: "You have three guesses left."
  defp guesses_left(3), do: "You have two guesses left."
  defp guesses_left(4), do: "You only have one guess left..."

  defp wins_practice(ctx, game) do
    ctx
    |> mes("[Nia]")
    |> mes("Yes, the number that")
    |> mes("I guessed was ^ff0000#{game.number}^000000!")
    |> mes("Congratulations, you")
    |> mes("just won this practice")
    |> mes("game! Now you should be")
    |> mes("ready for the real thing~")
    |> close()
  end

  defp wins_game(ctx, game) do
    total_time = elapsed(gettimetick(ctx, 2), game.start_time)
    {name, record_time} = record(ctx)

    if record_time >= total_time or record_time == 0 do
      ctx
      |> set_server_var(@record_name, char_name(ctx, 0))
      |> set_server_var(@record_time, total_time)
      |> mes("[Nia]")
      |> mes("Great! You guessed")
      |> mes("my number, which was")
      |> mes("^ff0000#{game.number}^000000. You finished in")
      |> mes("^ff0000#{duration(total_time)}^000000,")
      |> mes("breaking the previous record")
      |> mes("of ^ff0000#{duration(record_time)}^000000.")
      |> next()
      |> mes("[Nia]")
      |> mes("^ff0000#{name}^000000")
      |> mes("set that old record,")
      |> mes("but now you are the")
      |> mes("new person to beat in the")
      |> mes("Match Game. Congratulations")
      |> mes("for setting a new record!")
      |> close()
    else
      ctx
      |> mes("[Nia]")
      |> mes("Nice work, you guessed")
      |> mes("my number! The answer, of")
      |> mes("course, was ^ff0000#{game.number}^000000. You managed")
      |> mes("to guess this number correctly")
      |> mes("in ^ff0000#{duration(total_time)}^000000.")
      |> next()
      |> mes("[Nia]")
      |> mes("^ff0000#{name}^000000 is")
      |> mes("the current Number Match")
      |> mes("record holder with a time")
      |> mes("of ^ff0000#{duration(record_time)}^000000.")
      |> mes("Good luck, and hopefully you")
      |> mes("can break this record someday~")
      |> close()
    end
  end

  defp elapsed(end_time, start_time) when end_time < start_time,
    do: end_time + 3600 - start_time

  defp elapsed(end_time, start_time), do: end_time - start_time

  defp record(ctx) do
    name =
      case get_server_var(ctx, @record_name, "") do
        "" -> "(null)"
        name -> name
      end

    {name, get_server_var(ctx, @record_time, 0)}
  end

  defp duration(seconds), do: "#{div(seconds, 60)} minutes, #{rem(seconds, 60)} seconds"
end
