defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Crusader.Crusader do
  @moduledoc """
  Gabriel Valentine, the Crusader who gives aspiring Crusaders their knowledge test.

  ## Behavior

  - Greets Crusaders, Novices, and other non-Swordmen without offering the test.
  - Asks Swordmen on the knowledge step one of three random ten-question quizzes.
  - Passes a score of 90 or more, or 80 on a retry, and sends the candidate to Bliant Piyord.
  - Records a failed attempt so the next try counts as a retry.
  - Reminds candidates about the later steps of the Crusader job quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Black Dragon
    - Shin
    - Samuray22
    - SinSloth
    - L0ne_W0lf
    - Lupus
    - Kisuka
    - Capuche
    - Komurka
    - massdriller
    - DracoRPG
    - Vicious

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "prt_church", x: 95, y: 127, dir: 3, sprite: 745, name: "Crusader", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @undead_quiz [
    {["1. Which attribute is the most effective in atttacking the Undead?"],
     ["Neutral", "Earth", "Undead", "Holy"], 4},
    {[
       "2. If the monster is a Level 2 Undead, how much more damage does a Holy attack do compared to Fire?"
     ], ["25 %", "50 %", "75 %", "100 %"], 1},
    {["3. What item can you not get from an Evil Druid?"],
     ["Monk Hat", "Yggdrasil leaf", "White Herb", "Amulet "], 1},
    {["4. Which Undead monster", "has the highest HP?"],
     ["Ghoul", "Skeleton Prisoner", "Wraith", "Zombie Prisoner"], 4},
    {["5. Which of the following monsters is a different size than the others?"],
     ["Wraith", "Khalitzburg", "Drake", "Evil Druid"], 3},
    {["6. Which card grants you tolerance to Undead property attacks?"],
     ["Orc Skeleton Card", "Orc Zombie Card", "Ghoul Card", "Skel Worker Card"], 2},
    {["7. What was the relationship between Munak and Bongun before they passed away?"],
     [
       "Big Brother and Little Sister",
       "Childhood friends in the same village",
       "Stepbrother and sister",
       "Complete strangers"
     ], 2},
    {["8. Which of the following monsters is not aggressive?"],
     ["Soldier Skeleton", "Orc Skeleton", "Skeleton", "Skel Worker"], 3},
    {["9. What is the name of the shield in which a Munak Card has been inserted?"],
     ["Atomic Shield", "Amulet Shield", "Hypnotic Shield", "Homeroth Shield"], 2},
    {["10. Which of the following monsters does not drop Memento?"],
     ["Munak", "Ghoul", "Mummy", "Soldier Skeleton"], 1}
  ]

  @demon_quiz [
    {["1. Which of the following monsters is a different attribute than the others?"],
     ["Carat", "Wind Ghost", "Isis", "Wanderer"], 3},
    {["2. Which sword is effective in attacking Demon monsters?"],
     ["Decussate Tsurugi", "Hollowed Tsurugi", "Damned Tsurugi", "Drowsy Tsurugi"], 1},
    {["3. Which item is NOT dropped by Dokebi?"],
     ["Rough Elunium", "Golden Hammer", "Sword Mace", "Mighty Staff"], 2},
    {["4. Which Demon monster has the most HP?"], ["Giearth", "Magnolia", "Dokebi", "Marionette"],
     4},
    {["5. Which Demon monster is a different size than the others?"],
     ["Ghostring", "Whisper", "Deviruchi", "Baphomet Junior"], 1},
    {["6. Which shield reduces damage inflicted by Demon monsters?"],
     ["Satanic Shield", "Shield from Hell", "Amulet Shield", "Excellent Shield"], 2},
    {["7. Which attribute is the most effective on the Wind Ghost?"],
     ["Water", "Earth", "Fire", "Wind"], 2},
    {["8. Which monster is different from the other Demon monsters?"],
     ["Sohee", "Isis", "Dokebi", "Whisper"], 4},
    {["9. What effect does the Marionette Card have?"],
     [
       "Increase defense against Shadow attacks by 30 %",
       "Increase defense against poison attacks by 30 %",
       "Increase defense against Ghost attacks by 30 %",
       "Increase defense against Neutral attacks by 30 %"
     ], 3},
    {[
       "10. Which of the following is an effective way to react when encountering a demon monster?"
     ],
     [
       "Scream, 'Evil one, go away!'",
       "Offer your soul and get a deal.",
       "Put Holy Water on a weapon and attack.",
       "Put on a Deviruchi hat."
     ], 3}
  ]

  @skill_quiz [
    {["1. What level of 'Divine Protection' do you need to learn 'Demon Bane?'"],
     ["Level 1", "Level 2", "Level 3", "Level 4"], 3},
    {[
       "2. If your INT is 30, including INT bonuses from quipment, at level 55, how much HP does Level 5 Heal recover?"
     ], ["396", "440", "484", "528"], 2},
    {[
       "3. With Level 7 Divine Protection, by how much is your defense against the Undead increased?"
     ], ["21", "22", "23", "24"], 1},
    {[
       "4. Which of the following spears can attack Nightmare, which is endowed with the Ghost attribute?"
     ], ["Lance", "Bill Guisarme", "Cresent scythe", "Zephyrus"], 4},
    {["5. What level of 'Heal' do you need to learn 'Cure?'"],
     ["Level 1", "Level 2", "Level 3", "Level 4"], 2},
    {["6. What is the attack speed when Level 3 Cavalier Mastery is learned?"],
     [
       "70 % of normal speed",
       "80 % of normal speed",
       "90 % of normal speed",
       "100 % of normal speed"
     ], 2},
    {["7. Which of the following is not correct of the Demon Bane skill?"],
     [
       "Increase attack on Undead",
       "Only Acolytes can learn the skill",
       "When mastered, + 30 increase",
       "Passive Skill"
     ], 2},
    {["8. How much SP does Level 7 Heal use?"], ["30", "31", "33", "35"], 2},
    {["9. What status cannot be", "cured with the Cure skill?"],
     ["Curse", "Silence", "Chaos", "Blind"], 1},
    {["10. What best describes a Crusader?"],
     [
       "One preparing for matrimony.",
       "One preparing for the Holy War.",
       "One preparing consummation.",
       "One preparing potions."
     ], 2}
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Gabriel Valentine]")
    base_job = Rathena.job_id(base_job(ctx))

    cond do
      base_job == Rathena.job_id(:swordman) -> talk_to_swordman(ctx)
      base_job == Rathena.job_id(:crusader) -> greet_crusader(ctx)
      base_job == Rathena.job_id(:novice) -> greet_novice(ctx)
      true -> greet_other_job(ctx)
    end
  end

  defp greet_crusader(ctx) do
    ctx
    |> mes("Welcome, fellow Crusader.")
    |> mes("How is your training")
    |> mes("coming along?")
    |> next()
    |> mes("[Gabriel Valentine]")
    |> mes(
      "You must not forget to train everyday, and prepare for the day the Holy War will come upon us."
    )
    |> close()
  end

  defp greet_novice(ctx) do
    ctx
    |> mes("Welcome, I am a Crusader.")
    |> mes("I am preparing for the")
    |> mes("foretold Holy War")
    |> mes("that is to come.")
    |> next()
    |> mes("[Gabriel Valentine]")
    |> mes(
      "If you are interested in becoming a Crusader, you must train first as a Swordman. Come and visit us again when you believe that you have learned enough as a Swordman..."
    )
    |> next()
    |> mes("[Gabriel Valentine]")
    |> mes(
      "We are located in the Prontera Central Palace, so if you have time, it wouldn't hurt to stop by."
    )
    |> close()
  end

  defp greet_other_job(ctx) do
    ctx
    |> mes("Welcome, we are Crusaders.")
    |> mes("We are preparing for the")
    |> mes("foretold Holy War")
    |> mes("that is to come.")
    |> next()
    |> mes("[Gabriel Valentine]")
    |> mes("I hope you will train yourself in preparation for the future as well.")
    |> close()
  end

  defp talk_to_swordman(ctx) do
    case get_char_var(ctx, :CRUS_Q, 0) do
      0 -> point_to_leader(ctx)
      6 -> ctx |> introduce_test() |> run_quiz()
      7 -> ctx |> welcome_back_to_test() |> run_quiz()
      step when step in [8, 9] -> remind_next_test(ctx)
      10 -> remind_all_tests_done(ctx)
      _ -> not_my_turn(ctx)
    end
  end

  defp point_to_leader(ctx) do
    ctx
    |> mes("Welcome. We are Crusaders.")
    |> mes("We are preparing for the")
    |> mes("foretold Holy War")
    |> mes("that is to come.")
    |> next()
    |> mes("[Gabriel Valentine]")
    |> mes(
      "If you would like to become a Crusader, please speak with our leader in the Prontera Central Palace."
    )
    |> close()
  end

  defp introduce_test(ctx) do
    ctx
    |> mes("Welcome.")
    |> mes("Did you do well")
    |> mes("on those painful tests?")
    |> mes("I will be conducting your next test.")
    |> next()
    |> mes("[Gabriel Valentine]")
    |> mes(
      "My name is Gabriel Valentine. I, too, am preparing for the Holy War. For the time being, I act as guard for this church."
    )
    |> next()
    |> mes("[Gabriel Valentine]")
    |> mes(
      "I will test to see if you have acquired the knowledge that is necessary to become a Crusader."
    )
    |> mes("We can't very well win the Holy War just by swinging a sword.")
    |> next()
    |> mes("[Gabriel Valentine]")
    |> mes("I will give")
    |> mes("you 10 questions.")
    |> mes("Answer them correctly.")
    |> next()
  end

  defp welcome_back_to_test(ctx) do
    ctx
    |> mes("Welcome back~")
    |> mes("Did you prepare")
    |> mes("well for this test?")
    |> mes("Let's try again,")
    |> mes("shall we...?")
    |> next()
    |> mes("[Gabriel Valentine]")
    |> mes("Once again, I'm going")
    |> mes("to give you 10 questions")
    |> mes("Listen carefully, and")
    |> mes("choose the correct answer.")
    |> next()
  end

  defp run_quiz(ctx) do
    questions =
      case Enum.random(1..3) do
        1 -> @undead_quiz
        2 -> @demon_quiz
        _ -> @skill_quiz
      end

    {ctx, score} = ask_questions(ctx, questions)
    name = char_name(ctx, 0)

    ctx =
      ctx
      |> mes("[Gabriel Valentine]")
      |> mes("Good work~")
      |> mes("Well, first let me")
      |> mes("look at your results.")
      |> next()
      |> mes("[Gabriel Valentine]")
      |> mes(" #{name}'s score")
      |> mes("is #{score} points...")

    cond do
      score == 100 ->
        ctx |> advance_to_next_test() |> send_to_bliant("Superb! Now, it's time for")

      score == 90 ->
        ctx |> advance_to_next_test() |> send_to_bliant("Well done~ Now, it's time for")

      score == 80 and get_char_var(ctx, :CRUS_Q, 0) == 7 ->
        pass_on_retry(ctx)

      true ->
        fail_quiz(ctx)
    end
  end

  defp ask_questions(ctx, questions) do
    Enum.reduce(questions, {ctx, 0}, fn {lines, options, answer}, {ctx, score} ->
      {ctx, choice} =
        lines
        |> Enum.reduce(mes(ctx, "[Gabriel Valentine]"), &mes(&2, &1))
        |> next()
        |> select(options)

      if choice == answer, do: {ctx, score + 10}, else: {ctx, score}
    end)
  end

  defp advance_to_next_test(ctx) do
    ctx
    |> set_char_var(:CRUS_Q, 8)
    |> changequest(3011, 3013)
  end

  defp send_to_bliant(ctx, praise) do
    ctx
    |> mes(praise)
    |> mes("you to take the next test.")
    |> next()
    |> mes("[Gabriel Valentine]")
    |> mes("Go to Prontera Castle")
    |> mes("and meet Bliant Piyord.")
    |> mes("I will inform him that")
    |> mes("he will be testing you next.")
    |> close()
  end

  defp pass_on_retry(ctx) do
    ctx
    |> advance_to_next_test()
    |> mes("Seems like you prepared a lot so I'll let you pass this time.")
    |> mes("Hurry now and go take the next test.")
    |> next()
    |> mes("[Gabriel Valentine]")
    |> mes("Go to the Prontera Castle and meet Bliant Piyord.")
    |> mes("I will inform him to prepare the next test.")
    |> close()
  end

  defp fail_quiz(ctx) do
    ctx = set_char_var(ctx, :CRUS_Q, 7)

    ctx =
      if checkquest(ctx, 3011) != -1 do
        changequest(ctx, 3011, 3012)
      else
        ctx
      end

    ctx
    |> mes("Hmmm... What a pity.")
    |> mes("Go study some more and")
    |> mes("take this test again, okay?")
    |> next()
    |> mes("[Gabriel Valentine]")
    |> mes(
      "Don't stress, you need to know a lot in order to pass this test. In any case, I'll be waiting right here. When you think you're ready, come back, alright?"
    )
    |> close()
  end

  defp remind_next_test(ctx) do
    ctx
    |> mes(
      "Like I mentioned before, you should go to Prontera Castle and meet with Bliant Piyord to take your next test. Good luck, and become a Crusder soon, alright?"
    )
    |> close()
  end

  defp remind_all_tests_done(ctx) do
    ctx
    |> mes(
      "What are you still doing here? You've already completed all the tests. Go talk to our leader, you're pretty much ready to become a Crusader now."
    )
    |> next()
    |> mes("[Gabriel Valentine]")
    |> mes(
      "You will soon join us in our preparations for the Holy War. Continue to live with faith after becoming a Crusader."
    )
    |> close()
  end

  defp not_my_turn(ctx) do
    ctx
    |> mes("Mmm...?")
    |> mes("It seems that you're")
    |> mes("an aspiring Crusader...")
    |> mes("But, it's not my turn")
    |> mes("to test you quite yet.")
    |> next()
    |> mes("[Gabriel Valentine]")
    |> mes("Finish those other tests,")
    |> mes("and come to me once you're")
    |> mes("instructed. Until then,")
    |> mes("I'll see you later~")
    |> close()
  end
end
