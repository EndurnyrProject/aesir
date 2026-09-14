defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.Novice.Novice.Hanson do
  @moduledoc """
  Runs the pre-renewal novice personality test and sends novices to their first job town.

  ## Behavior

  - Offers an optional personality test after Bruce's job guidance.
  - Scores answers to recommend a first job class and grants training rewards.
  - Offers job-town travel or departure without taking the test.

  ## Credits

  - Original from rAthena, authors: Dr.Evil and MasterOfMuppets.
  - Elixir adaptation: transpiled and refactored by an LLM.
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "new_1-4",
        x: 100,
        y: 29,
        dir: 1,
        sprite: 46,
        name: "Hanson",
        scope: :pre_renewal,
        unique_name: "Hanson#nv"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{909, 400}]) == 0 -> too_heavy(ctx)
      get_char_var(ctx, :nov_3_swordman, 0) == 20 -> offer_personality_test(ctx)
      get_char_var(ctx, :nov_3_swordman, 0) == 40 -> send_finished_novice(ctx)
      true -> introduce_hanson(ctx)
    end
  end

  defp too_heavy(ctx) do
    ctx
    |> mes("[Hanson]")
    |> mes(
      "All of the items you are carrying must be quite a burden. Where did you get so much things? Please lighten your weight by getting rid of things you don't need."
    )
    |> close()
  end

  defp introduce_hanson(ctx) do
    name = char_name(ctx, 0)

    ctx
    |> mes("[Hanson]")
    |> mes("Hello, you")
    |> mes("must be #{name}.")
    |> next()
    |> mes("[Hanson]")
    |> mes("I am Hanson,")
    |> mes("the person in")
    |> mes("charge of the")
    |> mes("personality test.")
    |> next()
    |> mes("[Hanson]")
    |> mes("Please speak")
    |> mes("to Bruce for")
    |> mes("'Class Explanation'")
    |> mes("before we begin your")
    |> mes("test. Thank you.")
    |> close()
  end

  defp offer_personality_test(ctx) do
    name = char_name(ctx, 0)

    {ctx, choice} =
      ctx
      |> mes("[Hanson]")
      |> mes("Good day,")
      |> mes("^A62A2A#{name}'^000000.")
      |> mes("You've made quite")
      |> mes("an effort to come here.")
      |> next()
      |> mes("[Hanson]")
      |> mes("This final test in the Training Grounds is a personality test,")
      |> mes("but it's not a mandatory course.")
      |> next()
      |> mes("[Hanson]")
      |> mes("However, there are some benefits")
      |> mes(
        "to taking this test. When you take this test, you'll receive many health items which will help you when you join the Ragnarok Online community."
      )
      |> next()
      |> mes("[Hanson]")
      |> mes(
        "Secondly, after you finish the course we will suggest the job class that seems best suited to your personality and teleport you to a town where you can change into the job we suggested."
      )
      |> next()
      |> mes("[Hanson]")
      |> mes("Now...")
      |> mes("What would")
      |> mes("you like to do?")
      |> next()
      |> mes("[Hanson]")
      |> mes(
        "Do you wish to start Ragnarok Online immediately, or take this personality test course first?"
      )
      |> next()
      |> select(["I'll take the course.", "Let me start Ragnarok Online please."])

    case choice do
      1 -> run_personality_test(ctx)
      2 -> send_to_midgard(ctx)
      _ -> choose_job(ctx)
    end
  end

  defp run_personality_test(ctx) do
    ctx
    |> word_association_questions()
    |> yes_or_no_questions()
    |> situation_questions()
    |> finish_personality_test()
  end

  defp word_association_questions(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Hanson]")
      |> mes("Excellent choice!")
      |> mes(
        "You're supposed to take every training course if you really want to be a well-prepared player!"
      )
      |> next()
      |> mes("[Hanson]")
      |> mes("Alright, let me start the 1st personality test. Please relax")
      |> mes("and take it easy.")
      |> next()
      |> mes("[Hanson]")
      |> mes(
        "Remember, this test is only to check your personality, there is no set standard for right and wrong. Now! Let's begin the test!"
      )
      |> next()
      |> mes("[Hanson]")
      |> mes("Please choose the word")
      |> mes("that best matches you from")
      |> mes("among the following.")
      |> next()
      |> select(["Study", "Exercise", "Public service", "Violence"])

    ctx =
      case answer do
        1 -> increment_scores(ctx, [:magician_p])
        2 -> increment_scores(ctx, [:thief_p, :swordman_p])
        3 -> increment_scores(ctx, [:acolyte_p])
        4 -> increment_scores(ctx, [:thief_p])
        _ -> ctx
      end

    {ctx, answer} = select(ctx, ["Change", "Conserve"])

    ctx =
      case answer do
        1 -> increment_scores(ctx, [:magician_p])
        2 -> increment_scores(ctx, [:acolyte_p])
        _ -> ctx
      end

    {ctx, answer} = select(ctx, ["Consumer", "Seller", "Producer"])

    ctx =
      case answer do
        1 -> increment_scores(ctx, [:swordman_p, :thief_p, :acolyte_p])
        2 -> increment_scores(ctx, [:merchant_p])
        3 -> increment_scores(ctx, [:magician_p])
        _ -> ctx
      end

    {ctx, answer} = select(ctx, ["Celebrity", "Prudence"])

    ctx =
      case answer do
        1 -> increment_scores(ctx, [:thief_p])
        2 -> increment_scores(ctx, [:archer_p])
        _ -> ctx
      end

    {ctx, answer} = select(ctx, ["Theory", "Experience"])

    ctx =
      case answer do
        1 -> increment_scores(ctx, [:magician_p])
        2 -> increment_scores(ctx, [:swordman_p])
        _ -> ctx
      end

    {ctx, answer} = select(ctx, ["The Past", "Reality", "The Future"])

    case answer do
      1 -> increment_scores(ctx, [:archer_p])
      2 -> increment_scores(ctx, [:merchant_p, :thief_p])
      3 -> increment_scores(ctx, [:magician_p])
      _ -> ctx
    end
  end

  defp yes_or_no_questions(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Hanson]")
      |> mes("Please answer")
      |> mes("'Yes' or 'No' to")
      |> mes("the following questions.")
      |> next()
      |> mes("[Hanson]")
      |> mes("I'd rather die")
      |> mes("than live submissively.")
      |> next()
      |> select(["Yes.", "No."])

    ctx = score_binary_answer(ctx, answer, [:swordman_p], [:thief_p, :merchant_p])

    {ctx, answer} =
      ctx
      |> mes("[Hanson]")
      |> mes("You are often upset")
      |> mes("to see someone better")
      |> mes("than you.")
      |> next()
      |> select(["Yes.", "No."])

    ctx = score_binary_answer(ctx, answer, [:merchant_p], [:acolyte_p])

    {ctx, answer} =
      ctx
      |> mes("[Hanson]")
      |> mes("You don't mind")
      |> mes("exploring dangerous")
      |> mes("places.")
      |> next()
      |> select(["Yes.", "No."])

    ctx = score_binary_answer(ctx, answer, [:swordman_p], [:magician_p])

    {ctx, answer} =
      ctx
      |> mes("[Hanson]")
      |> mes("You are")
      |> mes("a leader-type")
      |> mes("person.")
      |> next()
      |> select(["Yes.", "No."])

    ctx = score_binary_answer(ctx, answer, [:swordman_p], [:archer_p])

    {ctx, answer} =
      ctx
      |> mes("[Hanson]")
      |> mes("While exploring")
      |> mes("a dungeon, you run")
      |> mes("into a dead end.")
      |> next()
      |> mes("[Hanson]")
      |> mes(
        "However, there is a sign that reads 'Do Not Push' next to a stone that looks strangely like a button on the wall next to you."
      )
      |> next()
      |> mes("[Hanson]")
      |> mes("Do you give in")
      |> mes("to the urge to push")
      |> mes("this button?")
      |> next()
      |> select(["Yes.", "No."])

    ctx = score_binary_answer(ctx, answer, [:thief_p], [:swordman_p])

    {ctx, answer} =
      ctx
      |> mes("[Hanson]")
      |> mes("You often see")
      |> mes("things that don't exist.")
      |> next()
      |> select(["Yes.", "No."])

    ctx = score_binary_answer(ctx, answer, [:acolyte_p], [:magician_p])

    {ctx, answer} =
      ctx
      |> mes("[Hanson]")
      |> mes("If you fell off")
      |> mes("a cliff, you'd feel")
      |> mes("like you were flying.")
      |> next()
      |> select(["Yes.", "No."])

    ctx = score_binary_answer(ctx, answer, [:acolyte_p], [:magician_p])

    {ctx, answer} =
      ctx
      |> mes("[Hanson]")
      |> mes("Money talks.")
      |> next()
      |> select(["Yes.", "No."])

    score_binary_answer(ctx, answer, [:merchant_p], [:archer_p])
  end

  defp situation_questions(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Hanson]")
      |> mes(
        "Now, let me give you some different questions. Please relax and take it easy, and choose the answer that suits you best."
      )
      |> next()
      |> mes("[Hanson]")
      |> mes("As you check")
      |> mes("your tight schedule....")
      |> next()
      |> select([
        "You feel like a robot.",
        "You are proud and satisfied.",
        "Schedule? What schedule?"
      ])

    ctx =
      case answer do
        1 -> increment_scores(ctx, [:swordman_p, :thief_p])
        2 -> increment_scores(ctx, [:acolyte_p, :magician_p])
        3 -> increment_scores(ctx, [:archer_p, :merchant_p])
        _ -> ctx
      end

    {ctx, answer} =
      ctx
      |> mes("[Hanson]")
      |> mes("As you go window shopping,")
      |> mes(
        "you find a really interesting item in a store, debating whether or not to buy it. Before making"
      )
      |> mes("a purchase, the first thing")
      |> mes("you do is...")
      |> next()
      |> select([
        "Consider if you need it.",
        "Check the price.",
        "Don't think twice, just buy it!"
      ])

    ctx =
      case answer do
        1 -> increment_scores(ctx, [:archer_p])
        2 -> increment_scores(ctx, [:merchant_p])
        3 -> increment_scores(ctx, [:thief_p])
        _ -> ctx
      end

    {ctx, answer} =
      ctx
      |> mes("[Hanson]")
      |> mes("Fill in the blank:")
      |> mes("You ^3355FF_____^000000")
      |> mes("competing with other people...")
      |> next()
      |> select(["don't mind...", "don't like...", "don't care about..."])

    ctx =
      case answer do
        1 -> increment_scores(ctx, [:merchant_p])
        2 -> increment_scores(ctx, [:thief_p])
        3 -> increment_scores(ctx, [:acolyte_p, :swordman_p])
        _ -> ctx
      end

    {ctx, answer} =
      ctx
      |> mes("[Hanson]")
      |> mes(
        "You're responsible for a task that requires you to cooperate with many people. If you handle it alone, it will take a lot of effort and time."
      )
      |> next()
      |> mes("[Hanson]")
      |> mes(
        "But if you cooperate with others, it will be simple and an enjoyable task. You would... "
      )
      |> next()
      |> select(["Handle it myself, even if it's hard.", "Ask friends to help."])

    ctx = score_binary_answer(ctx, answer, [:magician_p], [:merchant_p])

    {ctx, answer} =
      ctx
      |> mes("[Hanson]")
      |> mes("You happen to")
      |> mes("find a girl who")
      |> mes("fainted on the street.")
      |> mes("What would you do?")
      |> next()
      |> select([
        "Carry her to a hospital.",
        "Assess the situation before taking action.",
        "Just ignore it."
      ])

    ctx =
      case answer do
        1 -> increment_scores(ctx, [:acolyte_p])
        2 -> increment_scores(ctx, [:swordman_p, :archer_p])
        3 -> increment_scores(ctx, [:magician_p, :thief_p, :merchant_p])
        _ -> ctx
      end

    {ctx, answer} =
      ctx
      |> mes("[Hanson]")
      |> mes("You happen to")
      |> mes("pick up 'Clothing.'")
      |> mes("What would you do?")
      |> next()
      |> select([
        "Check the brand.",
        "Wonder who lost it.",
        "Finder's keepers!",
        "Leave it where it was."
      ])

    ctx =
      case answer do
        1 -> increment_scores(ctx, [:merchant_p])
        2 -> increment_scores(ctx, [:acolyte_p])
        3 -> increment_scores(ctx, [:merchant_p, :thief_p])
        4 -> increment_scores(ctx, [:magician_p])
        _ -> ctx
      end

    {ctx, answer} =
      ctx
      |> mes("[Hanson]")
      |> mes(
        "You happened to accidentally slip your tongue in the middle of a conversation. How do you cope with this situation?"
      )
      |> next()
      |> select([
        "Pretend it's a joke.",
        "Change the subject.",
        "Analyze it.",
        "Apologize honestly."
      ])

    ctx =
      case answer do
        1 -> increment_scores(ctx, [:thief_p])
        2 -> increment_scores(ctx, [:swordman_p])
        3 -> increment_scores(ctx, [:magician_p])
        4 -> increment_scores(ctx, [:acolyte_p])
        _ -> ctx
      end

    {ctx, answer} =
      ctx
      |> mes("[Hanson]")
      |> mes(
        "You're on a trip with your beloved. Your significant other then asks you to buy a souvenir that's not particularly good. What do you do?"
      )
      |> next()
      |> select(["Buy the item for her/him.", "Say 'no.'", "Promise it for next time."])

    case answer do
      1 -> increment_scores(ctx, [:swordman_p])
      2 -> increment_scores(ctx, [:merchant_p])
      3 -> increment_scores(ctx, [:thief_p])
      _ -> ctx
    end
  end

  defp finish_personality_test(ctx) do
    ctx =
      ctx
      |> mes("[Hanson]")
      |> mes(
        "Okay~! That's all for the test. You've finished all the Training Grounds courses. Congratulations!"
      )
      |> next()
      |> mes("[Hanson]")
      |> mes(
        "I've prepared some items for you since you passed the personality test. Please take them, you've earned it."
      )
      |> next()
      |> set_char_var(:nov_3_swordman, 40)
      |> give_item(501, 4)
      |> give_item(503, 2)
      |> give_item(506, 2)
      |> next()
      |> mes("[Hanson]")
      |> mes(
        "Now, we will recommend a suitable job for you after analyzing the results of your personality test. Please wait a moment."
      )
      |> next()
      |> mes("[Hanson]")
      |> mes("...")
      |> next()
      |> mes("[Hanson]")
      |> mes("...")
      |> mes("......")
      |> next()
      |> mes("[Hanson]")
      |> mes("Here's the")
      |> mes("final result")
      |> mes("of your test.")
      |> next()

    {ctx, recommendation} = choose_recommendation(ctx)
    present_recommendation(ctx, recommendation)
  end

  defp choose_recommendation(ctx) do
    candidates = [
      {:swordman_p, 1},
      {:magician_p, 2},
      {:merchant_p, 3},
      {:thief_p, 4},
      {:archer_p, 5},
      {:acolyte_p, 6}
    ]

    {_score, recommendation} =
      Enum.reduce(candidates, {-1, 1}, fn {score_name, job}, {best_score, _job} = best ->
        score = get_local(ctx, score_name, 0)
        if score >= best_score, do: {score, job}, else: best
      end)

    {set_local(ctx, :job_c, recommendation), recommendation}
  end

  defp present_recommendation(ctx, 1), do: recommend_swordman(ctx)
  defp present_recommendation(ctx, 2), do: recommend_mage(ctx)
  defp present_recommendation(ctx, 3), do: recommend_merchant(ctx)
  defp present_recommendation(ctx, 4), do: recommend_thief(ctx)
  defp present_recommendation(ctx, 5), do: recommend_archer(ctx)
  defp present_recommendation(ctx, 6), do: recommend_acolyte(ctx)
  defp present_recommendation(ctx, _recommendation), do: send_to_midgard(ctx)

  defp recommend_swordman(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hanson]")
      |> mes("Although you're very straight forward and simple minded, you")
      |> mes("have a strong will and want to be an important person for this world.")
      |> next()
      |> mes("[Hanson]")
      |> mes("You're also always")
      |> mes("trying to protect the weak.")
      |> next()
      |> mes("[Hanson]")
      |> mes(
        "For you, who has your own will, ^696969Swordman^000000 class is the most suitable job."
      )
      |> next()
      |> mes("[Hanson]")
      |> mes(
        "So would you like to accept our recommendation, or would you like to choose a job on your own?"
      )
      |> next()
      |> select(["Swordman!", "My own choice!"])

    case choice do
      1 -> accept_swordman(ctx)
      2 -> choose_job(ctx)
      _ -> send_to_midgard(ctx)
    end
  end

  defp accept_swordman(ctx) do
    name = char_name(ctx, 0)

    ctx
    |> mes("[Hanson]")
    |> mes("That's a great choice!")
    |> mes("After you receive all the supplies, I will teleport you to the Swordman Association.")
    |> next()
    |> mes("^660000List of Supplies^000000")
    |> mes("^0000335 Free Ticket for Kafra Storage^000000")
    |> mes("^0000335 Free Ticket for Kafra Transportation^000000")
    |> mes("^0000331 Falchion^000000")
    |> mes("^0000337 Phracon^000000")
    |> next()
    |> set_char_var(:nov_3_swordman, 40)
    |> give_item(7059, 5)
    |> give_item(7060, 5)
    |> give_item(1104, 1)
    |> give_item(1010, 7)
    |> mes("[Hanson]")
    |> mes(
      "Please check your inventory to see if you have received all the supplies listed. Let me briefly inform you about the items you've received."
    )
    |> next()
    |> mes("[Hanson]")
    |> mes(
      "Free tickets for Kafra storage and transportation can be used for Kafra storage and teleport services."
    )
    |> next()
    |> mes("[Hanson]")
    |> mes(
      "'Zeny' is the currency of Midgard. 'Falchion' is a weapon that will be very useful once you become a Swordman."
    )
    |> next()
    |> mes("[Hanson]")
    |> mes(
      "'Phracon' is an ore which can be used to upgrade lvl 1 weapons. To strengthen your Falchion with this Phracon, please visit a forge in one of the towns."
    )
    |> next()
    |> mes("[Hanson]")
    |> mes(
      "The town you will be sent to is called Izlude which is a satellite of Prontera. The Swordman Association is located in the West of town. Please remember this."
    )
    |> next()
    |> mes("[Hanson]")
    |> mes("You will now")
    |> mes("be teleported.")
    |> mes("Good luck,")
    |> mes("^A62A2A#{name}^000000")
    |> mes("and farewell.")
    |> close()
    |> clear_training_vars()
    |> savepoint("izlude", 93, 104)
    |> warp("izlude_in", 74, 167)
  end

  defp recommend_mage(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hanson]")
      |> mes(
        "You enjoy analyzing things around you, and you're very independent. You have use insightful judgment and you can be very shy and logical."
      )
      |> next()
      |> mes("[Hanson]")
      |> mes(
        "For you, the observative intellectual, ^696969Mage^000000 is the most suitable job."
      )
      |> next()
      |> mes("[Hanson]")
      |> mes(
        "So, would you like to accept our recommendation or would you like to choose a job on your own?"
      )
      |> next()
      |> select(["Mage!", "My own choice!"])

    case choice do
      1 -> accept_mage(ctx)
      2 -> choose_job(ctx)
      _ -> send_to_midgard(ctx)
    end
  end

  defp accept_mage(ctx) do
    name = char_name(ctx, 0)

    ctx
    |> mes("[Hanson]")
    |> mes("That's a great choice!")
    |> mes("After you receive all the supplies, I'll teleport you to the Mage town.")
    |> next()
    |> mes("^660000List of Supplies^000000")
    |> mes("^0000335 Free Ticket for Kafra Storage^000000")
    |> mes("^0000335 Free Ticket for Kafra Transportation^000000")
    |> mes("^0000331 Rod^000000")
    |> mes("^0000331 Cutter^000000")
    |> mes("^0000337 Phracon^000000")
    |> next()
    |> set_char_var(:nov_3_swordman, 40)
    |> give_item(7059, 5)
    |> give_item(7060, 5)
    |> give_item(1601, 1)
    |> give_item(1204, 1)
    |> give_item(1010, 7)
    |> mes("[Hanson]")
    |> mes(
      "Please check your inventory to see if you have received all the supplies listed. Let me briefly inform you about the items you've received."
    )
    |> next()
    |> mes("[Hanson]")
    |> mes(
      "Free tickets for Kafra storage and transportation can be used for Kafra storage and teleport services."
    )
    |> next()
    |> mes("[Hanson]")
    |> mes(
      "'Zeny' is the currency of Midgard. That 'Cutter' has been given to you so that you can fight monsters before you become a Mage."
    )
    |> next()
    |> mes("[Hanson]")
    |> mes(
      "Once you become a Mage, you can use the 'Rod' that has been given to you. It will be very useful during your early days as a Mage."
    )
    |> next()
    |> mes("[Hanson]")
    |> mes(
      "'Phracon' is an ore which can be used to upgrade lvl 1 weapons. To strengthen your Level 1 weapons with this Phracon, please visit a forge in one of the towns."
    )
    |> next()
    |> mes("[Hanson]")
    |> mes("The town you will arrive is named 'Geffen'.")
    |> mes("The mage academy is located in the Northwest part in town. Please remember this.")
    |> next()
    |> mes("[Hanson]")
    |> mes("You'll now be teleported.")
    |> mes("Good luck, ^A62A2A#{name}^000000 and farewell.")
    |> close()
    |> clear_training_vars()
    |> savepoint("geffen", 119, 37)
    |> warp("geffen_in", 163, 98)
  end

  defp recommend_merchant(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hanson]")
      |> mes(
        "You're very willful and very well organized. You've already set a goal in life and have become very responsible for your actions."
      )
      |> next()
      |> mes("[Hanson]")
      |> mes(
        "Because of your drive and desire to succeed, ^696969Merchant^000000 is the most suitable job for you."
      )
      |> next()
      |> mes("[Hanson]")
      |> mes(
        "So, would you like to accept our recommendation or would you like to choose a job on your own?"
      )
      |> next()
      |> select(["Merchant!", "My own choice!"])

    case choice do
      1 -> accept_merchant(ctx)
      2 -> choose_job(ctx)
      _ -> send_to_midgard(ctx)
    end
  end

  defp accept_merchant(ctx) do
    name = char_name(ctx, 0)

    ctx
    |> mes("[Hanson]")
    |> mes("That's a great choice!")
    |> mes("After you receive all the supplies, I will teleport you to the merchant town.")
    |> next()
    |> mes("^660000List of Supplies^000000")
    |> mes("^0000334 Free Ticket for Kafra Storage^000000")
    |> mes("^0000334 Free Ticket for Kafra Transportation^000000")
    |> mes("^0000334 Free Ticket for the Cart Service^000000")
    |> mes("^0000331 Battle Axe^000000")
    |> mes("^0000337 Phracon^000000")
    |> next()
    |> set_char_var(:nov_3_swordman, 40)
    |> give_item(7059, 4)
    |> give_item(7060, 4)
    |> give_item(7061, 4)
    |> give_item(1351, 1)
    |> give_item(1010, 7)
    |> mes("[Hanson]")
    |> mes(
      "Please check your inventory to see if you have received all the supplies listed. Let me briefly inform you about the items you've received."
    )
    |> next()
    |> mes("[Hanson]")
    |> mes(
      "Free tickets for Kafra storage and transportation can be used for Kafra storage and teleport services."
    )
    |> next()
    |> mes("[Hanson]")
    |> mes(
      "'Zeny' is the currency of Midgard. 'Battle Axe' will come in handy once you become a Merchant."
    )
    |> next()
    |> mes("[Hanson]")
    |> mes(
      "'Phracon' is an ore which can be used to upgrade lvl 1 weapons. To strengthen your Battle Axe with this Phracon, please visit a forge in one of the towns."
    )
    |> next()
    |> mes("[Hanson]")
    |> mes(
      "The town you will be sent to is named Alberta. The Merchant Guild is located to the SouthWest within Alberta. Please remember this."
    )
    |> next()
    |> mes("[Hanson]")
    |> mes("You will now")
    |> mes("be teleported.")
    |> mes("Good luck,")
    |> mes("^A62A2A#{name}^000000")
    |> mes("and farewell.")
    |> close()
    |> clear_training_vars()
    |> savepoint("alberta", 30, 232)
    |> warp("alberta_in", 62, 44)
  end

  defp recommend_thief(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hanson]")
      |> mes("Carpe diem:")
      |> mes("Seize the day.")
      |> mes("That's how you live.")
      |> next()
      |> mes("[Hanson]")
      |> mes("From your natural curiosity")
      |> mes("comes a happy-go-lucky sense of adventure, and a desire to explore.")
      |> next()
      |> mes("[Hanson]")
      |> mes("For someone like you,")
      |> mes("^696969Thief^000000 is the most suitable job.'")
      |> next()
      |> mes("[Hanson]")
      |> mes(
        "So, would you like to accept our recommendation or would you like to choose a job on your own?"
      )
      |> next()
      |> select(["Thief!", "My own choice!"])

    case choice do
      1 -> accept_thief(ctx)
      2 -> choose_job(ctx)
      _ -> send_to_midgard(ctx)
    end
  end

  defp accept_thief(ctx) do
    name = char_name(ctx, 0)

    ctx
    |> mes("[Hanson]")
    |> mes("That's a great choice!")
    |> mes("After you receive all the supplies, I'll teleport you to the Thief town.")
    |> next()
    |> mes("^660000List of Supplies^000000")
    |> mes("^0000335 Free Ticket for Kafra Storage^000000")
    |> mes("^0000335 Free Ticket for Kafra Transportation^000000")
    |> mes("^0000331 Main Gauche^000000")
    |> mes("^0000337 Phracon^000000")
    |> next()
    |> set_char_var(:nov_3_swordman, 40)
    |> give_item(7059, 5)
    |> give_item(7060, 5)
    |> give_item(1207, 1)
    |> give_item(1010, 7)
    |> mes("[Hanson]")
    |> mes(
      "Please check your inventory to see if you have received all the supplies listed. Let me briefly inform you about the items you've received."
    )
    |> next()
    |> mes("[Hanson]")
    |> mes(
      "Free tickets for Kafra storage and transportation can be used for Kafra storage and teleport services."
    )
    |> next()
    |> mes("[Hanson]")
    |> mes(
      "'Zeny' is the currency of Midgard. 'Main Gauche' is a weapon that will be very useful once you become a Thief."
    )
    |> next()
    |> mes("[Hanson]")
    |> mes(
      "'Phracon' is an ore which can be used to upgrade lvl 1 weapons. To strengthen your Main Gauche with this Phracon, please visit a forge in one of the towns."
    )
    |> next()
    |> mes("[Hanson]")
    |> mes(
      "The town you will be sent to is named Morocc. The Thief Guild is in the first underground floor of the pyramid NorthWest of Morocc. Remember this."
    )
    |> next()
    |> mes("[Hanson]")
    |> mes("You will now")
    |> mes("be teleported.")
    |> mes("Good luck,")
    |> mes("^A62A2A#{name}^000000")
    |> mes("and farewell.")
    |> close()
    |> savepoint("morocc", 150, 99)
    |> warp("moc_ruins", 155, 44)
  end

  defp recommend_archer(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hanson]")
      |> mes(
        "You always try to understand other people, even though they are strange. You expect others to try to understand you."
      )
      |> next()
      |> mes("[Hanson]")
      |> mes(
        "You refuse to be a ordinary person as you persue your dream. As a person sensitive to nature, ^696969Archer^000000 is the most suitable job for you."
      )
      |> next()
      |> mes("[Hanson]")
      |> mes(
        "So, would you like to accept our recommendation or would you like to choose a job on your own?"
      )
      |> next()
      |> select(["Archer!", "My own choice!"])

    case choice do
      1 -> accept_archer(ctx)
      2 -> choose_job(ctx)
      _ -> send_to_midgard(ctx)
    end
  end

  defp accept_archer(ctx) do
    name = char_name(ctx, 0)

    ctx
    |> mes("[Hanson]")
    |> mes("That's a great choice!")
    |> mes("After you receive all the supplies, I'll teleport you to the Archer town.")
    |> next()
    |> mes("^660000List of Supplies^000000")
    |> mes("^0000335 Free Ticket for Kafra Storage^000000")
    |> mes("^0000335 Free Ticket for Kafra Transportation^000000")
    |> mes("^0000331 Composite Bow^000000")
    |> mes("^0000337 Phracon^000000")
    |> next()
    |> set_char_var(:nov_3_swordman, 40)
    |> give_item(7059, 5)
    |> give_item(7060, 5)
    |> give_item(1704, 1)
    |> give_item(1010, 7)
    |> mes("[Hanson]")
    |> mes(
      "Please check your inventory to see if you have received all the supplies listed. Let me briefly inform you about the items you've received."
    )
    |> next()
    |> mes("[Hanson]")
    |> mes(
      "Free tickets for Kafra storage and transportation can be used for Kafra storage and teleport services."
    )
    |> next()
    |> mes("[Hanson]")
    |> mes(
      "'Zeny' is the currency of Midgard. 'Composite Bow' is a weapon that will be very useful once you become an Archer."
    )
    |> next()
    |> mes("[Hanson]")
    |> mes(
      "'Phracon' is an ore which can be used to upgrade lvl 1 weapons. To strengthen your Composite Bow with this Phracon, please visit a forge in one of the towns."
    )
    |> next()
    |> mes("[Hanson]")
    |> mes(
      "The town you will be sent to is named Payon. The Archer Guild is located to the NorthWest in town. Please remember this."
    )
    |> next()
    |> mes("[Hanson]")
    |> mes("You will now")
    |> mes("be teleported.")
    |> mes("Good luck,")
    |> mes("^A62A2A#{name}^000000")
    |> mes("and farewell.")
    |> close()
    |> clear_training_vars()
    |> savepoint("payon", 70, 100)
    |> warp("payon_in02", 64, 65)
  end

  defp recommend_acolyte(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hanson]")
      |> mes(
        "You are very warm hearted and considerate, and you're willing to sacrifice your well being for the sake of others."
      )
      |> next()
      |> mes("[Hanson]")
      |> mes("You're always eager to help others, which is why you're so well liked.")
      |> next()
      |> mes("[Hanson]")
      |> mes("For you who are kind of heart, ^696969Acolyte^000000 is the most suitable job.")
      |> next()
      |> mes("[Hanson]")
      |> mes(
        "So, would you like to accept our recommendation or would you like to choose a job on your own?"
      )
      |> next()
      |> select(["Acolyte!", "My own choice!"])

    case choice do
      1 -> accept_acolyte(ctx)
      2 -> choose_job(ctx)
      _ -> send_to_midgard(ctx)
    end
  end

  defp accept_acolyte(ctx) do
    name = char_name(ctx, 0)

    ctx
    |> mes("[Hanson]")
    |> mes("That's a great choice!")
    |> mes("After you receive all the supplies, I'll teleport you behind the Sanctuary.")
    |> next()
    |> mes("^660000List of Supplies^000000")
    |> mes("^0000335 Free Ticket for Kafra Storage^000000")
    |> mes("^0000335 Free Ticket for Kafra Transportation^000000")
    |> mes("^0000331 Mace^000000")
    |> mes("^0000337 Phracon^000000")
    |> next()
    |> set_char_var(:nov_3_swordman, 40)
    |> give_item(7059, 5)
    |> give_item(7060, 5)
    |> give_item(1504, 1)
    |> give_item(1010, 7)
    |> mes("[Hanson]")
    |> mes(
      "Please check your inventory to see if you have received all the supplies listed. Let me briefly inform you about the items you've received."
    )
    |> next()
    |> mes("[Hanson]")
    |> mes(
      "Free tickets for Kafra storage and transportation can be used for Kafra storage and teleport services."
    )
    |> next()
    |> mes("[Hanson]")
    |> mes(
      "'Zeny' is the currency of Midgard. 'Mace' is a weapon that will be very useful once you become an Acolyte."
    )
    |> next()
    |> mes("[Hanson]")
    |> mes(
      "'Phracon' is an ore which can be used to upgrade lvl 1 weapons. To strengthen your Mace with this Phracon, please visit a forge in one of the towns."
    )
    |> next()
    |> mes("[Hanson]")
    |> mes(
      "You have chosen to be an Acolyte. The town you will be sent to is named Prontera. The Sanctuary is NorthEast in Prontera. Please remember this."
    )
    |> next()
    |> mes("[Hanson]")
    |> mes("You will now")
    |> mes("be teleported.")
    |> mes("Good luck,")
    |> mes("^A62A2A#{name}^000000")
    |> mes("and farewell.")
    |> close()
    |> clear_training_vars()
    |> savepoint("prontera", 117, 72)
    |> warp("prt_church", 172, 19)
  end

  defp choose_job(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hanson]")
      |> mes("I see. It's your choice.")
      |> mes(
        "There is no obligation to change to the job we recommend. Please choose the job you wish to become."
      )
      |> next()
      |> select(["Swordsman", "Mage", "Merchant", "Thief", "Archer", "Acolyte"])

    jobs = ["Swordsman", "Mage", "Merchant", "Thief", "Archer", "Acolyte"]

    ctx =
      jobs
      |> Enum.with_index(1)
      |> Enum.reduce(ctx, fn {job, index}, ctx ->
        jobs_array = Rathena.put_at(get_local(ctx, :"Jobs$", []), index, job, 0)
        set_local(ctx, :"Jobs$", jobs_array)
      end)
      |> mes("[Hanson]")
      |> mes("You have chosen")
      |> describe_job_choice(choice)
      |> next()
      |> mes("[Hanson]")
      |> mes("Let me give you")
      |> mes("some supplies. Then")
      |> mes("you will transported")
      |> mes("to the chosen town.")
      |> next()
      |> mes("^660000List of Supplies^000000")
      |> mes("^0000335 Free Ticket for Kafra Storage^000000")
      |> mes("^0000335 Free Ticket for Kafra Transportation^000000")
      |> mes("^0000331 Adventurer's Suit^000000")
      |> next()
      |> set_char_var(:nov_3_swordman, 40)
      |> give_item(7059, 5)
      |> give_item(7060, 5)
      |> give_item(2305, 1)
      |> mes("[Hanson]")
      |> mes("Please check your inventory")
      |> mes(
        "to see if you have received all the supplies listed. Let me briefly inform you about the items you've received."
      )
      |> next()
      |> mes("[Hanson]")
      |> mes(
        "Free tickets for Kafra storage and transportation can be used for Kafra storage and teleport services."
      )
      |> next()
      |> mes("[Hanson]")

    selected_job = Enum.at(get_local(ctx, :"Jobs$", []), choice, "")
    name = char_name(ctx, 0)

    ctx
    |> mes(
      "'Zeny' is the currency of Midgard. The 'Adventurer's Suit' will come in handy once you become a #{selected_job}."
    )
    |> next()
    |> mes("[Hanson]")
    |> mes("You will now")
    |> mes("be teleported.")
    |> mes("Good luck,")
    |> mes("^A62A2A#{name}^000000")
    |> mes("and farewell.")
    |> next()
    |> clear_training_vars()
    |> send_to_job_town(choice)
  end

  defp describe_job_choice(ctx, 1) do
    ctx
    |> mes("to become a Swordsman.")
    |> mes("You will be sent to")
    |> mes("the town of Izlude.")
    |> next()
    |> mes("[Hanson]")
    |> mes(
      "The Swordman Association is located to the Northwest in Izlude. Please remember this."
    )
  end

  defp describe_job_choice(ctx, 2) do
    ctx
    |> mes("to become a Mage.")
    |> mes("You will be sent to")
    |> mes("the town of Geffen.")
    |> next()
    |> mes("[Hanson]")
    |> mes("The Mage Academy is located in the NorthWest in town. Please remember this.")
  end

  defp describe_job_choice(ctx, 3) do
    ctx
    |> mes("to become a Merchant.")
    |> mes("You will be sent to")
    |> mes("the town of Alberta.")
  end

  defp describe_job_choice(ctx, 4) do
    ctx
    |> mes("to become a Thief.")
    |> mes("You will be sent to")
    |> mes("the town of Morocc.")
    |> next()
    |> mes("[Hanson]")
    |> mes(
      "The Thief guild is in the underground 1st floor of a pyramid which is NorthWest of town. Please remember this."
    )
  end

  defp describe_job_choice(ctx, 5) do
    ctx
    |> mes("to become an Archer.")
    |> mes("You will be sent to")
    |> mes("the town of Payon.")
    |> next()
    |> mes("[Hanson]")
    |> mes("The Archer Guild is located to the NorthWest in Payon. Please remember this.")
  end

  defp describe_job_choice(ctx, _choice) do
    ctx
    |> mes("to become an Acolyte.")
    |> mes("You will be sent to")
    |> mes("the town of Prontera.")
    |> next()
    |> mes("[Hanson]")
    |> mes(
      "The Prontera Sanctuary is located to the NorthEast in Prontera. Please remember this."
    )
  end

  defp send_to_job_town(ctx, 1),
    do: ctx |> savepoint("izlude", 93, 104) |> warp("izlude_in", 74, 167)

  defp send_to_job_town(ctx, 2),
    do: ctx |> savepoint("geffen", 119, 37) |> warp("geffen_in", 163, 98)

  defp send_to_job_town(ctx, 3),
    do: ctx |> savepoint("alberta", 30, 232) |> warp("alberta_in", 62, 44)

  defp send_to_job_town(ctx, 4),
    do: ctx |> savepoint("morocc", 150, 99) |> warp("moc_ruins", 155, 44)

  defp send_to_job_town(ctx, 5),
    do: ctx |> savepoint("payon", 70, 100) |> warp("payon_in02", 64, 65)

  defp send_to_job_town(ctx, _choice),
    do: ctx |> savepoint("prontera", 117, 72) |> warp("prt_church", 172, 19)

  defp send_to_midgard(ctx) do
    name = char_name(ctx, 0)

    ctx =
      ctx
      |> mes("[Hanson]")
      |> mes("I understand.")
      |> mes("Let me transport")
      |> mes("you to the world of")
      |> mes("Ragnarok Online")
      |> mes("immediately.")
      |> next()
      |> mes("[Hanson]")
      |> mes(
        "For more information and knowledge, I hope you will obtain your own experiences in Midgard."
      )
      |> next()
      |> mes("[Hanson]")
      |> mes("Lastly...")
      |> mes("I hope you will")
      |> mes("become a nice player,")
      |> mes("#{name}.")
      |> mes("Fare well.")
      |> next()
      |> set_char_var(:nov_3_swordman, 40)
      |> clear_training_vars()

    start_map = Enum.random(1..6)

    ctx
    |> set_local(:startmap, start_map)
    |> send_to_random_field(start_map, :new_novice)
  end

  defp send_finished_novice(ctx) do
    ctx =
      ctx
      |> mes("[Hanson]")
      |> mes("Hmmm...?")
      |> mes("Why are you")
      |> mes("still here?")
      |> next()
      |> mes("[Hanson]")
      |> mes("You didn't say anything, so")
      |> mes(
        "I assumed you were already gone. Since you have already finished the final test and I gave you all the supplies..."
      )
      |> next()
      |> mes("[Hanson]")
      |> mes("The only thing")
      |> mes("left to do is to lead")
      |> mes("you to Midgard~")
      |> next()
      |> clear_training_vars()

    start_map = Enum.random(1..6)

    ctx
    |> set_local(:startmap, start_map)
    |> send_to_random_field(start_map, :finished_novice)
  end

  defp send_to_random_field(ctx, 1, _origin),
    do: ctx |> savepoint("prontera", 117, 72) |> warp("prt_fild08", 170, 371)

  defp send_to_random_field(ctx, 2, _origin),
    do: ctx |> savepoint("geffen", 119, 37) |> warp("gef_fild07", 327, 188)

  defp send_to_random_field(ctx, 3, _origin),
    do: ctx |> savepoint("alberta", 30, 232) |> warp("pay_fild03", 388, 70)

  defp send_to_random_field(ctx, 4, _origin),
    do: ctx |> savepoint("morocc", 150, 99) |> warp("moc_fild07", 198, 39)

  defp send_to_random_field(ctx, 5, :new_novice),
    do: ctx |> savepoint("payon", 256, 242) |> warp("pay_fild01", 334, 354)

  defp send_to_random_field(ctx, 5, :finished_novice),
    do: ctx |> savepoint("payon", 70, 100) |> warp("pay_fild01", 334, 354)

  defp send_to_random_field(ctx, 6, _origin),
    do: ctx |> savepoint("izlude", 93, 104) |> warp("prt_fild08", 357, 212)

  defp score_binary_answer(ctx, 1, yes_scores, _no_scores),
    do: increment_scores(ctx, yes_scores)

  defp score_binary_answer(ctx, 2, _yes_scores, no_scores),
    do: increment_scores(ctx, no_scores)

  defp score_binary_answer(ctx, _answer, _yes_scores, _no_scores), do: ctx

  defp increment_scores(ctx, scores) do
    Enum.reduce(scores, ctx, fn score, ctx ->
      set_local(ctx, score, get_local(ctx, score, 0) + 1)
    end)
  end

  defp clear_training_vars(ctx) do
    ctx
    |> set_char_var(:nov_1st_cos, 0)
    |> set_char_var(:nov_2nd_cos, 0)
    |> set_char_var(:nov_3_swordman, 0)
    |> set_char_var(:nov_3_archer, 0)
    |> set_char_var(:nov_3_thief, 0)
    |> set_char_var(:nov_3_magician, 0)
    |> set_char_var(:nov_3_acolyte, 0)
    |> set_char_var(:nov_3_merchant, 0)
  end
end
