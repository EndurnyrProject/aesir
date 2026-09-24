defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Dancer.Bijou do
  @moduledoc """
  Retired dancer who interviews Dancer candidates, sends them to the dance test, and performs
  the job change.

  ## Behavior

  - Refuses anyone with unspent skill points and greets non-Archers without starting the quest.
  - Gives one of three random ten-question quizzes; more than 70 points passes, and a failed
    candidate may retake it.
  - Explains the dance test on request and sends the candidate to the testing area.
  - Changes a candidate who passed the dance test into a Dancer and gives a Job Level-dependent
    gift.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kalen
    - Fredzilla
    - Lupus
    - L0ne_W0lf
    - Samuray22
    - Brainstorm
    - Kisuka
    - Euphy
    - Vicious
    - Lance
    - Skotlex

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "job_duncer",
        x: 95,
        y: 93,
        dir: 4,
        sprite: 101,
        name: "Bijou",
        scope: :shared,
        unique_name: "Bijou#da"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FClearjobvar
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      Rathena.truthy?(skill_point(ctx)) -> refuse_unspent_skill_points(ctx)
      Rathena.job_id(base_job(ctx)) != Rathena.job_id(:archer) -> greet_non_archer(ctx)
      true -> continue_quest(ctx, get_char_var(ctx, :DANC_Q, 0))
    end
  end

  defp refuse_unspent_skill_points(ctx) do
    ctx
    |> mes("[Bijou]")
    |> mes("You can't change jobs")
    |> mes("if you still have skill")
    |> mes("points left. Use the rest")
    |> mes("and come back later.")
    |> close()
  end

  defp greet_non_archer(ctx) do
    base_job_id = Rathena.job_id(base_job(ctx))

    cond do
      base_job_id == Rathena.job_id(:bard) ->
        ctx
        |> mes("[Bijou]")
        |> mes("Welcome~")
        |> mes(
          "Ooh, a Bard! Do you have any new songs to show us? We can always use some musical accompaniment for our dances."
        )
        |> close()

      base_job_id == Rathena.job_id(:dancer) ->
        ctx
        |> mes("[Bijou]")
        |> mes("Oh my...!")
        |> mes("Welcome back~")
        |> next()
        |> mes("[Bijou]")
        |> mes("How are you")
        |> mes("these days?")
        |> mes("A lot of people")
        |> mes("must love watching")
        |> mes("you dance. Are you")
        |> mes("enjoying the spotlight?")
        |> close()

      true ->
        ctx
        |> mes("[Bijou]")
        |> mes("Oh dear~")
        |> mes("You seem to have traveled quite a distance to watch me perform.")
        |> next()
        |> mes("[Bijou]")
        |> mes(
          "I'm sorry, but I've retired. Now I'm focusing on training new Dancers. If you go to the Center Stage, you can watch my students~"
        )
        |> close()
    end
  end

  defp continue_quest(ctx, dance_q) do
    cond do
      dance_q < 5 ->
        ctx
        |> mes("[Bijou]")
        |> mes("Oh my~")
        |> mes("You want to")
        |> mes("become a Dancer,")
        |> mes("don't you?")
        |> next()
        |> mes("[Bijou]")
        |> mes(
          "I know you're excited, but the first step is the application. Go over to the left side of the stage where Aile can help you with that."
        )
        |> close()

      dance_q > 4 and dance_q < 7 ->
        interview(ctx, dance_q)

      dance_q == 7 ->
        offer_dance_test(ctx)

      dance_q == 8 ->
        ctx
        |> mes("[Bijou]")
        |> mes("Oh my...")
        |> mes("Did you")
        |> mes("fail last time?")
        |> mes("Don't worry, just")
        |> mes("try to feel the rhythm~")
        |> close()
        |> warp("job_duncer", 105, 109)

      dance_q == 9 ->
        if Rathena.truthy?(skill_point(ctx)) do
          refuse_unspent_skill_points(ctx)
        else
          change_to_dancer(ctx)
        end

      true ->
        ctx
    end
  end

  defp interview(ctx, dance_q) do
    ctx =
      if dance_q == 5 do
        ctx
        |> mes("[Bijou]")
        |> mes("Oh my~")
        |> mes("You want to")
        |> mes("become a Dancer,")
        |> mes("don't you?")
        |> next()
        |> mes("[Bijou]")
        |> mes("G-goodness!")
        |> mes("Look at that stomach fat!")
        |> mes(
          "Well, it's not much, so you'll lose it in no time. Especially since I'll be handling your training~"
        )
        |> next()
        |> mes("[Bijou]")
        |> mes("Still...")
        |> mes("The idea of the")
        |> mes("perfect body sure")
        |> mes("has changed since")
        |> mes("I was young. Anyway...")
        |> next()
        |> mes("[Bijou]")
        |> mes("Let's start")
        |> mes("with the interview.")
        |> mes("I'm only going to ask")
        |> mes("a couple of simple things")
        |> mes("so don't worry~")
        |> next()
        |> mes("[Bijou]")
        |> mes("Okay...")
        |> mes("Let's begin.")
        |> next()
      else
        ctx
        |> mes("[Bijou]")
        |> mes("Oh, you're back~")
        |> mes("Have you studied")
        |> mes("some more? Try to")
        |> mes("pass this time, okay?")
        |> next()
      end

    {ctx, score} = run_quiz({ctx, 0}, Enum.random(1..3))

    ctx
    |> mes("[Bijou]")
    |> mes("Good job~")
    |> mes("It seems like you")
    |> mes("answered all the")
    |> mes("questions~")
    |> next()
    |> mes("[Bijou]")
    |> mes("Let's see...")
    |> mes("Your score is")
    |> mes("#{score} points...")
    |> grade_interview(score)
  end

  defp run_quiz(state, 1) do
    state
    |> ask(
      ["1. The Dancer's dance, ^CD6889Lady Luck^000000,", "increases which of the following?"],
      ["Intelligence (INT)", "Dexterity (DEX)", "Vitality (VIT)", "Critical Attack Rate"],
      [4]
    )
    |> ask_with_penalty(
      ["2. Of the following,", "which can you not consider", "to be a dance?"],
      ["Tango", "Tap Dance", "HIP-HOP", "Hip Shaker", "Lightning Bolt"],
      5
    )
    |> ask(
      ["3. Which of the following", "best describes a Dancer?"],
      ["Person who yells.", "A loud person.", "A person who dances.", "A person who sings."],
      [3]
    )
    |> ask(
      ["4. Which of the following", "cannot be associated with Comodo?"],
      [
        "Beach city.",
        "Dancer Job Change.",
        "Always dark like the night.",
        "Dungeons in 3 directions.",
        "A lot of Thieves."
      ],
      [5]
    )
    |> ask(
      [
        "5. Before Comodo, what is the region name of the region NorthEast of Pharoah's Lighthouse Island?"
      ],
      ["Elmeth Plateau", "Comuko Beach", "Comodo Beach", "Ginai Swamp"],
      [3]
    )
    |> ask_best_dancer(["6. Who is the most", "beautiful dancer?"], ":Bijou:Aile:Bonjour")
    |> ask(
      ["7. Of the following,", "who can perform together", "with a Dancer?"],
      ["Assassin", "Bard", "Alchemist", "Sage"],
      [2]
    )
    |> ask(
      ["8. Which of the following", "is not a specialty of Comodo?"],
      ["Berserk Potion", "Clam Shell", "Crab Shell", "Shining Stone"],
      [4]
    )
    |> ask(
      ["9. Who is the manager", "of the Comodo Casino?"],
      ["Yoo", "Moo", "Hoon", "Roul"],
      [2]
    )
    |> ask(
      ["10. Who accepts the", "Dancer job change", "applications?"],
      ["Bijou", "Aile", "Athena", "Sonotora"],
      [2]
    )
  end

  defp run_quiz(state, 2) do
    state
    |> ask(
      ["1. What is the effect", "of the combined skill,", "^CD6889Mental Sensing^000000?"],
      [
        "Instant monster death.",
        "Doubles damage.",
        "Increases experience.",
        "Increases attack speed."
      ],
      [3]
    )
    |> ask(
      ["2. Which is considered", "bad etiquette on the dance", "floor after a dance?"],
      [
        "Thank your partner.",
        "Praise your partner's dance.",
        "Ask to dance a different dance.",
        "Criticize your partner."
      ],
      [4]
    )
    |> ask(
      [
        "3. Which is not an",
        "appropriate response",
        "when someone makes",
        "a mistake while you",
        "are dancing together?"
      ],
      [
        "Smile at each other and continue dancing.",
        "Point out the mistake.",
        "Ignore it if the dancer does not realize it.",
        "Give them a smile."
      ],
      [2]
    )
    |> ask(
      ["4. In which town", "can you change jobs", "to a Dancer?"],
      ["Cocomo", "Sandarman", "Comudo", "Comodo"],
      [4]
    )
    |> ask(
      ["5. How many dungeons", "are directly connected", "to Comodo?"],
      ["1", "2", "3", "4"],
      [3]
    )
    |> ask(
      ["6. Which of the following", "is not a Cute Pet monster?"],
      ["Isis", "Argiope", "Dokebi", "Deviruchi"],
      [2]
    )
    |> ask_best_dancer(["7. Who is the most", "graceful dancer?"], ":Bijou:Isis:Mercy Bokou")
    |> ask(
      ["8. What is the", "exact name of the", "Kafra in Comodo?"],
      [
        "Kafra Headquarters",
        "Kafra West Headquarters",
        "Kafra Service",
        "Kafra Headquarters",
        " Western Branch"
      ],
      [4]
    )
    |> ask(
      ["9. What is my name?"],
      ["Borjuis", "Bourgeois", "Bijou", "Beruberu"],
      [3],
      "[......]"
    )
    |> ask(
      ["10. What is the", "effect of ^CD6889Lullaby^000000?"],
      [
        "Casts the Blind effect in the area.",
        "Casts the Sleep effect on the area.",
        "Puts a night effect on the area.",
        "Freezes the area."
      ],
      [2]
    )
  end

  defp run_quiz(state, 3) do
    state
    |> ask(
      ["1. What is the effect", "of the skill ^CD6889Dance Lessons^000000?"],
      [
        "Increases INT",
        "Increases the effect of dancing skills",
        "Increase damage of Whip weapons.",
        "Inflict Stun on a certain area around the caster."
      ],
      [2, 3]
    )
    |> ask(
      [
        "2. What dance uses shoes",
        "that are designed to make",
        "sound as the dancer rolls",
        "their feet and taps the",
        "ground to create a rhythm?"
      ],
      ["Tap Dance", "Improve Concentration", "Tango", "Double Strafing"],
      [1]
    )
    |> ask(
      ["3. Which of the following", "is not a characteristic of a Dancer?"],
      [
        "Uses Dance skills. ",
        "Attacks from a distance.",
        "Uses Whips.",
        "Uses Two-handed swords."
      ],
      [4]
    )
    |> ask(
      ["4. Which town has", "the most Dancers?"],
      ["Al De Baran", "Juno", "Morocc", "Comodo"],
      [4]
    )
    |> ask_best_dancer(
      ["5. Of the following,", "who dances most beautifully?"],
      ":Bijou:Isis:Guton Tak"
    )
    |> ask(
      ["6. What is the Dancer", "better at than the other", "job classes?"],
      ["Health", "Acting ", "Dancing ", "Magic "],
      [3]
    )
    |> ask(
      ["7. Who is the manager", "of the Comodo Casino?"],
      ["Ryu", "Moo", "Roul", "Hoon"],
      [2]
    )
    |> ask(
      ["8. What item cannot", "be equipped by a Dancer?"],
      ["Kitty Band ", "Two-handed Sword", "Sandals", "Earring"],
      [2]
    )
    |> ask(
      ["9. Do you think you", "can say this quiz is", "frustrating and annoying?"],
      ["Yes", "No"],
      :any
    )
    |> ask(
      ["10. Which of the following", "is not a Jazz musician?"],
      ["Art Blakey", "Billie Holiday ", "Louis Armstrong ", "Bud Powell ", "Elder Willow "],
      [5]
    )
  end

  defp run_quiz(state, _quiz), do: state

  defp ask({ctx, score}, question, options, correct_choices, speaker \\ "[Bijou]") do
    {ctx, choice} = ctx |> mes(speaker) |> mes_lines(question) |> next() |> select(options)

    if correct_choices == :any or choice in correct_choices do
      {ctx, score + 10}
    else
      {ctx, score}
    end
  end

  defp ask_with_penalty({ctx, score}, question, options, correct_choice) do
    {ctx, choice} = ctx |> mes("[Bijou]") |> mes_lines(question) |> next() |> select(options)

    if choice == correct_choice do
      {ctx, score + 10}
    else
      {ctx, score - 10}
    end
  end

  defp ask_best_dancer({ctx, score}, question, other_dancers) do
    ctx = ctx |> mes("[Bijou]") |> mes_lines(question) |> next()
    {ctx, choice} = select(ctx, String.split("#{char_name(ctx, 0)}#{other_dancers}", ":"))

    case choice do
      1 ->
        ctx =
          ctx
          |> mes("[Bijou]")
          |> mes("...")
          |> mes("That's...")
          |> mes("^660000completely wrong^000000.")
          |> mes("Didn't you see the")
          |> mes("other choices?!")
          |> mes("Minus points...!")
          |> next()

        {ctx, score - 10}

      2 ->
        {ctx, score + 10}

      _ ->
        {ctx, score}
    end
  end

  defp grade_interview(ctx, 100) do
    ctx
    |> set_char_var(:DANC_Q, 7)
    |> mes("Very well done!")
    |> mes("A perfect score!")
    |> next()
    |> mes("[Bijou]")
    |> mes(
      "There aren't too many people who apply for the Dancer job with this kind of knowledge. I'm sorry for judging you by your looks~"
    )
    |> next()
    |> mes("[Bijou]")
    |> mes("Whew~")
    |> mes(
      "Now you only have the Dance Test. While we prepare the test, why don't you rest a bit? Ho ho ho~"
    )
    |> close()
  end

  defp grade_interview(ctx, score) when score > 70 do
    ctx
    |> set_char_var(:DANC_Q, 7)
    |> mes("It wasn't perfect, but I'll let you pass.")
    |> close()
  end

  defp grade_interview(ctx, _score) do
    ctx
    |> set_char_var(:DANC_Q, 6)
    |> mes("You.. You failed!")
    |> next()
    |> mes("[Bijou]")
    |> mes("Was it too hard?")
    |> mes(
      "When I was young, everyone knew at least enough to pass this test. Go and study some more before coming back, okay?"
    )
    |> close()
  end

  defp offer_dance_test(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Bijou]")
      |> mes("Okay...")
      |> mes("Are you ready")
      |> mes("for the Dance Test?")
      |> mes("If you like, I can")
      |> mes("explain the instructions.")
      |> next()
      |> select(["Listen to instructions.", "Go to the testing area."])

    if choice == 1 do
      explain_dance_test(ctx)
    else
      ctx
      |> mes("[Bijou]")
      |> mes("Well then~")
      |> mes("Good luck...!!")
      |> changequest(7004, 7005)
      |> set_char_var(:DANC_Q, 8)
      |> close()
      |> warp("job_duncer", 105, 109)
    end
  end

  defp explain_dance_test(ctx) do
    ctx
    |> mes("[Bijou]")
    |> mes(
      "First of all, each person gets ^CD68891 minute^000000 for the test, and everyone dances ^CD6889one at a time^000000. Don't worry if you've never danced before~"
    )
    |> next()
    |> mes("[Bijou]")
    |> mes(
      "Once you enter the testing area, you will see the stage. First, ^CD6889change your camera angle so that it faces forward^000000. It will probably work if you ^CD6889double-click on the right mouse button^000000."
    )
    |> next()
    |> mes("[Bijou]")
    |> mes(
      "If you don't reset your camera angle, you may get the ^CD6889Up, Down, Left, Right^000000 commands confused."
    )
    |> next()
    |> mes("[Bijou]")
    |> mes(
      "Wait for your turn in the ^CD6889waiting room^000000. If the person in front of you fails, or if it's your turn in line, your test will begin."
    )
    |> next()
    |> mes("[Bijou]")
    |> mes(
      "If there are a lot of people, not everyone might fit in the waiting room. If that's the case, just create an orderly line~"
    )
    |> next()
    |> mes("[Bijou]")
    |> mes(
      "When the test begins, the music will be broadcast, as well as the direction in which you should move. Just follow the instructions and move your legs."
    )
    |> next()
    |> mes("[Bijou]")
    |> mes(
      "Remember, ^CD6889you will be disqualified if you don't perform the steps with the right timing^000000. Be careful, the test is very strict~"
    )
    |> close()
  end

  defp change_to_dancer(ctx) do
    ctx =
      ctx
      |> mes("[Bijou]")
      |> mes("Oh my...")
      |> mes("I saw your")
      |> mes("dance earlier.")
      |> mes("You were great!")
      |> next()
      |> mes("[Bijou]")
      |> mes(
        "Your performance shows that you are than qualified to become a Dancer. Well then, let me change your job."
      )
      |> next()
      |> mes("[Bijou]")
      |> mes(
        "With the blessing of our goddess, you shall be reborn as a Dancer. From now on, no one will leave your presense without a smile~"
      )
      |> next()

    job_level_before_change = job_level(ctx)

    {ctx, _} =
      ctx
      |> mes("[Bijou]")
      |> completequest(7006)
      |> jobchange(:dancer)
      |> FClearjobvar.call([])

    ctx =
      ctx
      |> mes("Ooh...!")
      |> mes("You look great")
      |> mes("as a Dancer~")
      |> mes("Congratulations!")
      |> next()
      |> mes("[Bijou]")
      |> mes("Here's a small")
      |> mes("gift from me.")
      |> mes("Please take it.")
      |> mes("May your performances always bring joy to your audience~")

    if job_level_before_change == 50 do
      ctx |> give_item(1953, 1) |> close()
    else
      ctx |> give_item(1950, 1) |> close()
    end
  end

  defp mes_lines(ctx, lines), do: Enum.reduce(lines, ctx, &mes(&2, &1))
end
