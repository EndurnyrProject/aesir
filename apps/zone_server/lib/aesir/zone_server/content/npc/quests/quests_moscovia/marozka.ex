defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.Marozka do
  @moduledoc """
  Marozka tests the player's worth before giving them Golden Thread.

  ## Behavior

  - He requests appropriate footwear, makes the thread, and tests the player's wisdom.
  - Passing his quiz awards Golden Thread and advances the quest.

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
        map: "mosk_fild02",
        x: 243,
        y: 270,
        dir: 0,
        sprite: 866,
        name: "Marozka",
        scope: :shared,
        unique_name: "Marozka#rus31"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    main = get_char_var(ctx, :rhea_rus_main, 0)
    quiz = get_char_var(ctx, :rhea_rus_quiz, 0)

    cond do
      main < 8 or (main == 8 and quiz < 3) ->
        ctx |> mes("[Marozka]") |> mes("...........................") |> close()

      main == 8 and quiz in [3, 29] and getequipid(ctx, 2) != 2429 and
          getequipid(ctx, 2) != 2430 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("...Hmm, did I forget to wear something...?")
        |> close()

      main == 8 and quiz == 3 ->
        begin_thread(ctx)

      main == 8 and quiz == 4 ->
        wait_for_thread(ctx)

      main == 8 and quiz == 28 ->
        introduce_quiz(ctx)

      main == 8 and quiz == 29 ->
        offer_quiz(ctx)

      true ->
        ctx
        |> mes("[Marozka]")
        |> mes("...............................")
        |> next()
        |> mes("- He closes his eyes -")
        |> mes("- and stands still -")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp begin_thread(ctx) do
    ctx = ctx |> mes("[Marozka]") |> mes(".....................you came.") |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes(
        "Are you Marozka? Here, I've proven to you my strength now can you make me the 'Golden Thread'?"
      )
      |> mes("I need it to get Maria out of that wall.")
      |> next()
      |> mes("- You put the cookies and -")
      |> mes("- apples in front of him -")
      |> mes("- and he slowly utters -")
      |> next()
      |> mes("[Marozka]")
      |> mes(
        "As you've heard, to make the 'Golden Thread' is very difficult and takes a very long time."
      )
      |> next()
      |> mes("[Marozka]")
      |> mes(
        "I will begin making it now... let me see... Could you please come back to me in an hour?"
      )
      |> set_char_var(:rhea_rus_quiz, 4)

    ctx = set_char_var(ctx, :rus_time01, gettime(ctx, 3))
    ctx |> set_char_var(:rus_time02, gettime(ctx, 4)) |> close()
  end

  defp wait_for_thread(ctx) do
    if get_char_var(ctx, :rus_time01, 0) != gettime(ctx, 3) or
         get_char_var(ctx, :rus_time02, 0) != gettime(ctx, 4) do
      ctx
      |> mes("[Marozka]")
      |> mes("Ah, just in time.")
      |> mes(
        "I have finally finished making the 'Golden Thread'. Just wait one more second and it'll be ready."
      )
      |> set_char_var(:rhea_rus_quiz, 28)
      |> close()
    else
      ctx
      |> mes("[Marozka]")
      |> mes(
        "As you've heard, to make the 'Golden Thread' is very difficult and takes a very long time."
      )
      |> next()
      |> mes("[Marozka]")
      |> mes(
        "I will begin making it now... let me see... Could you please come back to me in an hour?"
      )
      |> close()
    end
  end

  defp introduce_quiz(ctx) do
    ctx
    |> mes("[Marozka]")
    |> mes("As promised, here's the 'Golden Thread'.")
    |> mes("So, you are really going to fight Koshei the Immportal, eh?")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("I don't know but I promised to get Maria out of there.")
    |> next()
    |> mes("[Marozka]")
    |> mes(
      "Huh, Koshei is not your average adversary. Strength alone cannot beat him. You will need wisdom and an unfaltering spirit in order to win."
    )
    |> next()
    |> mes("[Marozka]")
    |> mes("Koshei will be extremely hostile to you because you are helping Maria.")
    |> next()
    |> mes("[Marozka]")
    |> mes(
      "Do you still want the Golden Thread? Ok, I will give it to you! But, there is one more test."
    )
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("One more test?")
    |> mes("Didn't I already prove my worth?")
    |> next()
    |> mes("[Marozka]")
    |> mes("That was a test of your strength. Now you must pass the test of mind and wisdom.")
    |> set_char_var(:rhea_rus_quiz, 29)
    |> close()
  end

  defp offer_quiz(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Marozka]")
      |> mes("...So? Have you decided?")
      |> next()
      |> select(["I need more time...", "I will take it!"])

    case choice do
      1 -> ctx |> mes("[Marozka]") |> mes("Ok then. Come back when you are ready.") |> close()
      2 -> take_quiz(ctx)
      _ -> ctx
    end
  end

  defp take_quiz(ctx) do
    {ctx, first_answer} =
      ctx
      |> mes("[Marozka]")
      |> mes(
        "You will... Ok, let's get to it. You must answer all of these questions correctly in order to pass the test."
      )
      |> next()
      |> mes("[Marozka]")
      |> mes("What is deaf, dumb, and blind and always tells the truth?")
      |> next()
      |> select(["A Poring", "A Picky", "A Mirror", "A Tree"])

    ctx = set_local(ctx, :j, first_answer)

    {ctx, second_answer} =
      ctx
      |> set_local(
        :rus_quiz01,
        if(get_local(ctx, :j, 0) == 3, do: 1, else: 0)
      )
      |> mes("[Marozka]")
      |> mes(
        "If 4 cats can catch 4 mice every 4 minutes, what is the minimum number of cats needed to get 10 mice in 10 minutes?"
      )
      |> next()
      |> select(["4", "5", "6", "10"])

    ctx = set_local(ctx, :j, second_answer)

    {ctx, third_answer} =
      ctx
      |> set_local(
        :rus_quiz01,
        if(get_local(ctx, :j, 0) == 1,
          do: get_local(ctx, :rus_quiz01, 0) + 1,
          else: get_local(ctx, :rus_quiz01, 0)
        )
      )
      |> mes("[Marozka]")
      |> mes("Which of these gets shorter during winter and longer during summer?")
      |> next()
      |> select(["Sky", "Day", "Waves", "Wind"])

    ctx = set_local(ctx, :j, third_answer)

    {ctx, fourth_answer} =
      ctx
      |> set_local(
        :rus_quiz01,
        if(get_local(ctx, :j, 0) == 2,
          do: get_local(ctx, :rus_quiz01, 0) + 1,
          else: get_local(ctx, :rus_quiz01, 0)
        )
      )
      |> mes("[Marozka]")
      |> mes(
        "Doris Etticoat, wears a petticoat and has a red nose; the longer she stands, the shorter she grows. What is she?"
      )
      |> next()
      |> select(["A Star", "A Candle", "A Sword", "The Moon"])

    ctx = set_local(ctx, :j, fourth_answer)

    {ctx, fifth_answer} =
      ctx
      |> set_local(
        :rus_quiz01,
        if(get_local(ctx, :j, 0) == 2,
          do: get_local(ctx, :rus_quiz01, 0) + 1,
          else: get_local(ctx, :rus_quiz01, 0)
        )
      )
      |> mes("[Marozka]")
      |> mes(
        "My top and bottom are twins of a kind. The middle of me makes one body combined. If I stand tall and still, run faster I will. What am I?"
      )
      |> next()
      |> select(["A Woman", "Valkyrie", "The Moon", "An Hourglass"])

    ctx = set_local(ctx, :j, fifth_answer)

    ctx =
      ctx
      |> set_local(
        :rus_quiz01,
        if(get_local(ctx, :j, 0) == 4,
          do: get_local(ctx, :rus_quiz01, 0) + 1,
          else: get_local(ctx, :rus_quiz01, 0)
        )
      )
      |> mes("[Marozka]")
      |> mes("Now let's see how you did.")
      |> next()

    if get_local(ctx, :rus_quiz01, 0) > 4 do
      ctx
      |> mes("[Marozka]")
      |> mes("You got all of them correct.")
      |> next()
      |> mes("[Marozka]")
      |> mes(
        "I know that a quiz is a strange way of evaluating a person's wisdom. But, it is my way of knowing if you are truly committed to fighting Koshei."
      )
      |> next()
      |> mes("[Marozka]")
      |> mes("I hope you help Maria with your strength and kindness.")
      |> set_char_var(:rhea_rus_quiz, 30)
      |> give_item(7879, 10)
      |> close()
    else
      ctx
      |> mes("[Marozka]")
      |> mes(
        "I told you before that I wouldn't give you the Golden Thread until you got all questions correct."
      )
      |> next()
      |> mes("[Marozka]")
      |> mes("It is not too late to try again. With wisdom comes patience.")
      |> close()
    end
  end
end
